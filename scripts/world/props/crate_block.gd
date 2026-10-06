class_name CrateBlock
extends StaticBody3D
## One 2 m destructible cargo block. Blocks sit on a 2 m grid; the arena drops unsupported blocks (settle).

const MATS: Array[Material] = [
	preload("res://assets/materials/crate_steel.tres"),
	preload("res://assets/materials/crate_magenta.tres"),
	preload("res://assets/materials/crate_cyan.tres"),
]
const DEBRIS_COLORS := [Color("#3a2a80"), Color("#ff2bd6"), Color("#21e6ff")]

@export_range(0, 2) var variant := 0:
	set(v):
		variant = v
		if is_inside_tree():
			$Mesh.material_override = MATS[variant]


func _ready() -> void:
	add_to_group("blocks")
	$Mesh.material_override = MATS[variant]


func grid() -> Vector3i:
	return Vector3i(floori(position.x / 2.0), floori(position.y / 2.0), floori(position.z / 2.0))


func debris_color() -> Color:
	return DEBRIS_COLORS[variant]
