@tool
class_name RoadSegment
extends Node3D
## Straight road segment (local +Z along the road): marked asphalt, kerbs with a violet glow line and
## paved sidewalks either side. Markings are drawn by assets/shaders/road.gdshader.

@export var length := 40.0:
	set(v):
		length = v
		_rebuild()
@export var width := 13.77:
	set(v):
		width = v
		_rebuild()
@export var crosswalk_start := false:
	set(v):
		crosswalk_start = v
		_rebuild()
@export var crosswalk_end := false:
	set(v):
		crosswalk_end = v
		_rebuild()
@export var sidewalks := true:
	set(v):
		sidewalks = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var asphalt: MeshInstance3D = $Asphalt
	(asphalt.mesh as PlaneMesh).size = Vector2(width, length)
	var m := asphalt.material_override as ShaderMaterial
	m.set_shader_parameter("length", length)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("lanes", 4 if width > 13.0 else 2)
	m.set_shader_parameter("crosswalk_start", crosswalk_start)
	m.set_shader_parameter("crosswalk_end", crosswalk_end)
	for side in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var kerb: MeshInstance3D = get_node("Kerb" + tag)
		(kerb.mesh as BoxMesh).size = Vector3(0.24, 0.14, length)
		kerb.position = Vector3(side * (width * 0.5 + 0.12), 0.07, 0)
		var kg: MeshInstance3D = get_node("KerbGlow" + tag)
		(kg.mesh as BoxMesh).size = Vector3(0.06, 0.02, length)
		kg.position = Vector3(side * (width * 0.5 + 0.12), 0.15, 0)
		var walk: MeshInstance3D = get_node("Walk" + tag)
		walk.visible = sidewalks
		(walk.mesh as BoxMesh).size = Vector3(3.5, 0.12, length)
		walk.position = Vector3(side * (width * 0.5 + 1.85), 0.06, 0)
