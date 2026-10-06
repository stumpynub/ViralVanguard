class_name Spider
extends CharacterBody3D
## Spider robot "swarmer". Walks at the nearest player with a diagonal-pair leg cycle, steers around buildings,
## chews through cargo blocks that block it, and rears up for a claw slash at close range.
## The host runs the AI; on other peers a spider is a `puppet` that follows the host's snapshots.

const FLASH_MAT := preload("res://assets/materials/overlay_flash.tres")
const CHILL_MAT := preload("res://assets/materials/overlay_chill.tres")
const STUN_MAT := preload("res://assets/materials/overlay_stun.tres")

@export var base_health := 60.0
@export var health_per_wave := 4.0
@export var base_speed := 3.0
@export var speed_per_wave := 0.25
@export var slash_range := 2.5
@export var slash_damage := 14.0
@export var slash_damage_per_wave := 0.8
@export var model: Node3D
## Applied to every part of the imported model except the glow strips (uses the model's baked vertex colours).
@export var hull_material: Material = preload("res://assets/materials/spider_hull.tres")

var hp := 60.0
var speed := 3.0
var wave := 1
var chill := 0.0
var stun := 0.0
var dead := false
var net_id := 0
var puppet := false

var _net_pos := Vector3.ZERO
var _net_rot := 0.0
var _net_has := false

var _flash := 0.0
var _phase := randf() * TAU
var _eat := 0.0
var _steer_t := 0.0
var _steer_sign := 1.0
var _slash := -1.0
var _slash_hit := false
var _slash_cd := 0.0
var _slash_side := 1.0
var _legs: Array[Node3D] = []
var _leg_axes: Array[Vector3] = []
var _front: Array[int] = []
var _hull: Node3D
var _meshes: Array[GeometryInstance3D] = []
var _overlay: Material


func setup(w: int) -> void:
	wave = w
	hp = base_health + w * health_per_wave
	speed = base_speed + w * speed_per_wave + randf()


func _ready() -> void:
	add_to_group("enemies")
	_hull = model.find_child("Hull", true, false)
	for i in 4:
		var leg: Node3D = model.find_child("Leg%d" % i, true, false)
		_legs.append(leg)
		var p := leg.position
		_leg_axes.append(Vector3(p.z, 0, -p.x).normalized())
	# the two legs furthest forward (+Z) do the slashing
	var idx := [0, 1, 2, 3]
	idx.sort_custom(func(a, b): return _legs[a].position.z > _legs[b].position.z)
	_front = [idx[0], idx[1]]
	for m in model.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(m)
		if m.name != "Glow" and hull_material:
			m.material_override = hull_material


func legs() -> Array[Node3D]:
	return _legs


func leg_axes() -> Array[Vector3]:
	return _leg_axes


## Middle of the body (the original's enemy origin, 1.2 m up).
func center() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


## Host: subtract health. Returns true when this killed it (the arena handles the death everywhere).
func apply_damage(dmg: float) -> bool:
	if dead:
		return false
	hp -= dmg
	_flash = 0.07
	return hp <= 0.0


## Immediate hit feedback for whoever shot it.
func flash_hit() -> void:
	_flash = 0.07


## Puppet: latest host state.
func net_target(pos: Vector3, rot: float, flags: int) -> void:
	_net_pos = pos
	_net_rot = rot
	stun = 0.2 if flags & 1 else 0.0
	chill = 0.2 if flags & 2 else 0.0
	if not _net_has:
		_net_has = true
		global_position = pos
		rotation.y = rot


## Puppet: the host says a slash started.
func start_slash(side: float) -> void:
	_slash = 0.0
	_slash_hit = true
	_slash_side = side
	Sfx.play_at("slash_windup", global_position)


func _puppet_step(delta: float) -> void:
	_flash -= delta
	_update_overlay()
	if not _net_has:
		return
	var before := global_position
	global_position = global_position.lerp(_net_pos, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _net_rot, minf(1.0, delta * 12.0))
	var spd := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.001)
	if stun <= 0.0:
		_phase += spd * delta * 5.5 + (0.0 if spd > 0.3 else delta * 0.35)
		_walk_cycle()
	if _slash >= 0.0:
		_slash_anim(delta)


