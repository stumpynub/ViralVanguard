@tool
extends Node3D
## Parked civilian spacecraft. `light_tint` swaps the stock amber running lights for custom LEDs.

const TINTS := {"orange": Color("#ff6a10"), "blue": Color("#2a7dff"), "pink": Color("#ff3cb4")}
static var _mats := {}

@export_enum("stock", "orange", "blue", "pink") var light_tint := "stock":
	set(v):
		light_tint = v
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	for part in ["HullMain", "Hull"]:
		var m := find_child(part, true, false) as MeshInstance3D
		if m:
			m.material_override = _cached(part, m, func(sm: StandardMaterial3D):
				sm.metallic = 0.55                 # no env reflections to sell full metal at night
				sm.roughness = 0.42)
	var lights := find_child("Lights", true, false) as MeshInstance3D
	if lights:
		if not TINTS.has(light_tint):
			lights.material_override = null
		else:
			var c: Color = TINTS[light_tint]
			lights.material_override = _cached("L_" + light_tint, lights, func(sm: StandardMaterial3D):
				sm.emission = c
				sm.emission_energy_multiplier = 3.0
				sm.albedo_color = c)


func _cached(key: String, m: MeshInstance3D, edit: Callable) -> Material:
	if not _mats.has(key):
		var src := m.mesh.surface_get_material(0) as StandardMaterial3D
		if src == null:
			return null
		var sm: StandardMaterial3D = src.duplicate()
		edit.call(sm)
		_mats[key] = sm
	return _mats[key]
