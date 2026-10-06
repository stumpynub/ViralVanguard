@tool
class_name NeonSign
extends Node3D
## Glowing shop / street sign: dark backing panel, coloured rim and HDR text that blooms.

@export var text := "NOODLES":
	set(v):
		text = v
		_rebuild()
@export var color := Color("#ff2bd6"):
	set(v):
		color = v
		_rebuild()
@export var size := Vector2(3.0, 0.75):
	set(v):
		size = v
		_rebuild()
## Stack the letters top to bottom (blade signs).
@export var vertical := false:
	set(v):
		vertical = v
		_rebuild()
@export var brightness := 2.6:
	set(v):
		brightness = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var back: MeshInstance3D = $Backing
	(back.mesh as BoxMesh).size = Vector3(size.x, size.y, 0.08)
	var rim: MeshInstance3D = $Rim
	(rim.mesh as BoxMesh).size = Vector3(size.x + 0.08, size.y + 0.08, 0.04)
	var rm := rim.material_override as StandardMaterial3D
	if rm:
		rm.albedo_color = color
		rm.emission = color
	var label: Label3D = $Label
	label.text = "\n".join(text.split("")) if vertical else text
	label.modulate = Color(color.r * brightness, color.g * brightness, color.b * brightness)
	label.outline_modulate = Color(color.r, color.g, color.b, 0.6)
	var chars := maxi(1, text.length())
	var px := 0.0
	if vertical:
		px = minf(size.x * 0.62, size.y / chars * 0.86)
	else:
		px = minf(size.y * 0.55, size.x / chars * 1.4)
	label.font_size = 64
	label.pixel_size = px / 64.0
	label.position = Vector3(0, 0, 0.05)
