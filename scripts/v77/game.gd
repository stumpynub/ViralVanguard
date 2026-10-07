class_name V77Game
extends Node3D
## Neon Core match: a port of v77's game loop (tick / move / fire / spiders / waves), keeping its variable names,
## constants and order of operations so the mechanics match the original. Units: metres, seconds, radians.

signal died(score: int, wave: int)
signal paused_changed(on: bool)

const D = preload("res://scripts/v77/data.gd")
const GRAV := 26.0
const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_GLASS := 4

var cfg := {"w": "pulse", "a": "vanguard", "s": "shield", "sn": 1.0, "fov": 85.0, "adsMode": "toggle"}

# ---------------------------------------------------------------- world
var world: V77World
var col := V77Col.new()
var space: PhysicsDirectSpaceState3D
var C: Camera3D
var hud: V77Hud
var sfx: V77Sfx
var block_nodes := {}            ## Vector3i -> {mesh, body, col}
var glass := []                  ## [{node, body, cells, top, n, broken}]
var doors := []                  ## v77 DOORS: {pan:[[node, sg]], OW, top, cells, pos, k, open}

# ---------------------------------------------------------------- player (v77 globals)
var P := Vector3(0, 0, 34)
var V := Vector3.ZERO
var dash_dir := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var ground := 1
var slideT := 0.0
var hp := 100.0
var maxHP := 100.0
var ammo := 30
var rel := 0.0
var fcd := 0.0
var bcd := 0.0
var scd := 0.0
var wave := 1
var score := 0
var wt := 0.0
var go := false
var rec := 0.0
var dashT := 0.0
var invT := 0.0
var shieldT := 0.0
var droneT := 0.0
var dshot := 0.0
var slowT := 0.0
var healA := 0.0
var dmgA := 0.0
var Wp: Dictionary = D.WEAPONS[0]
var Ar: Dictionary = D.ARMORS[1]
var Sk: Dictionary = D.SKILLS[1]
var stance := 0
var eyeH := 1.65
var ads := 0.0
var adsW := false
var sprinting := false
var sprintLock := false
var swapT := 0.0
var slots: Array = []
var slotAmmo := [30, 40]
var cur := 0
var tacN := 2
var tacT := 0.0
var dsrc := ""
var trig := false
var cdT := 0.0                   ## crouch press time (s since start); 0 = none
var dj := 0
var airT := 0.0
var padT := 0.0
var shake := 0.0
var spinT := 0.0
var burstN := 0
var burstT := 0.0
var SK := {"k": 0, "used": [0, 0, 0]}
var FB := {"hold": 0, "t": 0.0, "mode": "hip"}
var adsOn := false
var adsHeld := 0
var rmb := false
var F_f := 0
var K := {}                      ## held keys by physical keycode
var JET := {"fuel": 1.0, "on": false, "k": 0.0, "hold": false, "cool": 0.0, "t": 0.0, "dust": 0.0}
var SJ := {"t": 0.0, "fov": 0.0, "roll": 0.0, "dip": 0.0}
var TURN := {"t": -1.0, "from": 0.0, "dir": 1, "dur": .36, "roll": 0.0, "dip": 0.0, "gx": 0.0, "gy": 0.0, "fov": 0.0, "cur": null}
var grap = null
var LEDGE = null
# camera / gait state (v77 tick)
var stepOff := 0.0
var stepKick := 0.0
var stepRoll := 0.0
var gaitPh := 0.0
var gaitSpd := 0.0
var runK := 0.0
var sprK := 0.0
var stairFoot := 0
var st := 0.0
var dirty := 0
var now_s := 0.0

# ---------------------------------------------------------------- gun
var gun: Node3D                  ## v77 gun group (camera child)
var gun_wrap: Node3D
var gun_model: Node3D
var gun_parts := {}
var barrel: Node3D
var mf: OmniLight3D
var muzzle_flash: MeshInstance3D

# ---------------------------------------------------------------- enemies / fx
var EN: Array = []
var DEAD: Array = []
var PA: Array = []               ## particles {m, v, l}
var TR: Array = []               ## tracers {m, t}
var WELLS: Array = []
var drone: Node3D
var spider_scene: PackedScene
var feed_lines: Array = []
var _rng := RandomNumberGenerator.new()


func rnd() -> float:
	return _rng.randf()


static func cl(v: float, a: float, b: float) -> float:
	return maxf(a, minf(b, v))


# ================================================================ setup
func _ready() -> void:
	_rng.randomize()
	world = V77World.new()
	add_child(world)
	col.load_baked()
	space = get_world_3d().direct_space_state
	_build_physics()
	_find_blocks()
	_find_doors_and_glass()
	C = Camera3D.new()
	C.near = .1
	C.far = 1400.0
	C.fov = cfg.fov
	C.rotation_order = EULER_ORDER_YXZ
	add_child(C)
	C.current = true
	gun = Node3D.new()
	gun.position = Vector3(.3, -.28, -.6)
	C.add_child(gun)
	var fill := OmniLight3D.new()           # v77: a soft light near the camera so the weapon reads
	fill.light_color = Color(0xb4 / 255.0, 0xc4 / 255.0, 1.0).linear_to_srgb()
	fill.light_energy = 1.1
	fill.omni_range = 2.2
	fill.omni_attenuation = 0.0
	fill.position = Vector3(.1, .25, .1)
	C.add_child(fill)
	spider_scene = load("res://assets/baked/spider/spider.scn")
	drone = load("res://assets/baked/drone/drone.scn").instantiate()
	drone.visible = false
	C.add_child(drone)
	drone.position = Vector3(-1.22, .74, -1.5)
	sfx = V77Sfx.new()
	add_child(sfx)
	hud = V77Hud.new()
	add_child(hud)
	hud.game = self


## Ray colliders from v77's CITY.proxies (boxes and cylinders, world matrices exported) and the glass panes.
func _build_physics() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/collision/proxies.json"))
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for p in data.proxies:
		if p.glass:
			continue
		var e: Array = p.m
		var b := Basis(Vector3(e[0], e[1], e[2]), Vector3(e[4], e[5], e[6]), Vector3(e[8], e[9], e[10]))
		var sc := b.get_scale()
		var cs := CollisionShape3D.new()
		if p.t == "b":
			var bx := BoxShape3D.new()
			bx.size = sc.abs().max(Vector3(.02, .02, .02))
			cs.shape = bx
		else:
			var cy := CylinderShape3D.new()
			cy.radius = maxf(.02, absf(sc.x))
			cy.height = maxf(.02, absf(sc.y))
			cs.shape = cy
		cs.transform = Transform3D(b.orthonormalized(), Vector3(e[12], e[13], e[14]))
		body.add_child(cs)


func _find_blocks() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/collision/proxies.json"))
	var want := {}
	for b in data.blocks:
		want[Vector3i(b[0], b[1], b[2])] = b
	for mi in world.city.find_children("*", "MeshInstance3D", true, false):
		var gp: Vector3 = mi.global_position
		var kc := Vector3i(roundi((gp.x - 1) / 2), roundi((gp.y - 1) / 2), roundi((gp.z - 1) / 2))
		var p := Vector3(kc.x * 2 + 1, kc.y * 2 + 1, kc.z * 2 + 1)
		if want.has(kc) and not block_nodes.has(kc) and gp.distance_to(p) < .01 and mi.mesh and absf(mi.mesh.get_aabb().size.x - 2.0) < .01:
			var b: Array = want[kc]
			var key := Vector3i(b[0], b[1], b[2])
			var body := StaticBody3D.new()
			body.collision_layer = LAYER_WORLD
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(2, 2, 2)
			cs.shape = bx
			body.add_child(cs)
			add_child(body)
			body.global_position = p
			block_nodes[key] = {"mesh": mi, "body": body, "col": int(b[3])}
			col.blocks[key] = true


func _node_by_index() -> Dictionary:
	var out := {}
	for n in world.city.find_children("*", "Node3D", true, false):
		var s := String(n.name)
		var u := s.rfind("_")
		if u > 0 and s.substr(u + 1).is_valid_int():
			out[int(s.substr(u + 1))] = n
	return out


## v77 grid index (GX0 -172, GZ0 -142, NZ 284, i = gx * NZ + gz) -> our cell index
func _v77_cell(i: int) -> int:
	var gx := i / 284
	var gz := i % 284
	return col.ci(gx - 172 + .5, gz - 142 + .5)


func _find_doors_and_glass() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/collision/doors.json"))
	var byi := _node_by_index()
	for d in data.doors:
		var cells := []
		for i in d.cells:
			cells.append(_v77_cell(int(i)))
		var pan := []
		for q in d.pan:
			if byi.has(int(q[0])):
				pan.append([byi[int(q[0])], int(q[1])])
		doors.append({"pan": pan, "OW": float(d.OW), "top": float(d.top), "cells": cells, "pos": Vector3(d.pos[0], d.pos[1], d.pos[2]), "k": 0.0, "open": false})
	var gp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/collision/proxies.json"))
	for k in gp.glass.size():
		var g: Dictionary = gp.glass[k]
		var node: Node3D = byi.get(int(data.glassNodes[k])) if k < data.glassNodes.size() else null
		var e: Array = g.m
		var b := Basis(Vector3(e[0], e[1], e[2]), Vector3(e[4], e[5], e[6]), Vector3(e[8], e[9], e[10]))
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_GLASS
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = b.get_scale().abs().max(Vector3(.02, .02, .02))
		cs.shape = bx
		cs.transform = Transform3D(b.orthonormalized(), Vector3(e[12], e[13], e[14]))
		body.add_child(cs)
		add_child(body)
		var cells := []
		for i in g.cells:
			cells.append(_v77_cell(int(i)))
		var entry := {"node": node, "body": body, "cells": cells, "top": float(g.top), "n": Vector3(g.n[0], g.n[1], g.n[2]), "broken": false, "pos": Vector3(e[12], e[13], e[14])}
		body.set_meta("glass", entry)
		glass.append(entry)


