@tool
class_name GravityLift
extends Node3D
## Gravity lift: stand in the cyan beam to be carried up to `top` (highways, bridges, the Spire deck).
## Players query `lift_velocity()`; anything in the "lifts" group is checked.

const RADIUS_SQ := 1.9

@export var top := 20.0:
	set(v):
		top = v
		_rebuild()


const GLOW_DIM := 0.45      ## the kit's glow strips are dense; at full energy they bloom into a white blob


func _ready() -> void:
	add_to_group("lifts")
	_rebuild()
	if not Engine.is_editor_hint():
		for m in find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi == $Beam or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i) as ShaderMaterial
				if mat and mat.shader and mat.shader.resource_path.ends_with("kit_glow.gdshader"):
					var dim: ShaderMaterial = mat.duplicate()
					var e = mat.get_shader_parameter("energy")
					dim.set_shader_parameter("energy", (2.6 if e == null else float(e)) * GLOW_DIM)
					mi.set_surface_override_material(i, dim)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var beam: MeshInstance3D = $Beam
	var c := beam.mesh as CylinderMesh
	c.height = top
	beam.position.y = top * 0.5
	(beam.material_override as ShaderMaterial).set_shader_parameter("height", top)


## Upward speed for a body at `p` (feet), or -1 when it isn't in the beam.
func lift_velocity(p: Vector3) -> float:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	if d.length_squared() < RADIUS_SQ and p.y < global_position.y + top + 0.2 and p.y > global_position.y - 0.5:
		return minf(9.0, (global_position.y + top - p.y) * 4.0 + 1.5)
	return -1.0
