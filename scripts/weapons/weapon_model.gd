class_name WeaponModel
extends Node3D
## A first-person gun built from primitive part nodes (grip at origin, barrel along +Z).
## Moving parts are found by name: Mag, Top, Front, Spin, VaneL, VaneR. Meshes in the "glow" group pulse during reloads.
## apply_reload(t) runs the original per-weapon reload choreography (t = 0..1) and returns the gun pose offsets.

@export var weapon_id := "pulse"
@export var muzzle: Marker3D
@export var flash: Node3D
@export var flash_light: OmniLight3D
## Wrist targets for a full-body character (right hand on the grip, left hand on the handguard).
@export var grip_hand: Marker3D
@export var support_hand: Marker3D

var parts := {}
var _base := {}
var _glows: Array[GeometryInstance3D] = []
var _glow_mat: StandardMaterial3D
var _glow_color: Color
var _flash_t := 0.0


func _ready() -> void:
	for n in ["Mag", "Top", "Front", "Spin", "VaneL", "VaneR", "Bolt", "Clip", "Glint"]:
		var node := get_node_or_null(n) as Node3D
		if node:
			parts[n] = node
			_base[n] = [node.position, node.rotation, node.scale, node.visible]
	for g in find_children("*", "GeometryInstance3D", true, false):
		if g.is_in_group("glow"):
			_glows.append(g)
	if _glows.size() > 0 and _glows[0].material_override is StandardMaterial3D:
		_glow_mat = (_glows[0].material_override as StandardMaterial3D).duplicate()
		_glow_color = _glow_mat.emission
		for g in _glows:
			g.material_override = _glow_mat
	if flash:
		flash.visible = false


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0 and flash:
			flash.visible = false
	if flash_light:
		flash_light.light_energy *= 0.6


func fire_flash() -> void:
	_flash_t = 0.045
	if flash:
		flash.visible = true
		flash.rotation.z = randf() * TAU
		var k := randf_range(0.7, 1.2)
		flash.scale = Vector3(k, k, randf_range(0.8, 1.4))
	if flash_light:
		flash_light.light_energy = 3.0


# ------------------------------------------------------------------ bolt action (Nightfall)
## One bolt cycle, t = 0..1: the rifle cants right so the port faces you, the right hand leaves the grip for the knob,
## lifts, racks back (the case flies out at ~0.47), drives forward, locks down, and the hand returns. Returns gun offsets.
func bolt_cycle(t: float) -> Dictionary:
	var o := {"rx": 0.0, "ry": 0.0, "rz": 0.0, "px": 0.0, "py": 0.0, "pz": 0.0}
	var bolt: Node3D = parts.get("Bolt")
	if t < 0.0 or bolt == null:
		return o
	var b: Array = _base["Bolt"]
	var cant := sm(t, 0.0, 0.17) - sm(t, 0.76, 1.0)
	o.rz = -0.36 * cant
	o.rx = 0.06 * cant + 0.05 * (sm(t, 0.44, 0.47) - sm(t, 0.47, 0.62))     # the rack jolts the muzzle up
	o.ry = 0.05 * cant
	o.px = -0.02 * cant
	o.py = 0.018 * cant
	o.pz = -0.018 * (sm(t, 0.44, 0.47) - sm(t, 0.47, 0.6)) + 0.012 * (sm(t, 0.62, 0.65) - sm(t, 0.65, 0.78))   # slam forward
	var lift := sm(t, 0.24, 0.33) - sm(t, 0.66, 0.75)
	var rack := sm(t, 0.35, 0.46) - sm(t, 0.53, 0.64)
	bolt.position = b[0] + Vector3(0, 0, -0.085 * rack)
	bolt.rotation = b[1] + Vector3(0, 0, -1.05 * lift)
	return o


## Right wrist: on the grip, or travelling to the bolt knob during a bolt cycle / a reload.
func grip_target(bolt_t: float, reload_t: float) -> Vector3:
	var g := grip_hand.global_position if grip_hand else global_position
	var knob := get_node_or_null("Bolt/BoltHand") as Node3D
	if knob == null:
		return g
	var k := 0.0
	if bolt_t >= 0.0:
		k = sm(bolt_t, 0.08, 0.23) - sm(bolt_t, 0.74, 0.9)
	elif reload_t >= 0.0:
		k = (sm(reload_t, 0.05, 0.12) - sm(reload_t, 0.24, 0.31)) + (sm(reload_t, 0.66, 0.72) - sm(reload_t, 0.86, 0.93))
	return g.lerp(knob.global_position, k)


