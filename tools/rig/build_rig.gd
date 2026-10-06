extends Node
## Auto-rigs assets/models/sick_rig.glb (an unrigged, A-posed armoured marine facing +Z, feet at y = 0).
## Builds a 23-bone humanoid skeleton (Godot SkeletonProfileHumanoid names, so animations can be retargeted onto it),
## takes 4-bone skin weights from the Blender pass, authors procedural animations and saves:
##   assets/models/sick_operative.res            skinned ArrayMesh
##   assets/materials/sick_operative.tres        its material (textures from the glb)
##   assets/animations/sick_operative.res        AnimationLibrary
##   scenes/characters/sick_operative.tscn       Skeleton3D + MeshInstance3D + AnimationPlayer
## Run: godot --headless --path . res://tools/rig/build_rig.tscn
## Other characters (rigged by tools/rig/blender_rig_any.py, which also writes their joint positions):
##   godot --headless --path . res://tools/rig/build_rig.tscn -- <name> <src.glb> <weighted.glb> <joints.json>
##   e.g. -- hunter_operative res://assets/placeholder/models/hunter.glb res://tools/rig/hunter_weighted.glb res://tools/rig/hunter_joints.json

var SRC := "res://assets/models/sick_rig.glb"
var OUT := "sick_operative"

# joint heads in character space (+X = character's left, +Z = forward); "tip" is where the last bone of a chain ends
var J := {
	"Root": [Vector3(0, 0, 0), ""],
	"Hips": [Vector3(0, 0.98, 0), "Root"],
	"Spine": [Vector3(0, 1.10, -0.01), "Hips"],
	"Chest": [Vector3(0, 1.25, -0.01), "Spine"],
	"UpperChest": [Vector3(0, 1.40, -0.02), "Chest"],
	"Neck": [Vector3(0, 1.56, -0.02), "UpperChest"],
	"Head": [Vector3(0, 1.66, 0.0), "Neck"],
	"LeftShoulder": [Vector3(0.07, 1.50, -0.03), "UpperChest"],
	"LeftUpperArm": [Vector3(0.24, 1.44, -0.05), "LeftShoulder"],
	"LeftLowerArm": [Vector3(0.33, 1.19, -0.05), "LeftUpperArm"],
	"LeftHand": [Vector3(0.34, 0.95, 0.0), "LeftLowerArm"],
	"RightShoulder": [Vector3(-0.07, 1.50, -0.03), "UpperChest"],
	"RightUpperArm": [Vector3(-0.24, 1.44, -0.05), "RightShoulder"],
	"RightLowerArm": [Vector3(-0.33, 1.19, -0.05), "RightUpperArm"],
	"RightHand": [Vector3(-0.34, 0.95, 0.0), "RightLowerArm"],
	"LeftUpperLeg": [Vector3(0.11, 0.93, 0.0), "Hips"],
	"LeftLowerLeg": [Vector3(0.15, 0.56, 0.02), "LeftUpperLeg"],
	"LeftFoot": [Vector3(0.20, 0.12, -0.02), "LeftLowerLeg"],
	"LeftToes": [Vector3(0.21, 0.03, 0.12), "LeftFoot"],
	"RightUpperLeg": [Vector3(-0.11, 0.93, 0.0), "Hips"],
	"RightLowerLeg": [Vector3(-0.15, 0.56, 0.02), "RightUpperLeg"],
	"RightFoot": [Vector3(-0.20, 0.12, -0.02), "RightLowerLeg"],
	"RightToes": [Vector3(-0.21, 0.03, 0.12), "RightFoot"],
}
var TIPS := {"Head": Vector3(0, 1.89, 0), "LeftHand": Vector3(0.34, 0.78, 0.07), "RightHand": Vector3(-0.34, 0.78, 0.07),
	"LeftToes": Vector3(0.21, 0.02, 0.22), "RightToes": Vector3(-0.21, 0.02, 0.22), "Root": Vector3(0, 0.98, 0)}

var names: Array[String] = []
var idx := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 4:
		OUT = a[0]
		SRC = a[1]
		WEIGHTED = a[2]
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(a[3]))
		var parents: Dictionary = data.get("parents", {})
		for n in data.joints:
			var v: Array = data.joints[n]
			if J.has(n):
				J[n][0] = Vector3(v[0], v[1], v[2])
			elif parents.has(n):
				J[n] = [Vector3(v[0], v[1], v[2]), parents[n]]      # finger / thumb chains
		for n in data.tips:
			var v: Array = data.tips[n]
			TIPS[n] = Vector3(v[0], v[1], v[2])
		print("rigging %s with joints from %s" % [OUT, a[3]])
	for n in J:
		idx[n] = names.size()
		names.append(n)
	var t0 := Time.get_ticks_msec()
	var mesh := _skin_mesh()
	print("skinned in %d ms" % (Time.get_ticks_msec() - t0))
	var lib := _animations()
	DirAccess.make_dir_recursive_absolute("res://assets/animations")
	DirAccess.make_dir_recursive_absolute("res://scenes/characters")
	ResourceSaver.save(lib, "res://assets/animations/%s.res" % OUT)
	_scene(mesh, load("res://assets/animations/%s.res" % OUT))
	print("RIG DONE")
	get_tree().quit()


