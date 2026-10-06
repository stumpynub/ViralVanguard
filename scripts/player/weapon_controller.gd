class_name WeaponController
extends Node
## Two weapon slots (the chosen weapon + a sidearm), firing, reloads, aiming down sights.
## Fire modes, bursts, spin-up, pellets, piercing rails, explosive / chill / chain / gravity-well rounds are all
## driven by the WeaponData resource of the active slot.

signal ammo_changed(ammo: int, mag: int, reloading: bool)
signal weapon_changed(weapon: WeaponData, other: WeaponData)

@export var player: Player
@export var gun_wrap: Node3D

var slots: Array[WeaponData] = []
var slot_ammo := [0, 0]
var cur := 0
var weapon: WeaponData
var ammo := 0
var ads := 0.0
var aiming := false
var trigger := false
var recoil := 0.0
var last_source := ""

var _model: WeaponModel
var _fire_cd := 0.0
var _reload_t := 0.0
var _swap_t := 0.0
var _burst_n := 0
var _burst_t := 0.0
var _spin_t := 0.0
var _hold := false
var _hold_t := 0.0
var _ads_toggle := false
var _reload_sfx := 0

# precision rifle (bolt action, scope, breath)
signal bolt_cycled
var bolt_t := -1.0                 ## 0..1 through the bolt cycle, -1 when closed
var _bolt_cues := 0
var settle := 0.0                  ## 0..1: scope steadiness after coming fully on target
var breath := 1.0                  ## hold-breath stamina
var holding_breath := false
var winded := false                ## held too long: shaky until it recovers
var sway := Vector2.ZERO           ## scope sway (yaw, pitch) radians, applied to the view by the player
var _sway_t := randf() * 50.0
var _breath_sfx := 0.0
const CASING := preload("res://scenes/fx/casing.tscn")
const BULLET := preload("res://scripts/weapons/bullet.gd")


func _ready() -> void:
	var main := Game.weapon(str(player.loadout.get("weapon", "")))
	slots = [main, Game.weapon("pulse" if main.id == "smg" else "smg")]
	slot_ammo = [slots[0].magazine, slots[1].magazine]
	_equip(0)
	if player.remote:      # other players' guns are driven by their own peer
		set_process(false)
		set_process_unhandled_input(false)


func reloading() -> bool:
	return _reload_t > 0.0


## 0..1 through the current reload, or -1 when not reloading.
func reload_phase() -> float:
	return 1.0 - _reload_t / weapon.reload_time if _reload_t > 0.0 else -1.0


func view_model() -> WeaponModel:
	return _model


func swap_dip() -> float:
	return WeaponModel.sm(_swap_t, 0.0, 0.5) * 0.45 if _swap_t > 0.0 else 0.0


func scoped_view() -> bool:
	return weapon.scoped and ads > 0.6


## Field of view for the current aim state (scoped rifles zoom to ~4x).
func view_fov(base: float) -> float:
	if weapon.scoped:
		var sk := clampf((ads - 0.6) / 0.4, 0.0, 1.0)
		return lerpf(base * (1.0 - 0.22 * minf(1.0, ads / 0.6)), base / weapon.scope_zoom, sk)
	return base * (1.0 - weapon.ads_zoom * ads)


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if player.is_dead():
		return
	if event.is_action_pressed("fire"):
		_hold = true
		_hold_t = 0.0
		if weapon.fire_mode == "onetap":
			fire()
	elif event.is_action_released("fire"):
		if _hold and weapon.fire_mode == "release":
			fire()
		_hold = false
	elif event.is_action_pressed("aim") and Game.settings.ads_mode == "toggle":
		_ads_toggle = not _ads_toggle
	elif event.is_action_pressed("reload"):
		reload()
	elif event.is_action_pressed("swap_weapon"):
		swap()
	elif event.is_action_pressed("weapon_1"):
		swap(0)
	elif event.is_action_pressed("weapon_2"):
		swap(1)