## Where the left wrist should be: on the handguard, or following the magazine while reloading.
func support_target(reload_t: float) -> Vector3:
	var hand := support_hand.global_position if support_hand else global_position
	var clip: Node3D = parts.get("Clip")
	if clip and reload_t >= 0.0:
		# down to the chest rig for a clip, up to the open action, thumb the rounds in, flick the strip, back to the guard
		var pouch := global_transform * Vector3(0.05, -0.34, 0.12)
		var away := sm(reload_t, 0.14, 0.26) - sm(reload_t, 0.72, 0.84)
		var target := pouch.lerp(clip.global_position + global_basis.y.normalized() * 0.02 * global_basis.get_scale().y, sm(reload_t, 0.27, 0.36))
		return hand.lerp(target, away)
	var mag: Node3D = parts.get("Mag")
	if reload_t < 0.0 or mag == null:
		return hand
	# off the gun to the mag and back (the original RIG timing: grab 0.1, pull 0.2, seat 0.72, return 0.86)
	var k := sm(reload_t, 0.02, 0.12) - sm(reload_t, 0.78, 0.9)
	var at_mag := mag.global_position - global_basis.y.normalized() * 0.05 * global_basis.get_scale().y
	if not mag.is_visible_in_tree():
		at_mag = global_position - global_basis.y.normalized() * 0.35 * global_basis.get_scale().y
	return hand.lerp(at_mag, k)


func spin(amount: float) -> void:
	if parts.has("Spin"):
		parts.Spin.rotation.z += amount


func reset_parts() -> void:
	for n in _base:
		var b: Array = _base[n]
		parts[n].position = b[0]
		parts[n].rotation = b[1]
		parts[n].scale = b[2]
		parts[n].visible = b[3]
	_glow_level(1.0)


func _glow_level(k: float) -> void:
	if _glow_mat:
		_glow_mat.emission = _glow_color * k
		_glow_mat.albedo_color = _glow_color * minf(k, 1.0)