func seg_end(n: String) -> Vector3:
	for c in J:
		if J[c][1] == n and not c.ends_with("Shoulder") and not c.ends_with("UpperLeg"):
			return J[c][0]
	return TIPS.get(n, J[n][0])


# ------------------------------------------------------------------ skin weights
## Weights come from tools/rig/blender_weights.py (bone-heat on a voxel proxy, transferred to the real mesh).
## Here the bone indices are remapped onto our skeleton, whose bone rests are axis-aligned (so the procedural
## animations below can be written as plain euler swings).
var WEIGHTED := "res://tools/rig/sick_weighted.glb"


func _skin_mesh() -> ArrayMesh:
	var scene: Node3D = load(WEIGHTED).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var sk_src: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var xf := Transform3D()
	var n: Node = mi
	while n != scene:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var src: Mesh = mi.mesh
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in verts.size():
		verts[i] = xf * verts[i]
		nrm[i] = (xf.basis * nrm[i]).normalized()
		lo = lo.min(verts[i])
		hi = hi.max(verts[i])
	print("weighted mesh bounds ", lo, " .. ", hi)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrm
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tg: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		for i in verts.size():
			var t := (xf.basis * Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])).normalized()
			tg[i * 4] = t.x; tg[i * 4 + 1] = t.y; tg[i * 4 + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = tg
	# skin bind index -> our bone index
	var remap := PackedInt32Array()
	for b in mi.skin.get_bind_count():
		var bn := String(mi.skin.get_bind_name(b))
		if bn == "":
			bn = sk_src.get_bone_name(mi.skin.get_bind_bone(b))
		assert(idx.has(bn), "unknown bone " + bn)
		remap.append(idx[bn])
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for i in bones.size():
		bones[i] = remap[bones[i]]
	# Weight transfer from the voxel proxy can leak across gaps (a hip strap picking up the hand).
	# Drop arm influences on torso / leg vertices and leg influences on arm vertices, then renormalise.
	var arm_b := {}
	var leg_b := {}
	for side in ["Left", "Right"]:
		for b in ["UpperArm", "LowerArm", "Hand"]:
			arm_b[idx[side + b]] = true
		for b in ["UpperLeg", "LowerLeg", "Foot", "Toes"]:
			leg_b[idx[side + b]] = true
	var fixed := 0
	for i in verts.size():
		# the vertex belongs to whichever limb group its strongest (Blender) influence is in
		var top := 0
		for k in range(1, 4):
			if weights[i * 4 + k] > weights[i * 4 + top]:
				top = k
		var dom := bones[i * 4 + top]
		var banned: Dictionary = leg_b if arm_b.has(dom) else (arm_b if leg_b.has(dom) or dom == idx.Hips else {})
		var sum := 0.0
		for k in 4:
			if banned.has(bones[i * 4 + k]) and weights[i * 4 + k] > 0.0:
				weights[i * 4 + k] = 0.0
				fixed += 1
			sum += weights[i * 4 + k]
		for k in 4:
			weights[i * 4 + k] /= sum
	print("cleaned %d cross-region influences" % fixed)
	# drop the few faces that physically join a glove to the thigh plate (fingertips touching the leg at rest)
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	var dropped := 0
	var group := func(v: int) -> int:
		var top := 0
		for k in range(1, 4):
			if weights[v * 4 + k] > weights[v * 4 + top]:
				top = k
		var b := bones[v * 4 + top]
		return 1 if arm_b.has(b) else (2 if leg_b.has(b) or b == idx.Hips else 0)
	for t in range(0, index.size(), 3):
		var g := [group.call(index[t]), group.call(index[t + 1]), group.call(index[t + 2])]
		if 1 in g and 2 in g:
			dropped += 1
			continue
		kept.append(index[t]); kept.append(index[t + 1]); kept.append(index[t + 2])
	arrays[Mesh.ARRAY_INDEX] = kept
	print("dropped %d arm-to-leg bridge faces" % dropped)
	fixed = _rigid_mixed_pieces(verts, kept, bones, weights, arm_b, leg_b)
	print("rebound %d vertices of pieces split between arm and leg" % fixed)
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	# surface 0 = body, surface 1 = head (helmet). First person hides surface 1 so the camera can sit at the eyes.
	var mesh := ArrayMesh.new()
	var head_b: int = idx.Head
	var body_tris := PackedInt32Array()
	var head_tris := PackedInt32Array()
	var final_index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, final_index.size(), 3):
		var in_head := false
		for c in 3:
			var v := final_index[t + c]
			var top := 0
			for k in range(1, 4):
				if weights[v * 4 + k] > weights[v * 4 + top]:
					top = k
			if bones[v * 4 + top] == head_b:
				in_head = true
		var dst := head_tris if in_head else body_tris
		dst.append(final_index[t]); dst.append(final_index[t + 1]); dst.append(final_index[t + 2])
	for tris in [body_tris, head_tris]:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _subset(arrays, tris))
	print("body tris %d, head tris %d" % [body_tris.size() / 3, head_tris.size() / 3])
	var mat: Material = load(SRC).instantiate().find_children("*", "MeshInstance3D", true, false)[0].mesh.surface_get_material(0).duplicate()
	ResourceSaver.save(mat, "res://assets/materials/%s.tres" % OUT)
	mesh.surface_set_material(0, load("res://assets/materials/%s.tres" % OUT))
	mesh.surface_set_material(1, load("res://assets/materials/%s.tres" % OUT))
	mesh.surface_set_name(0, "Body")
	mesh.surface_set_name(1, "Head")
	mesh.resource_name = OUT.to_pascal_case()
	ResourceSaver.save(mesh, "res://assets/models/%s.res" % OUT)
	scene.free()
	return load("res://assets/models/%s.res" % OUT)


