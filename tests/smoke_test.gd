extends Node
## Automated smoke test: boots the game, deploys with every weapon / armour / skill, fires, uses every ability and
## the streaks, and optionally saves screenshots. Run:  godot --path . res://tests/smoke_test.tscn [-- shots]

var main: Node
var shots := false
var frame := 0


func _ready() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	main.pause_on_focus_loss = false
	add_child(main)
	await _wait(30)
	await _shot("hangar")
	main.hangar.open_pop("weapon")
	await _wait(10)
	await _shot("hangar_weapons")
	main.hangar.open_pop("weapon")
	var weapons: Array = Game.DB.weapons
	var armors: Array = Game.DB.armors
	var skills: Array = Game.DB.skills
	for i in weapons.size():
		Game.settings.weapon = weapons[i].id
		Game.settings.armor = armors[i % armors.size()].id
		Game.settings.skill = skills[i % skills.size()].id
		main.deploy()
		await _wait(5)
		var a: Arena = main.arena
		var p: Player = a.player
		print("deploy %s / %s / %s  enemies=%d" % [weapons[i].id, Game.settings.armor, Game.settings.skill, a.enemies.size()])
		# aim at the nearest spider and shoot for a while
		for t in 90:
			var e := a.nearest_enemy(p.global_position, 500.0)
			if e:
				var d := e.center() - p.camera.global_position
				p.yaw = atan2(-d.x, -d.z)
				p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
			p.weapons.fire()
			if t == 20: p.abilities.use_skill()
			if t == 30: p.abilities.blast()
			if t == 40: p.abilities.tactical()
			if t == 50: p.weapons.swap()
			if t == 70: p.weapons.swap()
			if t == 80: p.weapons.reload()
			await get_tree().physics_frame
		if i == 0:
			await _shot("match")
		a.streak_kills = 15
		for k in 3:
			p.abilities.call_streak(k)
		await _wait(20)
		print("   score=%d wave=%d hp=%.0f ammo=%d" % [a.score, a.wave, p.hp, p.weapons.ammo])
	# die and come back
	main.arena.player.inv_t = 0.0
	main.arena.player.shield_t = 0.0
	main.arena.player.take_damage(99999)
	await _wait(5)
	print("end screen visible: ", main.end_screen.visible)
	main.to_hangar()
	await _wait(5)
	print("SMOKE TEST DONE")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if not shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/shot_%s.png" % name)
	print("saved shot ", name)
