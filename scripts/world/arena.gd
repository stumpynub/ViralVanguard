class_name Arena
extends Node3D
## Match controller for the Neo-Kairo arena (co-op, 1-8 players).
## The host (peer 1, which is also the single-player case) owns the swarm, waves, score, crates and game over.
## Every peer simulates its own player and its own hit detection; damage requests go to the host, which applies
## them and broadcasts the results. The city itself is plain nodes under City/.

signal score_changed(score: int)
signal wave_changed(wave: int)
signal kill_feed(text: String)
signal streak_changed(kills: int)
signal local_player_died(respawn_in: float)
signal local_player_respawned
signal game_over(score: int, wave: int)

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const RESPAWN_TIME := 8.0
const SNAPSHOT_RATE := 15.0

enum Fx { TRACER, IMPACT, BLOOD, BURST }

static var current: Arena

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var spider_scene: PackedScene = preload("res://scenes/enemies/spider.tscn")
@export var first_wave_size := 5
@export var max_wave_size := 24
## Extra infected per additional player.
@export var per_player_bonus := 0.5
@export var wave_delay := 2.0
## Off for arenas without the swarm (the sniper duel).
@export var waves := true
@export var respawn_time := 8.0
## Walkable area (x, z) — spiders spawn inside it and players are kept within it.
@export var bounds := Rect2(-86, -86, 172, 172)

@export_group("Effects")
@export var tracer_scene: PackedScene = preload("res://scenes/fx/tracer.tscn")
@export var impact_scene: PackedScene = preload("res://scenes/fx/impact.tscn")
@export var explosion_scene: PackedScene = preload("res://scenes/fx/explosion.tscn")
@export var puff_scene: PackedScene = preload("res://scenes/fx/puff.tscn")
@export var blood_scene: PackedScene = preload("res://scenes/fx/blood.tscn")
@export var chunks_scene: PackedScene = preload("res://scenes/fx/chunks.tscn")
@export var well_scene: PackedScene = preload("res://scenes/fx/void_well.tscn")

var player: Player                  ## the local player
var players := {}                   ## peer id -> Player (local and remote)
var enemies: Array[Spider] = []
var wave := 1
var score := 0
var streak_kills := 0               ## the local player's kills toward their streaks
var running := false
var shake := 0.0
var chrono_t := 0.0                 ## Chrono Field: every infected slowed while > 0

var _enemy_by_id := {}
var _next_enemy := 1
var _wave_t := 0.0
var _settle_t := 0.0
var _snap_t := 0.0
var _dirty := false
var _dead := {}                     ## host: peer id -> true while dead
var _respawn_t := -1.0
var _glass_paths: Array[String] = []

@onready var _spawn: Marker3D = $PlayerSpawn
@onready var _blocks_root: Node3D = $City/CargoBlocks
@onready var _fx_root: Node3D = $FX
var _players_root: Node3D


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	for g in get_tree().get_nodes_in_group("glass"):
		_glass_paths.append(str(get_path_to(g)))
	_players_root = Node3D.new()
	_players_root.name = "Players"
	add_child(_players_root)


func me() -> int:
	return multiplayer.get_unique_id()


func is_host() -> bool:
	return multiplayer.is_server()


# ------------------------------------------------------------------ match lifecycle
func start_match() -> void:
	running = true
	wave = 1
	score = 0
	streak_kills = 0
	player = _spawn_player(me(), Net.local_info(), false)
	Net.roster_changed.connect(_sync_roster)
	_sync_roster()
	if is_host() and waves:
		for i in first_wave_size:
			spawn_spider(1)
	else:
		_req_state.rpc_id(1)
	wave_changed.emit(wave)
	score_changed.emit(score)
	Sfx.loop("ambience", true, 0.5)