## Copy of `arrays` containing only the vertices used by `tris` (re-indexed).
func _subset(arrays: Array, tris: PackedInt32Array) -> Array:
	var remap := {}
	var order := PackedInt32Array()
	var idx_out := PackedInt32Array()
	idx_out.resize(tris.size())
	for i in tris.size():
		var v := tris[i]
		if not remap.has(v):
			remap[v] = order.size()
			order.append(v)
		idx_out[i] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var widths := {Mesh.ARRAY_TANGENT: 4, Mesh.ARRAY_BONES: 4, Mesh.ARRAY_WEIGHTS: 4}
	for a in Mesh.ARRAY_MAX:
		var src = arrays[a]
		if src == null or a == Mesh.ARRAY_INDEX:
			continue
		var wdt: int = widths.get(a, 1)
		var dst = src.duplicate()
		dst.resize(order.size() * wdt)
		for i in order.size():
			for k in wdt:
				dst[i * wdt + k] = src[order[i] * wdt + k]
		out[a] = dst
	out[Mesh.ARRAY_INDEX] = idx_out
	return out


## Armour is made of separate pieces. A piece whose vertices are split between an arm and a leg would stretch
## (e.g. a thigh holster under the resting hand), so bind such pieces rigidly to their majority bone.
func _rigid_mixed_pieces(verts: PackedVector3Array, index: PackedInt32Array, bones: PackedInt32Array, weights: PackedFloat32Array, arm_b: Dictionary, leg_b: Dictionary) -> int:
	var nv := verts.size()
	var parent := PackedInt32Array()
	parent.resize(nv)
	for i in nv:
		parent[i] = i
	var find := func(x: int) -> int:
		var r := x
		while parent[r] != r:
			r = parent[r]
		while parent[x] != r:
			var nx := parent[x]
			parent[x] = r
			x = nx
		return r
	# weld UV-seam duplicates by position, then join along triangles
	var by_pos := {}
	for i in nv:
		var key := Vector3i(roundi(verts[i].x * 20000.0), roundi(verts[i].y * 20000.0), roundi(verts[i].z * 20000.0))
		if by_pos.has(key):
			parent[find.call(i)] = find.call(by_pos[key])
		else:
			by_pos[key] = i
	for t in range(0, index.size(), 3):
		var a: int = find.call(index[t])
		parent[find.call(index[t + 1])] = a
		parent[find.call(index[t + 2])] = find.call(a)
	var stats := {}   # root -> [arm count, leg count, {bone: count}]
	var doms := PackedInt32Array()
	doms.resize(nv)
	for i in nv:
		var top := 0
		for k in range(1, 4):
			if weights[i * 4 + k] > weights[i * 4 + top]:
				top = k
		var d := bones[i * 4 + top]
		doms[i] = d
		var r: int = find.call(i)
		if not stats.has(r):
			stats[r] = [0, 0, {}]
		var st: Array = stats[r]
		if arm_b.has(d): st[0] += 1
		elif leg_b.has(d) or d == idx.Hips: st[1] += 1
		st[2][d] = st[2].get(d, 0) + 1
	var target := {}
	for r in stats:
		var st: Array = stats[r]
		var tot: int = st[0] + st[1]
		if tot < 40000 and tot < nv / 4 and st[0] > 0 and st[1] > 0 and mini(st[0], st[1]) > 0.03 * tot:   # small plates only, never the whole body shell
			var want_arm: bool = st[0] > st[1]
			var best := -1
			var bc := -1
			for b in st[2]:
				if (arm_b.has(b) if want_arm else (leg_b.has(b) or b == idx.Hips)) and st[2][b] > bc:
					bc = st[2][b]
					best = b
			target[r] = best
			print("  mixed piece: %d verts (arm %d / leg %d) -> %s" % [tot, st[0], st[1], names[best]])
	var n := 0
	for i in nv:
		var r: int = find.call(i)
		if target.has(r):
			bones[i * 4] = target[r]
			weights[i * 4] = 1.0
			for k in range(1, 4):
				weights[i * 4 + k] = 0.0
			n += 1
	return n


