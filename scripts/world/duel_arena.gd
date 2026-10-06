class_name DuelArena
extends Arena
## 1v1 sniper duel on the rooftops (scenes/world/arena_duel.tscn). Same networking as co-op: every peer simulates
## its own player and resolves its own shots; a hit on the other player is sent to that player's peer, which applies
## it (and its own invulnerability / shields); a death is reported to the host, which keeps the score and calls the
## match. First to `kills_to_win`. Solo, the rooftops are a practice range with a few swarmers wandering in.

signal duel_changed(text: String)
signal duel_feed(text: String)

@export var kills_to_win := 5
@export var practice_swarmers := 4
@export var spawn_a: Marker3D
@export var spawn_b: Marker3D

var kills := {}               ## peer id -> kills (host authoritative, mirrored)
var _practice_t := 3.0


func _ready() -> void:
	super._ready()
	# props instanced from the shared kit (wrecks, barriers, signs) get the arena's cel / ink look too
	ToonStyle.apply($City, {"outline": 0.0009, "outline_max": 0.02, "tint": Color(1.2, 1.2, 1.3), "desaturate": 0.75})


func start_match() -> void:
	waves = false
	respawn_time = 3.5
	super.start_match()
	kills.clear()
	_emit_score()
	player.abilities.drone.visible = false      # nothing to hunt with it here; keep the sight picture clean
	Sfx.loop("rain", true, 0.45)


func _exit_match() -> void:
	super._exit_match()
	Sfx.loop("rain", false)


## Host takes the west roof, the challenger the east.
func _spawn_point(id: int) -> Vector3:
	var m := spawn_a if id == 1 else spawn_b
	return m.global_position if m else super._spawn_point(id)


func _respawn_point() -> Vector3:
	return _spawn_point(me()) + Vector3(randf_range(-1.5, 1.5), 0.2, randf_range(-1.5, 1.5))


func _spawn_player(id: int, info: Dictionary, remote: bool) -> Player:
	var p := super._spawn_player(id, info, remote)
	var m := spawn_a if id == 1 else spawn_b
	if m:
		p.yaw = m.global_rotation.y      # face the other roof
	return p


## Deaths never end a duel; the score does.
func _check_game_over() -> void:
	pass


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# solo practice: keep a few swarmers on the rooftops to shoot at
	if running and not Net.is_online() and is_host():
		_practice_t -= delta
		if _practice_t <= 0.0 and enemies.size() < practice_swarmers:
			_practice_t = 6.0
			spawn_spider(1)


# ------------------------------------------------------------------ hits between players
func pvp_hit(target: Player, dmg: float, head: bool) -> void:
	if not running or target == null or target.is_dead():
		return
	if target == player:
		return
	_pvp_hit.rpc_id(target.peer_id, dmg, head)


@rpc("any_peer", "reliable")
func _pvp_hit(dmg: float, head: bool) -> void:
	if player == null or player.is_dead():
		return
	var shooter := multiplayer.get_remote_sender_id()
	var was_alive := not player.is_dead()
	player.take_damage(dmg)
	Sfx.play("headshot" if head else "hit_body", 0.8)
	shake = maxf(shake, 0.35 if head else 0.2)
	if was_alive and player.is_dead():
		if is_host():
			_pvp_died(me(), shooter, head)
		else:
			_report_kill.rpc_id(1, shooter, head)


@rpc("any_peer", "reliable")
func _report_kill(killer: int, head: bool) -> void:
	if is_host():
		_pvp_died(multiplayer.get_remote_sender_id(), killer, head)


## Host: score it, tell everyone, end the match at kills_to_win.
func _pvp_died(victim: int, killer: int, head: bool) -> void:
	kills[killer] = int(kills.get(killer, 0)) + 1
	var line := "[color=#ff3a3a]%s[/color]  ✛  %s%s" % [Net.player_name(killer), Net.player_name(victim), "  [color=#ff3a3a]HEADSHOT[/color]" if head else ""]
	_duel_state.rpc(kills, line)
	_duel_state(kills, line)
	if kills[killer] >= kills_to_win:
		_duel_over.rpc(killer)
		_duel_over(killer)


@rpc("authority", "call_remote", "reliable")
func _duel_state(k: Dictionary, line: String) -> void:
	kills = k
	duel_feed.emit(line)
	kill_feed.emit(line)
	_emit_score()


@rpc("authority", "call_remote", "reliable")
func _duel_over(winner: int) -> void:
	running = false
	_exit_match()
	game_over.emit(int(kills.get(me(), 0)), int(kills.get(winner, 0)) if winner != me() else -1)


func _emit_score() -> void:
	var mine := int(kills.get(me(), 0))
	var theirs := 0
	var foe := "WAITING FOR A CHALLENGER"
	for id in players:
		if id != me():
			theirs = int(kills.get(id, 0))
			foe = Net.player_name(id)
	if not Net.is_online():
		foe = "PRACTICE RANGE"
	duel_changed.emit("%d  —  %d\n%s" % [mine, theirs, foe] if Net.is_online() else foe)


func _sync_roster() -> void:
	super._sync_roster()
	_emit_score()
