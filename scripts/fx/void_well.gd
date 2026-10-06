extends Node3D
## Event Horizon gravity well: drags infected within 9 m toward its core, grinds anything within 2.6 m,
## then collapses for a final 45 damage blast.

@export var pull_radius := 9.0
@export var pull_speed := 7.0
@export var crush_radius := 2.6
@export var crush_dps := 38.0
@export var collapse_radius := 3.5
@export var collapse_damage := 45.0

var _t := 1.8
var _color := Color("#e14dff")


var owner_peer := 0


func setup(life: float, color: Color, owner_id := 0) -> void:
	owner_peer = owner_id
	_t = life
	_color = color
	var m: StandardMaterial3D = $Ring.material_override.duplicate()
	m.albedo_color = Color(color, 0.85)
	m.emission = color
	$Ring.material_override = m


func _physics_process(delta: float) -> void:
	var a := Arena.current
	if a == null:
		return
	_t -= delta
	$Ring.rotate_object_local(Vector3.UP, delta * 4.0)
	scale = Vector3.ONE * (0.8 + 0.2 * sin(Time.get_ticks_msec() / 60.0))
	if not a.is_host():          # clients only show it; the host moves and damages the infected
		if _t <= -0.5:
			queue_free()
		return
	for e in a.enemies_near(global_position, pull_radius):
		var d := Vector3(global_position.x - e.global_position.x, 0, global_position.z - e.global_position.z)
		var dist := d.length()
		if dist > 0.01:
			e.global_position += d / dist * minf(dist, pull_speed * delta)
		if dist < crush_radius:
			a._apply_damage(e.net_id, crush_dps * delta, "VOID WELL", 0.0, 0.0, owner_peer)
	if _t <= 0.0:
		a.burst(global_position, 24, _color)
		a.shake = maxf(a.shake, 0.2)
		a._apply_area(global_position, collapse_radius, collapse_damage, "VOID WELL", false, 0.0, owner_peer)
		queue_free()