func _process(delta: float) -> void:
	if player.is_dead():
		return
	_fire_cd -= delta
	_swap_t -= delta
	recoil *= 0.9
	if _hold:
		_hold_t += delta
	var m := weapon.fire_mode
	trigger = _hold and m in ["hip", "ads", "mixed"]
	var held_aim := Input.is_action_pressed("aim") if Game.settings.ads_mode == "hold" else _ads_toggle
	aiming = (held_aim or (_hold and (m == "ads" or m == "release" or (m == "mixed" and _hold_t > 0.25)))) and _reload_t <= 0.0 and _swap_t <= 0.0
	# while the bolt is worked the rifle comes off the eye (you see the action), then settles back in
	var ads_cap := 1.0
	if bolt_t >= 0.0:
		ads_cap = 0.3 + 0.7 * WeaponModel.sm(bolt_t, 0.8, 1.0)
	if aiming:
		ads = minf(ads_cap, ads + delta / weapon.ads_time) if ads < ads_cap else maxf(ads_cap, ads - delta / (weapon.ads_time * 0.5))
	else:
		ads = maxf(0.0, ads - delta / (weapon.ads_time * 0.8))
	_precision(delta)
	if trigger:
		fire()

	if bolt_t >= 0.0 and _reload_t <= 0.0:
		bolt_t += delta / weapon.bolt_time
		var cues := [[0.26, "bolt_up"], [0.4, "bolt_back"], [0.47, "eject"], [0.58, "bolt_fwd"], [0.7, "bolt_down"]]
		while _bolt_cues < cues.size() and bolt_t >= cues[_bolt_cues][0]:
			var cue: String = cues[_bolt_cues][1]
			if cue == "eject":
				_eject_case()
			else:
				Sfx.play(cue, 0.9, randf_range(0.96, 1.04))
			_bolt_cues += 1
		var o := _model.bolt_cycle(minf(bolt_t, 1.0))
		gun_wrap.rotation = Vector3(o.rx, o.ry, o.rz)
		gun_wrap.position = Vector3(o.px, o.py, o.pz)
		if bolt_t >= 1.0:
			bolt_t = -1.0
			_model.reset_parts()
			gun_wrap.position = Vector3.ZERO
			gun_wrap.rotation = Vector3.ZERO
			bolt_cycled.emit()

	if _reload_t > 0.0:
		_reload_t -= delta
		var t := 1.0 - _reload_t / weapon.reload_time
		var o := _model.apply_reload(clampf(t, 0.0, 1.0))
		gun_wrap.rotation = Vector3(o.rx, o.ry, o.rz)
		var k := WeaponModel.sm(t, 0, .1) - WeaponModel.sm(t, .88, 1)
		gun_wrap.position = Vector3(o.px - 0.11 * k, o.py + 0.12 * k, o.pz + 0.14 * k)
		if weapon.bolt_action:
			var cues := [0.13, 0.2, 0.37, 0.46, 0.54, 0.64, 0.72, 0.79]
			var names := ["bolt_up", "bolt_back", "clip_in", "round_in", "round_in", "casing", "bolt_fwd", "bolt_down"]
			while _reload_sfx < cues.size() and t > cues[_reload_sfx]:
				Sfx.play(names[_reload_sfx], 0.85, randf_range(0.95, 1.05))
				_reload_sfx += 1
		elif _reload_sfx == 0 and t > 0.2:
			_reload_sfx = 1
			Sfx.play("reload_out", 0.8)
		elif _reload_sfx == 1 and t > 0.62:
			_reload_sfx = 2
			Sfx.play("reload_in", 0.9)
		if _reload_t <= 0.0:
			ammo = weapon.magazine
			bolt_t = -1.0
			_model.reset_parts()
			gun_wrap.position = Vector3.ZERO
			gun_wrap.rotation = Vector3.ZERO
			_emit_ammo()

	if _burst_n > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			if ammo > 0 and _reload_t <= 0.0:
				_discharge()
				_burst_n -= 1
				_burst_t = 0.075
			else:
				_burst_n = 0
			if _burst_n == 0:
				_fire_cd = weapon.fire_interval

	if weapon.spin_up > 0.0:
		_spin_t = _spin_t + delta if trigger and _reload_t <= 0.0 and ammo > 0 else maxf(0.0, _spin_t - delta * 1.5)
		if _reload_t <= 0.0:
			_model.spin(delta * (4.0 + 30.0 * minf(1.0, _spin_t / weapon.spin_up)) * (1.0 if trigger else 0.3))


