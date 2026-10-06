class_name Player
extends CharacterBody3D
## First-person operative. Movement follows the original tuning: 6.5 m/s jog, x1.35 sprint, crouch / prone,
## slide out of a sprint, double jump, auto-vault over low cover, jetpack on Mk III+ armour, dash and grapple skills.
## Weapons live in WeaponController, skills / streaks / grenades in Abilities.
## Multiplayer: each peer simulates its own player (authority) and streams its state; on the other peers the
## same scene runs as a `remote` body that interpolates that state and animates / IKs the character from it.

signal died
signal health_changed(hp: float, max_hp: float)
signal damaged
signal healed
signal hit_confirmed(head: bool)      ## our round connected (hitmarker / headshot feedback)

const STANCE_SPEED := [1.0, 0.55, 0.25]
const STANCE_EYE := [1.65, 1.15, 0.55]
const STANCE_HEIGHT := [1.8, 1.25, 0.7]
const GRAVITY := 26.0
const GRAPPLE_RANGE := 20.0
const PAD_FLIGHT := 6.0                 ## max launch-pad flight (ends on landing)
const JUMP := 11.0
const DOUBLE_JUMP := 10.0
const RUN_SPEED := 6.5
const NET_RATE := 20.0

@export var head: Node3D
@export var camera: Camera3D
@export var gun_holder: Node3D
@export var weapons: WeaponController
@export var abilities: Abilities
@export var jet_fx: Node3D
@export var cable: MeshInstance3D
## The rigged main character. In first person only its shadow renders; T switches to an over-the-shoulder view.
@export var body: CharacterModel
@export var third_person_offset := Vector3(0.55, 0.2, 2.6)
@export_group("Full body")
## View-model gun placement (camera space) that the character's arms can actually reach.
@export var gun_hip := Vector3(0.14, -0.23, -0.34)
@export var gun_ads_z := -0.3
## Long guns sit further out (the rifle is over a metre long).
@export var long_gun_hip := Vector3(0.16, -0.25, -0.5)
@export var long_gun_ads_z := -0.4
@export var view_model_scale := 0.9
## Spine bend toward the look direction is limited to this; the arm IK covers the rest.
@export var max_body_pitch := 0.8
## Camera sits this far behind the model's eye marker, so in first person the torso and feet are in front of
## (and below) the camera and come into view when you look down.
@export var eye_setback := 0.04

var peer_id := 1
var remote := false              ## true on peers that don't own this player
var loadout := {}                ## {name, weapon, armor, skill}
var armor: ArmorData
var hp := 100.0
var max_hp := 100.0
var yaw := 0.0
var pitch := 0.0
var stance := 0          # 0 stand, 1 crouch, 2 prone
var sprinting := false
var eye_h := 1.65

# timers shared with Abilities
var inv_t := 0.0         # invulnerable (dash, overdrive)
var shield_t := 0.0
var chrono_t := 0.0
var dash_t := 0.0
var pad_t := 0.0                    ## launch-pad flight: steering locked while > 0
var _in_lift := false
var dash_dir := Vector3.ZERO

var jet_fuel := 1.0
var jet_on := false
var _jet_k := 0.0
var _jet_cool := 0.0

var _slide_t := 0.0
var _double_jumped := false
var _air_t := 0.0
var _crouch_press := -1.0
var _gait := 0.0
var _run_k := 0.0
var _sprint_k := 0.0
var _step_kick := 0.0
var _turn_t := -1.0
var _turn_from := 0.0
var _turn_cur := 0.0
var _turn_fx := {"roll": 0.0, "dip": 0.0, "fov": 0.0, "gx": 0.0, "gy": 0.0}
var _was_floor := true
var third_person := false
var _body_gun: WeaponModel
var _cam_dist := 2.6

# network
var _net_t := 0.0
var _net_pos := Vector3.ZERO
var _net_vel := Vector3.ZERO
var _net_yaw := 0.0
var _net_pitch := 0.0
var _net_floor := true
var _net_age := 0.0
var _net_weapon := -1
var _name_tag: Label3D

# first-person feel (inspired by docs/first_person_animation: springs, punch, recoil debt, camera on the head)
## A damped spring on a Vector3, sub-stepped for stability.
class Spring:
	var x := Vector3.ZERO
	var v := Vector3.ZERO
	var k := 120.0
	var c := 14.0
	func _init(stiff := 120.0, damp := 14.0) -> void:
		k = stiff
		c = damp
	func step(target: Vector3, dt: float) -> Vector3:
		var n := maxi(1, ceili(dt / 0.008))
		var h := dt / n
		for i in n:
			v += (-(x - target) * k - v * c) * h
			x += v * h
		return x
	func kick(impulse: Vector3) -> void:
		v += impulse

var _gun_pos := Spring.new(140.0, 15.0)
var _gun_rot := Spring.new(120.0, 13.0)
var _punch := Spring.new(170.0, 16.0)       ## view punch (pitch, yaw, roll)
var _fov_punch := Spring.new(160.0, 18.0)
var _dip := Spring.new(150.0, 14.0)          ## landing dip (y)
var _recoil_debt := 0.0
var _roll := 0.0
var _last_look := Vector2.ZERO
var _look_vel := Vector2.ZERO
var _land_v := 0.0
var _trauma := 0.0
var _net_scoped := false

# grapple / ledge
var grapple: Dictionary = {}
var ledge: Dictionary = {}


