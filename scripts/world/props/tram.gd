extends PathFollow3D
## Maglev tram shuttling back and forth along its rail.
@export var speed := 0.025   ## fraction of the track per second

var _u := 0.0

func _process(delta: float) -> void:
	_u = fmod(_u + delta * speed, 2.0)
	progress_ratio = clampf(_u if _u < 1.0 else 2.0 - _u, 0.001, 0.999)
