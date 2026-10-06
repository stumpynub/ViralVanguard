extends Node3D
## Fires every GPUParticles3D child once, fades an optional flash light, tints anything in the "tint" group
## with the colour passed to set_color(), then frees itself.

@export var lifetime := 2.0
@export var light: OmniLight3D
@export var light_fade := 0.25

var _t := 0.0
var _light_energy := 0.0


func _ready() -> void:
	for p in find_children("*", "GPUParticles3D", true, false):
		p.restart()
		p.emitting = true
	if light:
		_light_energy = light.light_energy


func set_color(c: Color) -> void:
	for n in find_children("*", "", true, false):
		if not n.is_in_group("tint"):
			continue
		if n is GPUParticles3D and n.process_material is ParticleProcessMaterial:
			var m: ParticleProcessMaterial = n.process_material.duplicate()
			m.color = c
			n.process_material = m
		elif n is OmniLight3D:
			n.light_color = c
		elif n is GeometryInstance3D and n.material_override is StandardMaterial3D:
			var sm: StandardMaterial3D = n.material_override.duplicate()
			sm.albedo_color = Color(c, sm.albedo_color.a)
			sm.emission = c
			n.material_override = sm


func _process(delta: float) -> void:
	_t += delta
	if light:
		light.light_energy = _light_energy * maxf(0.0, 1.0 - _t / light_fade)
	if _t >= lifetime:
		queue_free()