## The house style: black / grey / crimson cel shading with hairline ink.
const STYLE := {"outline": 0.0008, "outline_max": 0.008, "tint": Color(1.5, 1.5, 1.6), "desaturate": 0.9, "rim_strength": 2.0}


func _ready() -> void:
	add_to_group("player")
	body.stylize(STYLE)
	armor = Game.armor(str(loadout.get("armor", "")))
	max_hp = armor.max_health
	hp = max_hp
	cable.top_level = true
	cable.visible = false
	jet_fx.visible = false
	weapons.weapon_changed.connect(func(w, _o): _attach_body_gun(w))
	_attach_body_gun(weapons.weapon)
	if remote:
		camera.current = false
		abilities.drone.visible = false
		set_process_unhandled_input(false)
		_net_pos = global_position
		set_third_person(true)
		_name_tag = Label3D.new()
		_name_tag.text = str(loadout.get("name", "OPERATIVE"))
		_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_tag.no_depth_test = true
		_name_tag.fixed_size = true
		_name_tag.pixel_size = 0.0012
		_name_tag.font_size = 22
		_name_tag.outline_size = 6
		_name_tag.modulate = Color("#21e6ff")
		_name_tag.position = Vector3(0, 2.15, 0)
		add_child(_name_tag)
		return
	camera.current = true
	camera.fov = Game.settings.fov
	body.set_first_person(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(hp, max_hp)


## Another player's loadout changed (roster update): armour affects their health bar and jetpack.
func apply_loadout(info: Dictionary) -> void:
	loadout = info
	armor = Game.armor(str(info.get("armor", "")))
	max_hp = armor.max_health
	if _name_tag:
		_name_tag.text = str(info.get("name", "OPERATIVE"))


func is_dead() -> bool:
	return hp <= 0.0


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = 0.0022 * Game.settings.sensitivity * (1.0 - 0.3 * weapons.ads) * (0.32 if weapons.scoped_view() else 1.0)
		yaw -= clampf(event.relative.x, -150, 150) * s
		pitch = clampf(pitch - clampf(event.relative.y, -150, 150) * s, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("jump"):
		_jump_button()
	elif event.is_action_pressed("crouch"):
		if sprinting and is_on_floor():
			_slide()
		else:
			_crouch_press = Time.get_ticks_msec() / 1000.0
	elif event.is_action_released("crouch"):
		if _crouch_press >= 0.0 and Time.get_ticks_msec() / 1000.0 - _crouch_press < 0.3:
			stance = 0 if stance == 1 else 1
		_crouch_press = -1.0
	elif event.is_action_pressed("quick_turn"):
		quick_turn()
	elif event.is_action_pressed("toggle_view"):
		set_third_person(not third_person)


## Recoil climbs the look, then most of it is paid back over the next moments (aim follows it).
func add_recoil(kick: float) -> void:
	pitch += kick
	yaw += (randf() - 0.5) * kick
	_recoil_debt += kick * 0.72


## Heavy shot feel: view punch, FOV punch, a little trauma and a hard gun kick.
func view_kick(kick: float) -> void:
	_punch.kick(Vector3(kick * 34.0, (randf() - 0.5) * kick * 10.0, (randf() - 0.5) * kick * 16.0))
	_fov_punch.kick(Vector3(kick * 120.0, 0, 0))
	_gun_pos.kick(Vector3(0, kick * 1.2, kick * 9.0))
	_gun_rot.kick(Vector3(kick * 26.0, 0, (randf() - 0.5) * kick * 8.0))
	_trauma = minf(1.0, _trauma + kick * 4.0)


## Our round connected: HUD marker + the sound.
func confirm_hit(head: bool) -> void:
	hit_confirmed.emit(head)
	Sfx.play("headshot" if head else "hitmarker", 0.9 if head else 0.6)


# ------------------------------------------------------------------ physics
func _physics_process(delta: float) -> void:
	if remote:
		_remote_step(delta)
		return
	_net_send(delta)
	if is_dead():
		return
	if _crouch_press >= 0.0 and Time.get_ticks_msec() / 1000.0 - _crouch_press >= 0.3:
		stance = 2
		_crouch_press = -1.0
	inv_t -= delta
	shield_t -= delta
	chrono_t -= delta
	_turn_step(delta)
	_move(delta)
	_jet_visuals(delta)
	_update_shape()
	if hp < max_hp:
		hp = minf(max_hp, hp + armor.regen * delta)
		health_changed.emit(hp, max_hp)
	_camera(delta)
	_animate_body(delta)


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var mx := input.x
	var f := -input.y
	var l := Vector2(mx, f).length()
	var n := maxf(1.0, l)
	var ads := weapons.ads
	sprinting = on_floor and _slide_t <= 0.0 and not weapons.aiming and ads < 0.35 and f > 0.3 and Input.is_action_pressed("sprint")
	if sprinting and stance:
		stance = 0
	var sp: float = RUN_SPEED * armor.speed * weapons.weapon.move_multiplier * (1.35 if sprinting else 1.0) * STANCE_SPEED[stance] * (1.0 - 0.4 * ads)
	var wx := (cos(yaw) * mx - sin(yaw) * f) / n
	var wz := (-sin(yaw) * mx - cos(yaw) * f) / n
	if _slide_t > 0.0:
		_slide_t -= delta
		if _slide_t <= 0.0:
			stance = 1
		if l < 0.1:
			wx = -sin(yaw)
			wz = -cos(yaw)
		sp = 14.0 * armor.speed * (_slide_t / 0.75 + 0.3)

	if not ledge.is_empty():
		_ledge_step(delta)
		return
	if not grapple.is_empty() and grapple.pull:
		_grapple_step(delta)
	else:
		if dash_t > 0.0:
			dash_t -= delta
			velocity.x = dash_dir.x * 34.0
			velocity.z = dash_dir.z * 34.0
		elif pad_t > 0.0:
			pad_t -= delta       # launch-pad flight keeps its arc until you land (or grapple / dash out of it)
			if on_floor and pad_t < PAD_FLIGHT - 0.25:
				pad_t = 0.0
		else:
			var c := minf(1.0, delta * (10.0 if on_floor else 3.0))
			velocity.x += (wx * sp - velocity.x) * c
			velocity.z += (wz * sp - velocity.z) * c
		velocity.y -= GRAVITY * delta
		_jet_step(delta, on_floor)
		_traversal_step()
	if not grapple.is_empty():
		_grapple_tick(delta)

	var pre_vel := velocity
	move_and_slide()

	# auto-vault: walking into low cover (< ~1.5 m) hops you over it
	if on_floor and l > 0.1 and is_on_wall() and grapple.is_empty():
		var wn := get_wall_normal()
		var probe := global_position + Vector3(0, 1.85, 0) - Vector3(wn.x, 0, wn.z) * 0.6
		if Arena.current and Arena.current.is_clear(probe, 0.3):
			velocity.y = 10.0

	var now_floor := is_on_floor()
	if now_floor:
		_double_jumped = false
		if not _was_floor and _air_t > 0.2:
			Sfx.play("land", minf(1.0, 0.4 + _air_t * 0.5))
			_dip.kick(Vector3(0, -minf(2.2, 0.6 + _air_t * 1.6), 0))
			_gun_pos.kick(Vector3(0, -minf(1.2, 0.3 + _air_t), 0))
			_step_kick = minf(0.13, 0.035 + _air_t * 0.09)
			_gait = roundf(_gait / PI) * PI
		_air_t = 0.0
	else:
		_air_t += delta
	_was_floor = now_floor

	# gait: one footstep per half cycle
	var hs := Vector2(velocity.x, velocity.z).length()
	if now_floor and hs > 0.4 and _slide_t <= 0.0:
		var stride := 0.9 if stance == 2 else clampf(0.55 + hs * 0.22, 0.6, 2.6)
		var before := floori(_gait / PI)
		_gait += PI * minf(hs * delta, 1.5) / stride
		if floori(_gait / PI) != before:
			_step_kick = maxf(_step_kick, 0.008 * minf(1.2, hs / 6.0))
			Sfx.play("footstep", (0.55 if stance else 1.0) * minf(1.0, 0.35 + hs / 8.0), randf_range(0.9, 1.1))
	_run_k += ((minf(1.35, hs / 6.5) if now_floor and hs > 0.5 and _slide_t <= 0.0 else 0.0) - _run_k) * minf(1.0, delta * 8.0)
	var sprint_target := 1.0 if sprinting and hs > 0.5 and not weapons.trigger and not weapons.reloading() and ads < 0.1 else 0.0
	_sprint_k += (sprint_target - _sprint_k) * minf(1.0, delta * (6.0 if sprinting else 11.0))
	if Arena.current:
		var b := Arena.current.bounds
		global_position.x = clampf(global_position.x, b.position.x, b.end.x)
		global_position.z = clampf(global_position.z, b.position.y, b.end.y)
	if global_position.y < -5.0:
		global_position.y = 1.0
		velocity = Vector3.ZERO


## Gravity lifts carry you up their beam; launch pads throw you along a fixed arc.
func _traversal_step() -> void:
	var p := global_position
	var lifted := false
	for l in get_tree().get_nodes_in_group("lifts"):
		var v: float = l.lift_velocity(p)
		if v >= 0.0:
			velocity.y = maxf(velocity.y, v)
			lifted = true
			break
	if lifted != _in_lift:
		_in_lift = lifted
		if lifted:
			Sfx.play("lift", 0.6)
	if pad_t <= 0.0 and velocity.y <= 0.5:
		for pad in get_tree().get_nodes_in_group("pads"):
			if pad.touching(p):
				velocity = pad.launch_velocity()
				pad_t = PAD_FLIGHT
				_double_jumped = true
				Sfx.play("launch", 0.9)
				break


func _jump_button() -> void:
	if stance > 0:
		stance = 0
		return
	if not grapple.is_empty() and grapple.pull:
		var hanging: bool = grapple.hang > 0.0
		var kx := velocity.x
		var kz := velocity.z
		end_grapple(11.0)
		if hanging:
			velocity.x = -sin(yaw) * 7.0
			velocity.z = -cos(yaw) * 7.0
		else:
			velocity.x = kx * 0.6
			velocity.z = kz * 0.6
		return
	if is_on_floor():
		velocity.y = JUMP * armor.jump_multiplier
		_double_jumped = false
		Sfx.play("footstep", 0.8)
	elif not _double_jumped and grapple.is_empty():
		_double_jumped = true
		velocity.y = DOUBLE_JUMP * armor.jump_multiplier
		if Arena.current:
			Arena.current.burst(global_position + Vector3(0, 0.1, 0), 10, Color("#21e6ff"))
		Sfx.beep(520, 0.14, "sine", 0.08)


func _slide() -> void:
	if is_on_floor() and _slide_t <= 0.0:
		_slide_t = 0.75
		stance = 0


func _update_shape() -> void:
	var shape: CollisionShape3D = $Shape
	var cap := shape.shape as CapsuleShape3D
	var h: float = STANCE_HEIGHT[1] if _slide_t > 0.0 else STANCE_HEIGHT[stance]
	if absf(cap.height - h) > 0.01:
		if h > cap.height and Arena.current and not Arena.current.is_clear(global_position + Vector3(0, h - 0.3, 0), 0.3):
			stance = maxi(stance, 1)   # can't stand up under something
			return
		cap.height = h
		shape.position.y = h * 0.5


# ------------------------------------------------------------------ jetpack (Mk III / Mk IV)
func jet_available() -> bool:
	return armor.tier >= 2


func _jet_step(delta: float, on_floor: bool) -> void:
	if not jet_available():
		return
	var want := Input.is_action_pressed("jump") and not on_floor and stance == 0 and jet_fuel > 0.0 and (_air_t > 0.18 or velocity.y < 1.5) and grapple.is_empty()
	if want and not jet_on and jet_fuel < 0.08:
		want = false
	if want != jet_on:
		jet_on = want
		Sfx.loop("jet", want, 0.6)
	var mk4 := armor.tier >= 3
	if jet_on:
		velocity.y = minf(8.5 if mk4 else 7.0, velocity.y + (40.0 if mk4 else 36.0) * delta * (1.6 if velocity.y < 0.0 else 1.0))
		jet_fuel = maxf(0.0, jet_fuel - delta / (3.4 if mk4 else 2.6))
		_jet_cool = 0.5
		if Arena.current:
			Arena.current.shake = maxf(Arena.current.shake, 0.02)
	else:
		_jet_cool -= delta
		if on_floor and _jet_cool <= 0.0:
			jet_fuel = minf(1.0, jet_fuel + delta / (2.2 if mk4 else 2.8))


func _jet_visuals(delta: float) -> void:
	_jet_k += ((1.0 if jet_on else 0.0) - _jet_k) * minf(1.0, delta * (14.0 if jet_on else 6.0))
	jet_fx.visible = _jet_k > 0.01
	if jet_fx.visible:
		jet_fx.rotation.y = yaw
		jet_fx.scale = Vector3(1, 0.4 + 0.6 * _jet_k, 1)
		if not remote:
			Sfx.loop_pitch("jet", 0.8 + 0.4 * clampf((velocity.y + 2.0) / 10.0, 0.0, 1.0))


# ------------------------------------------------------------------ damage
## Returns true when the hit landed (not blocked by dash invulnerability or the overshield).
func take_damage(x: float) -> bool:
	if inv_t > 0.0 or shield_t > 0.0 or is_dead():
		return false
	hp -= x * (1.0 - armor.damage_reduction)
	if Arena.current:
		Arena.current.shake = maxf(Arena.current.shake, 0.35)
	damaged.emit()
	health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		hp = 0.0
		Sfx.loop("jet", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_third_person(true)
		body.play(&"death", 0.15)
		end_grapple()
		jet_on = false
		died.emit()
	return true


## Host -> owner: a spider's claw hit this player.
@rpc("any_peer", "call_remote", "reliable")
func net_hit(dmg: float) -> void:
	if multiplayer.get_remote_sender_id() == 1 and not remote:
		take_damage(dmg)


## Back in the fight after a death (the arena picks the spot, next to a living teammate when there is one).
func respawn(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	hp = max_hp
	stance = 0
	inv_t = 2.0
	shield_t = 0.0
	jet_fuel = 1.0
	set_third_person(false)
	body.play(&"idle_rifle", 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(hp, max_hp)
	healed.emit()


# ------------------------------------------------------------------ network state
func _net_send(delta: float) -> void:
	if not Net.is_online():
		return
	_net_t += delta
	if _net_t < 1.0 / NET_RATE:
		return
	_net_t = 0.0
	var flags := stance | (4 if is_on_floor() else 0) | (8 if jet_on else 0) | (16 if is_dead() else 0) | (32 if _slide_t > 0.0 else 0) | (64 if weapons.scoped_view() else 0)
	if Arena.current:
		Arena.current.send_player_state(global_position, velocity, yaw, pitch, flags, Game.DB.weapons.find(weapons.weapon), hp)


## Called by the arena with the owner's latest state.
func net_state(pos: Vector3, vel: Vector3, y: float, p: float, flags: int, weapon_idx: int, health: float) -> void:
	_net_pos = pos
	_net_vel = vel
	_net_yaw = y
	_net_pitch = p
	_net_age = 0.0
	stance = flags & 3
	_net_floor = flags & 4 != 0
	jet_on = flags & 8 != 0
	_slide_t = 0.1 if flags & 32 else 0.0
	_net_scoped = flags & 64 != 0
	var was_dead := is_dead()
	hp = health
	if hp <= 0.0 and not was_dead:
		body.play(&"death", 0.15)
	if weapon_idx != _net_weapon and weapon_idx >= 0 and weapon_idx < Game.DB.weapons.size():
		_net_weapon = weapon_idx
		_attach_body_gun(Game.DB.weapons[weapon_idx])


func _remote_step(delta: float) -> void:
	_net_age += delta
	var target := _net_pos + _net_vel * minf(_net_age, 0.15)      # short extrapolation hides packet gaps
	if global_position.distance_to(target) > 6.0:
		global_position = target
	else:
		global_position = global_position.lerp(target, minf(1.0, delta * 14.0))
	velocity = _net_vel
	yaw = lerp_angle(yaw, _net_yaw, minf(1.0, delta * 16.0))
	pitch = lerpf(pitch, _net_pitch, minf(1.0, delta * 16.0))
	_air_t = 0.0 if _net_floor else _air_t + delta
	eye_h += (STANCE_EYE[stance] - eye_h) * minf(1.0, delta * 10.0)
	head.position = Vector3(0, eye_h, 0)
	head.rotation = Vector3(0, yaw, 0)
	camera.rotation = Vector3(pitch, 0, 0)
	_jet_visuals(delta)
	_animate_body(delta)
	_glint()


## A scoped rifle flashes its lens at whoever it is pointed at (stronger the more directly it faces the viewer).
func _glint() -> void:
	var g := _body_gun.get_node_or_null("Glint") as MeshInstance3D if _body_gun else null
	if g == null:
		return
	var cam := get_viewport().get_camera_3d()
	if not _net_scoped or cam == null:
		g.visible = false
		return
	var fwd := -(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)).z
	var to_cam := (cam.global_position - g.global_position).normalized()
	var k := clampf((fwd.dot(to_cam) - 0.93) / 0.07, 0.0, 1.0)
	g.visible = k > 0.0
	var d := cam.global_position.distance_to(g.global_position)
	g.top_level = true
	g.global_position = _body_gun.get_node("ScopeEye").global_position + fwd * 0.12
	g.scale = Vector3.ONE * (0.4 + d * 0.035) * k * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.02))


func remote_fire_flash() -> void:
	if _body_gun:
		_body_gun.fire_flash()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	healed.emit()
	health_changed.emit(hp, max_hp)


# ------------------------------------------------------------------ quick 180 (V)
func quick_turn() -> void:
	if _turn_t >= 0.0:
		return
	_turn_t = 0.0
	_turn_from = yaw
	_turn_cur = yaw
	Sfx.play("footstep", 0.7)


func _turn_step(delta: float) -> void:
	if _turn_t < 0.0:
		return
	_turn_t += delta
	var u := minf(1.0, _turn_t / 0.36)
	var e := 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0
	var b := sin(PI * u)
	var target := _turn_from + PI * e
	yaw += target - _turn_cur
	_turn_cur = target
	_turn_fx = {"roll": 0.075 * b, "dip": 0.06 * b, "fov": 7.0 * b, "gx": -0.07 * sin(PI * minf(1.0, u * 1.15)), "gy": -0.42 * sin(PI * minf(1.0, u * 1.1))}
	if u >= 1.0:
		_turn_t = -1.0
		_turn_fx = {"roll": 0.0, "dip": 0.0, "fov": 0.0, "gx": 0.0, "gy": 0.0}


# ------------------------------------------------------------------ grapple + ledge mantle
## Fires the grapple along the view ray (GRAPPLE_RANGE). Returns false when nothing is in range.
func fire_grapple() -> bool:
	var a := Arena.current
	var from := camera.global_position
	var hit := a.raycast(from, from - camera.global_basis.z * GRAPPLE_RANGE, Arena.LAYER_WORLD)
	if hit.is_empty():
		Sfx.beep(160, 0.12, "square", 0.05)
		return false
	var p: Vector3 = hit.position
	var nrm: Vector3 = hit.normal
	var roof := nrm.y > 0.5
	var top := p.y
	var tg: Vector3
	var edge := Vector3.ZERO
	var near_top := false
	if not roof:
		# find the top of the wall just behind the hit point
		var q := p - nrm * 0.3
		var probe := a.raycast(Vector3(q.x, p.y + 8.0, q.z), Vector3(q.x, p.y - 0.1, q.z), Arena.LAYER_WORLD)
		if not probe.is_empty() and probe.normal.y > 0.5:
			top = probe.position.y
			near_top = top - p.y < 6.0
	if roof:
		tg = p + Vector3(0, 1.2, 0)
	elif near_top:
		edge = Vector3(p.x, top, p.z)
		tg = edge + nrm * 0.65
		tg.y = top - 0.85
	else:
		tg = p + nrm * 1.6
	grapple = {"p": p, "n": nrm, "tg": tg, "edge": edge, "roof": roof, "ledge": near_top, "t": 0.0, "shot": 0.0, "pull": false, "stall": 0.0, "hang": 0.0, "last": global_position}
	stance = 0
	_slide_t = 0.0
	pad_t = 0.0
	Sfx.beep(900, 0.16, "sawtooth", 0.06)
	Sfx.beep(300, 0.25, "square", 0.03)
	return true


func end_grapple(pop := 0.0) -> void:
	if grapple.is_empty():
		return
	grapple = {}
	cable.visible = false
	_double_jumped = false
	if pop > 0.0:
		velocity.y = maxf(velocity.y, pop)


func _grapple_tick(delta: float) -> void:
	grapple.t += delta
	var muzzle := camera.to_global(Vector3(-0.24, -0.18, -0.8))
	if not grapple.pull:
		grapple.shot = minf(1.0, grapple.shot + delta * 110.0 / maxf(1.0, muzzle.distance_to(grapple.p)))
		if grapple.shot >= 1.0:
			grapple.pull = true
			Sfx.beep(220, 0.35, "square", 0.035)
	if grapple.t > (6.0 if grapple.hang > 0.0 else 2.6):
		end_grapple(4.0)
		return
	var tip: Vector3 = muzzle.lerp(grapple.p, grapple.shot)
	cable.visible = true
	var len := muzzle.distance_to(tip)
	cable.global_position = (muzzle + tip) * 0.5
	if len > 0.01:
		cable.global_basis = Basis.looking_at(tip - muzzle, Vector3.UP if absf((tip - muzzle).normalized().y) < 0.99 else Vector3.RIGHT)
	cable.scale = Vector3(1, 1, maxf(0.01, len))


func _grapple_step(delta: float) -> void:
	var to: Vector3 = grapple.tg - (global_position + Vector3(0, 0.9, 0))
	var d := to.length()
	if grapple.ledge and (d < 1.5 or grapple.stall > 0.12):
		_start_ledge()
		return
	if d < 1.4 or grapple.hang > 0.0:
		if grapple.roof:
			end_grapple(5.0)
			return
		grapple.hang += delta     # cling to the wall: jump off, or fire the grapple again to climb
		velocity = Vector3.ZERO
		if grapple.hang > 3.0:
			end_grapple(0.1)
		return
	var sp := minf(34.0, 12.0 + d * 2.2)
	velocity = to / d * sp
	if global_position.distance_to(grapple.last) < sp * delta * 0.25:
		grapple.stall += delta
		if grapple.stall > 0.22:
			end_grapple(9.0)
			return
	else:
		grapple.stall = 0.0
	grapple.last = global_position


func _start_ledge() -> void:
	var e: Vector3 = grapple.edge
	var n: Vector3 = grapple.n
	n.y = 0
	n = n.normalized()
	ledge = {"t": 0.0, "n": n, "from": global_position,
		"hang": Vector3(e.x + n.x * 0.45, e.y - 1.72, e.z + n.z * 0.45),
		"peak": Vector3(e.x + n.x * 0.30, e.y - 0.02, e.z + n.z * 0.30),
		"stand": Vector3(e.x - n.x * 0.65, e.y + 0.02, e.z - n.z * 0.65)}
	grapple = {}
	cable.visible = false
	velocity = Vector3.ZERO
	Sfx.play("land", 0.5)


func _ledge_step(delta: float) -> void:
	ledge.t += delta
	var t: float = ledge.t
	var sm := func(x: float) -> float: return x * x * (3.0 - 2.0 * x)
	if t < 0.7:
		var ty := atan2(ledge.n.x, ledge.n.z)
		yaw += wrapf(ty - yaw, -PI, PI) * minf(1.0, delta * 12.0)
	var p: Vector3
	if t < 0.22:
		p = ledge.from.lerp(ledge.hang, sm.call(t / 0.22))
	elif t < 0.70:
		var u: float = sm.call((t - 0.22) / 0.48)
		p = ledge.hang.lerp(ledge.peak, u)
		p.y = ledge.hang.y + (ledge.peak.y - ledge.hang.y) * pow(u, 0.8)
	else:
		var u: float = sm.call(minf(1.0, (t - 0.70) / 0.28))
		p = ledge.peak.lerp(ledge.stand, u)
		p.y += 0.12 * sin(PI * u)
	global_position = p
	velocity = Vector3.ZERO
	if t >= 0.98:
		global_position = ledge.stand
		ledge = {}
		Sfx.play("land", 0.7)


# ------------------------------------------------------------------ camera, head bob, gun sway
func _camera(delta: float) -> void:
	var a := Arena.current
	_trauma = maxf(_trauma - delta * 1.6, (a.shake if a else 0.0) * 2.0)
	var target_eye: float = STANCE_EYE[stance]
	eye_h += (target_eye - eye_h) * minf(1.0, delta * 10.0)
	_step_kick *= exp(-delta * 16.0)
	# recoil debt: most of each kick is repaid smoothly, so the sight comes back near the target
	var repay := _recoil_debt * (1.0 - exp(-delta * 7.0))
	pitch -= repay
	_recoil_debt -= repay
	var ads := weapons.ads
	var g_a := _run_k * (1.0 - ads) * (0.3 if stance == 2 else 1.0)
	var heft := 1.7 if weapons.weapon.bolt_action else 1.0
	# look speed (for weapon lag) and body-frame velocity (for move sway / strafe roll)
	var look := Vector2(yaw, pitch)
	_look_vel = _look_vel.lerp((look - _last_look) / maxf(delta, 0.001), minf(1.0, delta * 14.0))
	_last_look = look
	var local_v := Basis(Vector3.UP, yaw).inverse() * velocity
	_roll = lerpf(_roll, clampf(-local_v.x * 0.0045, -0.04, 0.04), minf(1.0, delta * 8.0))
	if third_person or remote:
		var sh := (randf() - 0.5) * _trauma * 0.3
		head.position = Vector3(sh, eye_h - _turn_fx.dip, sh)
	head.rotation = Vector3(0, yaw, 0)
	var dip := _dip.step(Vector3.ZERO, delta)
	var punch := _punch.step(Vector3.ZERO, delta)
	var fovp := _fov_punch.step(Vector3.ZERO, delta)
	var ledge_tilt := 0.42 * sin(PI * minf(1.0, ledge.t / 0.98)) if not ledge.is_empty() else 0.0
	var tn := Time.get_ticks_msec() * 0.001
	var shake := Vector3(sin(tn * 37.0) + sin(tn * 53.0 + 1.0), sin(tn * 41.0 + 2.0), sin(tn * 29.0 + 3.0)) * _trauma * _trauma * 0.012
	var sway := weapons.sway
	camera.position = Vector3(0, dip.y * 0.05, 0) if not third_person else camera.position
	camera.rotation = Vector3(pitch + punch.x * 0.01 + shake.x + sway.y - 0.03 * _sprint_k - ledge_tilt,
		punch.y * 0.01 + shake.y - sway.x,
		(0.08 if _slide_t > 0.0 else 0.0) + _turn_fx.roll + _roll + punch.z * 0.01 + shake.z)
	camera.fov = weapons.view_fov(Game.settings.fov) + _turn_fx.fov + fovp.x * 0.1

	# weapon in camera space: hip / ADS pose plus springs (look lag, move sway, jump lift, bob, breathing, sprint carry)
	var na := 1.0 - ads
	var g2 := _gait - 0.45
	var j_a := _run_k * na * (1.0 - _sprint_k)
	var still := clampf(1.0 - Vector2(velocity.x, velocity.z).length() / 2.0, 0.0, 1.0)
	var bob := Vector3(0.013 * j_a * sin(g2), -0.014 * j_a * cos(2.0 * g2), 0.008 * j_a * cos(g2))
	var breathe := Vector3(0, 0.0025 * sin(tn * 1.3), 0) * still * (0.3 + 0.7 * na)
	var lag_p := Vector3(-_look_vel.x * 0.006, _look_vel.y * 0.004, 0).limit_length(0.05) * (0.25 + 0.75 * na) * heft
	var move_p := Vector3(-local_v.x * 0.0035, -velocity.y * 0.0025, local_v.z * 0.002).limit_length(0.04) * (0.3 + 0.7 * na)
	var air := Vector3(0, -0.02, 0) if _air_t > 0.1 else Vector3.ZERO
	var gp := _gun_pos.step(lag_p + move_p + air, delta * (1.0 / sqrt(heft)))
	var lag_r := Vector3(_look_vel.y * 0.012, _look_vel.x * 0.02, _look_vel.x * 0.02).limit_length(0.12) * (0.2 + 0.8 * na) * heft
	var gr := _gun_rot.step(lag_r + Vector3(0, 0, -local_v.x * 0.004), delta * (1.0 / sqrt(heft)))
	var dipg := weapons.swap_dip()
	var hip := long_gun_hip if weapons.weapon.bolt_action else gun_hip
	var ads_z := long_gun_ads_z if weapons.weapon.bolt_action else gun_ads_z
	var base_y := lerpf(hip.y, -_sight_height() * view_model_scale, ads)
	gun_holder.position = Vector3(hip.x * na + _turn_fx.gx, base_y - dipg - _step_kick * 0.35 * na, lerpf(hip.z, ads_z, ads)) \
		+ bob + breathe + gp + Vector3(0, 0, weapons.recoil * 2.0 * (1.0 - 0.5 * ads))
	var q := _sprint_k * na
	var sw := sin(_gait)
	var ud := cos(2.0 * _gait)
	gun_holder.rotation = Vector3(dipg * 1.2 + 0.025 * j_a * cos(2.0 * g2) + q * (0.42 + 0.06 * ud) + 0.004 * sin(tn * 1.3) * still,
		0.02 * j_a * sin(g2) + _turn_fx.gy + q * (0.78 + 0.13 * sw),
		0.035 * j_a * sin(g2) + _turn_fx.gy * 0.35 + q * (0.68 + 0.16 * sw)) + gr * Vector3(1, 1, 1)
	# scoped: hide the rifle once the scope fills the view
	if weapons.view_model():
		weapons.view_model().visible = not weapons.scoped_view() or third_person


func _sight_height() -> float:
	var vm := weapons.view_model()
	if vm and vm.has_node("ScopeEye"):
		return vm.get_node("ScopeEye").position.y
	return weapons.weapon.sight_height


## First person: the camera rides the animated head (position only; the look stays the player's own),
## so the body's own motion (gait, crouch, lean, landings) moves the eye. Runs every drawn frame.
func _process(_delta: float) -> void:
	if remote or third_person or is_dead() or body == null or body.fp_head == null:
		return
	var eye := body.eye_world()
	head.global_position = eye + Basis(Vector3.UP, yaw) * Vector3(0, 0, eye_setback)


# ------------------------------------------------------------------ body / third person
func set_third_person(on: bool) -> void:
	third_person = on
	body.set_first_person(not on)
	gun_holder.visible = not on
	if _body_gun:
		_body_gun.visible = on
	if not on:
		camera.position = Vector3.ZERO


## The third-person gun rides the body's chest mount (the *_rifle animations hold their hands on it).
func _attach_body_gun(w: WeaponData) -> void:
	if _body_gun:
		_body_gun.queue_free()
	_body_gun = w.model_scene.instantiate()
	body.weapon_grip.add_child(_body_gun)
	ToonStyle.apply(_body_gun, {"outline": 0.0008, "outline_max": 0.008, "tint": Color(1.4, 1.4, 1.5), "desaturate": 0.8})
	# long guns sit tucked into the shoulder pocket (closer and more central), and the torso turns further into
	# them so the support arm can reach the fore-end
	if w.bolt_action:
		_body_gun.position = Vector3(0.07, 0.03, -0.1)
	body.ik.chest_twist = -0.85 if w.bolt_action else -0.5
	_body_gun.visible = third_person


func body_muzzle() -> Vector3:
	return _body_gun.muzzle.global_position if _body_gun and _body_gun.muzzle else camera.global_position


func body_fire_flash() -> void:
	if third_person and _body_gun:
		_body_gun.fire_flash()


func _animate_body(delta: float) -> void:
	body.rotation.y = yaw + PI     # the model faces +Z, the player looks down -Z
	# first person only bends the spine to look up; leaning forward to look down would hide your own body
	body.aim_pitch = clampf(pitch, -max_body_pitch, max_body_pitch) if third_person or body.fp_head == null else pitch
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_dead():
		body.ik.arm_weight = 0.0
		return
	var grounded := _net_floor if remote else is_on_floor()
	if not grounded and _air_t > 0.15:
		body.play(&"jump_rifle", 0.2)
	elif stance == 2:
		body.play(&"prone_rifle", 0.35)
	elif stance == 1 or _slide_t > 0.0:
		body.play(&"crouch_rifle", 0.2)
	elif hs > 4.5:
		body.play(&"run_rifle", 0.2, hs / 7.5)
	elif hs > 0.4:
		body.play(&"walk_rifle", 0.2, maxf(0.6, hs / 3.4))
	else:
		body.play(&"idle_rifle", 0.3)
	# full body: slide the body under the head so the character's eyes sit where the player's eyes are
	# (crouch / prone / leaning over a look-down all line up; foot IK keeps the feet on the ground)
	if body.fp_head == null:
		# older rigs: slide the body under the camera so the model's eyes line up with it
		var eye := body.eye.global_position - body.global_basis.z.normalized() * eye_setback
		var err := head.global_position - eye
		var off := body.position + err * minf(1.0, delta * 18.0)
		var flat := Vector2(off.x, off.z).limit_length(1.0)
		body.position = Vector3(flat.x, clampf(off.y, -0.7, 0.3), flat.y)
	else:
		body.position = Vector3.ZERO      # the camera follows the head instead (see _process)
	# looking down: dissolve the chest plate so the gun, legs and feet stay visible
	if not third_person:
		var k := clampf((-pitch - 0.35) / 0.6, 0.0, 1.0)
		body.set_fp_fade(body.fp_fade_near + 0.14 * k, body.fp_fade_far + 0.16 * k)
	# arm IK: hands on whichever gun is showing; the left hand goes to the magazine during reloads
	var gun: WeaponModel = _body_gun if third_person else weapons.view_model()
	if gun and gun.grip_hand:
		body.ik.arm_weight = move_toward(body.ik.arm_weight, 1.0, delta * 4.0)
		var bt := weapons.bolt_t if not third_person else -1.0
		body.ik.right_target = gun.grip_target(bt, weapons.reload_phase())
		body.ik.left_target = gun.support_target(weapons.reload_phase())
		# hand orientation from the gun's own axes: barrel forward f, up u, the shooter's right r
		var f := (gun.muzzle.global_position - gun.grip_hand.global_position).normalized() if gun.muzzle else -camera.global_basis.z
		var u := gun.global_basis.y.normalized()
		u = (u - f * u.dot(f)).normalized()
		var r := f.cross(u).normalized()
		var rl := weapons.reload_phase() if not third_person else -1.0
		var on_bolt := bt > 0.1 and bt < 0.85 or (rl >= 0.0 and ((rl > 0.08 and rl < 0.28) or (rl > 0.68 and rl < 0.9)))
		if on_bolt:
			# thumb and fingers pinch the bolt knob from above and behind
			body.ik.right_hand_dir = (f * 0.55 - u * 0.45 - r * 0.2).normalized()
			body.ik.right_palm_dir = (-u * 0.3 + f * 0.2 - r * 0.9).normalized()
			body.ik.right_curl = 0.75
			body.ik.right_thumb = 0.85
		else:
			# pistol grip: fingers wrap down and across from the right side, thumb over the top
			body.ik.right_hand_dir = (-u * 0.8 + f * 0.35 - r * 0.25).normalized()
			body.ik.right_palm_dir = (-r * 0.9 - u * 0.1).normalized()
			body.ik.right_curl = 0.95
			body.ik.right_thumb = 0.9
		if rl >= 0.0 and rl > 0.14 and rl < 0.84:
			body.ik.left_hand_dir = Vector3.ZERO           # fetching / pressing the clip: keep the arm's own hand
			body.ik.left_palm_dir = Vector3.ZERO
			body.ik.left_curl = 0.7
			body.ik.left_thumb = 0.9
		else:
			# support hand: palm up under the handguard, fingers curling up its right side
			body.ik.left_hand_dir = (f * 0.75 + r * 0.55 + u * 0.1).normalized()
			body.ik.left_palm_dir = (u * 0.9 + r * 0.25).normalized()
			body.ik.left_curl = 0.6
			body.ik.left_thumb = 0.45
		if body.grip_lock:
			body.grip_lock.weight = body.ik.arm_weight
			body.grip_lock.right_target = body.ik.right_target
			body.grip_lock.left_target = body.ik.left_target
		if body.spine:
			body.spine.strength = body.ik.arm_weight * (0.85 if not third_person else 0.5)
	else:
		body.ik.arm_weight = 0.0
		if body.grip_lock:
			body.grip_lock.weight = 0.0
		if body.spine:
			body.spine.strength = 0.0
	if third_person and not remote:
		# over-the-shoulder boom that pulls in when a wall is behind the player
		var want := Basis(Vector3.RIGHT, pitch) * third_person_offset
		var from := head.global_position
		var to := head.global_transform * want
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		var dist := want.length()
		if not hit.is_empty():
			dist = maxf(0.3, from.distance_to(hit.position) - 0.2)
		_cam_dist = dist if dist < _cam_dist else lerpf(_cam_dist, dist, minf(1.0, delta * 6.0))
		camera.position = want.normalized() * _cam_dist
