extends SceneTree
## Builds the hangar operative meshes (armour tiers 0-3) from the v77 bakes, keeping the per-vertex material data
## v77's operative shader reads: aCol -> COLOR, aEmi -> CUSTOM0.rgb, aMR -> CUSTOM1, aX -> UV2.
##   godot --headless --path . --script res://tools/import_operative.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/baked/operative"))
	for t in 4:
		var name := "operative" if t == 0 else "operative_t%d" % t
		var base := ProjectSettings.globalize_path("res://bake/%s/" % name)
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "scene.json"))
		var bin := FileAccess.get_file_as_bytes(base + "geometry.bin")
		var g: Dictionary = m.geometries[0]
		var f := func(a: Dictionary) -> PackedFloat32Array:
			return bin.slice(int(a.off), int(a.off) + int(a.n) * int(a.s) * 4).to_float32_array()
		var nv: int = int(g.position.n)
		var pos: PackedFloat32Array = f.call(g.position)
		var nor: PackedFloat32Array = f.call(g.normal)
		var ex := {}
		for e in g.extra:
			ex[e[0]] = e[1]
		var col: PackedFloat32Array = f.call(ex.aCol)
		var emi: PackedFloat32Array = f.call(ex.aEmi)
		var mr: PackedFloat32Array = f.call(ex.aMR)
		var ax: PackedFloat32Array = f.call(ex.aX)
		var V := PackedVector3Array(); V.resize(nv)
		var N := PackedVector3Array(); N.resize(nv)
		var Cc := PackedColorArray(); Cc.resize(nv)
		var C0 := PackedFloat32Array(); C0.resize(nv * 4)
		var C1 := PackedFloat32Array(); C1.resize(nv * 4)
		var U2 := PackedVector2Array(); U2.resize(nv)
		for i in nv:
			V[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
			N[i] = Vector3(nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2])
			Cc[i] = Color(col[i * 3], col[i * 3 + 1], col[i * 3 + 2])
			C0[i * 4] = emi[i * 3]; C0[i * 4 + 1] = emi[i * 3 + 1]; C0[i * 4 + 2] = emi[i * 3 + 2]; C0[i * 4 + 3] = 0
			for k in 4:
				C1[i * 4 + k] = mr[i * 4 + k]
			U2[i] = Vector2(ax[i * 2], ax[i * 2 + 1])
		var idx := bin.slice(int(g.index.off), int(g.index.off) + int(g.index.n) * 4).to_int32_array()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = V
		arr[Mesh.ARRAY_NORMAL] = N
		arr[Mesh.ARRAY_COLOR] = Cc
		arr[Mesh.ARRAY_CUSTOM0] = C0
		arr[Mesh.ARRAY_CUSTOM1] = C1
		arr[Mesh.ARRAY_TEX_UV2] = U2
		arr[Mesh.ARRAY_INDEX] = idx
		var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		ResourceSaver.save(mesh, "res://assets/baked/operative/tier%d.res" % t, ResourceSaver.FLAG_COMPRESS)
		print("operative tier %d: %d verts %d tris" % [t, nv, idx.size() / 3])
	quit()
