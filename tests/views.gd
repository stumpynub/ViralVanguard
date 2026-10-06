extends Node
## Captures reference screenshots of the arena, a spider and every gun:  godot --path . res://tests/views.tscn

var main: Node


func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	main.pause_on_focus_loss = false
	add_child(main)
	await _wait(30)
	await _shot("hangar")
	Game.settings.weapon = "pulse"
	Game.settings.armor = "mk4"
	main.deploy()
	var a: Arena = main.arena
	var p: Player = a.player
	for e in a.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(20)
	p.yaw = 0.0
	p.pitch = 0.12
	await _shot("spawn_north")
	p.set_third_person(true)
	p.pitch = 0.05
	await _wait(20)
	await _shot("third_person")
	p.set_third_person(false)
	p.global_position = Vector3(40, 0.2, 10)
	p.yaw = PI * 0.75
	p.pitch = 0.05
	await _wait(10)
	await _shot("street_ne")
	var e: Spider = a.enemies[0]
	e.global_position = p.global_position + Vector3(-sin(p.yaw), 0, -cos(p.yaw)) * 5.0
	e.rotation.y = p.yaw
	p.pitch = -0.15
	await _wait(5)
	await _shot("spider")
	p.global_position = Vector3(31, 0.2, 33)
	p.yaw = PI * 0.5
	p.pitch = 0.1
	await _wait(10)
	await _shot("stairs")
	# overview from the spire deck
	p.global_position = Vector3(0, 25, 9)
	p.yaw = 0.0
	p.pitch = -0.35
	await _wait(10)
	await _shot("overview")
	p.global_position = Vector3(0, 0.2, 40)
	p.pitch = 0.0
	for w in ["pulse", "scatter", "rail", "ion", "void", "burst"]:
		p.weapons.slots[0] = Game.weapon(w)
		p.weapons.cur = 1
		p.weapons._equip(0)
		await _wait(8)
		await _shot("gun_" + w)
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/view_%s.png" % name)
