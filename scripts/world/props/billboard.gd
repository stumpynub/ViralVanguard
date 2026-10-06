@tool
class_name Billboard
extends Node3D
## Holographic advert: animated screen, frame, brand title and slogan.

@export var title := "VOLT COLA":
	set(v):
		title = v
		_rebuild()
@export var slogan := "CHARGE UP":
	set(v):
		slogan = v
		_rebuild()
@export var color_a := Color("#ff2bd6"):
	set(v):
		color_a = v
		_rebuild()
@export var color_b := Color("#ff9a3c"):
	set(v):
		color_b = v
		_rebuild()
@export var size := Vector2(14, 14):
	set(v):
		size = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var screen: MeshInstance3D = $Screen
	(screen.mesh as QuadMesh).size = size
	var m := screen.material_override as ShaderMaterial
	if m:
		m.set_shader_parameter("color_a", color_a)
		m.set_shader_parameter("color_b", color_b)
	var frame: MeshInstance3D = $Frame
	(frame.mesh as BoxMesh).size = Vector3(size.x + 0.8, size.y + 0.8, 0.3)
	frame.position = Vector3(0, 0, -0.2)
	var t: Label3D = $Title
	t.text = title
	t.pixel_size = size.x / 900.0
	t.position = Vector3(-size.x * 0.44, -size.y * 0.22, 0.06)
	t.outline_modulate = color_a
	var s: Label3D = $Slogan
	s.text = slogan
	s.pixel_size = size.x / 1600.0
	s.position = Vector3(-size.x * 0.44, -size.y * 0.36, 0.06)
	s.modulate = Color(color_a.r * 2.0, color_a.g * 2.0, color_a.b * 2.0)