func _exit_match() -> void:
	Sfx.loop("ambience", false)
	Sfx.loop("jet", false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_exit_match()


func _spawn_player(id: int, info: Dictionary, remote: bool) -> Player:
	var p: Player = player_scene.instantiate()
	p.name = str(id)
	p.peer_id = id
	p.remote = remote
	p.loadout = info
	p.set_multiplayer_authority(id)
	# spread players around the spawn by id (every peer computes the same spots, so nobody spawns inside anyone)
	p.position = _spawn_point(id)
	_players_root.add_child(p)
	players[id] = p
	if not remote:
		p.died.connect(_on_local_died)
	return p


## Create / remove the bodies of other players to match the session roster.
## Where peer `id` spawns: around the spawn marker, spread by id so every peer computes the same spots.
func _spawn_point(id: int) -> Vector3:
	var ang := float(id % 997) / 997.0 * TAU
	return _spawn.global_position + (Vector3.ZERO if id == 1 else Vector3(cos(ang), 0, sin(ang)) * 3.0)


func _sync_roster() -> void:
	for id in Net.players:
		if id != me() and not players.has(id):
			_spawn_player(id, Net.players[id], true)
		elif id != me() and players.has(id):
			players[id].apply_loadout(Net.players[id])
	for id in players.keys():
		if id != me() and not Net.players.has(id):
			players[id].queue_free()
			players.erase(id)
			_dead.erase(id)
	if is_host():
		_check_game_over()


## Player state goes through the arena (which always exists) rather than the player node, so packets that
## arrive before a newly joined player's body has spawned are simply dropped.
func send_player_state(pos: Vector3, vel: Vector3, yaw: float, pitch: float, flags: int, weapon_idx: int, hp: float) -> void:
	_player_state.rpc(pos, vel, yaw, pitch, flags, weapon_idx, hp)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(pos: Vector3, vel: Vector3, yaw: float, pitch: float, flags: int, weapon_idx: int, hp: float) -> void:
	var p: Player = players.get(multiplayer.get_remote_sender_id())
	if p and p.remote:
		p.net_state(pos, vel, yaw, pitch, flags, weapon_idx, hp)


func living_players() -> Array:
	var out := []
	for id in players:
		var p: Player = players[id]
		if is_instance_valid(p) and not p.is_dead():
			out.append(p)
	return out


func _physics_process(delta: float) -> void:
	if not running:
		return
	shake *= 0.88
	chrono_t -= delta
	if _respawn_t > 0.0:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			_respawn_local()
	_settle_t += delta
	if _dirty and _settle_t > 0.18:
		_settle_t = 0.0
		_settle()
	if not is_host():
		return
	if enemies.is_empty() and waves:
		_wave_t += delta
		if _wave_t > wave_delay:
			_wave_t = 0.0
			wave += 1
			var n := int((4 + wave * 2) * (1.0 + per_player_bonus * (players.size() - 1)))
			for i in mini(int(max_wave_size * (1.0 + per_player_bonus * (players.size() - 1))), n):
				spawn_spider(wave)
			_hud_state.rpc(wave, score)
			wave_changed.emit(wave)
	_snap_t += delta
	if _snap_t >= 1.0 / SNAPSHOT_RATE and Net.is_online():
		_snap_t = 0.0
		_send_snapshot()


# ------------------------------------------------------------------ deaths, respawns, game over
func _on_local_died() -> void:
	streak_kills = 0
	streak_changed.emit(0)
	if is_host():
		_set_dead(me(), true)
	else:
		_report_dead.rpc_id(1, true)
	_respawn_t = respawn_time
	local_player_died.emit(respawn_time)


func _respawn_local() -> void:
	if not running:
		return
	player.respawn(_respawn_point())
	if is_host():
		_set_dead(me(), false)
	else:
		_report_dead.rpc_id(1, false)
	local_player_respawned.emit()


## Co-op: back next to a living teammate, or at the spawn.
func _respawn_point() -> Vector3:
	var alive := living_players()
	if not alive.is_empty():
		return alive[randi() % alive.size()].global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2))
	return _spawn.global_position


