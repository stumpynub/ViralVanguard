extends GeometryInstance3D
## Blinks an emissive material on and off (beacons, barrier strobes, aircraft warning lights).
@export var rate := 3.0
@export var duty := 0.2       ## sin threshold: higher = shorter on time
@export var phase := 0.0

func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	visible = sin(t * rate + phase) > duty