# ------------------------------------------------------------------ actions
func fire() -> void:
	if _reload_t > 0.0 or _swap_t > 0.0 or bolt_t >= 0.0:
		return
	if weapon.burst_count > 0:
		if _burst_n > 0 or _fire_cd > 0.0:
			return
		if ammo <= 0:
			reload()
			return
		_burst_n = mini(weapon.burst_count, ammo)
		_burst_t = 0.0
		return
	if _fire_cd > 0.0:
		return
	if ammo <= 0:
		reload()
		return
	var spin_mult := 1.0 + 2.0 * (1.0 - minf(1.0, _spin_t / weapon.spin_up)) if weapon.spin_up > 0.0 else 1.0
	_fire_cd = weapon.fire_interval * spin_mult
	_discharge()


func reload() -> void:
	if _reload_t <= 0.0 and ammo < weapon.magazine and bolt_t < 0.0:
		_reload_t = weapon.reload_time
		_reload_sfx = 0
		_emit_ammo()


func swap(to := -1) -> void:
	if _swap_t > 0.0:
		return
	var n := cur ^ 1 if to < 0 else to
	if n == cur:
		return
	slot_ammo[cur] = ammo
	_reload_t = 0.0
	_burst_n = 0
	_spin_t = 0.0
	bolt_t = -1.0
	_hold = false
	_ads_toggle = false
	_equip(n)
	_swap_t = 0.5
	_fire_cd = 0.0
	Sfx.beep(320, 0.08, "square", 0.05)


func _equip(i: int) -> void:
	cur = i
	weapon = slots[i]
	ammo = slot_ammo[i]
	if _model:
		_model.queue_free()
	_model = weapon.model_scene.instantiate()
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * player.view_model_scale
	gun_wrap.add_child(_model)
	ToonStyle.apply(_model, {"outline": 0.0004, "outline_max": 0.002, "tint": Color(1.4, 1.4, 1.5), "desaturate": 0.8})
	gun_wrap.position = Vector3.ZERO
	gun_wrap.rotation = Vector3.ZERO
	weapon_changed.emit(weapon, slots[i ^ 1])
	_emit_ammo()


func _emit_ammo() -> void:
	ammo_changed.emit(ammo, weapon.magazine, _reload_t > 0.0)


func muzzle_position() -> Vector3:
	if player.third_person:
		return player.body_muzzle()
	return _model.muzzle.global_position if _model and _model.muzzle else player.camera.global_position


# ------------------------------------------------------------------ the shot
func _discharge() -> void:
	var a := Arena.current
	var w := weapon
	ammo -= 1
	_emit_ammo()
	_model.fire_flash()
	player.body_fire_flash()
	Sfx.fire(w)
	last_source = w.short_name
	var spr := shot_spread()
	recoil += w.recoil
	player.add_recoil(w.kick)
	if w.bolt_action:
		player.view_kick(w.kick)
		bolt_t = 0.0
		_bolt_cues = 0
		settle = 0.0
	var cam := player.camera
	var origin := cam.global_position
	var muzzle := muzzle_position()
	var ends := PackedVector3Array()
	for p in w.pellets:
		var dir := (-cam.global_basis.z + cam.global_basis.x * (randf() - 0.5) * 2.0 * spr + cam.global_basis.y * (randf() - 0.5) * 2.0 * spr).normalized()
		var far := origin + dir * w.max_range
		if w.bullet_speed > 0.0:
			var b: Node3D = BULLET.new()
			a.get_node("FX").add_child(b)
			b.launch(player, w, muzzle, origin, dir * w.bullet_speed)
			ends.append(origin + dir * minf(w.max_range, 200.0))
			continue
		if w.pierce:
			ends.append(_pierce_shot(origin, dir, muzzle))
			continue
		var hit := a.raycast(origin, far)
		if w.gravity_well_time > 0.0:
			var pt: Vector3 = hit.position if hit else origin + dir * 60.0
			_tracer(muzzle, pt, ends)
			if hit and hit.collider is Spider:
				a.blood(pt, dir, w.damage / 30.0)
				a.damage_enemy(hit.collider, w.damage, w.short_name)
			elif hit:
				a.destroy_blocks(pt, w.block_break)
			a.add_well(pt, w.gravity_well_time, w.color)
			continue
		if hit.is_empty():
			_tracer(muzzle, far if w.max_range < 100.0 else origin + dir * 60.0, ends)
			continue
		var pt: Vector3 = hit.position
		_tracer(muzzle, pt, ends)
		if hit.collider is GlassPanel:
			a.shatter_glass(hit.collider)
			continue
		if w.explosion_radius > 0.0:
			a.explode(pt, w.damage, w.explosion_radius, w.color, w.block_break, w.short_name)
		elif hit.collider is Spider:
			var e: Spider = hit.collider
			var dmg := w.damage * zone_multiplier(e, origin, dir) * range_multiplier(origin.distance_to(pt))
			a.blood(pt, dir, dmg / 30.0)
			a.damage_enemy(e, dmg, w.short_name, w.chill_time)
			if w.chain_jumps > 0:
				_chain_zap(e, pt, dmg)
		else:
			a.destroy_blocks(pt, w.block_break)
			a.impact(pt, hit.normal, w.color, 0.55 if w.pellets > 1 else 1.0)
	a.shot(player.peer_id, Game.DB.weapons.find(w), muzzle, ends)


