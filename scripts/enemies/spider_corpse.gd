class_name SpiderCorpse
extends Node3D
## A killed swarmer (v74 death): the final hit knocks it back, it rears and topples onto its back or side under
## gravity, bounces once, the legs draw in to a death curl with fading twitches, and after a couple of seconds it
## disintegrates into ash. Purely visual and local to each peer.

const MAX_CORPSES := 14
const ASH := preload("res://scenes/fx/ash.tscn")
static var _all: Array[SpiderCorpse] = []

var _model: Node3D
var _legs: Array[Node3D] = []
var _axes: Array[Vector3] = []
var _rest: Array[Basis] = []
var _t := 0.0
var _a := 0.0          ## topple angle about the hip line
var _w := 0.0
var _end := 2.0
var _roll := 0.0
var _bounced := 0
var _vel := Vector3.ZERO
var _ground := 0.0
var _tw := randf() * 9.0
var _ashed := false


## Takes over the spider's model. `away` points from the killer to the spider.
static func from_spider(e: Spider, away: Vector3, parent: Node) -> SpiderCorpse:
	var c := SpiderCorpse.new()
	parent.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, e.global_rotation.y), e.global_position)
	away.y = 0.0
	if away.length_squared() < 1e-4:
		away = Vector3.BACK
	away = away.normalized()
	var fwd := e.global_basis.z
	var shot_from_front := fwd.dot(away) < 0.2
	# shot from the front -> topples backwards; from behind -> pitches forward
	c._end = -(2.55 + randf() * 0.5) if shot_from_front else (1.9 + randf() * 0.4)
	c._roll = (randf() - 0.5) * 1.1
	c._vel = Vector3(away.x * 3.2, 1.4, away.z * 3.2)
	var hit := e.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(e.global_position + Vector3.UP, e.global_position + Vector3.DOWN * 4.0, 1))
	c._ground = hit.position.y if hit else e.global_position.y
	c._model = e.model
	c._model.reparent(c, true)
	c._legs = e.legs()
	c._axes = e.leg_axes()
	for l in c._legs:
		c._rest.append(l.basis)
	for m in c._model.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).material_overlay = null
	_all.append(c)
	if _all.size() > MAX_CORPSES:
		var old: SpiderCorpse = _all.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return c


func _exit_tree() -> void:
	_all.erase(self)


func _process(delta: float) -> void:
	_t += delta
	var t := _t
	# topple about the hip line: gravity torque grows as it tips past balance; one damped bounce on landing
	if t < 1.6:
		var acc := 5.0 + 21.0 * sin(minf(PI * 0.5, absf(_a) + 0.25))
		_w += acc * delta
		_a += signf(_end) * _w * delta * (2.2 if t < 0.12 else 1.0)
		if absf(_a) >= absf(_end):
			_a = _end
			if _bounced < 2 and _w > 1.2:
				_w = -_w * 0.28
				_bounced += 1
			else:
				_w = 0.0
	# knock-back slide + hop
	_vel.x *= maxf(0.0, 1.0 - delta * 3.0)
	_vel.z *= maxf(0.0, 1.0 - delta * 3.0)
	_vel.y -= 26.0 * delta
	position += _vel * delta
	var off := absf(sin(_a)) * 0.45
	if position.y - off <= _ground:
		position.y = _ground + off
		_vel.y = -_vel.y * 0.18 if _vel.y < -4.0 else 0.0
	var k := clampf(absf(_a) / maxf(0.01, absf(_end)), 0.0, 1.0)
	_model.transform.basis = Basis(Vector3.RIGHT, _a) * Basis(Vector3.BACK, _roll * k) * Basis.from_scale(_model.transform.basis.get_scale())
	# legs: flail on the hit, then draw in to the death curl; small decaying nerve twitches
	var cu := clampf((t - 0.15) / 0.9, 0.0, 1.0)
	var ce := cu * cu * (3.0 - 2.0 * cu)
	for i in _legs.size():
		var tw := exp(-t * 1.6) * sin(t * (23.0 + i * 3.0) + _tw + i) * 0.22 * (1.0 if t > 0.5 else 0.0)
		var fl := sin(t * 30.0 + i * 1.7) * 0.35 * (1.0 - t / 0.3) if t < 0.3 else 0.0
		var curl := Basis(Vector3.UP, (1.0 if i % 2 else -1.0) * 0.35 * ce) * Basis(_axes[i], 1.15 * ce + fl + tw)
		_legs[i].basis = _rest[i].slerp(curl * _rest[i], minf(1.0, ce + 0.15))
	if t > 2.0 and not _ashed:
		_ashed = true
		var fx: Node3D = ASH.instantiate()
		get_parent().add_child(fx)
		fx.global_position = global_position + Vector3(0, 0.4, 0)
	if _ashed:
		var s := maxf(0.0, 1.0 - (t - 2.0) / 0.6)
		scale = Vector3(1, maxf(0.05, s), 1)
		if s <= 0.0:
			queue_free()
