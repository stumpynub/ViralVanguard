"""Blender pass of the auto-rig for any A-posed humanoid mesh (e.g. a generated character).

1. Turns the model to face +Z (glTF), scales it to 1.89 m and puts its feet on y = 0.
2. Fits the joints: spine / legs / head from the standard humanoid table, arms from the actual mesh
   (shoulder height, and the line from the shoulder to the fingertips for elbow and wrist).
3. Bone-heat weights on a watertight voxel proxy, transferred to the real mesh (4 influences).
4. Swings the arms down into the rig's rest pose (the one tools/rig/build_rig.gd animates from) and bakes it:
   the mesh is re-posed, the armature rest is re-applied.
5. Exports a skinned glb plus a JSON of the final joint positions for build_rig.gd.

blender -b -P tools/rig/blender_rig_any.py -- <in.glb> <out.glb> <joints.json> [facing: +x|-x|+z|-z] [decimate_ratio]
"""
import bpy, sys, json, math
import numpy as np
from mathutils import Vector, Quaternion

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, jpath = args[:3]
facing = args[3] if len(args) > 3 else "+z"
ratio = float(args[4]) if len(args) > 4 else 1.0
HEIGHT = 1.89

# glTF (x, y, z) <-> Blender (x, -z, y)
def B(p): return Vector((p[0], -p[2], p[1]))
def G(v): return (v.x, v.z, -v.y)

# standard joint heads (glTF space, +X = character's left, +Z = forward), as in build_rig.gd
J = {
    "Root": ((0, 0, 0), None), "Hips": ((0, .98, 0), "Root"), "Spine": ((0, 1.10, -.01), "Hips"), "Chest": ((0, 1.25, -.01), "Spine"),
    "UpperChest": ((0, 1.40, -.02), "Chest"), "Neck": ((0, 1.56, -.02), "UpperChest"), "Head": ((0, 1.66, 0), "Neck"),
}
for s, k in (("Left", 1), ("Right", -1)):
    J.update({
        s + "Shoulder": ((k * .07, 1.50, -.03), "UpperChest"), s + "UpperArm": ((k * .24, 1.44, -.05), s + "Shoulder"),
        s + "LowerArm": ((k * .33, 1.19, -.05), s + "UpperArm"), s + "Hand": ((k * .34, .95, 0), s + "LowerArm"),
        s + "UpperLeg": ((k * .11, .93, 0), "Hips"), s + "LowerLeg": ((k * .15, .56, .02), s + "UpperLeg"),
        s + "Foot": ((k * .20, .12, -.02), s + "LowerLeg"), s + "Toes": ((k * .21, .03, .12), s + "Foot"),
    })
CANON = {n: Vector(h) for n, (h, p) in J.items()}
TIPS = {"Head": (0, 1.89, 0), "LeftHand": (.34, .78, .07), "RightHand": (-.34, .78, .07), "LeftToes": (.21, .02, .22),
        "RightToes": (-.21, .02, .22), "Root": (0, .5, 0), "LeftShoulder": (.24, 1.44, -.05), "RightShoulder": (-.24, 1.44, -.05)}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
mesh = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh.name = "Character"
if ratio < 1.0:
    dec = mesh.modifiers.new("Decimate", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=dec.name)

# ---------------------------------------------------------------- normalise (in glTF space)
n = len(mesh.data.vertices)
co = np.empty(n * 3)
mesh.data.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
g = np.stack([co[:, 0], co[:, 2], -co[:, 1]], 1)          # Blender -> glTF
rot = {"+z": lambda p: p, "-z": lambda p: np.stack([-p[:, 0], p[:, 1], -p[:, 2]], 1),
       "+x": lambda p: np.stack([-p[:, 2], p[:, 1], p[:, 0]], 1), "-x": lambda p: np.stack([p[:, 2], p[:, 1], -p[:, 0]], 1)}[facing]
g = rot(g)
s = HEIGHT / (g[:, 1].max() - g[:, 1].min())
g *= s
g[:, 1] -= g[:, 1].min()
band = g[(g[:, 1] > 0.9) & (g[:, 1] < 1.3)]
g[:, 0] -= (band[:, 0].min() + band[:, 0].max()) / 2
g[:, 2] -= np.median(band[:, 2])
co = np.stack([g[:, 0], -g[:, 2], g[:, 1]], 1)
mesh.data.vertices.foreach_set("co", co.reshape(-1))
mesh.data.update()
# imported custom normals don't follow the vertices: drop them so normals are recomputed from the geometry
try:
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
except Exception as e:
    print("no custom normals:", e)
print("normalised: scale %.4f, %d verts" % (s, n))

# ---------------------------------------------------------------- fit the arms
fit = dict(CANON)
fit_tips = {}
for side, k in (("Left", 1), ("Right", -1)):
    arm = g[(k * g[:, 0] > 0.24) & (g[:, 1] > 0.75)]
    tip = arm[np.argmax(k * arm[:, 0] - 0.35 * arm[:, 1])]       # fingertips: far out and low
    near = arm[k * arm[:, 0] < 0.30]
    top = near[:, 1].max() if len(near) else 1.5
    sh = Vector((k * 0.22, top - 0.07, float(np.median(arm[:, 2]))))
    t = Vector(tuple(tip))
    d = t - sh
    fit[side + "Shoulder"] = Vector((k * 0.07, sh.y + 0.05, sh.z + 0.02))
    fit[side + "UpperArm"] = sh
    fit[side + "LowerArm"] = sh + d * 0.393
    fit[side + "Hand"] = sh + d * 0.749
    fit_tips[side + "Hand"] = t
    print(side, "arm fitted: shoulder", tuple(round(x, 3) for x in sh), "tip", tuple(round(x, 3) for x in t))