# ================================================================ deploy / reset (v77 resetRun + deploy)
func deploy(config: Dictionary) -> void:
	cfg.merge(config, true)
	for e in EN:
		e.m.queue_free()
	EN.clear()
	for d in DEAD:
		d.m.queue_free()
	DEAD.clear()
	for p in PA:
		p.m.queue_free()
	PA.clear()
	for t in TR:
		t.m.queue_free()
	TR.clear()
	for w in WELLS:
		w.g.queue_free()
	WELLS.clear()
	JET = {"fuel": 1.0, "on": false, "k": 0.0, "hold": false, "cool": 0.0, "t": 0.0, "dust": 0.0}
	TURN.t = -1.0
	TURN.cur = null
	TURN.roll = 0.0; TURN.dip = 0.0; TURN.gx = 0.0; TURN.gy = 0.0; TURN.fov = 0.0
	grap = null
	LEDGE = null
	dj = 0; airT = 0.0
	P = Vector3(10 * D.MAPK, 0, 92 * D.MAPK)
	V = Vector3.ZERO
	padT = 0.0; yaw = 0.0; pitch = 0.0; wave = 1; score = 0; wt = 0.0; bcd = 0.0; scd = 0.0; rel = 0.0; fcd = 0.0; rec = 0.0; slideT = 0.0
	dashT = 0.0; invT = 0.0; shieldT = 0.0; droneT = 0.0; slowT = 0.0; healA = 0.0; dmgA = 0.0; dirty = 0
	spinT = 0.0; burstN = 0
	Wp = D.pick(D.WEAPONS, cfg.w)
	Ar = D.pick(D.ARMORS, cfg.a)
	Sk = D.pick(D.SKILLS, cfg.s)
	maxHP = Ar.hp
	hp = maxHP
	ammo = Wp.mag
	slots = [Wp, D.pick(D.WEAPONS, "pulse" if Wp.id == "smg" else "smg")]
	slotAmmo = [slots[0].mag, slots[1].mag]
	cur = 0
	build_gun()
	stance = 0; eyeH = 1.65; ads = 0.0; adsOn = false; adsW = false; sprintLock = false; sprinting = false; swapT = 0.0
	tacN = 2; tacT = 0.0
	SK = {"k": 0, "used": [0, 0, 0]}
	FB.hold = 0
	feed_lines.clear()
	C.fov = cfg.fov
	for i in 5:
		spawn(1)
	go = false
	hud.reset()
	sfx.music("game")


## v77 CUT.end: the run starts with the weapon's full ready-up reload
func start_play() -> void:
	go = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rel = Wp.rl


func set_paused(on: bool) -> void:
	if on == (not go):
		return
	go = not on
	_stop_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	paused_changed.emit(on)


func _stop_input() -> void:
	F_f = 0
	K.clear()
	FB.hold = 0
	adsHeld = 0
	rmb = false
	sprintLock = false
	cdT = 0.0
	JET.hold = false


# ================================================================ input (v77 key / mouse handlers)
func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey:
		var k: InputEventKey = ev
		var c := k.physical_keycode
		if k.pressed and not k.echo:
			K[c] = 1
			if c == KEY_P or c == KEY_ESCAPE:
				set_paused(go)
				return
			if not go:
				return
			match c:
				KEY_SPACE: jump_btn()
				KEY_R: reload()
				KEY_E: blast()
				KEY_G: tactical()
				KEY_Q, KEY_F: use_skill()
				KEY_C, KEY_CTRL: crouch_down()
				KEY_X: swap_weapon(-1)
				KEY_1: swap_weapon(0)
				KEY_2: swap_weapon(1)
				KEY_4: call_streak(0)
				KEY_5: call_streak(1)
				KEY_6: call_streak(2)
				KEY_V: quick_turn()
				KEY_M: hud.toggle_map()
		elif not k.pressed:
			K[c] = 0
			if c == KEY_C or c == KEY_CTRL:
				crouch_up()
			if c == KEY_Q:
				release_grapple()
	elif ev is InputEventMouseMotion and go and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: InputEventMouseMotion = ev
		look(cl(m.relative.x, -150, 150), cl(m.relative.y, -150, 150), .0022)
	elif ev is InputEventMouseButton and go:
		var b: InputEventMouseButton = ev
		if b.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			F_f = 1 if b.pressed else 0
			if b.pressed:
				fire_down()
			else:
				fire_up()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			rmb = b.pressed


func key(c: int) -> bool:
	return K.get(c, 0) == 1


func look(dx: float, dy: float, s: float) -> void:
	s *= (1.0 - .3 * ads) * (.32 if scope_k > .5 else 1.0)
	yaw -= dx * s * float(cfg.sn)
	pitch = cl(pitch - dy * s * float(cfg.sn), -1.5, 1.5)


# ================================================================ main loop (v77 tick)
var scope_k := 0.0

func _process(dt_raw: float) -> void:
	if not visible:
		return
	var dt := cl(dt_raw, 0.0, .05)
	now_s += dt
	if not go:
		hud.update_hud(dt)
		return
	if key(KEY_SPACE) and stance == 0 and ground:
		jump()
	if cdT > 0.0 and now_s - cdT >= .3:
		stance = 2
		cdT = 0.0
	move(dt)
	turn_step(dt)
	jet_fx(dt)
	step_doors(dt)
	spider_push()
	fcd -= dt
	bcd -= dt
	var was := scd
	scd -= dt
	if was > 0 and scd <= 0:
		sfx.play("ready")
	swapT -= dt
	fire_engine(dt)
	if tacN < 2:
		tacT -= dt
		if tacT <= 0:
			tacN += 1
			tacT = 12.0 if tacN < 2 else 0.0
	var sk := scope_k
	var fv: float
	if D.SCOPED.has(Wp.id):
		fv = cfg.fov * (1 - .22 * minf(1, ads / .6) * (1 - sk)) * (1 - sk) + cfg.fov / 4.2 * sk
	else:
		fv = cfg.fov * (1 - float(D.ADS_Z.get(Wp.id, .22)) * ads)
	fv += float(TURN.fov) + float(SJ.fov)
	_scope_upd()
	C.fov = fv
	if rel > 0:
		rel -= dt
		if rel <= 0:
			ammo = Wp.mag
	if burstN > 0:
		burstT -= dt
		if burstT <= 0:
			if ammo > 0 and rel <= 0:
				discharge()
				burstN -= 1
				burstT = .075
			else:
				burstN = 0
			if burstN == 0:
				fcd = Wp.rate
	if Wp.get("spin"):
		spinT = spinT + dt if (trig and rel <= 0 and ammo > 0) else maxf(0, spinT - dt * 1.5)
		var sp = gun_parts.get("spin")
		if sp and rel <= 0:
			sp.rotation.z += dt * (4 + 30 * minf(1, spinT / float(Wp.spin))) * (1.0 if trig else .3)
	invT -= dt
	shieldT -= dt
	slowT -= dt
	rec *= .9
	if mf:
		mf.light_energy *= .6
	shake *= .88
	_update_camera(dt)
	_update_gun(dt)
	upd_grapple(dt)
	_step_wells(dt)
	_step_drone(dt)
	st += dt
	if dirty and st > .18:
		st = 0.0
		settle()
	if EN.is_empty():
		wt += dt
		if wt > 2:
			wt = 0.0
			wave += 1
			var n := mini(24, 4 + wave * 2)
			for i in n:
				spawn(wave)
	_step_enemies(dt)
	step_dead(dt)
	hp = minf(maxHP, hp + float(Ar.reg) * dt)
	dmgA *= .9
	healA *= .94
	if hp <= 0:
		die()
		return
	_step_particles(dt)
	hud.update_hud(dt)


func die() -> void:
	go = false
	_stop_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	died.emit(score, wave)