@rpc("any_peer", "reliable")
func _report_dead(dead: bool) -> void:
	if is_host():
		_set_dead(multiplayer.get_remote_sender_id(), dead)


func _set_dead(id: int, dead: bool) -> void:
	if dead:
		_dead[id] = true
	else:
		_dead.erase(id)
	_check_game_over()


func _check_game_over() -> void:
	if not running or players.is_empty():
		return
	for id in players:
		if not _dead.has(id):
			return
	_game_over.rpc(score, wave)
	_game_over(score, wave)


@rpc("authority", "call_remote", "reliable")
func _game_over(final_score: int, final_wave: int) -> void:
	running = false
	_respawn_t = -1.0
	_exit_match()
	game_over.emit(final_score, final_wave)


# ------------------------------------------------------------------ enemies (host simulates, clients mirror)
func spawn_spider(w: int) -> void:
	var alive := living_players()
	var p: Vector3 = alive[randi() % alive.size()].global_position if not alive.is_empty() else Vector3.ZERO
	var pos := Vector3.ZERO
	for i in 40:
		var a := randf() * TAU
		var r := randf_range(38.0, 62.0)
		pos = Vector3(clampf(p.x + cos(a) * r, bounds.position.x + 2, bounds.end.x - 2), 0.0, clampf(p.z + sin(a) * r, bounds.position.y + 2, bounds.end.y - 2))
		var near := false
		for q in alive:
			if Vector2(pos.x - q.global_position.x, pos.z - q.global_position.z).length() < 25.0:
				near = true
		if is_clear(pos + Vector3(0, 1.1, 0), 1.0) and not near:
			break
	var id := _next_enemy
	_next_enemy += 1
	var speed := 3.0 + w * 0.25 + randf()
	_spawn_spider_net.rpc(id, pos, w, speed)
	_spawn_spider_net(id, pos, w, speed)


@rpc("authority", "call_remote", "reliable")
func _spawn_spider_net(id: int, pos: Vector3, w: int, speed: float) -> void:
	if _enemy_by_id.has(id):
		return
	var s: Spider = spider_scene.instantiate()
	s.name = "S%d" % id
	s.net_id = id
	s.puppet = not is_host()
	s.position = pos
	s.setup(w)
	s.speed = speed
	$Enemies.add_child(s)
	enemies.append(s)
	_enemy_by_id[id] = s


func enemy(id: int) -> Spider:
	var e = _enemy_by_id.get(id)
	return e if is_instance_valid(e) else null


func _send_snapshot() -> void:
	var ids := PackedInt32Array()
	var pos := PackedVector3Array()
	var rot := PackedFloat32Array()
	var flags := PackedByteArray()
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		ids.append(e.net_id)
		pos.append(e.global_position)
		rot.append(e.rotation.y)
		flags.append((1 if e.stun > 0.0 else 0) | (2 if e.chill > 0.0 else 0))
	_snapshot.rpc(ids, pos, rot, flags)


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(ids: PackedInt32Array, pos: PackedVector3Array, rot: PackedFloat32Array, flags: PackedByteArray) -> void:
	for i in ids.size():
		var e := enemy(ids[i])
		if e:
			e.net_target(pos[i], rot[i], flags[i])


## Host: a spider started a claw slash (clients play the animation).
func spider_slash(e: Spider, side: float) -> void:
	if Net.is_online():
		_spider_slash_net.rpc(e.net_id, side)


@rpc("authority", "call_remote", "unreliable")
func _spider_slash_net(id: int, side: float) -> void:
	var e := enemy(id)
	if e:
		e.start_slash(side)


## Host: a spider's claw connected with player `target`.
## A player's round hit another player. Co-op has no friendly fire; DuelArena overrides this.
func pvp_hit(_target: Player, _dmg: float, _head: bool) -> void:
	pass


func hit_player(target: Player, dmg: float) -> bool:
	if target == player:
		return player.take_damage(dmg)
	target.net_hit.rpc_id(target.peer_id, dmg)
	return true


