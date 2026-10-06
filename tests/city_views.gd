extends Node
## Screenshots of Neon Core City from a free camera, plus a lift / launch-pad ride:  godot --path . res://tests/city_views.tscn

var main: Node


func _ready() -> void:
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	main.pause_on_focus_loss = false
	add_child(main)
	await _wait(20)
	Game.settings.weapon = "pulse"
	main.deploy()
	var a: Arena = main.arena
	var p: Player = a.player
	for e in a.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(20)
	await _shot("ncc_spawn")
	var cam := Camera3D.new()
	cam.far = 1500
	a.add_child(cam)
	cam.current = true
	for v in [] if "quick" in OS.get_cmdline_user_args() else [["ncc_aerial", Vector3(0, 150, 170), Vector3(0, 0, 0)], ["ncc_aerial_w", Vector3(-170, 90, 0), Vector3(0, 10, 0)],
			["ncc_street", Vector3(8, 1.7, 60), Vector3(0, 20, 0)], ["ncc_highway", Vector3(-60, 26, 40), Vector3(0, 19, -20)],
			["ncc_skyport", Vector3(60, 40, -30), Vector3(40, 20, -60)], ["ncc_bay", Vector3(0, 40, 75), Vector3(0, 10, 300)]]:
		cam.look_at_from_position(v[1], v[2])
		await _wait(6)
		await _shot(v[0])
	cam.current = false
	p.camera.current = true
	var lifts := get_tree().get_nodes_in_group("lifts")
	var pads := get_tree().get_nodes_in_group("pads")
	print("lifts=%d pads=%d glass=%d" % [lifts.size(), pads.size(), get_tree().get_nodes_in_group("glass").size()])
	for l in lifts:
		p.global_position = l.global_position + Vector3(0.3, 0.2, 0)
		p.velocity = Vector3.ZERO
		if "trace" in OS.get_cmdline_user_args():
			for k in 14:
				await _wait(30)
				print("   %s v=%s dead=%s pad=%.1f dash=%.1f grapple=%s" % [p.global_position, p.velocity, p.is_dead(), p.pad_t, p.dash_t, not p.grapple.is_empty()])
		else:
			await _wait(420)
		print("lift %s top %.1f -> player %s" % [l.global_position, l.global_position.y + l.top, p.global_position])
	for pad in pads:
		p.global_position = pad.global_position + Vector3(0, 0.2, 0)
		p.pad_t = 0.0
		p.velocity = Vector3.ZERO
		await _wait(240)
		print("pad target %s -> player %s" % [pad.target, p.global_position])
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % name)