# ------------------------------------------------------------------ reloads (ported from the original RLD table)
static func sm(t: float, a: float, b: float) -> float:
	var x := clampf((t - a) / (b - a), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func swap(t: float, a1: float, b1: float, a2: float, b2: float, d: float) -> float:
	return d * sm(t, a1, b1) if t < (b1 + a2) * 0.5 else d * (1.0 - sm(t, a2, b2))


## Returns {rx, ry, rz, px, py, pz}: rotation / offset for the whole gun this frame.
func apply_reload(t: float) -> Dictionary:
	reset_parts()
	var o := {"rx": 0.0, "ry": 0.0, "rz": 0.0, "px": 0.0, "py": 0.0, "pz": 0.0}
	var mag: Node3D = parts.get("Mag")
	var top: Node3D = parts.get("Top")
	match weapon_id:
		"sniper":
			# stripper-clip reload: cant, open the bolt, clip from the rig, thumb five rounds down, flick, close
			var k := sm(t, 0, .1) - sm(t, .88, 1)
			o.rz = -.5 * k; o.rx = .14 * k; o.py = .02 * k; o.px = -.02 * k
			var bolt: Node3D = parts.get("Bolt")
			if bolt:
				var lift := sm(t, .12, .17) - sm(t, .76, .82)
				var rack := sm(t, .18, .24) - sm(t, .7, .76)
				bolt.position.z += -.085 * rack
				bolt.rotation.z += -1.05 * lift
			var clip: Node3D = parts.get("Clip")
			if clip:
				clip.visible = t > .26 and t < .7
				var pouch := Vector3(0.05, -0.34, 0.12)
				var at := (_base["Clip"][0] as Vector3) + Vector3(0, .07, 0)
				clip.position = pouch.lerp(at, sm(t, .27, .36))
				# two thumb presses push the rounds down into the magazine
				var press := sm(t, .38, .45) * .5 + sm(t, .48, .56) * .5
				clip.position.y -= .045 * press
				for i in clip.get_child_count():
					var rn := clip.get_child(i) as Node3D
					if rn.name.begins_with("Round"):
						rn.visible = press < (1.0 - i * 0.18) or t < .38
				clip.position += Vector3(-.12, .08, .04) * sm(t, .6, .68)      # flick the empty strip away
				clip.rotation = Vector3(0, 0, -2.0 * sm(t, .6, .68))
			o.pz = .015 * (sm(t, .7, .73) - sm(t, .73, .82))
		"scatter":
			var k := sm(t, 0, .14) - sm(t, .8, .94)
			o.rz = -.85 * k; o.rx = .12 * k
			var ph := (t - .16) / .6 * 4.0
			if mag and ph >= 0.0 and ph < 4.0:
				var f := fmod(ph, 1.0)
				mag.visible = f < .85
				mag.position.x += .14 * (1.0 - sm(f, 0, .7))
				mag.position.y += -.03 * (1.0 - sm(f, 0, .7))
			if top: top.position.z += -.09 * (sm(t, .8, .86) - sm(t, .89, .95))
		"rail":
			var k := sm(t, 0, .12) - sm(t, .88, 1)
			o.rx = .35 * k; o.rz = .2 * k
			if mag:
				mag.position.z += swap(t, .12, .32, .45, .65, -.32)
				mag.position.y += swap(t, .12, .32, .45, .65, .04)
			_glow_level(1.0 if t < .1 else (.15 if t < .68 else .15 + .95 * sm(t, .68, .95) + (randf() - .5) * .3 * float(t < .95)))
		"smg":
			var k := sm(t, 0, .14) - sm(t, .86, 1)
			o.rz = 1.15 * k; o.rx = -.1 * k
			var d := swap(t, .14, .32, .45, .66, -.34)
			if mag:
				mag.position.y += d; mag.rotation.x += d * 9.0
			if top: top.position.z += -.05 * (sm(t, .7, .76) - sm(t, .8, .86))
		"arc":
			var k := sm(t, 0, .12) - sm(t, .86, 1)
			o.rx = -.18 * k; o.rz = .25 * k
			var front: Node3D = parts.get("Front")
			if front: front.rotation.x += .6 * (sm(t, .1, .28) - sm(t, .68, .82))
			if mag:
				mag.visible = t > .3 and t < .66
				mag.position.z += -.34 * (1.0 - sm(t, .32, .6))
				mag.position.y += .05 * (1.0 - sm(t, .32, .6))
		"ion":
			var k := sm(t, 0, .15) - sm(t, .86, 1)
			o.py = -.07 * k; o.rx = .18 * k; o.rz = .3 * k
			if mag:
				mag.position.y += swap(t, .15, .35, .45, .68, -.45)
				mag.position.x += swap(t, .15, .35, .45, .68, .06)
			if parts.has("Spin"): parts.Spin.rotation.z += sm(t, .72, 1) * sm(t, .72, 1) * 30.0
		"cryo":
			var k := sm(t, 0, .12) - sm(t, .86, 1)
			o.rz = -.6 * k; o.rx = .1 * k
			if mag:
				mag.rotation.y += 3.2 * sm(t, .1, .24) + 3.2 * sm(t, .62, .78)
				mag.position.y += swap(t, .22, .38, .48, .62, .28)
			_glow_level(1.0 - sm(t, .05, .2) * .85 if t < .2 else (.15 if t < .62 else .15 + .85 * sm(t, .62, .85)))
		"void":
			var k := sm(t, 0, .12) - sm(t, .86, 1)
			o.rx = .3 * k; o.py = .03 * k
			var v := sm(t, .06, .2) - sm(t, .8, .92)
			if parts.has("VaneL"): parts.VaneL.rotation.z += 1.1 * v
			if parts.has("VaneR"): parts.VaneR.rotation.z -= 1.1 * v
			var c := 1.0 - sm(t, .12, .32) if t < .34 else sm(t, .38, .78)
			if mag: mag.scale = Vector3.ONE * maxf(.01, c * (1.0 + .15 * sin(t * 60.0)))
			_glow_level(.2 + .8 * c + (.6 if t > .7 and t < .8 else 0.0))
		"burst":
			var k := sm(t, 0, .12) - sm(t, .86, 1)
			o.ry = .5 * k; o.rz = .35 * k
			if mag: mag.position.x += swap(t, .12, .3, .42, .56, .24) + (-.012 * sin((t - .56) / .06 * PI) if t > .56 and t < .62 else 0.0)
			if top: top.position.z += -.06 * (sm(t, .04, .1) - sm(t, .68, .71))
		"chain":
			var k := sm(t, 0, .15) - sm(t, .84, 1)
			o.rx = .85 * k; o.rz = -.2 * k
			if mag: mag.position.y += swap(t, .15, .32, .42, .6, -.36)
			_glow_level(1.0 if t < .15 else (.12 if t < .62 else ((1.7 if randf() < .5 else .25) if t < .84 else 1.0)))
		_:  # pulse and anything new
			var k := sm(t, 0, .14) - sm(t, .86, 1)
			o.rz = .5 * k; o.rx = -.2 * k; o.py = -.03 * k
			if mag:
				mag.position.y += swap(t, .14, .32, .42, .6, -.4)
				mag.rotation.x += swap(t, .14, .32, .42, .6, -.4)
			if top: top.position.z += -.07 * (sm(t, .66, .73) - sm(t, .78, .84))
	return o
