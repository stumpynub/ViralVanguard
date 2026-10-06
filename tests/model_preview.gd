extends Node3D
## Renders a GLB with the menu's cel shading from three angles:
##   godot --path . res://tests/model_preview.tscn -- res://path/model.glb name
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://assets/placeholder/models/sniper.glb"
	var tag := args[1] if args.size() > 1 else "model"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a2a2e")
	env.ambient_light_color = Color("#8890a0")
	env.ambient_light_energy = 0.35
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.6, 0)
	key.light_energy = 2.2
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 0.6, -1.5)
	rim.light_color = Color("#ff2020")
	rim.light_energy = 6.0
	rim.omni_range = 5.0
	add_child(rim)
	var m: Node3D = load(path).instantiate()
	add_child(m)
	ToonStyle.apply(m, {"outline": 0.006, "tint": Color("#7a7a82")})
	var aabb := AABB()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge(mi.global_transform * mi.get_aabb()) if aabb.size != Vector3.ZERO else mi.global_transform * mi.get_aabb()
	var c := aabb.get_center()
	var r := aabb.size.length() * 0.62
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	for v in [["side", Vector3(1, 0.15, 0)], ["front34", Vector3(0.75, 0.3, 0.6)], ["back34", Vector3(-0.7, 0.35, -0.6)]]:
		cam.look_at_from_position(c + (v[1] as Vector3).normalized() * r * 2.2, c)
		for i in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/shots/%s_%s.png" % [tag, v[0]])
	get_tree().quit()
