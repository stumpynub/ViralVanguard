extends Node3D
## Bullet tracer: a hot head racing from the muzzle to the hit point, and a faint trail that fades behind it.

const SPEED := 320.0

@export var head: MeshInstance3D
@export var trail: MeshInstance3D

var _a: Vector3
var _dir: Vector3
var _len := 0.0
var _t := 0.0
var _life := 0.0
var _hm: StandardMaterial3D
var _tm: StandardMaterial3D


func setup(a: Vector3, b: Vector3, color: Color, life := 0.0) -> void:
	_a = a
	_len = a.distance_to(b)
	_dir = (b - a).normalized() if _len > 0.001 else Vector3.FORWARD
	_life = life
	_hm = head.material_override.duplicate()
	_hm.albedo_color = Color(1, 0.9, 0.7).lerp(color, 0.55)
	head.material_override = _hm
	_tm = trail.material_override.duplicate()
	_tm.albedo_color = color
	trail.material_override = _tm
	var up := Vector3.UP if absf(_dir.y) < 0.99 else Vector3.RIGHT
	global_basis = Basis.looking_at(_dir, up)
	_update()


func _process(delta: float) -> void:
	_t += delta
	_update()
	if _t > maxf(_life, _len / SPEED + 0.15):
		queue_free()


func _update() -> void:
	var hd := minf(_len, _t * SPEED) if _life <= 0.0 else _len
	var hl := minf(3.2, _len * 0.4)
	var tl := maxf(0.0, hd - hl)
	head.position = Vector3(0, 0, -(hd + tl) * 0.5)
	head.scale = Vector3(1, 1, maxf(0.01, hd - tl))
	_hm.albedo_color.a = 1.0 if hd < _len else maxf(0.0, 1.0 - (_t - _len / SPEED) * 25.0)
	if _life > 0.0:
		_hm.albedo_color.a = 1.0 - _t / _life
	trail.position = Vector3(0, 0, -hd * 0.5)
	trail.scale = Vector3(1, 1, maxf(0.01, hd))
	_tm.albedo_color.a = maxf(0.0, 0.35 - _t * 2.6) if _life <= 0.0 else 0.6 * (1.0 - _t / _life)