func _kill(e: Spider, source: String, killer: int) -> void:
	score += 100
	_spider_died.rpc(e.net_id, source, killer)
	_spider_died(e.net_id, source, killer)
	_hud_state.rpc(wave, score)
	score_changed.emit(score)
	if killer == me():
		_credit_kill()
	elif killer > 0:
		_credit_kill.rpc_id(killer)


@rpc("authority", "call_remote", "reliable")
func _spider_died(id: int, source: String, killer: int) -> void:
	var e := enemy(id)
	_enemy_by_id.erase(id)
	if e == null:
		return
	enemies.erase(e)
	var p := e.center() + Vector3(0, 0.2, 0)
	var from: Vector3 = players[killer].global_position if players.has(killer) else e.global_position
	_fx_local(Fx.BLOOD, p, ((e.global_position - from).normalized() + Vector3(0, 0.3, 0)).normalized(), Color(), 2.4)
	_fx_local(Fx.BLOOD, p, Vector3(randf() - 0.5, 0.6, randf() - 0.5).normalized(), Color(), 1.6)
	Sfx.play_at("enemy_die", e.global_position, 0.8)
	var who := "YOU" if killer == me() else Net.player_name(killer)
	kill_feed.emit("[color=#21e6ff]%s[/color] [color=#ff2bd6][%s][/color] SWARMER" % [who, source])
	if killer == me():
		shake = maxf(shake, 0.12)
	e.dead = true
	SpiderCorpse.from_spider(e, e.global_position - from, _fx_root)
	e.queue_free()


@rpc("authority", "call_remote", "reliable")
func _credit_kill() -> void:
	streak_kills += 1
	streak_changed.emit(streak_kills)


func reset_streak() -> void:
	streak_kills = 0
	streak_changed.emit(0)


@rpc("authority", "call_remote", "reliable")
func _hud_state(w: int, s: int) -> void:
	if w != wave:
		wave = w
		wave_changed.emit(w)
	score = s
	score_changed.emit(s)


func enemies_near(pt: Vector3, radius: float) -> Array[Spider]:
	var out: Array[Spider] = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.center().distance_to(pt) < radius:
			out.append(e)
	return out


func nearest_enemy(pt: Vector3, max_dist: float) -> Spider:
	var best: Spider = null
	var bd := max_dist
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d := e.center().distance_to(pt)
		if d < bd and not e.dead:
			bd = d
			best = e
	return best


## Host: the living player closest to `pt` (what a spider hunts).
func nearest_player(pt: Vector3) -> Player:
	var best: Player = null
	var bd := INF
	for p in living_players():
		var d: float = p.global_position.distance_squared_to(pt)
		if d < bd:
			bd = d
			best = p
	return best


# ------------------------------------------------------------------ damage requests (anyone -> host)
## Damage an infected. Hit feedback is immediate for the shooter; the host decides the outcome.
func damage_enemy(e: Spider, dmg: float, source: String, chill := 0.0, stun := 0.0) -> void:
	if e == null or e.dead:
		return
	e.flash_hit()
	if is_host():
		_apply_damage(e.net_id, dmg, source, chill, stun, me())
	else:
		_req_damage.rpc_id(1, e.net_id, dmg, source, chill, stun)


@rpc("any_peer", "reliable")
func _req_damage(id: int, dmg: float, source: String, chill: float, stun: float) -> void:
	if is_host():
		_apply_damage(id, dmg, source, chill, stun, multiplayer.get_remote_sender_id())


func _apply_damage(id: int, dmg: float, source: String, chill: float, stun: float, from: int) -> void:
	var e := enemy(id)
	if e == null or e.dead:
		return
	if chill > 0.0:
		e.chill = maxf(e.chill, chill)
	if stun > 0.0:
		e.stun = maxf(e.stun, stun)
	if dmg > 0.0 and e.apply_damage(dmg):
		_kill(e, source, from)


