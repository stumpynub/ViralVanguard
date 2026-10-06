extends Node
## Screenshots of the main menu:  godot --path . res://tests/menu_shot.tscn [-- tag]
func _ready() -> void:
	var tag: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "menu"
	var main = preload("res://scenes/main.tscn").instantiate()
	main.pause_on_focus_loss = false
	add_child(main)
	for i in 120: await get_tree().process_frame
	await _shot(tag)
	var st = main.hangar.stage
	var cam: Camera3D = st.camera
	var keep := cam.global_transform
	cam.look_at_from_position(st.featured.global_position + Vector3(0.6, 0.35, 2.2), st.featured.global_position)
	for i in 6: await get_tree().process_frame
	await _shot(tag + "_sniper")
	cam.global_transform = keep
	main.hangar.open_pop("weapon")
	for i in 30: await get_tree().process_frame
	await _shot(tag + "_weapons")
	get_tree().quit()

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % n)
