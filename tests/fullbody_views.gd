extends Node
## Screenshots of the full-body first-person setup:  godot --path . res://tests/fullbody_views.tscn

var main: Node


func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	add_child(main)
	main.pause_on_focus_loss = false
	await _wait(10)
	Game.settings.weapon = "pulse"
	main.deploy()
	var a: Arena = main.arena
	var p: Player = a.player
	for e in a.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(0, 0.2, 45)
	p.yaw = 0.0
	p.pitch = 0.0
	await _wait(30)
	var sk: Skeleton3D = p.body.skeleton
	print("head ", p.head.global_position, " eye ", p.body.eye.global_position, " body.pos ", p.body.position, " body.global ", p.body.global_position)
	print("eye bone global (skel space) ", sk.get_bone_global_pose(sk.find_bone("Head")).origin, " hand R ", sk.get_bone_global_pose(sk.find_bone("RightHand")).origin)
	print("ik targets ", p.body.ik.right_target, " ", p.body.ik.left_target, " w ", p.body.ik.arm_weight)
	print("cam ", p.camera.global_position)
	await _shot("fp_hip")
	p.pitch = -1.1
	await _wait(15)
	await _shot("fp_look_down")
	p.pitch = 0.0
	p.weapons._ads_toggle = true
	await _wait(25)
	await _shot("fp_ads")

	p.weapons._ads_toggle = false
	await _wait(25)
	p.weapons.ammo = 3
	p.weapons.reload()
	await _wait(int(60 * 1.4 * 0.38))
	await _shot("fp_reload")
	await _wait(60)
	p.stance = 1
	p.pitch = -0.7
	await _wait(40)
	await _shot("fp_crouch_down")
	p.stance = 0
	p.pitch = 0.0
	p.set_third_person(true)
	p.yaw = PI * 0.8
	await _wait(30)
	await _shot("tp_idle")
	p.stance = 1
	await _wait(40)
	await _shot("tp_crouch")
	p.stance = 2
	await _wait(40)
	await _shot("tp_prone")
	p.stance = 0
	# stand half-way up a stair run, side view, to see the feet on different steps
	p.global_position = Vector3(23, 4.6, 29.7)
	p.velocity = Vector3.ZERO
	p.yaw = -PI / 2
	await _wait(60)
	await _shot("tp_stairs")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/fb_%s.png" % name)