# ================================================================ movement (v77 move)
func move(dt: float) -> void:
	SJ.t = maxf(0, SJ.t - dt)
	if ground and SJ.t < 1.2:
		SJ.t = 0.0
	SJ.fov *= exp(-dt * (1.3 if SJ.t > 0 else 3.5))
	SJ.dip *= exp(-dt * 4)
	SJ.roll *= exp(-dt * 2.5)
	var mx := (1.0 if key(KEY_D) else 0.0) - (1.0 if key(KEY_A) else 0.0)
	var f := (1.0 if key(KEY_W) else 0.0) - (1.0 if key(KEY_S) else 0.0)
	if sprintLock and not key(KEY_S):
		f = maxf(f, 1)
	var l := Vector2(mx, f).length()
	var n := l if l > 1 else 1.0
	sprinting = ground and slideT <= 0 and not adsW and ads < .35 and f > .3 and (key(KEY_SHIFT) or sprintLock)
	if sprinting and stance:
		stance = 0
	var sp: float = 6.5 * float(Ar.spd) * float(Wp.get("move", 1.0)) * (1.35 if sprinting else 1.0) * D.STM[stance] * (1 - .4 * ads)
	var wx := (cos(yaw) * mx - sin(yaw) * f) / n
	var wz := (-sin(yaw) * mx - cos(yaw) * f) / n
	var px0 := P.x
	var pz0 := P.z
	stepOff *= exp(-dt * 13)
	stepKick *= exp(-dt * 16)
	stepRoll *= exp(-dt * 9)
	if slideT > 0:
		slideT -= dt
		if slideT <= 0:
			stance = 1
		if l < .1:
			wx = -sin(yaw)
			wz = -cos(yaw)
		sp = 14 * float(Ar.spd) * (slideT / .75 + .3)
	if LEDGE != null:
		V = Vector3.ZERO
	elif grap != null and grap.pull:
		grap_step(dt)
	else:
		if dashT > 0:
			dashT -= dt
			V.x = dash_dir.x * 34
			V.z = dash_dir.z * 34
		elif padT > 0 and not ground:
			padT = maxf(padT, .01)
		elif SJ.t > 0 and not ground:
			var hx := -sin(yaw)
			var hz := -cos(yaw)
			var curv := Vector2(V.x, V.z).length()
			var tg := maxf(21.0 if JET.on else 16.0, curv * .997)
			var c := minf(1, dt * 3.2)
			V.x += (hx * tg - V.x) * c
			V.z += (hz * tg - V.z) * c
		else:
			var c2 := minf(1, dt * (10 if ground else 3))
			V.x += (wx * sp - V.x) * c2
			V.z += (wz * sp - V.z) * c2
		V.y -= GRAV * dt
		jet_step(dt)
		var lt := col.lift_at(P.x, P.y, P.z)
		if lt > 0:
			V.y = maxf(V.y, minf(9, (lt - P.y) * 4 + 1.5))
			if V.y < 0:
				V.y = 0
			dj = 0
		var pd = col.pad_at(P.x, P.y, P.z) if padT <= 0 else null
		if pd != null:
			# omnidirectional: the pad keeps its launch height and throw distance but throws you the way you are
			# running (or facing, when standing still) instead of along a fixed arrow
			var hv := Vector2(V.x, V.z)
			var dir := hv.normalized() if hv.length() > 1.5 else Vector2(-sin(yaw), -cos(yaw))
			var spd := maxf(4.0, Vector2(float(pd[2]), float(pd[4])).length())
			V = Vector3(dir.x * spd, pd[3], dir.y * spd)
			padT = .35
			dj = 1
			sfx.play("pad")
	var ox := P.x
	P.x += V.x * dt
	if col.hit(P.x, P.y, P.z):
		var tx := P.x
		var u := _step_up(tx, P.z)
		if u > 0:
			P.y += u
		else:
			P.x = ox
			V.x = 0
			if l > .1 and P.y < 1.5 and ground and grap == null and not col.hit(tx, P.y + 1.8, P.z):
				V.y = 10
	var oz := P.z
	P.z += V.z * dt
	if col.hit(P.x, P.y, P.z):
		var tz := P.z
		var u2 := _step_up(P.x, tz)
		if u2 > 0:
			P.y += u2
		else:
			P.z = oz
			V.z = 0
			if l > .1 and P.y < 1.5 and ground and grap == null and not col.hit(P.x, P.y + 1.8, tz):
				V.y = 10
	var wasG := ground
	ground = 0
	var ns := maxi(1, ceili(absf(V.y * dt) / .3))
	var dy := V.y * dt / ns
	for i in ns:
		var oy := P.y
		P.y += dy
		if col.hit(P.x, P.y, P.z):
			if V.y < 0:
				ground = 1
			P.y = oy
			V.y = 0
			break
	if wasG and not ground and V.y <= 0 and grap == null and dashT <= 0 and P.y > 0 and col.hit(P.x, P.y - .8, P.z):
		var lo2 := 0.0
		var hi2 := .8
		for i in 7:
			var m2 := (lo2 + hi2) / 2
			if col.hit(P.x, P.y - m2, P.z):
				hi2 = m2
			else:
				lo2 = m2
		P.y -= lo2
		stepOff += lo2
		ground = 1
		V.y = 0
	# gait: one footstep per half cycle
	var dd := Vector2(P.x - px0, P.z - pz0).length()
	var spd := dd / maxf(dt, 1e-3)
	var gnd := ground or P.y <= 0
	gaitSpd = spd if gnd else 0.0
	if gnd and spd > .4 and slideT <= 0 and grap == null:
		var slen: float = .9 if stance == 2 else minf(2.6, maxf(.6, .55 + spd * .22))
		var before := floori(gaitPh / PI)
		gaitPh += PI * minf(dd, 1.5) / slen
		if floori(gaitPh / PI) != before:
			stairFoot ^= 1
			var kk := minf(1.2, spd / 6)
			stepKick = maxf(stepKick, .008 * kk)
			sfx.play("step", (.55 if stance else 1.0) * minf(1.2, .35 + spd / 8))
	if P.y <= 0:
		P.y = 0
		V.y = maxf(0, V.y)
		ground = 1
	if ground:
		dj = 0
		if not wasG and airT > .2:
			sfx.play("land", minf(1.0, .5 + airT * .4))
			stepKick = minf(.13, .035 + airT * .09)
			gaitPh = round(gaitPh / PI) * PI
		airT = 0.0
	else:
		airT += dt
	P.x = cl(P.x, col.bounds[0] + 1, col.bounds[1] - 1)
	P.z = cl(P.z, col.bounds[2] + 1, col.bounds[3] - 1)
	if ground:
		padT = maxf(0, padT - dt * 4)


## v77 su(): how far up the body can step at (x, z) (0 = blocked)
func _step_up(x: float, z: float) -> float:
	if not ground or grap != null or col.hit(x, P.y + .8, z):
		return 0.0
	var lo := 0.0
	var hi := .8
	for i in 7:
		var m := (lo + hi) / 2
		if col.hit(x, P.y + m, z):
			lo = m
		else:
			hi = m
	stepOff -= hi
	return hi


func jump() -> void:
	if not go or stance:
		return
	if slideT > 0 and ground:
		slide_burst()
		return
	if ground:
		V.y = 11 * float(Ar.get("jmp", 1.0))
		ground = 0
		dj = 0
		sfx.play("jump", .8)
	elif not dj and not (grap != null and grap.pull):
		dj = 1
		V.y = 10 * float(Ar.get("jmp", 1.0))
		burst(Vector3(P.x, P.y + .1, P.z), 10, 0x21e6ff, 5)
		sfx.beep(520, .14, "sine", .08)


func jump_btn() -> void:
	if not go:
		return
	if stance > 0:
		stance = 0
		return
	if grap != null and grap.pull:
		var kx := V.x
		var kz := V.z
		var hang: bool = grap.hang > 0
		end_grapple(11)
		if hang:
			V.x = sin(yaw) * 7
			V.z = cos(yaw) * 7
		else:
			V.x = kx * .6
			V.z = kz * .6
		return
	jump()


func crouch_down() -> void:
	sprintLock = false
	if sprinting and ground:
		slide()
		cdT = 0.0
		return
	cdT = now_s


func crouch_up() -> void:
	if cdT > 0 and now_s - cdT < .3:
		stance = 0 if stance == 1 else 1
	cdT = 0.0


func slide() -> void:
	if go and ground and slideT <= 0:
		slideT = .75
		stance = 0
		sprintLock = false
		sfx.play("slide")


func slide_burst() -> void:
	var sp := Vector2(V.x, V.z).length()
	var fx := -sin(yaw)
	var fz := -cos(yaw)
	var out := maxf(sp * 1.3, 18)
	V.x = fx * out
	V.z = fz * out
	V.y = 7.8 * float(Ar.get("jmp", 1.0))
	ground = 0
	dj = 1
	slideT = 0.0
	stance = 0
	SJ.t = 1.35
	SJ.fov = 16.0
	SJ.dip = 1.0
	SJ.roll = (-1.0 if rnd() < .5 else 1.0) * .05
	shake = maxf(shake, .28)
	JET.fuel = maxf(0, JET.fuel - .12)
	JET.cool = .6
	padT = 0.0
	burst(Vector3(P.x, P.y + .15, P.z), 28, 0x4f8cff, 10)
	burst(Vector3(P.x - fx * .6, P.y + .4, P.z - fz * .6), 16, 0xff2bd6, 6)
	sfx.play("slide_burst")


func jet_ok() -> bool:
	return int(Ar.get("tier", 0)) >= 2


func jet_step(dt: float) -> void:
	if not jet_ok():
		JET.on = false
		return
	var want: bool = (JET.hold or key(KEY_SPACE)) and not ground and not stance and JET.fuel > 0 and (airT > .18 or V.y < 1.5) and LEDGE == null and not (grap != null and grap.pull)
	if want and not JET.on and JET.fuel < .08:
		return
	if want != JET.on:
		JET.on = want
		sfx.loop("jet", want)
	var mk4 := int(Ar.get("tier", 0)) >= 3
	var acc := 40.0 if mk4 else 36.0
	var cap := 8.5 if mk4 else 7.0
	if JET.on:
		V.y = minf(cap, V.y + acc * dt * (1.6 if V.y < 0 else 1.0))
		JET.fuel = maxf(0, JET.fuel - dt / (3.4 if mk4 else 2.6))
		JET.cool = .5
		shake = maxf(shake, .02)
	else:
		JET.cool -= dt
		if ground and JET.cool <= 0:
			JET.fuel = minf(1, JET.fuel + dt / (2.2 if mk4 else 2.8))


func jet_fx(dt: float) -> void:
	JET.k += ((1.0 if JET.on else minf(1, SJ.t * 1.6)) - JET.k) * minf(1, dt * (14 if JET.on or SJ.t > 1.2 else 6))
	JET.t += dt
	if JET.on and P.y < 4:
		JET.dust -= dt
		if JET.dust <= 0:
			JET.dust = .05
			burst(Vector3(P.x + (rnd() - .5) * 1.2, .12, P.z + (rnd() - .5) * 1.2), 2, 0x8aa0c8, 3.5)


func quick_turn() -> void:
	if not go or TURN.t >= 0:
		return
	TURN.t = 0.0
	TURN.from = yaw
	TURN.dir = 1
	sprintLock = false
	sfx.play("turn")


func turn_step(dt: float) -> void:
	if TURN.t < 0:
		return
	TURN.t += dt
	var u := minf(1, TURN.t / TURN.dur)
	var e := 4 * u * u * u if u < .5 else 1 - pow(-2 * u + 2, 3) / 2
	var b := sin(PI * u)
	var target: float = TURN.from + TURN.dir * PI * e
	var prev: float = TURN.from if TURN.cur == null else TURN.cur
	yaw += target - prev
	TURN.cur = target
	TURN.roll = TURN.dir * .075 * b
	TURN.dip = .06 * b
	TURN.fov = 7 * b
	TURN.gx = -TURN.dir * .07 * sin(PI * minf(1, u * 1.15))
	TURN.gy = -TURN.dir * .42 * sin(PI * minf(1, u * 1.1))
	if u >= 1:
		TURN.t = -1.0
		TURN.cur = null
		TURN.roll = 0.0; TURN.dip = 0.0; TURN.gx = 0.0; TURN.gy = 0.0; TURN.fov = 0.0