# ------------------------------------------------------------------ scene
func _scene(mesh: ArrayMesh, lib: AnimationLibrary) -> void:
	var root := Node3D.new()
	root.name = OUT.to_pascal_case()
	root.set_script(load("res://scripts/characters/character_model.gd"))
	var sk := Skeleton3D.new()
	sk.name = "Skeleton"
	root.add_child(sk)
	for n in names:
		sk.add_bone(n)
	for n in names:
		var i: int = idx[n]
		var parent: String = J[n][1]
		if parent != "":
			sk.set_bone_parent(i, idx[parent])
		var off: Vector3 = J[n][0] - (J[parent][0] if parent != "" else Vector3.ZERO)
		sk.set_bone_rest(i, Transform3D(Basis(), off))
	sk.reset_bone_poses()
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.add_animation_library("", lib)
	ap.autoplay = "idle"
	var chest := BoneAttachment3D.new()
	chest.name = "WeaponMount"
	chest.bone_name = "UpperChest"
	sk.add_child(chest)
	var grip := Marker3D.new()
	grip.name = "Grip"
	grip.position = GRIP_IN_CHEST
	chest.add_child(grip)
	# modifiers run in child order after the animation: steady chest -> look bend (+ eye) -> limb IK -> grip lock
	var spine := SpineStabilizer.new()
	spine.name = "SpineStabilizer"
	sk.add_child(spine)
	var aim := FirstPersonHead.new()
	aim.name = "FirstPersonHead"
	sk.add_child(aim)
	var ik := FullBodyIK.new()
	ik.name = "FullBodyIK"
	sk.add_child(ik)
	var lock := GripLock.new()
	lock.name = "GripLock"
	sk.add_child(lock)
	var head_mount := BoneAttachment3D.new()
	head_mount.name = "HeadMount"
	head_mount.bone_name = "Head"
	sk.add_child(head_mount)
	var eye := Marker3D.new()
	eye.name = "Eye"
	eye.position = Vector3(0, 0.06, 0.11)
	head_mount.add_child(eye)
	for n in [sk, mi, ap, chest, grip, spine, aim, ik, lock, head_mount, eye]:
		n.owner = root
	root.set("skeleton", sk)
	root.set("animation_player", ap)
	root.set("weapon_grip", grip)
	root.set("eye", eye)
	root.set("ik", ik)
	root.set("fp_head", aim)
	root.set("spine", spine)
	root.set("grip_lock", lock)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://scenes/characters/%s.tscn" % OUT)
	root.free()


# ------------------------------------------------------------------ animations
## Where the rifle's grip sits, relative to the UpperChest joint (shared with the in-game third-person gun).
const GRIP_IN_CHEST := Vector3(-0.15, -0.16, 0.32)


func _q(e: Vector3) -> Quaternion:
	return Quaternion.from_euler(e)


## Rotation that turns rest direction `from` into `to` (shortest arc).
func _arc(from: Vector3, to: Vector3) -> Quaternion:
	return Quaternion(from.normalized(), to.normalized())


## Two-bone IK for an arm in the UpperChest rest frame: returns local rotations for UpperArm and LowerArm.
func _arm_ik(side: String, target: Vector3, pole: Vector3) -> Array:
	var s: Vector3 = J[side + "UpperArm"][0]
	var e0: Vector3 = J[side + "LowerArm"][0]
	var w0: Vector3 = J[side + "Hand"][0]
	var l1 := s.distance_to(e0)
	var l2 := e0.distance_to(w0)
	var to := target - s
	var d := minf(to.length(), l1 + l2 - 0.001)
	var dir := to.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var pv := (pole - dir * pole.dot(dir)).normalized()
	var e := s + dir * a + pv * h
	var w := s + dir * d
	var g1 := _arc(e0 - s, e - s)
	var g2 := _arc(w0 - e0, w - e)
	return [g1, g1.inverse() * g2]


