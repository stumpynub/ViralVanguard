extends Node
## Hand / grip close-ups:  godot --path . res://tests/hands_view.tscn
var main: Node

func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	main.pause_on_focus_loss = false
	add_child(main)
	for i in 20: await get_tree().process_frame
	Net.game_mode = "duel"
	Net.play_solo()
	await _wait(60)
	var a: Arena = main.arena
	var p: Player = a.player
	for e in a.enemies:
		e.queue_free()
	a.enemies.clear()
	p.set_third_person(true)
	await _wait(30)
	# inspection lighting for the close-ups
	a.get_node("Post").visible = false
	var key := OmniLight3D.new()
	key.light_energy = 3.0
	key.omni_range = 4.0
	a.add_child(key)
	var cam := Camera3D.new()
	cam.fov = 35
	a.add_child(cam)
	var g: Node3D = p._body_gun
	var fwd := -p.global_basis.z if false else Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
	var sk: Skeleton3D = p.body.skeleton
	await sk.skeleton_updated
	print("support marker local-to-gun ", g.to_local(g.support_hand.global_position), " grip ", g.to_local(g.grip_hand.global_position), " ik.left_target local ", g.to_local(p.body.ik.left_target))
	for side in ["Left", "Right"]:
		var hb := sk.find_bone(side + "Hand")
		var hp := sk.global_transform * sk.get_bone_global_pose(hb).origin
		var sb := sk.find_bone(side + "UpperArm")
		var sp := sk.global_transform * sk.get_bone_global_pose(sb).origin
		var t: Vector3 = p.body.ik.left_target if side == "Left" else p.body.ik.right_target
		print("%s hand->target %.3f  shoulder->target %.3f  weight %.2f lock %.2f" % [side, hp.distance_to(t), sp.distance_to(t), p.body.ik.arm_weight, p.body.grip_lock.weight])
	await _close(cam, g.global_position + right * 0.9 + Vector3(0, 0.15, 0) + fwd * 0.1, g.global_position, "hands_right")
	await _close(cam, g.global_position - right * 0.9 + Vector3(0, 0.1, 0) + fwd * 0.25, g.global_position + fwd * 0.25, "hands_left")
	Input.action_press("move_forward")
	await _wait(50)
	await _close(cam, p._body_gun.global_position + right * 1.0 + Vector3(0, 0.2, 0), p._body_gun.global_position, "hands_walk")
	Input.action_release("move_forward")
	main.arena.get_node("Post").visible = true
	cam.current = false
	p.camera.current = true
	p.set_third_person(false)
	await _wait(40)
	await _shot("hands_fp")
	p.weapons.fire()
	while p.weapons.bolt_t >= 0.0 and p.weapons.bolt_t < 0.4:
		await get_tree().process_frame
	await _shot("hands_fp_bolt")
	await _wait(80)
	p.weapons.ammo = 0
	p.weapons.reload()
	while p.weapons.reload_phase() >= 0.0 and p.weapons.reload_phase() < 0.45:
		await get_tree().process_frame
	await _shot("hands_fp_reload")
	await _wait(200)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(60)
	await _shot("hands_fp_sprint")
	get_tree().quit()

func _close(cam: Camera3D, from: Vector3, at: Vector3, n: String) -> void:
	cam.look_at_from_position(from, at)
	var key: Array = main.arena.get_children().filter(func(c): return c is OmniLight3D)
	if key.size() > 0:
		key[0].global_position = from + Vector3(0, 0.4, 0)
	cam.current = true
	await _wait(4)
	await _shot(n)

func _wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % n)
