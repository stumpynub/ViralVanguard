extends Node
## Two-process sniper duel over ENet:  godot --path . res://tests/duel_mp_test.tscn -- host | client
## Only the host picks duel mode; the client must learn it from Net._welcome. The client then snipes the host.
var main: Node
var role := "host"

func _ready() -> void:
	role = "client" if "client" in OS.get_cmdline_user_args() else "host"
	Game.settings.player_name = "WEST" if role == "host" else "EAST"
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	main.pause_on_focus_loss = false
	add_child(main)
	await _wait(10)
	if role == "host":
		Net.game_mode = "duel"
		Net.host_lan()
	else:
		Net.game_mode = "coop"        # deliberately wrong: the host's welcome must fix it
		await get_tree().create_timer(3.0).timeout
		Net.join_ip("127.0.0.1")
	var t := 0.0
	while t < 20.0 and (main.arena == null or main.arena.players.size() < 2):
		await get_tree().process_frame
		t += get_process_delta_time()
	var a: Arena = main.arena
	if a == null or a.players.size() < 2:
		print("[%s] FAILED to connect" % role)
		get_tree().quit(1)
		return
	print("[%s] mode=%s duel_arena=%s weapon=%s me=%d pos=%s" % [role, Net.game_mode, a is DuelArena, a.player.weapons.weapon.id, a.me(), a.player.global_position.snapped(Vector3.ONE * 0.1)])
	await _wait(60)
	var p: Player = a.player
	var other: Player
	for id in a.players:
		if id != a.me():
			other = a.players[id]
	if role == "client":
		var shots := 0
		var t2 := 0.0
		while t2 < 25.0 and int((a as DuelArena).kills.get(a.me(), 0)) < 1:
			if not other.is_dead() and p.weapons.bolt_t < 0.0 and p.weapons.ammo > 0:
				var aim := other.head.global_position + Vector3(0, 0.25, 0)      # hold over for drop
				var d := aim - p.camera.global_position
				p.yaw = atan2(-d.x, -d.z)
				p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
				p.weapons._ads_toggle = true
				await _wait(25)
				p.weapons.settle = 1.0
				p.weapons.fire()
				shots += 1
			elif p.weapons.ammo <= 0:
				p.weapons.reload()
			await get_tree().physics_frame
			t2 += get_physics_process_delta_time()
		print("[client] fired %d shots" % shots)
	else:
		var t3 := 0.0
		while t3 < 40.0 and (a as DuelArena).kills.is_empty():
			await get_tree().process_frame
			t3 += get_process_delta_time()
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(other):
		print("[%s] other left" % role)
		get_tree().quit()
		return
	print("[%s] kills=%s my_hp=%d other_hp=%d other_dead=%s" % [role, (a as DuelArena).kills, p.hp, other.hp, other.is_dead()])
	print("[%s] DONE" % role)
	if role == "client":
		await get_tree().create_timer(3.0).timeout
	get_tree().quit()

func _wait(n: int) -> void:
	for i in n: await get_tree().process_frame