# ---------------------------------------------------------------- fingers: one chain for the four fingers (mitten curl) + a thumb
FINGERS = {}
for side, k in (("Left", 1), ("Right", -1)):
    w = fit[side + "Hand"]
    t = fit_tips[side + "Hand"]
    d = t - w
    L = d.length
    dn = d.normalized()
    fwd = Vector((0, 0, 1))
    fwd = (fwd - dn * fwd.dot(dn)).normalized()
    FINGERS[side + "Fingers1"] = (w + d * 0.45, side + "Hand")
    FINGERS[side + "Fingers2"] = (w + d * 0.72, side + "Fingers1")
    FINGERS[side + "Thumb1"] = (w + d * 0.22 + fwd * 0.028, side + "Hand")
    FINGERS[side + "Thumb2"] = (w + d * 0.42 + fwd * 0.05, side + "Thumb1")
    fit_tips[side + "Fingers2"] = t
    fit_tips[side + "Thumb2"] = w + d * 0.6 + fwd * 0.065
    fit_tips[side + "Hand"] = FINGERS[side + "Fingers1"][0]      # the hand bone now ends at the knuckles
for n_, (h, p) in FINGERS.items():
    J[n_] = (tuple(h), p)
    fit[n_] = h

# ---------------------------------------------------------------- armature at the fitted joints
arm_data = bpy.data.armatures.new("Armature")
armo = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(armo)
bpy.context.view_layer.objects.active = armo
bpy.ops.object.mode_set(mode="EDIT")
children = {}
for nm, (h, p) in J.items():
    if p and not nm.endswith(("Shoulder", "UpperLeg")):
        children[p] = nm
for nm, (h, p) in J.items():
    b = arm_data.edit_bones.new(nm)
    b.head = B(fit[nm])
    if nm in fit_tips:
        tail = fit_tips[nm]
    elif nm in children:
        tail = fit[children[nm]]
    elif nm.endswith("Shoulder"):
        tail = fit[nm.replace("Shoulder", "UpperArm")]
    else:
        tail = Vector(TIPS[nm])
    b.tail = B(tail)
    if (b.tail - b.head).length < 0.02:
        b.tail = b.head + Vector((0, 0, 0.05))
for nm, (h, p) in J.items():
    if p:
        arm_data.edit_bones[nm].parent = arm_data.edit_bones[p]
arm_data.edit_bones["Root"].use_deform = False
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- heat weights via a watertight proxy
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.duplicate()
proxy = bpy.context.active_object
proxy.data.remesh_voxel_size = 0.012
bpy.ops.object.voxel_remesh()
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
armo.select_set(True)
bpy.context.view_layer.objects.active = armo
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
assert len(proxy.vertex_groups) > 0, "heat weighting failed on proxy"
for nm in J:
    if nm != "Root":
        mesh.vertex_groups.new(name=nm)
dt = mesh.modifiers.new("Transfer", "DATA_TRANSFER")
dt.object = proxy
dt.use_vert_data = True
dt.data_types_verts = {"VGROUP_WEIGHTS"}
dt.vert_mapping = "POLYINTERP_NEAREST"
dt.layers_vgroup_select_src = "ALL"
dt.layers_vgroup_select_dst = "NAME"
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.modifier_apply(modifier=dt.name)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
bpy.data.objects.remove(proxy)
mesh.parent = armo
am = mesh.modifiers.new("Armature", "ARMATURE")
am.object = armo

# ---------------------------------------------------------------- swing the arms into the rest pose and bake it
bpy.ops.object.select_all(action="DESELECT")
armo.select_set(True)
bpy.context.view_layer.objects.active = armo
bpy.ops.object.mode_set(mode="POSE")
for side in ("Left", "Right"):
    for nm, nxt in ((side + "UpperArm", side + "LowerArm"), (side + "LowerArm", side + "Hand")):
        pb = armo.pose.bones[nm]
        bpy.context.view_layer.update()
        cur = (pb.tail - pb.head).normalized()                          # armature space (Blender)
        want = (B(CANON[nxt]) - B(CANON[nm])).normalized()
        q_arm = cur.rotation_difference(want)
        mw = pb.matrix.to_quaternion()
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (mw.inverted() @ q_arm @ mw) @ pb.rotation_quaternion
bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.modifier_apply(modifier=am.name)                     # bake the new pose into the mesh
bpy.ops.object.select_all(action="DESELECT")
armo.select_set(True)
bpy.context.view_layer.objects.active = armo
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply(selected=False)                         # posed = new rest
bpy.ops.object.mode_set(mode="OBJECT")
am = mesh.modifiers.new("Armature", "ARMATURE")
am.object = armo

# ---------------------------------------------------------------- final joints + export
out = {"joints": {}, "tips": {}, "parents": {}}
for nm, (h, p) in J.items():
    b = arm_data.bones[nm]
    out["joints"][nm] = [round(x, 4) for x in G(b.head_local)]
    if nm in FINGERS:
        out["parents"][nm] = p
        out["tips"][nm] = [round(x, 4) for x in G(b.tail_local)]
for nm in TIPS:
    out["tips"][nm] = [round(x, 4) for x in G(arm_data.bones[nm].tail_local)] if nm.endswith("Hand") else list(TIPS[nm])
json.dump(out, open(jpath, "w"), indent=1)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
                          export_yup=True, export_apply=False)
print("RIG ANY DONE", dst)