# ================================================================ camera + view model (v77 tick tail)
func _update_camera(dt: float) -> void:
	var sl := .7 if slideT > 0 else 0.0
	var sh := (rnd() - .5) * shake
	eyeH += (D.EYE[stance] - eyeH) * minf(1, dt * 10)
	var mv := ground and gaitSpd > .5 and slideT <= 0
	runK += ((minf(1.35, gaitSpd / 6.5) if mv else 0.0) - runK) * minf(1, dt * 8)
	sprK += ((1.0 if (sprinting and mv and not trig and rel <= 0 and swapT <= 0 and ads < .1) else 0.0) - sprK) * minf(1, dt * (6 if sprinting else 11))
	var gp := gaitPh
	var gA := runK * (1 - ads) * (.3 if stance == 2 else 1.0)
	var hb := -(.016 + .026 * sprK) * gA * cos(2 * gp)
	var hl := (.02 + .012 * sprK) * gA * sin(gp)
	C.position = Vector3(P.x + sh + hl * cos(yaw), P.y + eyeH - sl + stepOff - stepKick + hb - float(TURN.dip), P.z + sh - hl * sin(yaw))
	var ledge_tilt := 0.0
	if LEDGE != null:
		ledge_tilt = .42 * sin(PI * minf(1, LEDGE.t / .98)) + .1 * maxf(0, 1 - LEDGE.t / .22)
	C.rotation = Vector3(pitch + SJ.dip * .05 + sh * .3 + .007 * gA * cos(2 * gp) - .03 * sprK - ledge_tilt,
		yaw + .006 * gA * sin(gp),
		(.08 if slideT > 0 else 0.0) + SJ.roll + stepRoll + float(TURN.roll) + (.009 + .01 * sprK) * gA * sin(gp))


