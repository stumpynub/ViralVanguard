class_name Abilities
extends Node
## Active skill (Q / F), lethal BLAST (E), tactical STUN charges (G), kill streaks (4 / 5 / 6) and the hunter drone.

signal changed

const STREAKS := [{"name": "SENTRY", "kills": 5}, {"name": "STRIKE", "kills": 10}, {"name": "OVERDRIVE", "kills": 15}]

@export var player: Player
@export var drone: Node3D
@export var drone_eye: MeshInstance3D
@export var blast_cooldown := 5.0
@export var stun_charges := 2
@export var stun_recharge := 12.0

var skill: SkillData
var skill_cd := 0.0
var blast_cd := 0.0
var stun_n := 2
var streak_used := [false, false, false]

var _stun_t := 0.0
var _drone_t := 0.0
var _drone_shot := 0.0
var _eye_mat: StandardMaterial3D


func _ready() -> void:
	skill = Game.skill(str(player.loadout.get("skill", "")))
	stun_n = stun_charges
	_eye_mat = drone_eye.material_override.duplicate()
	drone_eye.material_override = _eye_mat
	if player.remote:
		set_process(false)
		set_process_unhandled_input(false)


func cdr() -> float:
	return 1.0 - player.armor.cooldown_reduction


func streak_ready(i: int) -> bool:
	var a := Arena.current
	return a != null and not streak_used[i] and a.streak_kills >= STREAKS[i].kills


func _unhandled_input(event: InputEvent) -> void:
	if player.is_dead():
		return
	if event.is_action_pressed("skill"):
		use_skill()
	elif event.is_action_pressed("lethal"):
		blast()
	elif event.is_action_pressed("tactical"):
		tactical()
	elif event.is_action_pressed("streak_1"):
		call_streak(0)
	elif event.is_action_pressed("streak_2"):
		call_streak(1)
	elif event.is_action_pressed("streak_3"):
		call_streak(2)


func _process(delta: float) -> void:
	if player.is_dead():
		return
	skill_cd -= delta
	blast_cd -= delta
	if stun_n < stun_charges:
		_stun_t -= delta
		if _stun_t <= 0.0:
			stun_n += 1
			_stun_t = stun_recharge if stun_n < stun_charges else 0.0
	drone.position.y = 0.35 + sin(Time.get_ticks_msec() / 300.0) * 0.03
	if _drone_t > 0.0:
		_drone_t -= delta
		_drone_shot -= delta
		_eye_mat.emission = Color("#ff2bd6")
		if _drone_shot <= 0.0:
			_drone_shot = 0.3
			var a := Arena.current
			var best := a.nearest_enemy(player.global_position, 35.0)
			if best:
				a.tracer(drone.global_position, best.center(), Color("#ff2bd6"))
				a.damage_enemy(best, 18.0, "DRONE")
				Sfx.beep(980, 0.05, "square", 0.04)
	else:
		_eye_mat.emission = Color("#21e6ff")
	changed.emit()


func _aim_point(dist: float) -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	return Arena.current.raycast(from, from - cam.global_basis.z * dist)


func use_skill() -> void:
	if skill_cd > 0.0:
		return
	if skill.id == "grapple":
		if not player.grapple.is_empty() and not (player.grapple.hang > 0.0):
			return
		var hold := player.grapple
		player.grapple = {}
		if player.fire_grapple():
			skill_cd = skill.cooldown * cdr()
		elif not hold.is_empty():
			player.grapple = hold
		return
	skill_cd = skill.cooldown * cdr()
	Sfx.beep(660, 0.25, "triangle", 0.12)
	match skill.id:
		"dash":
			player.dash_dir = Vector3(-sin(player.yaw), 0, -cos(player.yaw))
			player.dash_t = 0.22
			player.pad_t = 0.0
			player.inv_t = 0.5
			Arena.current.shake = 0.15
		"shield":
			player.shield_t = 4.0
		"drone":
			_drone_t = 8.0
			_drone_shot = 0.0
		"chrono":
			player.chrono_t = 5.0
			Arena.current.set_chrono(5.0)
		"nanite":
			player.heal(50.0)


func blast() -> void:
	if blast_cd > 0.0:
		return
	var a := Arena.current
	blast_cd = blast_cooldown * cdr()
	Sfx.beep(120, 0.5, "sawtooth", 0.25)
	a.shake = 0.5
	var hit := _aim_point(100.0)
	var cam := player.camera
	var pt: Vector3 = hit.position if hit else cam.global_position - cam.global_basis.z * 60.0
	a.tracer(player.weapons.muzzle_position(), pt, Color("#ff2bd6"))
	a.destroy_blocks(pt, 5.5)
	a.burst(pt, 30, Color("#ff2bd6"))
	a.area_damage(pt, 8.0, 70.0, "BLAST")


func tactical() -> void:
	if stun_n < 1:
		return
	var a := Arena.current
	stun_n -= 1
	if _stun_t <= 0.0:
		_stun_t = stun_recharge
	var hit := _aim_point(16.0)
	var cam := player.camera
	var pt: Vector3 = hit.position if hit else cam.global_position - cam.global_basis.z * 14.0
	a.tracer(player.weapons.muzzle_position(), pt, Color.WHITE)
	a.burst(pt, 26, Color.WHITE)
	Sfx.beep(1400, 0.3, "sine", 0.12)
	a.shake = maxf(a.shake, 0.15)
	a.area_damage(pt, 7.0, 0.0, "STUN", false, 2.5)


func call_streak(i: int) -> void:
	if not streak_ready(i):
		return
	var a := Arena.current
	streak_used[i] = true
	Sfx.beep(520 + i * 180, 0.4, "triangle", 0.15)
	a.kill_feed.emit("[color=#21e6ff]%s[/color] ONLINE" % STREAKS[i].name)
	match i:
		0:
			_drone_t = 15.0
			_drone_shot = 0.0
		1:
			var hit := _aim_point(120.0)
			var cam := player.camera
			var pt: Vector3 = hit.position if hit else cam.global_position - cam.global_basis.z * 40.0
			pt.y = maxf(pt.y, 0.0)
			for k in 3:
				var r := Vector3(randf() - 0.5, 0, randf() - 0.5)
				a.tracer(pt + Vector3(r.x * 4.0, 45.0, r.z * 4.0), pt + r * 2.0, Color("#ff2a3d"), 0.45)
			a.destroy_blocks(pt, 4.5)
			a.burst(pt, 40, Color("#ff2a3d"))
			a.shake = 0.7
			a.area_damage(pt, 9.0, 220.0, "STRIKE")
		2:
			player.heal(player.max_hp)
			player.inv_t = 6.0
	if streak_used.all(func(u): return u):
		streak_used = [false, false, false]
		a.reset_streak()