func _rifle_arms() -> Dictionary:
	var c: Vector3 = J.UpperChest[0]
	var grip := c + GRIP_IN_CHEST
	var r := _arm_ik("Right", grip + Vector3(0, 0.06, -0.07), Vector3(-1, -1, -0.4))
	var l := _arm_ik("Left", grip + Vector3(0.15, -0.01, 0.27), Vector3(0.7, -1, -0.2))
	return {"RightUpperArm": r[0], "RightLowerArm": r[1], "LeftUpperArm": l[0], "LeftLowerArm": l[1],
		"RightHand": _q(Vector3(0.2, 0, 0)), "LeftHand": _q(Vector3(0.1, 0.4, -0.3))}


## Samples pose_fn(phase 0..1) -> {bone: Quaternion, "_hips": Vector3 offset} into a looping animation.
func _bake(length: float, steps: int, pose_fn: Callable, loop := true, overrides := {}) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for s in steps + 1:
		var u := float(s) / steps
		var pose: Dictionary = pose_fn.call(u)
		pose.merge(overrides, true)
		for b in pose:
			if b == "_hips":
				if not tracks.has(b):
					tracks[b] = anim.add_track(Animation.TYPE_POSITION_3D)
					anim.track_set_path(tracks[b], "Skeleton:Hips")
				anim.position_track_insert_key(tracks[b], u * length, J.Hips[0] + pose[b])
			else:
				if not tracks.has(b):
					tracks[b] = anim.add_track(Animation.TYPE_ROTATION_3D)
					anim.track_set_path(tracks[b], "Skeleton:" + b)
				anim.rotation_track_insert_key(tracks[b], u * length, pose[b])
	return anim


func _gait(u: float, thigh: float, knee: float, arm: float, elbow: float, lean: float, bob: float) -> Dictionary:
	var ph := u * TAU
	var out := {}
	for side in [["Left", 0.0], ["Right", PI]]:
		var p: float = ph + side[1]
		var th := -thigh * sin(p)                       # negative = leg forward
		var kn := 0.12 + knee * maxf(0.0, cos(p))        # bend most mid-swing
		out[side[0] + "UpperLeg"] = _q(Vector3(th, 0, 0))
		out[side[0] + "LowerLeg"] = _q(Vector3(kn, 0, 0))
		out[side[0] + "Foot"] = _q(Vector3(-(th + kn) * 0.7, 0, 0))
		out[side[0] + "UpperArm"] = _q(Vector3(arm * sin(p), 0, (0.08 if side[0] == "Left" else -0.08)))
		out[side[0] + "LowerArm"] = _q(Vector3(-elbow - 0.15 * maxf(0.0, -sin(p)), 0, 0))
	out["_hips"] = Vector3(0, -bob + bob * absf(cos(ph)), 0)
	out["Hips"] = _q(Vector3(0, 0.08 * sin(ph), 0))
	out["Spine"] = _q(Vector3(lean, -0.06 * sin(ph), 0))
	out["Chest"] = _q(Vector3(lean * 0.4, -0.04 * sin(ph), 0))
	out["Neck"] = _q(Vector3(-lean * 0.8, 0, 0))
	return out


func _idle(u: float) -> Dictionary:
	var ph := u * TAU
	return {"_hips": Vector3(0.006 * sin(ph), -0.004 + 0.004 * sin(ph * 2.0), 0),
		"Spine": _q(Vector3(0.015 * sin(ph * 2.0), 0, 0)), "Chest": _q(Vector3(0.02 * sin(ph * 2.0 + 0.6), 0, 0)),
		"Head": _q(Vector3(0.03 * sin(ph), 0.18 * sin(ph), 0)),
		"LeftUpperArm": _q(Vector3(0.03 * sin(ph * 2.0), 0, 0.06 + 0.02 * sin(ph * 2.0))),
		"RightUpperArm": _q(Vector3(0.03 * sin(ph * 2.0 + 1.0), 0, -0.06 - 0.02 * sin(ph * 2.0))),
		"LeftLowerArm": _q(Vector3(-0.12, 0, 0)), "RightLowerArm": _q(Vector3(-0.12, 0, 0)),
		"LeftUpperLeg": _q(Vector3(0, 0, 0.02 * sin(ph))), "RightUpperLeg": _q(Vector3(0, 0, 0.02 * sin(ph)))}


func _jump(_u: float) -> Dictionary:
	return {"LeftUpperLeg": _q(Vector3(-0.7, 0, 0)), "LeftLowerLeg": _q(Vector3(1.1, 0, 0)), "LeftFoot": _q(Vector3(-0.2, 0, 0)),
		"RightUpperLeg": _q(Vector3(-0.15, 0, 0)), "RightLowerLeg": _q(Vector3(0.5, 0, 0)),
		"LeftUpperArm": _q(Vector3(-0.4, 0, 0.5)), "RightUpperArm": _q(Vector3(0.3, 0, -0.5)),
		"LeftLowerArm": _q(Vector3(-0.6, 0, 0)), "RightLowerArm": _q(Vector3(-0.6, 0, 0)), "Spine": _q(Vector3(0.12, 0, 0))}