static func sm(x: float, a: float, b: float) -> float:
	var t := cl((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)


func _update_gun(_dt: float) -> void:
	if gun == null or gun_wrap == null:
		return
	var gp := gaitPh
	var dip := sm(swapT, 0, .5) * .45 if swapT > 0 else 0.0
	var na := 1 - ads
	var g2 := gp - .45
	var jA := runK * na * (1 - sprK)
	var yc: float = D.SIGHT_YC.get(Wp.id, .12)
	gun.position = Vector3(.3 - .3 * ads + .013 * jA * sin(g2), -.28 + (.28 - yc * .85) * ads - .014 * jA * cos(2 * g2) - dip - stepKick * .35 * na, -.6 + .12 * ads + rec * 2 * (1 - .5 * ads) + .008 * jA * cos(g2))
	gun.rotation = Vector3(dip * 1.2 + .025 * jA * cos(2 * g2), .02 * jA * sin(g2), .035 * jA * sin(g2))
	if TURN.gy:
		gun.rotation.y += float(TURN.gy)
		gun.position.x += float(TURN.gx)
		gun.rotation.z += float(TURN.gy) * .35
		gun.position.y -= absf(float(TURN.gx)) * .4
	var o := {"rx": 0.0, "ry": 0.0, "rz": 0.0, "px": 0.0, "py": 0.0, "pz": 0.0}
	var mag = gun_parts.get("mag")
	if rel > 0:
		var tt: float = 1 - rel / float(Wp.rl)
		var k := sm(tt, 0, .1) - sm(tt, .88, 1)
		o.py += .12 * k
		o.px -= .11 * k
		o.pz += .14 * k
		o.rx += .06 * k
		o.rz += .35 * k
		if mag:      # magazine out and back in
			var m := sm(tt, .15, .35) - sm(tt, .6, .8)
			mag.position = gun_parts.mag_rest + Vector3(0, -.25 * m, 0)
			mag.visible = not (tt > .35 and tt < .6)
	elif mag:
		mag.position = gun_parts.mag_rest
		mag.visible = true
	if SJ.t > 0:
		var q: float = minf(1, SJ.t / .4) * (1 - ads)
		o.rx += q * .22; o.rz += q * .32; o.py -= q * .07; o.px += q * .05; o.pz += q * .06
	if sprK > .001:
		var q2 := sprK * (1 - ads)
		var sw := sin(gp)
		var ud := cos(2 * gp)
		o.rx += q2 * (.42 + .06 * ud); o.ry += q2 * (.78 + .13 * sw); o.rz += q2 * (.68 + .16 * sw)
		o.px += q2 * (-.13 + .035 * sw); o.py += q2 * (-.12 - .04 * ud); o.pz += q2 * (.1 + .03 * cos(gp))
	gun_wrap.rotation = Vector3(o.rx, o.ry, o.rz)
	gun_wrap.position = Vector3(o.px, o.py, o.pz)
	gun.visible = scope_k <= .6


func _scope_upd() -> void:
	var want := go and D.SCOPED.has(Wp.id) and ads > .55
	var tk := minf(1, (ads - .55) / .4) if want else 0.0
	scope_k += (tk - scope_k) * .45


# ================================================================ weapons (v77 buildGun / fire / discharge)
func build_gun() -> void:
	for c in gun.get_children():
		c.queue_free()
	gun_wrap = Node3D.new()
	gun.add_child(gun_wrap)
	var inst: Node3D = load("res://assets/baked/weapons/%s/%s.scn" % [Wp.id, Wp.id]).instantiate()
	gun_wrap.add_child(inst)
	# exported as root -> [root group] -> gm.g; v77 buildGun turns gm.g 180 degrees and scales it to .85
	var gm: Node3D = inst.get_child(0).get_child(0) if inst.get_child_count() and inst.get_child(0).get_child_count() else inst
	gm.rotation.y = PI
	gm.scale = Vector3.ONE * .85
	gun_model = gm
	gun_parts = {}
	for n in gm.find_children("part_*", "Node3D", true, false):
		var pn := String(n.name).trim_prefix("part_")
		pn = pn.substr(0, pn.rfind("_")) if pn.rfind("_") > 0 else pn
		gun_parts[pn] = n
	if gun_parts.has("mag"):
		gun_parts.mag_rest = gun_parts.mag.position
	var muzzle: float = _muzzle_z()
	barrel = Node3D.new()
	barrel.position = Vector3(0, .035, muzzle)
	gm.add_child(barrel)
	mf = OmniLight3D.new()
	mf.light_color = fx_col(Wp.col)
	mf.light_energy = 0.0
	mf.omni_range = 10.0
	mf.omni_attenuation = 0.0
	mf.position = Vector3(0, .035, muzzle + .1)
	gm.add_child(mf)
	muzzle_flash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(.16, .16)
	muzzle_flash.mesh = q
	muzzle_flash.material_override = _glow_mat(Wp.col, true)
	muzzle_flash.position = Vector3(0, .035, muzzle + .06)
	muzzle_flash.visible = false
	gm.add_child(muzzle_flash)
	_set_layer_recursive(gun_wrap)


const MUZZLE := {"pulse": .78, "scatter": .7, "rail": .95, "smg": .44, "arc": .66, "ion": .68, "cryo": .42, "void": .32, "burst": .44, "chain": .44}

func _muzzle_z() -> float:
	return float(MUZZLE.get(Wp.id, .6))


## The view model draws over the world (its own render layer, rendered on top) like v77's renderOrder.
func _set_layer_recursive(n: Node) -> void:
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func fire_down() -> void:
	FB.hold = 1
	FB.t = 0.0
	FB.mode = D.FMODE.get(Wp.id, "hip")
	sprintLock = false
	if FB.mode == "onetap":
		fire()


func fire_up() -> void:
	if FB.hold and FB.mode == "release":
		fire()
	FB.hold = 0


func fire_engine(dt: float) -> void:
	if FB.hold:
		FB.t += dt
	var m: String = FB.mode
	trig = F_f > 0 and (m == "hip" or m == "ads" or m == "mixed") and FB.hold
	adsW = (adsOn or adsHeld > 0 or rmb or (FB.hold and (m == "ads" or m == "release" or (m == "mixed" and FB.t > .25)))) and rel <= 0 and swapT <= 0 and slideT <= 0
	if adsW or trig:
		sprintLock = false
	var at: float = D.ADS_T.get(Wp.id, .2)
	ads = minf(1, ads + dt / at) if adsW else maxf(0, ads - dt / (at * .8))
	if trig:
		fire()


func fire() -> void:
	if not go or rel > 0 or swapT > 0:
		return
	if Wp.get("burst"):
		if burstN > 0 or fcd > 0:
			return
		if ammo <= 0:
			reload()
			return
		burstN = mini(int(Wp.burst), ammo)
		burstT = 0.0
		return
	if fcd > 0:
		return
	if ammo <= 0:
		reload()
		return
	fcd = Wp.rate * ((1 + 2 * (1 - minf(1, spinT / float(Wp.spin)))) if Wp.get("spin") else 1.0)
	discharge()


## v77 aimAt: a ray through normalised device coordinates (ox, oy) of the camera.
func aim(ox: float, oy: float) -> Array:
	var vp := get_viewport().get_visible_rect().size
	var t := tan(deg_to_rad(C.fov) * .5)
	var dir := Vector3(ox * t * vp.x / vp.y, oy * t, -1).normalized()
	return [C.global_position, (C.global_basis * dir).normalized()]


func ray_hits(o: Vector3, d: Vector3, far: float, mask := LAYER_WORLD | LAYER_ENEMY | LAYER_GLASS, all := false) -> Array:
	var out := []
	var ex: Array[RID] = []
	for i in 24:
		var q := PhysicsRayQueryParameters3D.create(o, o + d * far, mask, ex)
		var h := space.intersect_ray(q)
		if h.is_empty():
			break
		h.distance = o.distance_to(h.position)
		out.append(h)
		if not all:
			break
		ex.append(h.rid)
	return out


func range_mul(dist: float) -> float:
	var R := D.weapon_range(Wp)
	return 1.0 if dist <= R * .5 else maxf(.35, 1 - .65 * (dist - R * .5) / (R * .5))


## v77 zoneMul: the ray against the spider body ellipsoid (head end 1.3x, legs only .35x)
func zone_mul(e: Dictionary, o: Vector3, d: Vector3) -> float:
	var inv: Transform3D = (e.m as Node3D).global_transform.affine_inverse()
	var zo := inv * o
	var zd := (inv.basis * d)
	var rx := 1.3
	var ry := .72
	var rz := .68
	var cy := .19
	var ox := zo.x / rx
	var oy := (zo.y - cy) / ry
	var oz := zo.z / rz
	var dx := zd.x / rx
	var dy := zd.y / ry
	var dz := zd.z / rz
	var a := dx * dx + dy * dy + dz * dz
	var b := 2 * (ox * dx + oy * dy + oz * dz)
	var c := ox * ox + oy * oy + oz * oz - 1
	var Dd := b * b - 4 * a * c
	if Dd < 0:
		return .35
	var t := (-b - sqrt(Dd)) / (2 * a)
	var hz := zo.z + zd.z * t
	return 1.3 if hz > rz * .45 else 1.0


func hit_dmg(e: Dictionary, h: Dictionary, o: Vector3, d: Vector3) -> float:
	return float(Wp.dmg) * zone_mul(e, o, d) * range_mul(h.distance)


func _kind(h: Dictionary) -> String:
	var c: Object = h.collider
	if c.has_meta("enemy"):
		return "en"
	if c.has_meta("glass"):
		return "glass"
	return "world"


func discharge() -> void:
	ammo -= 1
	_muzzle_fx()
	dsrc = D.SHORT.get(Wp.id, Wp.name)
	var spr: float = Wp.spr * (1 - .75 * ads) * [1.0, .8, .6][stance] * (1.6 if sprinting else 1.0)
	rec += Wp.rec
	pitch += Wp.kick
	yaw += (rnd() - .5) * Wp.kick
	if mf:
		mf.light_energy = 3.0
	sfx.fire(Wp)
	var far := D.weapon_range(Wp)
	for p in int(Wp.pel):
		var r := aim((rnd() - .5) * 2 * spr, (rnd() - .5) * 2 * spr)
		var o: Vector3 = r[0]
		var d: Vector3 = r[1]
		if Wp.get("pierce"):
			var hs := ray_hits(o, d, far, LAYER_WORLD | LAYER_ENEMY | LAYER_GLASS, true)
			var blocks := 0
			var end = null
			var seen := {}
			for h in hs:
				var k := _kind(h)
				if k == "en":
					var e: Dictionary = h.collider.get_meta("enemy")
					if not seen.has(e.id):
						seen[e.id] = 1
						var dm := hit_dmg(e, h, o, d)
						blood(h.position, d, dm / 30)
						hurt(e, dm)
				elif k == "glass":
					shatter(h.collider.get_meta("glass"), h.position)
				else:
					destroy(h.position, Wp.brk)
					impact(h.position, h.normal, Wp.col, 1)
					blocks += 1
					if blocks >= 3:
						end = h.position
						break
			tracer(end if end != null else o + d * 60)
			continue
		var hits := ray_hits(o, d, far)
		var h2: Dictionary = hits[0] if hits.size() else {}
		if Wp.get("well"):
			var pt: Vector3 = h2.position if h2 else o + d * 60
			tracer(pt)
			if h2 and _kind(h2) == "en":
				var e2: Dictionary = h2.collider.get_meta("enemy")
				var dm2 := hit_dmg(e2, h2, o, d)
				blood(h2.position, d, dm2 / 30)
				hurt(e2, dm2)
			elif h2 and _kind(h2) == "glass":
				shatter(h2.collider.get_meta("glass"), pt)
			elif h2:
				destroy(pt, Wp.brk)
			add_well(pt)
			continue
		if not h2:
			tracer(o + d * far)
			continue
		tracer(h2.position)
		if Wp.get("boom"):
			explode(h2.position, Wp.dmg, Wp.boom)
		elif _kind(h2) == "en":
			var e3: Dictionary = h2.collider.get_meta("enemy")
			var dm3 := hit_dmg(e3, h2, o, d)
			if Wp.get("chill"):
				e3.chill = float(Wp.chill)
			blood(h2.position, d, dm3 / 30)
			hurt(e3, dm3)
			if Wp.get("chain"):
				chain_zap(e3, dm3)
		elif _kind(h2) == "glass":
			shatter(h2.collider.get_meta("glass"), h2.position)
		else:
			destroy(h2.position, Wp.brk)
			impact(h2.position, h2.normal, Wp.col, .55 if Wp.pel > 1 else 1.0)


func explode(pt: Vector3, dmg: float, rad: float) -> void:
	shatter_near(pt, rad)
	destroy(pt, Wp.brk)
	burst(pt, 22, Wp.col, 12)
	shake = maxf(shake, .3)
	sfx.play_at("boom", pt)
	for e in EN.duplicate():
		var dd: float = e.m.global_position.distance_to(pt)
		if dd < rad:
			hurt(e, dmg * (1 - dd / (rad + 1)))


func chain_zap(e0: Dictionary, dmg: float) -> void:
	var curp: Vector3 = e0.m.global_position
	var hitset := {e0.id: 1}
	for k in int(Wp.chain):
		var best = null
		var bd := 7.5
		for e in EN:
			if hitset.has(e.id):
				continue
			var d: float = e.m.global_position.distance_to(curp)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		var np: Vector3 = best.m.global_position
		var mid := curp.lerp(np, .5) + Vector3((rnd() - .5) * .8, (rnd() - .5) * .8, (rnd() - .5) * .8)
		tracer(mid, curp)
		tracer(np, mid)
		hitset[best.id] = 1
		hurt(best, dmg * pow(.75, k + 1))
		burst(np, 4, Wp.col, 6)
		curp = np


func add_well(pt: Vector3) -> void:
	var g := Node3D.new()
	add_child(g)
	g.global_position = pt
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = .7
	s.height = 1.4
	core.mesh = s
	core.material_override = _glow_mat(0x05000a, false)
	g.add_child(core)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.35
	t.outer_radius = 1.45
	ring.mesh = t
	ring.material_override = _glow_mat(Wp.col, false)
	g.add_child(ring)
	WELLS.append({"g": g, "ring": ring, "p": pt, "t": float(Wp.well), "col": Wp.col})


func _step_wells(dt: float) -> void:
	for i in range(WELLS.size() - 1, -1, -1):
		var w: Dictionary = WELLS[i]
		w.t -= dt
		w.ring.rotation.y += dt * 4
		w.g.scale = Vector3.ONE * (.8 + .2 * sin(now_s * 1000 / 60))
		for e in EN.duplicate():
			var ep: Vector3 = e.m.global_position
			var dx: float = w.p.x - ep.x
			var dz: float = w.p.z - ep.z
			var d := maxf(Vector2(dx, dz).length(), 1e-4)
			if d < 9:
				var step := minf(d, 7 * dt)
				e.m.global_position = Vector3(ep.x + dx / d * step, ep.y, ep.z + dz / d * step)
				if d < 2.6:
					hurt(e, 38 * dt)
		if w.t <= 0:
			dsrc = "VOID WELL"
			w.g.queue_free()
			burst(w.p, 24, w.col, 10)
			shake = maxf(shake, .2)
			for e in EN.duplicate():
				if e.m.global_position.distance_to(w.p) < 3.5:
					hurt(e, 45)
			WELLS.remove_at(i)


func blast() -> void:
	if not go or bcd > 0:
		return
	dsrc = "BLAST"
	bcd = 5 * (1 - float(Ar.get("cdr", 0.0)))
	shake = .5
	var r := aim(0, 0)
	var hs := ray_hits(r[0], r[1], 100)
	var pt: Vector3 = hs[0].position if hs.size() else r[0] + r[1] * 60
	sfx.play_at("boom", pt, 1.25)
	tracer(pt, null, 0xff2bd6)
	destroy(pt, 5.5)
	burst(pt, 30, 0xff2bd6, 14)
	for e in EN.duplicate():
		if e.m.global_position.distance_to(pt) < 8:
			hurt(e, 70)


func reload() -> void:
	if rel <= 0 and ammo < Wp.mag:
		rel = Wp.rl
		sfx.play("reload")


func swap_weapon(to: int) -> void:
	if not go or swapT > 0:
		return
	var n := (cur ^ 1) if to < 0 else to
	if n == cur:
		return
	slotAmmo[cur] = ammo
	rel = 0.0
	burstN = 0
	spinT = 0.0
	FB.hold = 0
	adsOn = false
	cur = n
	Wp = slots[cur]
	ammo = slotAmmo[cur]
	build_gun()
	swapT = .5
	fcd = 0.0
	sfx.beep(320, .08, "square", .05)


func tactical() -> void:
	if not go or tacN < 1:
		return
	tacN -= 1
	if tacT <= 0:
		tacT = 12.0
	var r := aim(0, 0)
	var hs := ray_hits(r[0], r[1], 16)
	var pt: Vector3 = hs[0].position if hs.size() else r[0] + r[1] * 14
	tracer(pt, null, 0xffffff)
	burst(pt, 26, 0xffffff, 10)
	sfx.beep(1400, .3, "sine", .12)
	shake = maxf(shake, .15)
	for e in EN:
		if e.m.global_position.distance_to(pt) < 7:
			e.stun = 2.5


func call_streak(i: int) -> void:
	if not go:
		return
	var s: Dictionary = D.STREAKS[i]
	if SK.used[i] or SK.k < s.c:
		return
	SK.used[i] = 1
	sfx.beep(520 + i * 180, .4, "triangle", .15)
	feed("[b]%s[/b] ONLINE" % s.n)
	if i == 0:
		droneT = 15.0
		dshot = 0.0
	elif i == 1:
		var r := aim(0, 0)
		var hs := ray_hits(r[0], r[1], 120)
		var pt: Vector3 = hs[0].position if hs.size() else r[0] + r[1] * 40
		pt.y = maxf(pt.y, 0)
		for k in 3:
			tracer(pt + Vector3((rnd() - .5) * 2, 0, (rnd() - .5) * 2), pt + Vector3((rnd() - .5) * 4, 45, (rnd() - .5) * 4), 0xff2a3d, .45)
		dsrc = "STRIKE"
		destroy(pt, 4.5)
		burst(pt, 40, 0xff2a3d, 16)
		shake = .7
		for e in EN.duplicate():
			if e.m.global_position.distance_to(pt) < 9:
				hurt(e, 220)
	else:
		hp = maxHP
		invT = 6.0
		healA = .9
	if SK.used[0] and SK.used[1] and SK.used[2]:
		SK.k = 0
		SK.used = [0, 0, 0]


func use_skill() -> void:
	if not go or scd > 0:
		return
	if Sk.id == "grapple":
		if grap != null and not (grap.hang > 0):
			return
		var hold = grap
		if hold != null:
			grap = null
		if fire_grapple():
			scd = Sk.cd * (1 - float(Ar.get("cdr", 0.0)))
		elif hold != null:
			grap = hold
		return
	scd = Sk.cd * (1 - float(Ar.get("cdr", 0.0)))
	sfx.play("skill")
	match Sk.id:
		"dash":
			dash_dir = Vector3(-sin(yaw), 0, -cos(yaw))
			dashT = .22
			invT = .5
			shake = .15
		"shield":
			shieldT = 4.0
		"drone":
			droneT = 8.0
			dshot = 0.0
		"chrono":
			slowT = 5.0
		"nanite":
			hp = minf(maxHP, hp + 50)
			healA = .9


func take_dmg(x: float) -> void:
	if invT > 0:
		return
	if shieldT > 0:
		sfx.play("shield_hit")
		return
	sfx.play("hurt")
	hp -= x * (1 - float(Ar.dr))
	dmgA = .9


# ================================================================ grapple + ledge (v77)
const GRAPPLE_RANGE := 20.0

func grapple_hit():
	var r := aim(0, 0)
	var hs := ray_hits(r[0], r[1], GRAPPLE_RANGE, LAYER_WORLD | LAYER_GLASS)
	return hs[0] if hs.size() else null


func fire_grapple() -> bool:
	var h = grapple_hit()
	if h == null:
		sfx.beep(160, .12, "square", .05)
		return false
	var p: Vector3 = h.position
	var n: Vector3 = h.normal
	var q := p - n * .3
	var top := p.y
	while top < 130 and col.solid(q.x, top + .1, q.z):
		top += .5
	var lo := maxf(p.y, top - .5)
	var hi := top
	for i in 7:
		var m := (lo + hi) / 2
		if col.solid(q.x, m, q.z):
			lo = m
		else:
			hi = m
	top = lo
	var roof := n.y > .5
	var near_top := not roof and top - p.y < 6
	var tg: Vector3
	var E = null
	if roof:
		tg = Vector3(p.x, p.y + 1.2, p.z)
	elif near_top:
		E = Vector3(p.x, top, p.z)
		tg = E + n * .65
		tg.y = top - .85
	else:
		tg = p + n * 1.6
	grap = {"p": p, "n": n, "tg": tg, "E": E, "top": roof, "ledge": near_top, "t": 0.0, "shot": 0.0, "pull": false, "stall": 0.0, "hang": 0.0, "from": C.global_transform * Vector3(-.24, -.18, -.8), "last": null}
	sprintLock = false
	stance = 0
	slideT = 0.0
	sfx.play("grapple")
	_cable_show(true)
	return true


func end_grapple(pop := 0.0) -> void:
	if grap == null:
		return
	grap = null
	_cable_show(false)
	dj = 0
	if pop:
		V.y = maxf(V.y, pop)


func release_grapple() -> void:
	if grap == null:
		return
	var pop := minf(6, maxf(2, -V.y * .2 + 3)) if grap.pull else 0.0
	end_grapple(pop)
	if scd > 0:
		scd = minf(scd, Sk.cd * .35)


func start_ledge() -> void:
	var E: Vector3 = grap.E
	var n: Vector3 = grap.n
	n.y = 0
	n = n.normalized()
	LEDGE = {"t": 0.0, "n": n, "from": P, "hang": Vector3(E.x + n.x * .45, E.y - 1.72, E.z + n.z * .45), "peak": Vector3(E.x + n.x * .3, E.y - .02, E.z + n.z * .3), "stand": Vector3(E.x - n.x * .65, E.y + .02, E.z - n.z * .65)}
	grap = null
	_cable_show(false)
	V = Vector3.ZERO
	sfx.play("land", .5)


func ledge_step(dt: float) -> void:
	var L: Dictionary = LEDGE
	L.t += dt
	var t: float = L.t
	var T1 := .22
	var T2 := .7
	var T3 := .98
	var ee := func(x: float) -> float: return x * x * (3 - 2 * x)
	if t < T2:
		var ty := atan2(L.n.x, L.n.z)
		var dyw := ty - yaw
		dyw = atan2(sin(dyw), cos(dyw))
		yaw += dyw * minf(1, dt * 12)
	if t < T1:
		P = L.from.lerp(L.hang, ee.call(t / T1))
	elif t < T2:
		var u: float = ee.call((t - T1) / (T2 - T1))
		P = L.hang.lerp(L.peak, u)
		P.y = L.hang.y + (L.peak.y - L.hang.y) * pow(u, .8)
	else:
		var u2: float = ee.call(minf(1, (t - T2) / (T3 - T2)))
		P = L.peak.lerp(L.stand, u2)
		P.y = L.peak.y + (L.stand.y - L.peak.y) * u2 + .12 * sin(PI * u2)
	V = Vector3.ZERO
	if t >= T3:
		P = L.stand
		LEDGE = null
		ground = 1
		sfx.play("land", .7)


func grap_step(dt: float) -> void:
	var GV: Vector3 = grap.tg - Vector3(P.x, P.y + .9, P.z)
	var d := GV.length()
	if grap.ledge and (d < 1.5 or grap.stall > .12):
		start_ledge()
		return
	if d < 1.4 or grap.hang > 0:
		if grap.top:
			end_grapple(5)
			return
		grap.hang += dt
		V = Vector3.ZERO
		if grap.hang > 12:
			end_grapple(.1)
		return
	var sp := minf(34, 12 + d * 2.2)
	V = GV * (sp / d)
	if grap.last != null and grap.last.distance_to(P) < sp * dt * .25:
		grap.stall += dt
		if grap.stall > .22:
			end_grapple(9)
			return
	else:
		grap.stall = 0.0
	grap.last = P


var cable: MeshInstance3D

func _cable_show(on: bool) -> void:
	if cable == null:
		cable = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = .012
		cm.bottom_radius = .012
		cm.height = 1.0
		cable.mesh = cm
		cable.material_override = _glow_mat(0x3dffc8, false)
		add_child(cable)
	cable.visible = on


func upd_grapple(dt: float) -> void:
	if LEDGE != null:
		ledge_step(dt)
		return
	if grap == null:
		return
	grap.t += dt
	if not grap.pull:
		grap.shot = minf(1, grap.shot + dt * 110 / maxf(1, grap.from.distance_to(grap.p)))
		if grap.shot >= 1:
			grap.pull = true
			sfx.play_at("grapple_hit", grap.p)
	if grap.t > (14 if grap.hang > 0 else 2.6) or not go:
		end_grapple(4)
		return
	var m0: Vector3 = C.global_transform * Vector3(-.24, -.18, -.8)
	var hp_: Vector3 = grap.p if grap.pull else grap.from.lerp(grap.p, grap.shot)
	var L := m0.distance_to(hp_)
	if L > .01:
		cable.global_transform = Transform3D(Basis(), (m0 + hp_) * .5).looking_at(hp_, Vector3.UP if absf((hp_ - m0).normalized().y) < .99 else Vector3.FORWARD) * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO)
		cable.scale = Vector3(1, L, 1)


