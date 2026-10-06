extends Node
## Two-process multiplayer test over ENet (localhost):
##   godot --path . res://tests/mp_test.tscn -- host [shots]
##   godot --path . res://tests/mp_test.tscn -- client [shots]

var main: Node
var role := "host"
var shots := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = "client" if "client" in args else "host"
	shots = "shots" in args
	Game.settings.player_name = "HOSTY" if role == "host" else "CLIENTY"
	Game.settings.weapon = "pulse" if role == "host" else "scatter"
	Game.settings.armor = "vanguard" if role == "host" else "mk4"
	main = preload("res://scenes/main.tscn").instantiate()
	main.play_cinematic = false
	add_child(main)
	main.pause_on_focus_loss = false
	await _wait(10)
	if role == "host":
		Net.host_lan()
	else:
		await get_tree().create_timer(3.0).timeout
		Net.join_ip("127.0.0.1")
	# wait for the match and a teammate
	var t := 0.0
	while t < 20.0 and (main.arena == null or main.arena.players.size() < 2):
		await get_tree().process_frame
		t += get_process_delta_time()
	var a: Arena = main.arena
	if a == null or a.players.size() < 2:
		print("[%s] FAILED: players=%s" % [role, a.players.keys() if a else "no arena"])
		get_tree().quit(1)
		return
	print("[%s] connected: me=%d players=%s names=%s" % [role, a.me(), a.players.keys(), Net.players.values().map(func(i): return i.name)])
	var p: Player = a.player
	p.inv_t = 999.0
	await _wait(30)
	print("[%s] enemies seen=%d wave=%d" % [role, a.enemies.size(), a.wave])
	# client: walk forward and shoot the nearest spiders for a while; host: idle
	var start_score := a.score
	for i in 360:
		p.inv_t = 999.0
		if role == "client":
			var e := a.nearest_enemy(p.global_position, 500.0)
			if e:
				var d := e.center() - p.camera.global_position
				p.yaw = atan2(-d.x, -d.z)
				p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
				p.global_position = p.global_position.move_toward(e.global_position, 0.08) if d.length() > 12.0 else p.global_position
			p.weapons.fire()
			if i == 100:
				p.abilities.blast()
			if i == 50:     # client shoots out two sky-bridge windows; the host must see them go too
				var gl := get_tree().get_nodes_in_group("glass")
				a.shatter_glass(gl[0])
				a.shatter_glass(gl[1])
		await get_tree().physics_frame
	await _wait(30)
	var other: Player
	for id in a.players:
		if id != a.me():
			other = a.players[id]
	print("[%s] score %d -> %d  enemies=%d  my streak=%d  blocks=%d" % [role, start_score, a.score, a.enemies.size(), a.streak_kills, get_tree().get_nodes_in_group("blocks").size()])
	print("[%s] glass panels=%d corpses=%d" % [role, get_tree().get_nodes_in_group("glass").size(), a.get_node("FX").find_children("*", "SpiderCorpse", false, false).size()])
	print("[%s] other player %s at %s hp=%d weapon=%s remote=%s" % [role, other.name, other.global_position.snapped(Vector3.ONE * 0.1), other.hp, other._body_gun.weapon_id if other._body_gun else "?", other.remote])
	if shots:
		# look at the teammate and take a picture
		var d := other.global_position + Vector3(0, 1.2, 0) - p.camera.global_position
		p.yaw = atan2(-d.x, -d.z)
		p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _wait(20)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/mp_%s.png" % role)
	await get_tree().create_timer(4.0).timeout
	print("[%s] DONE" % role)
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
