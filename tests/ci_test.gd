extends Node
## Headless CI run (no GPU, no screenshots): boot -> hangar -> deploy -> walk -> kill a spider -> lobby.
## Exits 0 when every check passes, 1 otherwise.
##   godot --headless --path . res://tests/ci_test.tscn

var main: Node
var fails := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _secs(1.0)
	main._boot_t = 8.95
	await _secs(1.0)
	main.open_pop("weapon")
	await _secs(.3)
	main.open_pop("weapon")
	main.deploy()
	await _secs(1.0)
	main._end_cut()
	await _secs(.3)
	var g: V77Game = main.game
	_check(g != null, "game started")
	if g == null:
		_done()
		return
	_check(g.hp > 0, "player alive (hp=%s)" % g.hp)
	_check(g.EN.size() > 0, "spiders spawned (%d)" % g.EN.size())
	_check(g.block_nodes.size() == 103, "crate blocks (%d/103)" % g.block_nodes.size())
	_check(g.doors.size() == 33, "doors (%d/33)" % g.doors.size())
	_check(g.glass.size() == 77, "glass panes (%d/77)" % g.glass.size())
	await _secs(1.0)
	var z0: float = g.P.z
	g.K[KEY_W] = 1
	await _secs(1.5)
	g.K[KEY_W] = 0
	_check(absf(g.P.z - z0) > 2.0 and g.ground, "walk moves the player on the ground (dz=%.2f)" % (g.P.z - z0))
	# put a spider in clear view and shoot it
	var e: Dictionary = g.EN[0]
	var fw := Vector3(-sin(g.yaw), 0, -cos(g.yaw))
	e.m.global_position = Vector3(g.P.x, 1.2, g.P.z) + fw * 9
	var d: Vector3 = e.m.global_position - g.C.global_position
	g.yaw = atan2(-d.x, -d.z)
	g.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await _secs(.1)
	g.F_f = 1
	g.fire_down()
	await _secs(1.5)
	g.F_f = 0
	g.fire_up()
	_check(e.d and g.score > 0, "spider killed (hp=%s score=%s)" % [e.hp, g.score])
	g.P = Vector3(-34.4, 22.2, -95.4)
	g.V = Vector3.ZERO
	await _secs(1.0)
	_check(g.P.y > 20.0, "stands on the sky-bridge lobby floor (y=%.2f)" % g.P.y)
	_done()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _done() -> void:
	print("%d check(s) failed" % fails if fails else "all checks passed")
	get_tree().quit(1 if fails else 0)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