# ================================================================ doors, glass, blocks (v77 CITY)
func step_doors(dt: float) -> void:
	dt = minf(.05, dt)
	for d in doors:
		var near := Vector2(P.x - d.pos.x, P.z - d.pos.z).length() < 4.2 and absf(P.y + 1 - d.pos.y) < 3
		if near != d.open:
			d.open = near
			sfx.play_at("door_open" if near else "door_close", d.pos)
		var tk := 1.0 if d.open else 0.0
		d.k += signf(tk - d.k) * minf(absf(tk - d.k), dt / (.42 if d.open else .62))
		var e: float = d.k * d.k * (3 - 2 * d.k)
		for pp in d.pan:
			(pp[0] as Node3D).position.x = pp[1] * (d.OW / 4 + e * d.OW * .48)
		var solid_now: bool = d.k < .55
		for i in d.cells:
			col.set_ground(i, d.top + 3.2 if solid_now else d.top)


func shatter(g: Dictionary, pt: Vector3) -> void:
	if g.broken:
		return
	g.broken = true
	if g.node:
		g.node.visible = false
	g.body.queue_free()
	var top: float = g.top
	for i in g.cells:
		if i < 0:
			continue
		var keep := PackedFloat32Array()
		var s = col.spans[i]
		if s != null:
			for k in range(0, s.size(), 2):     # keep spans outside this corridor
				if s[k + 1] < top - 1.0 or s[k] > top + 5.6:
					keep.append(s[k])
					keep.append(s[k + 1])
		keep.append_array(PackedFloat32Array([top - .6, top, top + 4.8, top + 5.3]))
		col.spans[i] = keep
	burst(pt, 40, 0xbfeaff, 6)
	sfx.play_at("glass", pt)
	shake = maxf(shake, .08)


func shatter_near(pt: Vector3, r: float) -> void:
	for g in glass:
		if not g.broken and g.pos.distance_to(pt) < r + 2.5:
			shatter(g, g.pos)


## v77 destroy: crate blocks within r + .8 of the point break apart
func destroy(pt: Vector3, r: float) -> void:
	var rm := []
	for k in block_nodes:
		var b: Dictionary = block_nodes[k]
		if (b.mesh as Node3D).global_position.distance_to(pt) < r + .8:
			rm.append(k)
	if rm.is_empty():
		return
	for k in rm:
		var b: Dictionary = block_nodes[k]
		burst(b.mesh.global_position, 8, [0x3a2a80, 0xff2bd6, 0x21e6ff][b.col % 3] if b.col < 3 else b.col, 6)
		b.mesh.queue_free()
		b.body.queue_free()
		block_nodes.erase(k)
		col.blocks.erase(k)
	dirty = 1


