extends Node
## Diagnostic: skins the mesh at a walk frame on the CPU and reports triangles that stretch.
func _ready() -> void:
	var c: CharacterModel = load("res://scenes/characters/sick_operative.tscn").instantiate()
	add_child(c)
	var sk := c.skeleton
	var ap := c.animation_player
	ap.play("walk"); ap.seek(ap.current_animation_length * 0.25, true); ap.pause()
	await get_tree().process_frame
	var mats: Array[Transform3D] = []
	for b in sk.get_bone_count():
		mats.append(sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse())
	var mesh: ArrayMesh = load("res://assets/models/sick_operative.res")
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bo: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var p := PackedVector3Array(); p.resize(v.size())
	for i in v.size():
		var acc := Vector3.ZERO
		for k in 4:
			if w[i * 4 + k] > 0.0:
				acc += (mats[bo[i * 4 + k]] * v[i]) * w[i * 4 + k]
		p[i] = acc
	var bad := {}
	for t in range(0, ix.size(), 3):
		for e in [[0, 1], [1, 2], [2, 0]]:
			var i0 := ix[t + e[0]]; var i1 := ix[t + e[1]]
			var r := v[i0].distance_to(v[i1]); var q := p[i0].distance_to(p[i1])
			if q > 0.06 and q > r * 3.0:
				bad[i0] = true; bad[i1] = true
	print("stretched verts: ", bad.size())
	var groups := {}
	for i in bad:
		var top := 0
		for k in range(1, 4):
			if w[i * 4 + k] > w[i * 4 + top]: top = k
		var nm := sk.get_bone_name(bo[i * 4 + top])
		if not groups.has(nm): groups[nm] = [0, Vector3(INF, INF, INF), -Vector3(INF, INF, INF)]
		groups[nm][0] += 1
		groups[nm][1] = groups[nm][1].min(v[i]); groups[nm][2] = groups[nm][2].max(v[i])
	for g in groups: print("  ", g, " ", groups[g])
	get_tree().quit()
