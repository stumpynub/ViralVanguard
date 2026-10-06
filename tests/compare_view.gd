extends Node3D
## Renders the baked city from a given camera and saves a PNG, for side-by-side checks against v77's own render.
##   godot --path . res://tests/compare_view.tscn -- name x y z tx ty tz fov
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var w := V77World.new()
	add_child(w)
	var cam := Camera3D.new()
	cam.fov = float(a[7]) if a.size() > 7 else 70.0
	cam.near = 0.05
	cam.far = 1400.0
	add_child(cam)
	cam.look_at_from_position(Vector3(float(a[1]), float(a[2]), float(a[3])), Vector3(float(a[4]), float(a[5]), float(a[6])))
	cam.current = true
	if "noclip" in a:
		for mi in w.city.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh = mi.mesh if mi is MeshInstance3D else (mi.multimesh.mesh if mi is MultiMeshInstance3D else null)
			if mesh:
				for k in mesh.get_surface_count():
					var sm := mesh.surface_get_material(k) as ShaderMaterial
					if sm: sm.set_shader_parameter("v_clip_count", 0)
	if "nofog" in a:
		RenderingServer.global_shader_parameter_set("v77_fog_density", 0.0)
	if "facing" in a:
		RenderingServer.global_shader_parameter_set("v77_debug", 1)
	for arg in a:
		if arg.begins_with("hide="):
			var r: PackedStringArray = arg.trim_prefix("hide=").split("-")
			var top: Node = w.city.get_child(0)
			for k in range(int(r[0]), mini(int(r[1]) + 1, top.get_child_count())):
				(top.get_child(k) as Node3D).visible = false
			print("top children: ", top.get_child_count())
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % a[0])
	get_tree().quit()