## v77 settle: unsupported blocks drop one cell
func settle() -> void:
	var keys := block_nodes.keys()
	keys.sort_custom(func(a, b): return a.y < b.y)
	var mv := 0
	for k in keys:
		if k.y > 0 and not col.blocks.has(Vector3i(k.x, k.y - 1, k.z)):
			var nb := 0
			for o in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				if col.blocks.has(k + o):
					nb += 1
			if nb <= 1:
				var b: Dictionary = block_nodes[k]
				block_nodes.erase(k)
				col.blocks.erase(k)
				var nk := Vector3i(k.x, k.y - 1, k.z)
				block_nodes[nk] = b
				col.blocks[nk] = true
				b.mesh.global_position.y -= 2
				b.body.global_position.y -= 2
				mv = 1
	dirty = mv


# ================================================================ spiders (v77 spawn / tick loop / spAnim / spSlash / hurt / spDie)
const PIV := [[.211, .439, .211], [-.211, .439, .211], [-.211, .439, -.211], [.211, .439, -.211]]
var LAX: Array = []
var FRONT: Array = []
var _eid := 0


func _leg_axes() -> void:
	if LAX.size():
		return
	for p in PIV:
		LAX.append(Vector3(p[2], 0, -p[0]).normalized())
	var order := [0, 1, 2, 3]
	order.sort_custom(func(a, b): return PIV[a][2] > PIV[b][2])
	FRONT = [order[0], order[1]]


func spawn(w: int) -> void:
	_leg_axes()
	var sx := 0.0
	var sz := 0.0
	for i in 40:
		var a := rnd() * 6.28
		var r := 38 + rnd() * 24
		sx = cl(P.x + cos(a) * r, col.bounds[0] + 4, col.bounds[1] - 4)
		sz = cl(P.z + sin(a) * r, col.bounds[2] + 4, col.bounds[3] - 4)
		if not col.solid(sx, .4, sz) and not col.solid(sx, 1.4, sz) and Vector2(sx - P.x, sz - P.z).length() > 25:
			break
	var m := Node3D.new()
	add_child(m)
	m.global_position = Vector3(sx, 1.2, sz)
	var model: Node3D = spider_scene.instantiate()
	m.add_child(model)
	# per-spider material copies so hit flash / stun / chill tint each one on its own
	var mats := []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var sm := mesh.surface_get_material(s) as ShaderMaterial
			if sm and not sm.shader.resource_path.contains("unshaded"):
				var c2: ShaderMaterial = sm.duplicate()
				mi.set_surface_override_material(s, c2)
				mats.append(c2)
	var legs := []
	for i in 4:
		var found := model.find_children("leg%d_*" % i, "Node3D", true, false)
		legs.append(found[0] if found.size() else null)
	var bodyn := model.find_children("body_*", "Node3D", true, false)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_ENEMY
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.1, 2.1, 2.1)
	cs.shape = bx
	cs.position = Vector3(0, -.15, 0)
	body.add_child(cs)
	m.add_child(body)
	_eid += 1
	var e := {"id": _eid, "m": m, "body": body, "legs": legs, "b": bodyn[0] if bodyn.size() else null, "mats": mats, "ph": rnd() * 6.28, "fl": 0.0, "hp": 60.0 + w * 4, "sp": 3 + w * .25 + rnd(), "eat": 0.0, "chill": 0.0, "stun": 0.0, "sl": null, "scd": 0.0, "sd": 0.0, "sg": 0, "d": false, "ah": 0.0}
	body.set_meta("enemy", e)
	EN.append(e)


func sp_anim(e: Dictionary, _dist: float) -> void:
	var ph: float = e.ph
	for i in 4:
		var leg: Node3D = e.legs[i]
		if leg == null:
			continue
		var p := ph + (PI if i % 2 else 0.0)
		var sn := sin(p)
		var qa := Quaternion(LAX[i], -maxf(0, sn) * .38)
		var qb := Quaternion(Vector3.UP, cos(p) * .26)
		leg.quaternion = qb * qa
	if e.b:
		e.b.position.y = absf(sin(ph)) * .03
		e.b.rotation.z = sin(ph) * .025


func _tint(e: Dictionary) -> void:
	var em := Vector3.ZERO
	var k := 0.0
	if e.stun > 0:
		em = Vector3(1, 1, 1); k = .85
	elif e.chill > 0:
		em = Vector3(0x66 / 255.0, 0xd9 / 255.0, 1); k = .6
	if e.fl > 0:
		em = Vector3(1, .3, .3); k = maxf(k, .6)
	for m in e.mats:
		m.set_shader_parameter("v_emissive", em * k)


func _step_enemies(dt: float) -> void:
	var slowM: float = (.3 if slowT > 0 else 1.0) * float(Ar.get("eslow", 1.0))
	for e in EN.duplicate():
		if e.d:
			continue
		if e.chill > 0:
			e.chill -= dt
		e.fl -= dt
		_tint(e)
		var m: Node3D = e.m
		if e.stun > 0:
			e.stun -= dt
			m.rotation.y += dt * 2
			continue
		var pos := m.global_position
		var dx := P.x - pos.x
		var dz := P.z - pos.z
		var d := maxf(Vector2(dx, dz).length(), 1e-4)
		var s: float = e.sp * slowM * (.4 if e.chill > 0 else 1.0) * dt
		var ux := dx / d
		var uz := dz / d
		if e.sd > 0:      # steer around buildings
			e.sd -= dt
			var tx: float = -uz * e.sg
			var tz: float = ux * e.sg
			ux = tx * .85 + ux * .15
			uz = tz * .85 + uz * .15
		var adv := 1.0 if d > 1.5 else 0.0
		var nx := pos.x + ux * s * adv
		var nz := pos.z + uz * s * adv
		var blk := 0
		if not col.solid(nx, 1.2, pos.z) and not col.solid(nx, .4, pos.z):
			pos.x = nx
		else:
			e.eat += dt
			blk = 1
		if not col.solid(pos.x, 1.2, nz) and not col.solid(pos.x, .4, nz):
			pos.z = nz
		else:
			e.eat += dt
			blk = 1
		if blk and not (e.sd > 0) and (col.sol(nx, .4, pos.z) or col.sol(pos.x, .4, nz)):
			e.sd = .9 + rnd() * 1.1
			e.sg = e.sg if (e.sg != 0 and rnd() < .75) else (-1 if rnd() < .5 else 1)
		if e.eat > .8:
			e.eat = 0.0
			destroy(Vector3(nx, 1.2, nz), .6)
		for o in EN:
			if o == e or o.d:
				continue
			var op: Vector3 = o.m.global_position
			var ox := pos.x - op.x
			var oz := pos.z - op.z
			var od := Vector2(ox, oz).length()
			if od < 1.9 and od > 1e-4:
				var kk := (1.9 - od) * .5
				var px := pos.x + ox / od * kk
				var pz := pos.z + oz / od * kk
				if not col.solid(px, .4, pz) and not col.solid(px, 1.2, pz):
					pos.x = px
					pos.z = pz
		pos.y = 1.2
		m.global_position = pos
		e.ph += s * 5.5 * (adv if adv > 0 else .35)
		sp_anim(e, d)
		m.rotation.y = atan2(dx, dz)
		sp_slash(e, d, dt)


func sp_slash(e: Dictionary, d: float, dt: float) -> void:
	var inR := d < 2.5 and absf(P.y + .9 - e.m.global_position.y) < 1.7
	e.scd -= dt
	if e.sl == null:
		if inR and e.scd <= 0 and not (e.stun > 0):
			e.sl = 0.0
			e.sh = 0
			e.side = 1 if rnd() < .5 else -1
			sfx.play_at("slash_windup", e.m.global_position)
		else:
			return
	e.sl += dt * (.5 if e.chill > 0 else 1.0)
	var t: float = e.sl
	var up: float
	if t < .28:
		up = sin(t / .28 * PI / 2)
	elif t < .40:
		up = cos((t - .28) / .12 * PI / 2) - (t - .28) / .12 * .35
	else:
		up = -.35 * (1 - minf(1, (t - .40) / .3))
	var sw: float
	if t < .28:
		sw = -.35 * (t / .28)
	elif t < .40:
		sw = -.35 + 1.25 * ((t - .28) / .12)
	else:
		sw = .9 * (1 - minf(1, (t - .40) / .35))
	for k in 2:
		var li: int = FRONT[k]
		var leg: Node3D = e.legs[li]
		if leg == null:
			continue
		var sg: float = (1.0 if k else -1.0) * e.side
		leg.quaternion = Quaternion(Vector3.UP, sw * sg * .8) * Quaternion(LAX[li], -up * 1.15)
	if e.b:
		e.b.rotation.x = -up * .22
		e.b.position.z = sin((t - .28) / .22 * PI) * .18 if (t > .28 and t < .5) else 0.0
	if not e.sh and t >= .34:
		e.sh = 1
		if inR and not (invT > 0 or shieldT > 0):
			take_dmg(14 + wave * .8)
			dmgA = maxf(dmgA, 1)
			shake = maxf(shake, .35)
			sfx.play("slash_hit")
		else:
			sfx.play("slash_miss")
	if t >= .75:
		e.sl = null
		if e.b:
			e.b.rotation.x = 0
			e.b.position.z = 0
		e.scd = .9 + rnd() * .6


func spider_push() -> void:
	var RR := 1.4
	for e in EN:
		var q: Vector3 = e.m.global_position
		if P.y > q.y + 1.05 or P.y + 1.8 < q.y - 1.2:
			continue
		var dx := P.x - q.x
		var dz := P.z - q.z
		var d := Vector2(dx, dz).length()
		if d >= RR:
			continue
		var ux := dx / d if d > 1e-4 else sin(yaw)
		var uz := dz / d if d > 1e-4 else cos(yaw)
		var px := q.x + ux * RR
		var pz := q.z + uz * RR
		if not col.hit(px, P.y, pz):
			P.x = px
			P.z = pz
		elif not col.hit(px, P.y, P.z):
			P.x = px
		elif not col.hit(P.x, P.y, pz):
			P.z = pz
		var vn := V.x * ux + V.z * uz
		if vn < 0:
			V.x -= vn * ux
			V.z -= vn * uz


