"""Blender pass of the auto-rig: skin weights for sick_rig.glb.
The armour is hundreds of separate, overlapping plates, which breaks bone-heat weighting on the mesh itself.
So: voxel-remesh a watertight proxy, give the proxy automatic (heat) weights, transfer them to the real mesh,
limit to 4 influences and export a skinned glb. Joint positions match tools/rig/build_rig.gd.

blender -b -P tools/rig/blender_weights.py -- <in.glb> <out.glb> [decimate_ratio]
The optional ratio (e.g. 0.07) collapse-decimates the mesh first: the source is ~1.46M triangles, far too heavy for
web builds and for several characters on screen; the texture maps carry the fine surface detail.
"""
import bpy, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[:2]
ratio = float(args[2]) if len(args) > 2 else 1.0

# glTF (x, y, z) -> Blender (x, -z, y)
def V(x, y, z): return Vector((x, -z, y))

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
TIPS = {"Head": (0, 1.89, 0), "LeftHand": (.34, .78, .07), "RightHand": (-.34, .78, .07), "LeftToes": (.21, .02, .22),
        "RightToes": (-.21, .02, .22), "Root": (0, .5, 0), "LeftShoulder": (.24, 1.44, -.05), "RightShoulder": (-.24, 1.44, -.05)}
CHAIN_END = {}
for n, (h, p) in J.items():
    if p and not n.endswith(("Shoulder", "UpperLeg")):
        CHAIN_END[p] = h

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
mesh.name = "SickOperative"
if ratio < 1.0:
    before = len(mesh.data.polygons)
    dec = mesh.modifiers.new("Decimate", "DECIMATE")
    dec.decimate_type = "COLLAPSE"
    dec.ratio = ratio
    dec.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=dec.name)
    print("decimated %d -> %d faces" % (before, len(mesh.data.polygons)))

# armature
arm_data = bpy.data.armatures.new("Armature")
arm = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for n, (h, p) in J.items():
    b = arm_data.edit_bones.new(n)
    b.head = V(*h)
    t = TIPS.get(n) or CHAIN_END.get(n)
    b.tail = V(*t)
    if (b.tail - b.head).length < 0.02:
        b.tail = b.head + Vector((0, 0, 0.05))
for n, (h, p) in J.items():
    if p:
        arm_data.edit_bones[n].parent = arm_data.edit_bones[p]
arm_data.edit_bones["Root"].use_deform = False
bpy.ops.object.mode_set(mode="OBJECT")

# watertight proxy with heat weights
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.duplicate()
proxy = bpy.context.active_object
proxy.name = "Proxy"
proxy.data.remesh_voxel_size = 0.012
bpy.ops.object.voxel_remesh()
print("proxy faces", len(proxy.data.polygons))
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
assert len(proxy.vertex_groups) > 0, "heat weighting failed on proxy"

# transfer to the real mesh
for n in J:
    if n != "Root":
        mesh.vertex_groups.new(name=n)
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

mesh.parent = arm
am = mesh.modifiers.new("Armature", "ARMATURE")
am.object = arm
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_skins=True, export_animations=False,
                          export_yup=True, export_apply=False)
print("WEIGHTS DONE", dst)