func _physics_process(delta: float) -> void:
	var a := Arena.current
	if a == null or dead:
		return
	if puppet:
		_puppet_step(delta)
		return
	var player := a.nearest_player(global_position)
	if player == null:
		return
	chill -= delta
	_flash -= delta
	_slash_cd -= delta
	_update_overlay()
	if not is_on_floor():
		velocity.y -= 26.0 * delta
	else:
		velocity.y = 0.0
	if stun > 0.0:
		stun -= delta
		rotation.y += delta * 2.0
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var to_p := player.global_position - global_position
	to_p.y = 0
	var d := maxf(to_p.length(), 0.001)
	var slow := (0.3 if a.chrono_t > 0.0 else 1.0) * player.armor.enemy_slow * (0.4 if chill > 0.0 else 1.0)
	var dir := to_p / d
	if _steer_t > 0.0:   # side-step along the wall that blocked us
		_steer_t -= delta
		var side := Vector3(-dir.z * _steer_sign, 0, dir.x * _steer_sign)
		dir = (side * 0.85 + dir * 0.15).normalized()
	var adv := 1.0 if d > 1.5 else 0.0
	var spd := speed * slow * adv
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()

	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if absf(c.get_normal().y) > 0.6:
			continue
		var col := c.get_collider()
		if col is CrateBlock:
			_eat += delta
			if _eat > 0.8:
				_eat = 0.0
				a.destroy_blocks(c.get_position(), 0.6)
		elif col is StaticBody3D and _steer_t <= 0.0:
			_steer_t = randf_range(0.9, 2.0)
			_steer_sign = _steer_sign if randf() < 0.75 else -_steer_sign

	rotation.y = atan2(to_p.x, to_p.z)
	_phase += spd * delta * 5.5 * (adv if adv > 0.0 else 0.35)
	_walk_cycle()
	_slash_step(d, player, delta)


func _walk_cycle() -> void:
	for i in 4:
		var p := _phase + (PI if i % 2 else 0.0)
		var sn := sin(p)
		_legs[i].quaternion = Quaternion(Vector3.UP, cos(p) * 0.26) * Quaternion(_leg_axes[i], -maxf(0.0, sn) * 0.38)
	_hull.position.y = absf(sin(_phase)) * 0.03
	_hull.rotation = Vector3(0, 0, sin(_phase) * 0.025)


## Claw slash: front legs rear up (wind-up), swipe down and across (strike), then recover.
func _slash_step(d: float, player: Player, delta: float) -> void:
	var in_range := d < slash_range and absf(player.global_position.y + 0.9 - (global_position.y + 1.2)) < 1.7
	if _slash < 0.0:
		if in_range and _slash_cd <= 0.0:
			_slash = 0.0
			_slash_hit = false
			_slash_side = 1.0 if randf() < 0.5 else -1.0
			Sfx.play_at("slash_windup", global_position)
			Arena.current.spider_slash(self, _slash_side)
		else:
			return
	_slash_anim(delta)
	if not _slash_hit and _slash >= 0.34:
		_slash_hit = true
		if in_range and Arena.current.hit_player(player, slash_damage + wave * slash_damage_per_wave):
			Sfx.play_at("slash_hit", global_position)
		else:
			Sfx.play_at("slash_miss", global_position, 0.6)


## Front legs rear up (wind-up), swipe down and across (strike), then recover.
func _slash_anim(delta: float) -> void:
	_slash += delta * (0.5 if chill > 0.0 else 1.0)
	var t := _slash
	var up: float
	var sw: float
	if t < 0.28:
		up = sin(t / 0.28 * PI / 2.0)
		sw = -0.35 * (t / 0.28)
	elif t < 0.40:
		up = cos((t - 0.28) / 0.12 * PI / 2.0) - (t - 0.28) / 0.12 * 0.35
		sw = -0.35 + 1.25 * ((t - 0.28) / 0.12)
	else:
		up = -0.35 * (1.0 - minf(1.0, (t - 0.40) / 0.3))
		sw = 0.9 * (1.0 - minf(1.0, (t - 0.40) / 0.35))
	for k in 2:
		var li: int = _front[k]
		var sg := (1.0 if k else -1.0) * _slash_side
		_legs[li].quaternion = Quaternion(Vector3.UP, sw * sg * 0.8) * Quaternion(_leg_axes[li], -up * 1.15)
	_hull.rotation.x = -up * 0.22
	_hull.position.z = sin((t - 0.28) / 0.22 * PI) * 0.18 if t > 0.28 and t < 0.5 else 0.0
	if t >= 0.75:
		_slash = -1.0
		_hull.rotation.x = 0
		_hull.position.z = 0
		_slash_cd = 0.9 + randf() * 0.6


func _update_overlay() -> void:
	var m: Material = null
	if _flash > 0.0 or stun > 0.0:
		m = STUN_MAT if stun > 0.0 and _flash <= 0.0 else FLASH_MAT
	elif chill > 0.0:
		m = CHILL_MAT
	if m != _overlay:
		_overlay = m
		for g in _meshes:
			g.material_overlay = m