## Full damage out to half the weapon's range, then down to 35% at max range.
func range_multiplier(d: float) -> float:
	var r := weapon.max_range
	return 1.0 if d <= r * 0.5 else maxf(0.35, 1.0 - 0.65 * (d - r * 0.5) / (r * 0.5))


## Spider hit zones: the box collider is only a broad phase. The ray is tested against the body ellipsoid
## (cephalothorax + abdomen) in model space: body 1x, the head end 1.3x, a ray through only the legs 0.35x.
func zone_multiplier(e: Spider, origin: Vector3, dir: Vector3) -> float:
	var inv := e.model.global_transform.affine_inverse()
	var o := inv * origin
	var d := inv.basis * dir
	var r := Vector3(1.3, 0.72, 0.68)
	var oo := Vector3(o.x, o.y - 0.19, o.z) / r
	var dd := d / r
	var qa := dd.dot(dd)
	var qb := 2.0 * oo.dot(dd)
	var qc := oo.dot(oo) - 1.0
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return 0.35
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	return 1.3 if o.z + d.z * t > r.z * 0.45 else 1.0


# ------------------------------------------------------------------ precision rifle
func _precision(delta: float) -> void:
	sway = Vector2.ZERO
	if weapon.scope_sway <= 0.0:
		return
	var scoped := ads > 0.6
	var moving := Vector2(player.velocity.x, player.velocity.z).length()
	# settle: accuracy builds over settle_time once fully on target and fairly still
	if ads >= 0.98 and moving < 3.0:
		settle = minf(1.0, settle + delta / maxf(0.01, weapon.settle_time))
	elif ads < 0.9:
		settle = 0.0
	# hold breath (sprint key while scoped)
	var want_hold := scoped and Input.is_action_pressed("sprint") and not winded
	if want_hold and not holding_breath and breath > 0.15:
		holding_breath = true
		Sfx.play("breath_in", 0.7)
	elif holding_breath and not want_hold:
		holding_breath = false
		Sfx.play("breath_out", 0.6)
	if holding_breath:
		breath -= delta / weapon.hold_breath
		if breath <= 0.0:
			breath = 0.0
			holding_breath = false
			winded = true
			Sfx.play("breath_out", 0.9, 0.85)
	else:
		breath = minf(1.0, breath + delta / 3.0)
		if winded and breath > 0.45:
			winded = false
	if winded:
		_breath_sfx -= delta
		if _breath_sfx <= 0.0:
			_breath_sfx = 0.75
			Sfx.play("heartbeat", 0.55)
	# breathing sway: a slow figure-eight with a little noise; stance, breath and movement scale it
	_sway_t += delta
	var amp: float = weapon.scope_sway * [1.0, 0.65, 0.35][player.stance] * (0.07 if holding_breath else 1.0) * (2.4 if winded else 1.0) * (1.0 + moving * 0.35)
	var t := _sway_t
	var s := Vector2(sin(t * 0.9) + 0.35 * sin(t * 2.3 + 1.7), sin(t * 1.8 + 0.6) * 0.6 + 0.3 * sin(t * 3.1))
	sway = s * amp * ads