## Damage every infected within `radius` of `pt` (explosions, blast, void collapse, orbital strike).
func area_damage(pt: Vector3, radius: float, dmg: float, source: String, falloff := false, stun := 0.0) -> void:
	if is_host():
		_apply_area(pt, radius, dmg, source, falloff, stun, me())
	else:
		_req_area.rpc_id(1, pt, radius, dmg, source, falloff, stun)


@rpc("any_peer", "reliable")
func _req_area(pt: Vector3, radius: float, dmg: float, source: String, falloff: bool, stun: float) -> void:
	if is_host():
		_apply_area(pt, radius, dmg, source, falloff, stun, multiplayer.get_remote_sender_id())


func _apply_area(pt: Vector3, radius: float, dmg: float, source: String, falloff: bool, stun: float, from: int) -> void:
	for e in enemies_near(pt, radius):
		var d := dmg * (1.0 - e.center().distance_to(pt) / (radius + 1.0)) if falloff else dmg
		_apply_damage(e.net_id, d, source, 0.0, stun, from)


func set_chrono(t: float) -> void:
	if is_host():
		_chrono_net.rpc(t)
		_chrono_net(t)
	else:
		_req_chrono.rpc_id(1, t)


@rpc("any_peer", "reliable")
func _req_chrono(t: float) -> void:
	if is_host():
		set_chrono(t)


@rpc("authority", "call_remote", "reliable")
func _chrono_net(t: float) -> void:
	chrono_t = maxf(chrono_t, t)
	if player:
		player.chrono_t = chrono_t