func _death(u: float) -> Dictionary:
	var k := WeaponModel.sm(u, 0.0, 0.75)
	var land := WeaponModel.sm(u, 0.45, 0.8)
	return {"_hips": Vector3(0, -0.72 * land - 0.1 * k, -0.35 * k),
		"Hips": _q(Vector3(-1.45 * land, 0, 0.1 * k)), "Spine": _q(Vector3(0.25 * k, 0, 0)), "Head": _q(Vector3(0.4 * k, 0.3 * k, 0)),
		"LeftUpperLeg": _q(Vector3(-0.9 * k + 0.9 * land, 0, 0.15 * k)), "LeftLowerLeg": _q(Vector3(1.2 * k - 0.9 * land, 0, 0)),
		"RightUpperLeg": _q(Vector3(-0.5 * k + 0.6 * land, 0, -0.1 * k)), "RightLowerLeg": _q(Vector3(0.9 * k - 0.6 * land, 0, 0)),
		"LeftUpperArm": _q(Vector3(-0.8 * k, 0, 0.9 * k)), "RightUpperArm": _q(Vector3(-0.5 * k, 0, -1.0 * k)),
		"LeftLowerArm": _q(Vector3(-0.5 * k, 0, 0)), "RightLowerArm": _q(Vector3(-0.7 * k, 0, 0))}


# ------------------------------------------------------------------ mocap retargeting
## Quaternius' Universal Animation Library (CC0, tools/rig/anim_src/UAL_LICENSE.txt) is on a Rigify skeleton.
## Each clip is sampled on its own skeleton and retargeted in world space onto ours:
##   target_global(t) = source_global(t) * source_global_rest^-1 * target_ref
## where target_ref turns each of our (axis-aligned) bones to point the way the source bone points at rest.
const MOCAP := "res://tools/rig/anim_src/ual_standard.glb"
const MAP := {"DEF-hips": "Hips", "DEF-spine.001": "Spine", "DEF-spine.002": "Chest", "DEF-spine.003": "UpperChest",
	"DEF-neck": "Neck", "DEF-head": "Head",
	"DEF-shoulder.L": "LeftShoulder", "DEF-upper_arm.L": "LeftUpperArm", "DEF-forearm.L": "LeftLowerArm", "DEF-hand.L": "LeftHand",
	"DEF-shoulder.R": "RightShoulder", "DEF-upper_arm.R": "RightUpperArm", "DEF-forearm.R": "RightLowerArm", "DEF-hand.R": "RightHand",
	"DEF-thigh.L": "LeftUpperLeg", "DEF-shin.L": "LeftLowerLeg", "DEF-foot.L": "LeftFoot", "DEF-toe.L": "LeftToes",
	"DEF-thigh.R": "RightUpperLeg", "DEF-shin.R": "RightLowerLeg", "DEF-foot.R": "RightFoot", "DEF-toe.R": "RightToes"}
const MOCAP_FPS := 30.0

var _msrc: Node3D
var _msk: Skeleton3D
var _map: AnimationPlayer
var _mi := {}            # our bone -> source bone index
var _mW := Basis()       # source world -> our character space (facing / handedness fix)
var _mref := {}          # our bone -> target_ref (global rotation)
var _mrest := {}         # our bone -> source global rest rotation (in our space)
var _mhips_rest := Vector3.ZERO
var _mscale := 1.0