func _eject_case() -> void:
	var a := Arena.current
	if a == null or _model == null:
		return
	var port := _model.get_node_or_null("Eject") as Node3D
	var c: RigidBody3D = CASING.instantiate()
	a.get_node("FX").add_child(c)
	var at := port.global_position if port else _model.global_position
	c.global_position = at
	var cam := player.camera.global_basis
	c.linear_velocity = player.velocity + cam.x * randf_range(1.6, 2.4) + cam.y * randf_range(1.4, 2.0) - cam.z * randf_range(-0.2, 0.4)
	c.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-30, 30), randf_range(-20, 20))
	c.global_basis = cam * Basis(Vector3.RIGHT, PI / 2)
	Sfx.play("bolt_back", 0.35, 1.3)


## Effective spread for this shot: no-scope penalty until fully scoped and settled, plus movement.
func shot_spread() -> float:
	var w := weapon
	var spr: float = w.spread * (1.0 - 0.75 * ads) * [1.0, 0.8, 0.6][player.stance] * (1.6 if player.sprinting else 1.0)
	if w.hip_spread > 0.0:
		var ready := settle if ads >= 0.98 else 0.0
		spr += w.hip_spread * (1.0 - ready * 0.97)
		spr += Vector2(player.velocity.x, player.velocity.z).length() * 0.0025
	return spr


## Local tracer for our own shot (other peers draw theirs from Arena.shot).
func _tracer(muzzle: Vector3, end: Vector3, ends: PackedVector3Array) -> void:
	Arena.current._fx_local(Arena.Fx.TRACER, muzzle, end, weapon.color, 0.0)
	ends.append(end)


## Rail lance: hurts every infected along the line and punches through up to three blocks.
func _pierce_shot(origin: Vector3, dir: Vector3, muzzle: Vector3) -> Vector3:
	var a := Arena.current
	var w := weapon
	var exclude: Array[RID] = []
	var blocks := 0
	var from := origin
	var end := origin + dir * w.max_range
	for i in 24:
		var hit := a.raycast(from, origin + dir * w.max_range, Arena.LAYER_WORLD | Arena.LAYER_ENEMY, exclude)
		if hit.is_empty():
			break
		exclude.append(hit.rid)
		from = hit.position
		if hit.collider is Spider:
			var dmg := w.damage * zone_multiplier(hit.collider, origin, dir) * range_multiplier(origin.distance_to(hit.position))
			a.blood(hit.position, dir, dmg / 30.0)
			a.damage_enemy(hit.collider, dmg, w.short_name)
		elif hit.collider is GlassPanel:
			a.shatter_glass(hit.collider)
		else:
			a.destroy_blocks(hit.position, w.block_break)
			a.impact(hit.position, hit.normal, w.color, 1.0)
			blocks += 1
			if blocks >= 3 or not (hit.collider is CrateBlock):
				end = hit.position
				break
	Arena.current._fx_local(Arena.Fx.TRACER, muzzle, end, w.color, 0.0)
	return end


## Stormcaller: lightning jumps from the target to up to three more infected within 7.5 m.
func _chain_zap(first: Spider, from_pt: Vector3, dmg: float) -> void:
	var a := Arena.current
	var hit := {first: true}
	var cur_pt := from_pt
	for k in weapon.chain_jumps:
		var best: Spider = null
		var bd := 7.5
		for e in a.enemies:
			if hit.has(e) or not is_instance_valid(e):
				continue
			var d := e.center().distance_to(cur_pt)
			if d < bd and not e.dead:
				bd = d
				best = e
		if best == null:
			break
		var np := best.center()
		var mid := cur_pt.lerp(np, 0.5) + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.8
		a.tracer(cur_pt, mid, weapon.color)
		a.tracer(mid, np, weapon.color)
		hit[best] = true
		a.damage_enemy(best, dmg * pow(0.75, k + 1), weapon.short_name)
		a.burst(np, 4, weapon.color)
		cur_pt = np
