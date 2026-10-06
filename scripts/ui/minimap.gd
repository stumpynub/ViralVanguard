extends Control
## Rotating radar (port of the original canvas minimap): harbor water, building footprints, the plaza ring,
## cargo blocks and infected relative to the player. M toggles the big tactical view.

@export var small_scale := 2.6
@export var big_scale := 0.92
@export var water_color := Color("#0a0a10")
@export var building_color := Color("#1c1c22")
@export var road_color := Color("#141418")
@export var lift_color := Color("#e6e2da")
@export var block_color := Color("#3a3a42")
@export var enemy_color := Color("#ff2a3d")
@export var player_color := Color("#e6e2da")

var big := false
var _footprints: Array[Rect2] = []
var _roads: Array[PackedVector2Array] = []    ## world-space road outlines
var _lifts: PackedVector2Array = []


func cache_city(arena: Arena) -> void:
	_footprints.clear()
	for b in arena.find_children("*", "Building", true, false):
		if b.solid:
			var s: Vector3 = b.size
			var p: Vector3 = b.global_position
			_footprints.append(Rect2(p.x - s.x * 0.5, p.z - s.z * 0.5, s.x, s.z))
	_roads.clear()
	for r in arena.find_children("*", "RoadSegment", true, false):
		var t: Transform3D = r.global_transform
		var poly := PackedVector2Array()
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var w := t * Vector3(c.x * r.width * 0.5, 0, c.y * r.length * 0.5)
			poly.append(Vector2(w.x, w.z))
		_roads.append(poly)
	_lifts.clear()
	for l in arena.get_tree().get_nodes_in_group("lifts"):
		_lifts.append(Vector2(l.global_position.x, l.global_position.z))
	for l in arena.get_tree().get_nodes_in_group("pads"):
		_lifts.append(Vector2(l.global_position.x, l.global_position.z))


func toggle_big() -> void:
	big = not big
	var vp := get_viewport_rect().size
	if big:
		var s := minf(vp.y * 0.78, vp.x * 0.6)
		size = Vector2(s, s)
		position = (vp - size) * 0.5
	else:
		size = Vector2(160, 160)
		position = Vector2(20, 24)
	queue_redraw()


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var a := Arena.current
	if a == null or a.player == null:
		return
	var n := size.x
	var h := n * 0.5
	var q := (big_scale if big else small_scale) * n / 320.0
	var P := a.player.global_position
	var cy := cos(a.player.yaw)
	var sy := sin(a.player.yaw)
	var pt := func(x: float, z: float) -> Vector2:
		return Vector2(h + ((x - P.x) * cy - (z - P.z) * sy) * q, h + ((x - P.x) * sy + (z - P.z) * cy) * q)
	var bg := Color("#050506e6") if big else Color("#05050699")
	if big:
		draw_rect(Rect2(Vector2.ZERO, size), bg)
	else:
		draw_circle(Vector2(h, h), h, bg)
	var clip := func(poly: PackedVector2Array) -> PackedVector2Array:
		if big:
			return poly
		var circle := PackedVector2Array()
		for i in 32:
			circle.append(Vector2(h, h) + Vector2.from_angle(i / 32.0 * TAU) * (h - 2))
		var r := Geometry2D.intersect_polygons(poly, circle)
		return r[0] if r.size() > 0 else PackedVector2Array()
	var fill := func(world: PackedVector2Array, col: Color) -> void:
		var sp := PackedVector2Array()
		for v in world:
			sp.append(pt.call(v.x, v.y))
		var poly: PackedVector2Array = clip.call(sp)
		if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
			draw_colored_polygon(poly, col)
	var quad := func(x0: float, x1: float, z0: float, z1: float, col: Color) -> void:
		fill.call(PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]), col)
	var wb := a.bounds
	quad.call(wb.end.x, 600, -600, 600, water_color)
	quad.call(-600, wb.position.x, -600, 600, water_color)
	quad.call(wb.position.x, wb.end.x, -600, wb.position.y, water_color)
	quad.call(wb.position.x, wb.end.x, wb.end.y, 600, water_color)
	for r in _roads:
		fill.call(r, road_color)
	for r in _footprints:
		quad.call(r.position.x, r.end.x, r.position.y, r.end.y, building_color)
	var c: Vector2 = pt.call(0.0, 0.0)
	if big or c.distance_to(Vector2(h, h)) < h:
		draw_arc(c, 12.5 * q, 0, TAU, 48, Color("#c8101a"), 2.0)
	for l in _lifts:
		var lp: Vector2 = pt.call(l.x, l.y)
		if big or lp.distance_to(Vector2(h, h)) < h - 4:
			draw_circle(lp, maxf(2.0, q * 1.3), lift_color)
	var bs := q * 2.0
	for b in get_tree().get_nodes_in_group("blocks"):
		if b.position.y < 2.0:
			var p: Vector2 = pt.call(b.global_position.x, b.global_position.z)
			if big or p.distance_to(Vector2(h, h)) < h - bs:
				draw_rect(Rect2(p - Vector2(bs, bs) * 0.5, Vector2(bs, bs)), block_color)
	for id in a.players:
		var tm: Player = a.players[id]
		if tm == a.player or not is_instance_valid(tm):
			continue
		var tp: Vector2 = pt.call(tm.global_position.x, tm.global_position.z)
		if big or tp.distance_to(Vector2(h, h)) < h - 6:
			draw_circle(tp, 5.0, Color("#d9d6d0") if not tm.is_dead() else Color("#555566"))
	for e in a.enemies:
		var p: Vector2 = pt.call(e.global_position.x, e.global_position.z)
		if big or p.distance_to(Vector2(h, h)) < h - 6:
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color.WHITE if e.stun > 0.0 else enemy_color)
	draw_colored_polygon(PackedVector2Array([Vector2(h, h - 14), Vector2(h + 9, h + 9), Vector2(h - 9, h + 9)]), player_color)
	if big:
		draw_rect(Rect2(Vector2.ZERO, size), player_color, false, 1.0)
	else:
		draw_arc(Vector2(h, h), h - 1, 0, TAU, 64, player_color, 1.0)
