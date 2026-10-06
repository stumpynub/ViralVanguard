extends Node3D
## Renders front / side / top-down reference shots of the raw character and prints height-slice profiles.
func _ready() -> void:
	var m: Node3D = load("res://assets/models/sick_rig.glb").instantiate()
	add_child(m)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.25, 0.27, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 0.6
	add_child(env)
	var l := DirectionalLight3D.new(); l.rotation = Vector3(-0.6, 0.5, 0); add_child(l)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.1; add_child(cam)
	for v in [["front", Vector3(0, 0.95, 4), 0.0], ["side", Vector3(4, 0.95, 0), PI / 2], ["back", Vector3(0, 0.95, -4), PI]]:
		cam.position = v[1]; cam.rotation = Vector3(0, v[2], 0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tools/rig/look_%s.png" % v[0])
	# slice profile
	var mi: MeshInstance3D = m.find_children("*", "MeshInstance3D", true, false)[0]
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var off := mi.global_transform
	print("verts ", verts.size(), " xform ", off)
	var rows := {}
	for v in verts:
		var p := off * v
		var k := int(p.y * 20)
		if not rows.has(k): rows[k] = []
		rows[k].append(p.x)
	var keys := rows.keys(); keys.sort()
	for k in keys:
		var xs: Array = rows[k]; xs.sort()
		# find gaps > 4cm in x to identify separate limbs
		var segs := []; var s0: float = xs[0]
		for i in range(1, xs.size()):
			if xs[i] - xs[i - 1] > 0.04:
				segs.append("[%.2f,%.2f]" % [s0, xs[i - 1]]); s0 = xs[i]
		segs.append("[%.2f,%.2f]" % [s0, xs[-1]])
		print("y=%.2f n=%d %s" % [k / 20.0, xs.size(), " ".join(segs)])
	get_tree().quit()
