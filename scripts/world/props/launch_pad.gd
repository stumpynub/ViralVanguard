@tool
class_name LaunchPad
extends Node3D
## Launch pad: stepping on it throws you along a ballistic arc (gravity 26, apex 10 m above the target)
## onto an elevated route. Set `target` (world position) in the inspector; the launch velocity follows.

const GRAVITY := 26.0
const APEX := 10.0
const RADIUS_SQ := 3.2

@export var target := Vector3(0, 12, 0)


func _ready() -> void:
	add_to_group("pads")


func launch_velocity() -> Vector3:
	var p := global_position
	var vy := sqrt(2.0 * GRAVITY * (target.y - p.y + APEX))
	var tf := vy / GRAVITY + sqrt(2.0 * APEX / GRAVITY)
	return Vector3((target.x - p.x) / tf, vy, (target.z - p.z) / tf)


## True when a body standing at `p` (feet) is on the pad.
func touching(p: Vector3) -> bool:
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	return d.length_squared() < RADIUS_SQ and p.y < global_position.y + 0.8