func _mocap_setup() -> bool:
	if not ResourceLoader.exists(MOCAP):
		return false
	_msrc = load(MOCAP).instantiate()
	add_child(_msrc)
	_msk = _msrc.find_children("*", "Skeleton3D", true, false)[0]
	_map = _msrc.find_children("*", "AnimationPlayer", true, false)[0]
	for sb in MAP:
		var i := _msk.find_bone(sb)
		assert(i >= 0, "mocap bone missing " + sb)
		_mi[MAP[sb]] = i
	_msk.reset_bone_poses()
	var sg := func(b: String) -> Transform3D: return _msk.global_transform * _msk.get_bone_global_rest(_mi[b])
	# facing: our character looks down +Z with its left on +X
	var left: Vector3 = sg.call("LeftUpperArm").origin - sg.call("RightUpperArm").origin
	var fwd: Vector3 = sg.call("LeftToes").origin - sg.call("LeftFoot").origin
	fwd.y = 0
	var x := left.normalized()
	var z := fwd.normalized()
	z = (z - x * z.dot(x)).normalized()
	_mW = Basis(x, z.cross(x).normalized(), z).inverse().orthonormalized()
	var hips: Vector3 = _mW * sg.call("Hips").origin
	_mscale = J.Hips[0].y / hips.y
	_mhips_rest = hips * _mscale
	for b in _mi:
		_mrest[b] = (_mW * sg.call(b).basis.orthonormalized()).get_rotation_quaternion()
	# target reference: point each of our bones like its source bone at rest
	for b in _mi:
		var child := ""
		for c in J:
			if J[c][1] == b and _mi.has(c) and not c.ends_with("Shoulder") and not c.ends_with("UpperLeg"):
				child = c
		var src_dir: Vector3
		var dst_dir: Vector3 = seg_end(b) - J[b][0]
		if child != "":
			src_dir = _mW * (sg.call(child).origin - sg.call(b).origin)
		else:
			src_dir = _mW * sg.call(b).basis.y          # Rigify bones point along +Y
		if b.ends_with("Shoulder"):
			dst_dir = J[b.replace("Shoulder", "UpperArm")][0] - J[b][0]
			src_dir = _mW * (sg.call(b.replace("Shoulder", "UpperArm")).origin - sg.call(b).origin)
		if b == "Hips":
			dst_dir = J.Spine[0] - J.Hips[0]
			src_dir = _mW * (sg.call("Spine").origin - sg.call("Hips").origin)
		_mref[b] = _arc(dst_dir, src_dir) if dst_dir.length() > 0.001 and src_dir.length() > 0.001 else Quaternion()
		# both skeletons stand upright at rest: only the arms (T-pose vs arms-down) need re-aiming
		if not (b.ends_with("Shoulder") or b.ends_with("Arm") or b.ends_with("Hand")):
			_mref[b] = Quaternion()
	print("mocap: %d clips, scale %.3f, e.g. %s" % [_map.get_animation_list().size(), _mscale, _map.get_animation_list().slice(0, 4)])
	return true


## Bones a held weapon owns: no tracks for them in the *_rifle clips, so locomotion never fights the arm IK
## (arms, hands, fingers, clavicles, chest, neck and head stay at rest; SpineStabilizer / FirstPersonHead / FullBodyIK
## / GripLock pose them every frame).
const HOLD_FILTER := ["LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"Chest", "UpperChest", "Neck", "Head"]


## Retargets one source clip. `overrides`: {bone: local Quaternion} replacing tracks; `exclude`: bones left untracked.
func _mocap(clip: String, loop := true, overrides := {}, speed := 1.0, keep_root := false, exclude := []) -> Animation:
	var src_anim := _map.get_animation(clip)
	assert(src_anim != null, "no clip " + clip)
	var length := src_anim.length / speed
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for b in _mi:
		if b in exclude:
			continue
		tracks[b] = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tracks[b], "Skeleton:" + b)
	var hips_t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_t, "Skeleton:Hips")
	_map.play(clip)
	var steps := maxi(2, int(round(src_anim.length * MOCAP_FPS)))
	var first_xz := Vector3.ZERO
	for st in steps + 1:
		var ts := src_anim.length * st / steps
		_map.seek(ts, true)
		var glob := {}
		for b in _mi:
			var g := (_mW * (_msk.global_transform.basis * _msk.get_bone_global_pose(_mi[b]).basis).orthonormalized()).get_rotation_quaternion()
			glob[b] = g * _mrest[b].inverse() * _mref[b]
		for b in _mi:
			var parent: String = J[b][1]
			var pg: Quaternion = glob[parent] if glob.has(parent) else Quaternion()
			if not tracks.has(b):
				continue
			var local: Quaternion = overrides[b] if overrides.has(b) else (pg.inverse() * glob[b]).normalized()
			anim.rotation_track_insert_key(tracks[b], ts / speed, local)
		var hp: Vector3 = _mW * (_msk.global_transform * _msk.get_bone_global_pose(_mi.Hips)).origin * _mscale
		if st == 0:
			first_xz = Vector3(hp.x, 0, hp.z)
		var off := hp - _mhips_rest
		if not keep_root:
			off -= Vector3(hp.x, 0, hp.z) - first_xz       # in place: strip root travel
			off.x = clampf(off.x, -0.08, 0.08)
			off.z = clampf(off.z, -0.08, 0.08)
		anim.position_track_insert_key(hips_t, ts / speed, J.Hips[0] + off)
	_map.stop()
	return anim


