extends Node
## First-person sniper capture: hip, scoped, bolt cycle and reload frames, third person, looking down.
##   godot --path . res://tests/fp_sniper.tscn
var main: Node

func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	main.pause_on_focus_loss = false
	add_child(main)
	for i in 20: await get_tree().process_frame
	Game.settings.weapon = "sniper"
	if "duel" in OS.get_cmdline_user_args():
		Net.game_mode = "duel"
	main.deploy()
	var a: Arena = main.arena
	var p: Player = a.player
	for e in a.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.visible = false
	if not (a is DuelArena):
		p.global_position = Vector3(0, 0.2, 40)
		p.yaw = 0.0
	p.pitch = 0.0
	await _wait(60)
	await _shot("fp_hip")
	var w := p.weapons
	w._ads_toggle = true
	await _wait(40)
	await _shot("fp_scoped")
	w._ads_toggle = false
	await _wait(30)
	w.fire()
	for t in [0.05, 0.3, 0.42, 0.55, 0.75]:
		while w.bolt_t >= 0.0 and w.bolt_t < t:
			await get_tree().process_frame
		await _shot("fp_bolt_%02d" % int(t * 100))
	await _wait(60)
	w.ammo = 0
	w.reload()
	for t in [0.2, 0.33, 0.45, 0.75]:
		while w.reload_phase() >= 0.0 and w.reload_phase() < t:
			await get_tree().process_frame
		await _shot("fp_reload_%02d" % int(t * 100))
	await _wait(80)
	p.pitch = -1.1
	await _wait(30)
	await _shot("fp_look_down")
	p.pitch = 0.0
	p.set_third_person(true)
	await _wait(40)
	await _shot("tp_sniper")
	get_tree().quit()

func _wait(n: int) -> void:
	for i in n: await get_tree().process_frame

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % n)
