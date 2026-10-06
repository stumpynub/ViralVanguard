@tool
extends Node3D
## Rotates continuously (spire halo rings, radar dishes). Runs in the editor too.
@export var axis := Vector3.UP
@export var speed := 0.35

func _process(delta: float) -> void:
	rotate_object_local(axis.normalized(), speed * delta)