func _animations() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var rifle := _rifle_arms()
	if _mocap_setup():
		# mocap body, procedural rifle arms (the in-game FullBodyIK then puts the hands on the actual gun)
		lib.add_animation(&"idle", _mocap("Idle"))
		lib.add_animation(&"walk", _mocap("Walk"))
		lib.add_animation(&"run", _mocap("Jog_Fwd"))
		lib.add_animation(&"sprint", _mocap("Sprint"))
		lib.add_animation(&"jump", _mocap("Jump"))
		lib.add_animation(&"death", _mocap("Death01", false))
		lib.add_animation(&"hit", _mocap("Hit_Chest", false))
		lib.add_animation(&"roll", _mocap("Roll", false))
		lib.add_animation(&"idle_rifle", _mocap("Idle", true, {}, 1.0, false, HOLD_FILTER))
		lib.add_animation(&"walk_rifle", _mocap("Walk", true, {}, 1.0, false, HOLD_FILTER))
		lib.add_animation(&"run_rifle", _mocap("Jog_Fwd", true, {}, 1.0, false, HOLD_FILTER))
		lib.add_animation(&"sprint_rifle", _mocap("Sprint", true, {}, 1.0, false, HOLD_FILTER))
		lib.add_animation(&"jump_rifle", _mocap("Jump", true, {}, 1.0, false, HOLD_FILTER))
		lib.add_animation(&"crouch_rifle", _mocap("Crouch_Idle", true, {}, 1.0, false, HOLD_FILTER))
		lib.add_animation(&"crouch_walk_rifle", _mocap("Crouch_Fwd", true, {}, 1.0, false, HOLD_FILTER))
		var prone_m := func(u: float) -> Dictionary:
			var p := {"_hips": Vector3(0, -0.66, 0.0), "Hips": _q(Vector3(1.45, 0, 0)), "Neck": _q(Vector3(-0.9, 0, 0)), "Head": _q(Vector3(-0.35, 0, 0))}
			for side in [["Left", 1.0], ["Right", -1.0]]:
				p[side[0] + "UpperLeg"] = _q(Vector3(0.05, 0, side[1] * 0.18))
				p[side[0] + "Foot"] = _q(Vector3(0.6, 0, 0))
			return p
		lib.add_animation(&"prone_rifle", _bake(4.0, 8, prone_m, true, rifle))
		return lib
	var walk := func(u: float) -> Dictionary: return _gait(u, 0.42, 0.65, 0.32, 0.2, 0.04, 0.025)
	var run := func(u: float) -> Dictionary: return _gait(u, 0.8, 1.2, 0.7, 1.1, 0.2, 0.05)
	var crouch := func(u: float) -> Dictionary:
		var p := _idle(u)
		p["_hips"] = Vector3(0, -0.32, -0.05)
		for s in ["Left", "Right"]:
			p[s + "UpperLeg"] = _q(Vector3(-1.05, 0, 0.12 if s == "Left" else -0.12))
			p[s + "LowerLeg"] = _q(Vector3(1.6, 0, 0))
			p[s + "Foot"] = _q(Vector3(-0.55, 0, 0))
		p["Spine"] = _q(Vector3(0.3, 0, 0))
		p["Neck"] = _q(Vector3(-0.25, 0, 0))
		return p
	lib.add_animation(&"idle", _bake(4.0, 32, _idle))
	lib.add_animation(&"walk", _bake(1.05, 24, walk))
	lib.add_animation(&"run", _bake(0.66, 20, run))
	lib.add_animation(&"jump", _bake(0.5, 1, _jump))
	lib.add_animation(&"death", _bake(1.3, 26, _death, false))
	lib.add_animation(&"idle_rifle", _bake(4.0, 32, _idle, true, rifle))
	lib.add_animation(&"walk_rifle", _bake(1.05, 24, walk, true, rifle))
	lib.add_animation(&"run_rifle", _bake(0.66, 20, run, true, rifle))
	lib.add_animation(&"jump_rifle", _bake(0.5, 1, _jump, true, rifle))
	lib.add_animation(&"crouch_rifle", _bake(4.0, 16, crouch, true, rifle))
	var prone := func(u: float) -> Dictionary:
		var ph := u * TAU
		var p := {"_hips": Vector3(0, -0.66, 0.0), "Hips": _q(Vector3(1.45, 0, 0)),
			"Spine": _q(Vector3(-0.05 + 0.01 * sin(ph * 2.0), 0, 0)), "Neck": _q(Vector3(-0.9, 0, 0)), "Head": _q(Vector3(-0.35, 0, 0))}
		for side in [["Left", 1.0], ["Right", -1.0]]:
			p[side[0] + "UpperLeg"] = _q(Vector3(0.05, 0, side[1] * 0.18))
			p[side[0] + "LowerLeg"] = _q(Vector3(0.12, 0, 0))
			p[side[0] + "Foot"] = _q(Vector3(0.6, 0, 0))
		return p
	lib.add_animation(&"prone_rifle", _bake(4.0, 8, prone, true, rifle))
	return lib
