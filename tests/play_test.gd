extends Node
## Automated run: boot -> hangar shot -> deploy -> skip cinematic -> walk, look, fire -> gameplay shots -> report.
##   godot --path . res://tests/play_test.tscn

var main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/shots"))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _secs(1.0)
	await _shot("boot")
	main._boot_t = 8.95
	await _secs(2.5)
	await _shot("hangar")
	main.open_pop("weapon")
	await _secs(.5)
	await _shot("hangar_pop")
	main.open_pop("weapon")
	main.deploy()
	await _secs(1.2)
	await _shot("cut")
	main._end_cut()
	await _secs(.3)
	var g: V77Game = main.game
	print("deployed: P=", g.P, " hp=", g.hp, " enemies=", g.EN.size(), " blocks=", g.block_nodes.size(), " doors=", g.doors.size(), " glass=", g.glass.size())
	await _secs(2.0)
	await _shot("play_start")
	g.K[KEY_W] = 1
	await _secs(1.5)
	g.K[KEY_W] = 0
	print("after walk: P=", g.P, " ground=", g.ground)
	g.yaw += PI
	g.F_f = 1
	g.fire_down()
	await _secs(.6)
	await _shot("play_fire")
	g.F_f = 0
	g.fire_up()
	# face the nearest spider and shoot it
	var e = g.EN[0] if g.EN.size() else null
	if e:
		# put it in clear view on the street ahead so the shot is not blocked by buildings
		var fw := Vector3(-sin(g.yaw), 0, -cos(g.yaw))
		e.m.global_position = Vector3(g.P.x, 1.2, g.P.z) + fw * 9
		var d: Vector3 = e.m.global_position - g.C.global_position
		g.yaw = atan2(-d.x, -d.z)
		g.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		await _secs(.1)
		var dd: Vector3 = (e.m.global_position - g.C.global_position)
		var hs := g.ray_hits(g.C.global_position, dd.normalized(), 200.0)
		print("ray to spider dist=", dd.length(), " hit=", (hs[0].collider.name + " meta=" + str(hs[0].collider.get_meta_list()) + " at " + str(hs[0].distance)) if hs.size() else "none", " ammo=", g.ammo, " fov=", g.C.fov)
		var r = g.aim(0, 0)
		print("aim dir=", r[1], " want=", dd.normalized())
		g.F_f = 1
		g.fire_down()
		await _secs(1.5)
		g.F_f = 0
		g.fire_up()
		print("shot at spider: hp left=", e.hp, " score=", g.score, " dead=", e.d)
	await _shot("play_aim")
	g.P = Vector3(-34.4, 22.2, -95.4)      # Market Link lobby
	g.V = Vector3.ZERO
	g.yaw = PI / 2
	await _secs(1.0)
	await _shot("play_lobby")
	print("lobby: P=", g.P)
	get_tree().quit()


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/shots/%s.png" % n)
