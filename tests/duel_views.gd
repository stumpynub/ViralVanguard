extends Node
## Sniper-duel practice screenshots:  godot --path . res://tests/duel_views.tscn
var main: Node

func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	main.pause_on_focus_loss = false
	add_child(main)
	for i in 20: await get_tree().process_frame
	Net.game_mode = "duel"
	Net.play_solo()
	await _wait(90)
	var a: Arena = main.arena
	var p: Player = a.player
	print("duel arena: ", a is DuelArena, " weapon ", p.weapons.weapon.id, " pos ", p.global_position)
	await _shot("duel_spawn")
	p.weapons._ads_toggle = true
	await _wait(40)
	await _shot("duel_scoped")
	p.weapons._ads_toggle = false
	await _wait(30)
	var cam := Camera3D.new()
	cam.far = 800
	a.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 40
	cam.look_at_from_position(Vector3(-38, 60, 0.01), Vector3(-38, 0, 0))
	cam.current = true
	await _wait(8)
	await _shot("duel_west_top")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	for v in [["duel_aerial", Vector3(0, 45, 48), Vector3(0, 8, 0)], ["duel_canyon", Vector3(-5, 2, 14), Vector3(20, 8, -4)], ["duel_east", Vector3(20, 20, 10), Vector3(40, 15, 0)]]:
		cam.look_at_from_position(v[1], v[2])
		cam.current = true
		await _wait(8)
		await _shot(v[0])
	cam.current = false
	p.camera.current = true
	p.set_third_person(true)
	await _wait(30)
	await _shot("duel_tp")
	get_tree().quit()

func _wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % n)
