extends RigidBody3D
## A spent brass case: spins out of the port, clinks on whatever it hits, then fades away.
var _t := 0.0
var _clinks := 0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(func(_b):
		if _clinks < 3:
			Sfx.play_at("casing", global_position, 0.5 - _clinks * 0.12, randf_range(0.9, 1.15))
			_clinks += 1)

func _process(delta: float) -> void:
	_t += delta
	if _t > 6.0:
		queue_free()
