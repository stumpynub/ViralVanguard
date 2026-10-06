extends Node3D
## Main-menu rooftop: the operative on the turntable (cel-shaded at runtime by ToonStyle), the featured sniper
## turning on its holo pedestal, a flickering work lamp, lightning over the city and something watching
## from the parapet. Drag (or hold the arrow keys) to spin the operative.

signal lightning_struck(strength: float)

## The main character, rigged (tools/rig). Plays its unarmed idle on the turntable.
@export var character_scene: PackedScene = preload("res://scenes/characters/hunter_operative.tscn")
@export var idle_animation := &"idle"

@export var turntable: Node3D
@export var ring: MeshInstance3D
@export var camera: Camera3D
@export var featured: Node3D           ## the hovering showcase weapon
@export var lurker: Node3D             ## the spider on the parapet
@export var lamp: OmniLight3D
@export var lightning_light: DirectionalLight3D
@export var spot: SpotLight3D
@export var idle_sway := 0.25
## Seconds between lightning strikes (random in range).
@export var lightning_every := Vector2(6.0, 14.0)

const EYE := preload("res://assets/materials/glow_red.tres")

var _character: CharacterModel
var _spin := 0.0
var _vel := 0.0
var _dragging := false
var _keys := 0.0
var _focus := 0.0
var _focus_target := 0.0
var _t := 0.0
var _next_strike := 4.0
var _strike := 0.0
var _lamp_energy := 1.8
var _spot_energy := 6.0
var _lurker_base := Vector3.ZERO


func _ready() -> void:
	if featured:
		ToonStyle.apply(featured, {"outline": 0.0007, "outline_max": 0.005, "tint": Color(1.6, 1.6, 1.7), "desaturate": 0.85})
	if lurker:
		ToonStyle.apply(lurker, {"outline": 0.0007, "outline_max": 0.005, "tint": Color("#3a3a40"), "rim_strength": 2.5})
		for m in lurker.find_children("Glow", "MeshInstance3D", true, false):
			m.material_override = EYE      # its glow strips burn red in the dark
		_lurker_base = lurker.position
	if lamp:
		_lamp_energy = lamp.light_energy
	if spot:
		_spot_energy = spot.light_energy


func show_loadout(armor: ArmorData, _weapon: WeaponData, _skill: SkillData) -> void:
	if _character == null:
		_character = character_scene.instantiate()
		turntable.add_child(_character)
		_character.play(idle_animation, 0.0)
		# armour reads as black plate with a blood-red rim; the visor and trims keep their glow
		_character.stylize({"outline": 0.0008, "outline_max": 0.006, "tint": Color(1.45, 1.45, 1.55), "desaturate": 0.92, "rim_strength": 2.2, "bands": 3.0})
	var rm := ring.material_override as StandardMaterial3D
	if rm:
		rm.albedo_color = Color("#ff1a10")
		rm.emission = Color("#ff1a10")


## 0 = centred, 1 = shifted left to make room for the side panel.
func focus(k: float) -> void:
	_focus_target = k


func drag(dx: float) -> void:
	_vel = dx * 0.012
	_spin += _vel
	_dragging = true


func release() -> void:
	_dragging = false


func key_spin(dir: float) -> void:
	_keys = dir


func _process(delta: float) -> void:
	_t += delta
	if _keys != 0.0:
		_vel = _keys * 2.4 * delta
		_spin += _vel
	elif not _dragging:
		_spin += _vel
		_vel *= pow(0.02, delta)
	turntable.rotation.y = _spin + sin(_t * 0.4) * idle_sway * 0.2
	_focus += (_focus_target - _focus) * minf(1.0, delta * 6.0)
	camera.h_offset = 0.55 * _focus
	if featured:
		featured.rotation.y = _t * 0.45
		featured.position.y = 1.25 + sin(_t * 1.3) * 0.03
	# the lurker breathes, shifts its weight, and every so often turns toward you
	if lurker:
		lurker.position = _lurker_base + Vector3(0, sin(_t * 2.1) * 0.01, 0)
		lurker.rotation.y = -2.2 + sin(_t * 0.23) * 0.35 + (0.6 if fmod(_t, 17.0) > 14.5 else 0.0)
	# a dying work lamp
	if lamp:
		var f := 1.0
		if fmod(_t * 0.7, 5.0) > 4.2:
			f = 0.15 if randf() < 0.5 else 1.0
		lamp.light_energy = _lamp_energy * f
	# lightning: a double flash, then the thunder of a pause
	_next_strike -= delta
	if _next_strike <= 0.0:
		_next_strike = randf_range(lightning_every.x, lightning_every.y)
		_strike = 1.0
	if _strike > 0.0:
		_strike = maxf(0.0, _strike - delta * 2.2)
		var k := _strike * (0.55 + 0.45 * sin(_strike * 40.0)) if _strike > 0.4 else _strike * 0.6
		lightning_light.light_energy = k * 3.5
		if spot:
			spot.light_energy = _spot_energy * (1.0 - k * 0.5)
		lightning_struck.emit(k)