# ------------------------------------------------------------------ world queries
func raycast(from: Vector3, to: Vector3, mask := LAYER_WORLD | LAYER_ENEMY, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return get_world_3d().direct_space_state.intersect_ray(q)


func is_clear(pos: Vector3, radius := 0.4) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	q.shape = s
	q.transform = Transform3D(Basis(), pos)
	q.collision_mask = LAYER_WORLD
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# ------------------------------------------------------------------ destructible blocks (host orders, everyone applies)
func destroy_blocks(pt: Vector3, radius: float) -> void:
	if is_host():
		_destroy_blocks_net.rpc(pt, radius)
		_destroy_blocks_net(pt, radius)
	else:
		_req_blocks.rpc_id(1, pt, radius)


@rpc("any_peer", "reliable")
func _req_blocks(pt: Vector3, radius: float) -> void:
	if is_host():
		destroy_blocks(pt, radius)


@rpc("authority", "call_remote", "reliable")
func _destroy_blocks_net(pt: Vector3, radius: float) -> void:
	for b in get_tree().get_nodes_in_group("blocks"):
		var cb := b as CrateBlock
		if cb and cb.global_position.distance_to(pt) < radius + 0.8:
			spawn_fx(chunks_scene, cb.global_position, cb.debris_color())
			cb.remove_from_group("blocks")
			cb.queue_free()
			_dirty = true


## Sky-bridge glass: anyone can shoot it, the host makes it official.
func shatter_glass(panel: Node) -> void:
	if not is_instance_valid(panel) or panel.broken:
		return
	var path := str(get_path_to(panel))
	if is_host():
		_shatter_net.rpc(path)
		_shatter_net(path)
	else:
		panel.shatter()        # instant feedback for the shooter
		_req_shatter.rpc_id(1, path)


@rpc("any_peer", "reliable")
func _req_shatter(path: String) -> void:
	if is_host():
		shatter_glass(get_node_or_null(path))


@rpc("authority", "call_remote", "reliable")
func _shatter_net(path: String) -> void:
	var g := get_node_or_null(path)
	if g and not g.broken:
		g.shatter()


## Blocks with nothing underneath and at most one side neighbour drop one cell (2 m) per pass.
## Deterministic, so every peer settles the same way from the same destroy order.
func _settle() -> void:
	var grid := {}
	var blocks: Array = []
	for b in get_tree().get_nodes_in_group("blocks"):
		blocks.append(b)
		grid[b.grid()] = b
	blocks.sort_custom(func(a, b): return a.position.y < b.position.y or (a.position.y == b.position.y and str(a.get_path()) < str(b.get_path())))
	var moved := false
	for b in blocks:
		var g: Vector3i = b.grid()
		if g.y > 0 and not grid.has(g - Vector3i(0, 1, 0)):
			var n := 0
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				if grid.has(g + d):
					n += 1
			if n <= 1:
				grid.erase(g)
				b.position.y -= 2.0
				grid[b.grid()] = b
				moved = true
	_dirty = moved


# ------------------------------------------------------------------ late join
@rpc("any_peer", "reliable")
func _req_state() -> void:
	if not is_host():
		return
	var to := multiplayer.get_remote_sender_id()
	var ids := PackedInt32Array()
	var pos := PackedVector3Array()
	var waves := PackedInt32Array()
	var speeds := PackedFloat32Array()
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			ids.append(e.net_id)
			pos.append(e.global_position)
			waves.append(e.wave)
			speeds.append(e.speed)
	var paths := PackedStringArray()
	var heights := PackedFloat32Array()
	for b in get_tree().get_nodes_in_group("blocks"):
		paths.append(str(_blocks_root.get_path_to(b)))
		heights.append(b.position.y)
	_join_state.rpc_id(to, wave, score, chrono_t, ids, pos, waves, speeds, paths, heights)
	var broken := PackedStringArray()
	for path in _glass_paths:
		if not has_node(path):
			broken.append(path)
	if not broken.is_empty():
		_join_glass.rpc_id(to, broken)


@rpc("authority", "call_remote", "reliable")
func _join_glass(paths: PackedStringArray) -> void:
	for path in paths:
		var g := get_node_or_null(path)
		if g:
			g.queue_free()


@rpc("authority", "call_remote", "reliable")
func _join_state(w: int, s: int, chrono: float, ids: PackedInt32Array, pos: PackedVector3Array, waves: PackedInt32Array, speeds: PackedFloat32Array, paths: PackedStringArray, heights: PackedFloat32Array) -> void:
	_hud_state(w, s)
	chrono_t = chrono
	for i in ids.size():
		_spawn_spider_net(ids[i], pos[i], waves[i], speeds[i])
	var keep := {}
	for i in paths.size():
		keep[paths[i]] = heights[i]
	for b in get_tree().get_nodes_in_group("blocks"):
		var path := str(_blocks_root.get_path_to(b))
		if keep.has(path):
			b.position.y = keep[path]
		else:
			b.remove_from_group("blocks")
			b.queue_free()


# ------------------------------------------------------------------ effects (local + mirrored to other peers)
func explode(pt: Vector3, damage: float, radius: float, color: Color, block_radius: float, source: String) -> void:
	destroy_blocks(pt, block_radius)
	for g in get_tree().get_nodes_in_group("glass"):
		if g.global_position.distance_to(pt) < radius + 2.5:
			shatter_glass(g)
	burst(pt, 22, color)
	shake = maxf(shake, 0.3)
	area_damage(pt, radius, damage, source, true)


## The original's burst(): large counts become a full explosion, small ones a coloured spark puff.
func burst(pt: Vector3, n: int, color: Color) -> void:
	fx(Fx.BURST, pt, Vector3.ZERO, color, n)


func tracer(a: Vector3, b: Vector3, color: Color, life := 0.0) -> void:
	fx(Fx.TRACER, a, b, color, life)


func impact(pt: Vector3, normal: Vector3, color: Color, k := 1.0) -> void:
	fx(Fx.IMPACT, pt, normal, color, k)


func blood(pt: Vector3, dir: Vector3, k := 1.0) -> void:
	fx(Fx.BLOOD, pt, dir, Color(), k)


## Show an effect here and on every other peer.
func fx(kind: int, a: Vector3, b: Vector3, color: Color, k: float) -> void:
	_fx_local(kind, a, b, color, k)
	if Net.is_online():
		_fx_net.rpc(kind, a, b, color, k)


@rpc("any_peer", "call_remote", "unreliable")
func _fx_net(kind: int, a: Vector3, b: Vector3, color: Color, k: float) -> void:
	_fx_local(kind, a, b, color, k)


func _fx_local(kind: int, a: Vector3, b: Vector3, color: Color, k: float) -> void:
	match kind:
		Fx.TRACER:
			var t: Node3D = tracer_scene.instantiate()
			_fx_root.add_child(t)
			t.setup(a, b, color, k)
		Fx.IMPACT:
			var f := spawn_fx(impact_scene, a, color)
			if b.length() > 0.1:
				f.look_at(a + b, Vector3.UP if absf(b.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
			f.scale = Vector3.ONE * k
			Sfx.play_at("impact", a, 0.6)
		Fx.BLOOD:
			var f := spawn_fx(blood_scene, a, Color("#1a6cff"))
			if b.length() > 0.1:
				f.look_at(a + b, Vector3.UP if absf(b.normalized().y) < 0.99 else Vector3.RIGHT)
			f.scale = Vector3.ONE * clampf(k, 0.5, 2.6)
		Fx.BURST:
			var n := int(k)
			if n >= 18:
				var f := spawn_fx(explosion_scene, a, color)
				f.scale = Vector3.ONE * minf(1.6, n / 24.0)
				Sfx.play_at("explosion", a, minf(1.0, n / 30.0))
				if player and player.global_position.distance_to(a) < 20.0:
					shake = maxf(shake, 0.3 * (1.0 - player.global_position.distance_to(a) / 20.0))
			else:
				var f := spawn_fx(puff_scene, a, color)
				f.scale = Vector3.ONE * (0.6 if n <= 4 else 1.0)


## A remote player fired: tracers from their muzzle, the shot sound, their muzzle flash.
func shot(shooter: int, weapon_idx: int, muzzle: Vector3, ends: PackedVector3Array) -> void:
	if Net.is_online():
		_shot_net.rpc(shooter, weapon_idx, muzzle, ends)


@rpc("any_peer", "call_remote", "unreliable")
func _shot_net(shooter: int, weapon_idx: int, muzzle: Vector3, ends: PackedVector3Array) -> void:
	var w: WeaponData = Game.DB.weapons[clampi(weapon_idx, 0, Game.DB.weapons.size() - 1)]
	var p: Player = players.get(shooter)
	var from := p.body_muzzle() if p else muzzle
	for e in ends:
		_fx_local(Fx.TRACER, from, e, w.color, 0.0)
	Sfx.play_at("fire_" + w.id, from, 0.9)
	if p:
		p.remote_fire_flash()


# ------------------------------------------------------------------ void wells (host simulates the pull)
func add_well(pt: Vector3, life: float, color: Color, owner_id := -1) -> void:
	if owner_id < 0:
		owner_id = me()
	if is_host():
		_well_net.rpc(pt, life, color, owner_id)
		_well_net(pt, life, color, owner_id)
	else:
		_req_well.rpc_id(1, pt, life, color)


@rpc("any_peer", "reliable")
func _req_well(pt: Vector3, life: float, color: Color) -> void:
	if is_host():
		add_well(pt, life, color, multiplayer.get_remote_sender_id())


@rpc("authority", "call_remote", "reliable")
func _well_net(pt: Vector3, life: float, color: Color, owner_id: int) -> void:
	var w: Node3D = well_scene.instantiate()
	_fx_root.add_child(w)
	w.global_position = pt
	w.setup(life, color, owner_id)


func spawn_fx(scene: PackedScene, pt: Vector3, color := Color.WHITE) -> Node3D:
	var f: Node3D = scene.instantiate()
	_fx_root.add_child(f)
	f.global_position = pt
	if f.has_method("set_color"):
		f.set_color(color)
	return f
