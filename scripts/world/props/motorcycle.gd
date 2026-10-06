@tool
extends Node3D
## Parked motorcycle: black or red clearcoat paint.

const BLACK := preload("res://assets/materials/moto_black.tres")
const RED := preload("res://assets/materials/moto_red.tres")

@export var red := false:
	set(v):
		red = v
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	var paint := find_child("paint", true, false) as MeshInstance3D
	if paint:
		paint.material_override = RED if red else BLACK