func hurt(e: Dictionary, dmg: float) -> void:
	if e.d:
		return
	e.hp -= dmg
	e.fl = .07
	if e.hp > 0 and now_s > e.ah:
		e.ah = now_s + .18
		sfx.play_at("sp_hit", e.m.global_position)
	if e.hp <= 0:
		e.d = true
		sfx.play_at("sp_die", e.m.global_position)
		var bp: Vector3 = e.m.global_position + Vector3(0, .2, 0)
		blood(bp, Vector3(bp.x - P.x, .3, bp.z - P.z).normalized(), 2.4)
		score += 100
		SK.k += 1
		feed("[b]YOU[/b] [i][%s][/i] SWARMER" % dsrc)
		shake = maxf(shake, .12)
		EN.erase(e)
		sp_die(e)


func sp_die(e: Dictionary) -> void:
	var m: Node3D = e.m
	e.body.queue_free()
	var away := Vector3(m.global_position.x - P.x, 0, m.global_position.z - P.z)
	if away.length_squared() < 1e-4:
		away = Vector3(0, 0, 1)
	away = away.normalized()
	var fwd := Vector3(sin(m.rotation.y), 0, cos(m.rotation.y))
	var back := fwd.dot(away) < .2
	DEAD.append({"e": e, "m": m, "t": 0.0, "a": 0.0, "w": 0.0, "y": m.global_position.y, "vy": 1.4, "vx": away.x * 3.2, "vz": away.z * 3.2,
		"roll": (rnd() - .5) * 1.1, "ry": m.rotation.y, "end": -(2.55 + rnd() * .5) if back else (1.9 + rnd() * .4), "bounced": 0, "tw": rnd() * 9, "ash": false})
	if DEAD.size() > 14:
		var o: Dictionary = DEAD.pop_front()
		o.m.queue_free()


func step_dead(dt: float) -> void:
	for k in range(DEAD.size() - 1, -1, -1):
		var d: Dictionary = DEAD[k]
		var m: Node3D = d.m
		d.t += dt
		var t: float = d.t
		if t < 1.6:      # topple about the hip line under a growing gravity torque, one damped bounce
			var th := absf(d.a)
			var acc := 5 + 21 * sin(minf(PI / 2, th + .25))
			if not d.bounced or t < 1.4:
				d.w += acc * dt
				d.a += signf(d.end) * d.w * dt * (2.2 if t < .12 else 1.0)
			if absf(d.a) >= absf(d.end):
				d.a = d.end
				if d.bounced < 2 and d.w > 1.2:
					d.w = -d.w * .28
					d.bounced += 1
				else:
					d.w = 0.0
		var fr := maxf(0, 1 - dt * 4.5)
		d.vx *= fr
		d.vz *= fr
		var rk := minf(1, absf(d.a) / absf(d.end))
		m.quaternion = Quaternion(Vector3.UP, d.ry) * Quaternion(Vector3.RIGHT, d.a) * Quaternion(Vector3.BACK, d.roll * rk)
		var gr := _ground_below(m.global_position.x + d.vx * dt, d.y, m.global_position.z + d.vz * dt)
		d.vy -= GRAV * dt
		d.y += d.vy * dt
		var rest := gr + .45
		if d.y <= rest:
			d.y = rest
			d.vy = -d.vy * .18 if d.vy < -4 else 0.0
		m.global_position = Vector3(m.global_position.x + d.vx * dt, d.y, m.global_position.z + d.vz * dt)
		var cu := minf(1, maxf(0, (t - .15) / .9))
		var ce := cu * cu * (3 - 2 * cu)
		for i in 4:
			var leg: Node3D = d.e.legs[i]
			if leg == null:
				continue
			var tw := exp(-t * 1.6) * sin(t * (23 + i * 3) + d.tw + i) * .22 * (1.0 if t > .5 else 0.0)
			var fl := sin(t * 30 + i * 1.7) * .35 * (1 - t / .3) if t < .3 else 0.0
			leg.quaternion = Quaternion(Vector3.UP, (1.0 if i % 2 else -1.0) * .35 * ce) * Quaternion(LAX[i], 1.15 * ce + fl + tw)
		if t >= 2 and not d.ash:      # 2 s after death: ash and embers
			d.ash = true
			burst(m.global_position, 30, 0x8a5cff, 3)
		if d.ash:
			var u := minf(1, (t - 2) / .7)
			m.scale = Vector3.ONE * maxf(.01, 1 - u)
			if u >= 1:
				m.queue_free()
				DEAD.remove_at(k)


func _ground_below(x: float, y: float, z: float) -> float:
	var h := y
	while h > -1:
		if col.sol(x, h - .05, z):
			return h
		h -= .1
	return 0.0


# ================================================================ drone (skill and streak)
func _step_drone(dt: float) -> void:
	var on: bool = Sk.id == "drone" or droneT > 0
	drone.visible = on and go
	var tt := now_s
	drone.position = Vector3(-1.22 + sin(tt * .9) * .05, .74 + sin(tt * 1.7) * .05 + sin(tt * 3.1) * .014, -1.5 + cos(tt * .7) * .04)
	drone.rotation = Vector3(sin(tt * 1.3) * .08, sin(tt * .8) * .12, sin(tt * 1.1) * .07)
	if droneT > 0:
		droneT -= dt
		dshot -= dt
		if dshot <= 0:
			dshot = .3
			var best = null
			var bd := 35.0
			for e in EN:
				var d: float = e.m.global_position.distance_to(P)
				if d < bd:
					bd = d
					best = e
			if best != null:
				dsrc = "DRONE"
				var mp: Vector3 = drone.global_position
				var tp: Vector3 = best.m.global_position + Vector3(0, .1 + rnd() * .3, 0)
				tracer(tp, mp, 0x3a9cff)
				sfx.play("drone")
				var target: Dictionary = best
				get_tree().create_timer(minf(.14, .025 + mp.distance_to(tp) * .004)).timeout.connect(func():
					if not target.d:
						blood(tp, (tp - mp).normalized(), .7)
						hurt(target, 18))


# ================================================================ fx (v77 burst / tracer / impact / blood / muzzle)
static func fx_col(hex: int) -> Color:
	return V77Data.col(hex).linear_to_srgb()


var _mats := {}

func _glow_mat(hex: int, additive: bool) -> StandardMaterial3D:
	var key := "%d|%s" % [hex, additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = fx_col(hex)
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
	_mats[key] = m
	return m


var _cube: BoxMesh

## v77 burst: n glowing cubes (.28 m) thrown out at speed, falling under gravity 20, shrinking over their life
func burst(pt: Vector3, n: int, hex: int, spd: float) -> void:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3(.28, .28, .28)
	n = mini(n, 40)
	for i in n:
		var m := MeshInstance3D.new()
		m.mesh = _cube
		m.material_override = _glow_mat(hex, false)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.global_position = pt
		var v := Vector3((rnd() - .5) * spd, rnd() * spd, (rnd() - .5) * spd)
		PA.append({"m": m, "v": v, "l": .5 + rnd() * .5})


func impact(pt: Vector3, _n: Vector3, hex: int, k: float) -> void:
	burst(pt, int(6 * k), hex, 4)


func blood(pt: Vector3, dir: Vector3, k: float) -> void:
	var n := clampi(int(6 * k), 2, 16)
	for i in n:
		var m := MeshInstance3D.new()
		if _cube == null:
			_cube = BoxMesh.new()
			_cube.size = Vector3(.28, .28, .28)
		m.mesh = _cube
		m.scale = Vector3.ONE * .35
		m.material_override = _glow_mat(0x7a0610, false)
		add_child(m)
		m.global_position = pt
		var v := dir * (2 + rnd() * 3) + Vector3((rnd() - .5) * 2, rnd() * 2, (rnd() - .5) * 2)
		PA.append({"m": m, "v": v, "l": .4 + rnd() * .3, "s": .35})


func tracer(to: Vector3, from = null, hex := -1, life := .07) -> void:
	if from == null:
		from = barrel.global_position if barrel else C.global_position
	var a: Vector3 = from
	var L := a.distance_to(to)
	if L < .05:
		return
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = .012
	cm.bottom_radius = .012
	cm.height = L
	cm.radial_segments = 6
	cm.rings = 1
	m.mesh = cm
	m.material_override = _glow_mat(Wp.col if hex < 0 else hex, true)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var mid := (a + to) * .5
	var dir := (to - a).normalized()
	var up := Vector3.UP if absf(dir.y) < .99 else Vector3.RIGHT
	var b := Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2)
	m.global_transform = Transform3D(b, mid)
	TR.append({"m": m, "t": life})


func _muzzle_fx() -> void:
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = rnd() * TAU
		get_tree().create_timer(.04).timeout.connect(func(): if is_instance_valid(muzzle_flash): muzzle_flash.visible = false)


func _step_particles(dt: float) -> void:
	for i in range(PA.size() - 1, -1, -1):
		var p: Dictionary = PA[i]
		p.v.y -= 20 * dt
		var m: MeshInstance3D = p.m
		m.global_position += p.v * dt
		if m.global_position.y < .15:
			m.global_position.y = .15
			p.v *= .5
		p.l -= dt
		m.scale = Vector3.ONE * maxf(.01, p.l) * float(p.get("s", 1.0))
		if p.l <= 0:
			m.queue_free()
			PA.remove_at(i)
	for i in range(TR.size() - 1, -1, -1):
		TR[i].t -= dt
		if TR[i].t <= 0:
			TR[i].m.queue_free()
			TR.remove_at(i)


func feed(bb: String) -> void:
	feed_lines.push_front({"t": 3.5, "text": bb})
	while feed_lines.size() > 4:
		feed_lines.pop_back()
