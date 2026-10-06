class_name V77Hud
extends CanvasLayer
## The in-match HUD, laid out from v77's desktop CSS: wave / score / health bar top centre, rotating minimap top left,
## kill feed, crosshair, round ability buttons with key badges (streaks, stun, blast, 180, skill with its cooldown
## ring), the weapon card bottom centre, the controls hint, damage / shield / chrono / heal screen tints and the scope.

var game  # V77Game
var draw: Control
var font: Font
var font_b: Font
var map_big := false
var mm_q := 2.6

const INK := Color("#f4f0ff")
const DIM := Color("#a99bd6")
const MAG := Color("#ff2bd6")
const CYA := Color("#21e6ff")
const RED := Color("#ff2a3d")
const OK := Color("#3dff9a")
const BG := Color("#0a0620")


func _ready() -> void:
	layer = 5
	font = _sysfont(["Orbitron", "Chakra Petch", "Bahnschrift", "Segoe UI", "Arial"], 700)
	font_b = _sysfont(["Orbitron", "Bahnschrift", "Segoe UI", "Arial"], 900)
	draw = Control.new()
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_hud)
	add_child(draw)


static func _sysfont(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


func reset() -> void:
	map_big = false


func toggle_map() -> void:
	map_big = not map_big


func update_hud(dt: float) -> void:
	for f in game.feed_lines:
		f.t -= dt
	game.feed_lines = game.feed_lines.filter(func(f): return f.t > 0)
	draw.queue_redraw()


# ---------------------------------------------------------------- drawing
func _txt(pos: Vector2, s: String, size: int, c: Color, align := HORIZONTAL_ALIGNMENT_LEFT, f: Font = null, width := -1.0) -> void:
	var fo := f if f else font
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		var w := fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= w / 2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= fo.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw.draw_string(fo, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, c)


func _glow_txt(pos: Vector2, s: String, size: int, c: Color, glow: Color, align := HORIZONTAL_ALIGNMENT_LEFT, f: Font = null) -> void:
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		_txt(pos + o, s, size, Color(glow, .35), align, f)
	_txt(pos, s, size, c, align, f)


func _draw_hud() -> void:
	var g = game
	if g == null or not g.visible:
		return
	var vp := draw.size
	var u := minf(1.0, minf(vp.y * .002564, vp.x * .001185))
	# screen tints (v77 #dmg #shd #chr #heal)
	var dmg_a: float = maxf(g.dmgA, .35 if g.hp < g.maxHP * .35 else 0.0)
	if dmg_a > .01:
		_vignette(vp, Color(RED, .8 * dmg_a), .4)
	if g.shieldT > 0:
		_vignette(vp, Color(.13, .9, 1, .53), .55)
		draw.draw_rect(Rect2(Vector2.ZERO, vp), Color(.13, .9, 1, .67), false, 3)
	if g.slowT > 0:
		_vignette(vp, Color(.7, .42, 1, .47), .45)
	if g.healA > .01:
		_vignette(vp, Color(.24, 1, .6, .53 * g.healA), .45)
	if g.scope_k > .02:
		_scope(vp, g.scope_k)
	if not g.go:
		return
	# crosshair
	var cx := vp / 2
	var ca: float = .8 * (1 - g.ads) + .1
	draw.draw_arc(cx, 11, 0, TAU, 40, Color(CYA, ca), 2, true)
	draw.draw_rect(Rect2(cx - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, ca))
	# top: wave / score / hp
	var ty := 8.0 + 18
	var wtxt := "WAVE "
	var stxt := "   SCORE "
	var f11 := 11
	var w1 := font.get_string_size(wtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, f11).x
	var w2 := font_b.get_string_size(str(g.wave), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var w3 := font.get_string_size(stxt, HORIZONTAL_ALIGNMENT_LEFT, -1, f11).x
	var w4 := font_b.get_string_size(str(g.score), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var x0 := vp.x / 2 - (w1 + w2 + w3 + w4) / 2
	_glow_txt(Vector2(x0, ty), wtxt, f11, INK, MAG)
	_glow_txt(Vector2(x0 + w1, ty), str(g.wave), 18, CYA, MAG, HORIZONTAL_ALIGNMENT_LEFT, font_b)
	_glow_txt(Vector2(x0 + w1 + w2, ty), stxt, f11, INK, MAG)
	_glow_txt(Vector2(x0 + w1 + w2 + w3, ty), str(g.score), 18, CYA, MAG, HORIZONTAL_ALIGNMENT_LEFT, font_b)
	var bw := minf(240, vp.x * .34)
	var br := Rect2(vp.x / 2 - bw / 2, ty + 9, bw, 9)
	draw.draw_rect(br, Color(1, 1, 1, .12))
	var fr := br
	fr.size.x *= clampf(g.hp / g.maxHP, 0, 1)
	_hgrad(fr, MAG, CYA)
	draw.draw_rect(br, MAG, false, 1)
	_txt(Vector2(vp.x / 2, br.end.y + 15), "%d / %d" % [ceili(g.hp), int(g.maxHP)], 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	# kill feed
	var fy := 8.0 + 70 + 12
	for f in g.feed_lines:
		var s: String = f.text.replace("[b]", "").replace("[/b]", "").replace("[i]", "").replace("[/i]", "")
		var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 18
		draw.draw_rect(Rect2(vp.x / 2 - sw / 2, fy - 11, sw, 15), Color(BG, .7))
		draw.draw_rect(Rect2(vp.x / 2 - sw / 2, fy - 11, 2, 15), RED)
		_txt(Vector2(vp.x / 2, fy), s, 10, INK, HORIZONTAL_ALIGNMENT_CENTER)
		fy += 17
	_minimap(vp)
	# ability buttons (desktop set): streaks, stun, blast, 180, skill
	for i in 3:
		var s2: Dictionary = V77Data.STREAKS[i]
		var used: bool = g.SK.used[i]
		var rdy: bool = not used and g.SK.k >= s2.c
		var c3: Color = [CYA, RED, OK][i]
		var lb: String = "USED" if used else (s2.n if rdy else "%d/%d" % [mini(g.SK.k, s2.c), s2.c])
		_button(Vector2(vp.x * [.77, .84, .91][i], vp.y * .15), 56 * u, c3, lb, str(4 + i), rdy, 1.0)
	_button(Vector2(vp.x * .86, vp.y * .36), 60 * u, Color.WHITE, "STUN", "G", false, 1.0 if g.tacN >= 1 else .45, str(g.tacN))
	_button(Vector2(vp.x * .94, vp.y * .32), 60 * u, MAG, ("%ds" % ceili(g.bcd)) if g.bcd > 0 else "BLAST", "E", false, .45 if g.bcd > 0 else 1.0)
	_button(Vector2(vp.x * .63, vp.y * .60), 58 * u, CYA, "180", "V", g.TURN.t >= 0, 1.0)
	var cdr: float = 1 - float(g.Ar.get("cdr", 0.0))
	var p: float = (1 - g.scd / (float(g.Sk.cd) * cdr)) if g.scd > 0 else 1.0
	_button(Vector2(vp.x * .66, vp.y * .80), 80 * u, OK, ("%ds" % ceili(g.scd)) if g.scd > 0 else g.Sk.short, "Q", g.scd <= 0, 1.0, "", p)
	# weapon card (v77 #wsw)
	var cw := 180 * u
	var ch := 48 * u
	var cr := Rect2(vp.x / 2 - cw / 2, vp.y - 64 - ch / 2, cw, ch)
	_round_rect(cr, 10, Color(BG, .7), Color(1, 1, 1, .27))
	var nm: String = g.Wp.name.to_upper()
	if nm.length() > 16:
		nm = nm.substr(0, 15) + "..."
	_txt(cr.position + Vector2(10, 16 * u), nm, int(9 * u + 1), DIM)
	_glow_txt(cr.position + Vector2(10, 38 * u), "--" if g.rel > 0 else "%d/%d" % [g.ammo, g.Wp.mag], int(22 * u), INK, CYA, HORIZONTAL_ALIGNMENT_LEFT, font_b)
	_txt(Vector2(cr.end.x - 10, cr.position.y + 18 * u), "SWAP", int(8 * u + 1), CYA, HORIZONTAL_ALIGNMENT_RIGHT)
	var other: Dictionary = g.slots[g.cur ^ 1]
	_txt(Vector2(cr.end.x - 10, cr.position.y + 32 * u), V77Data.SHORT.get(other.id, other.name), int(9 * u + 1), INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_key(Vector2(cr.end.x + 2, cr.end.y + 2), "X")
	# jet fuel (Warden / Ascendant frames)
	if g.jet_ok():
		var jr := Rect2(vp.x / 2 - 60, br.end.y + 22, 120, 4)
		draw.draw_rect(jr, Color(1, 1, 1, .12))
		var jf := jr
		jf.size.x *= g.JET.fuel
		draw.draw_rect(jf, RED if g.JET.fuel < .25 else CYA)
		_txt(Vector2(jr.position.x - 6, jr.end.y + 2), "JET", 9, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	# controls hint
	_txt(Vector2(vp.x / 2, vp.y - 10), "WASD move · Mouse aim · LMB fire · RMB aim · Shift sprint · Space jump · C crouch (hold: prone) · R reload · X swap · E lethal · G stun · Q skill · 4/5/6 streaks · V 180 · M map · P pause", 10, Color(DIM, .7), HORIZONTAL_ALIGNMENT_CENTER)


func _button(c: Vector2, s: float, bc: Color, label: String, k: String, on: bool, op: float, cnt := "", prog := -1.0) -> void:
	var r := s / 2
	draw.draw_circle(c, r, Color(BG, .7 * op))
	if prog >= 0:
		draw.draw_arc(c, r - 1, -PI / 2, -PI / 2 + TAU, 48, Color(1, 1, 1, .12), 3, true)
		draw.draw_arc(c, r - 1, -PI / 2, -PI / 2 + TAU * clampf(prog, 0, 1), 48, Color(bc, op), 3, true)
	else:
		draw.draw_arc(c, r, 0, TAU, 48, Color(bc, .85 * op), 2, true)
	if on:
		draw.draw_arc(c, r + 3, 0, TAU, 48, Color(bc, .35), 6, true)
	_txt(c + Vector2(0, 4), label, int(8 * minf(1.0, s / 56.0) + 1), Color(INK, op), HORIZONTAL_ALIGNMENT_CENTER)
	_key(c + Vector2(r * .72, r * .72), k)
	if cnt != "":
		draw.draw_circle(c + Vector2(r * .7, -r * .7), 8, Color.WHITE)
		_txt(c + Vector2(r * .7, -r * .7 + 4), cnt, 10, BG, HORIZONTAL_ALIGNMENT_CENTER)


func _key(p: Vector2, k: String) -> void:
	var r := Rect2(p - Vector2(8, 8), Vector2(16, 16))
	_round_rect(r, 4, BG, DIM)
	_txt(p + Vector2(0, 4), k, 11, INK, HORIZONTAL_ALIGNMENT_CENTER)


func _round_rect(r: Rect2, rad: float, fill: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(rad))
	draw.draw_style_box(sb, r)


func _hgrad(r: Rect2, a: Color, b: Color) -> void:
	if r.size.x <= 0:
		return
	draw.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([a, b, b, a]))


func _vignette(vp: Vector2, c: Color, inner: float) -> void:
	# radial transparent centre -> colour at the edges, as a ring of quads
	var cx := vp / 2
	var R := vp.length() / 2
	var n := 48
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := cx + Vector2(cos(a0), sin(a0)) * R * inner
		var p1 := cx + Vector2(cos(a1), sin(a1)) * R * inner
		var q0 := cx + Vector2(cos(a0), sin(a0)) * R * 1.05
		var q1 := cx + Vector2(cos(a1), sin(a1)) * R * 1.05
		draw.draw_polygon(PackedVector2Array([p0, p1, q1, q0]), PackedColorArray([Color(c, 0), Color(c, 0), c, c]))


func _scope(vp: Vector2, k: float) -> void:
	var c := vp / 2
	var r := vp.y * .45
	var a := minf(1, k * 1.4)
	# black outside the lens
	var pts := PackedVector2Array()
	for i in 65:
		pts.append(c + Vector2(cos(TAU * i / 64), sin(TAU * i / 64)) * r)
	draw.draw_rect(Rect2(0, 0, c.x - r, vp.y), Color(0, 0, 0, a))
	draw.draw_rect(Rect2(c.x + r, 0, vp.x - c.x - r, vp.y), Color(0, 0, 0, a))
	for i in 64:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var e0 := Vector2(p0.x, 0 if p0.y < c.y else vp.y)
		var e1 := Vector2(p1.x, 0 if p1.y < c.y else vp.y)
		draw.draw_polygon(PackedVector2Array([p0, p1, e1, e0]), PackedColorArray([Color(0, 0, 0, a)]))
	draw.draw_arc(c, r, 0, TAU, 96, Color(0, 0, 0, a), 6, true)
	var s := r / 100.0
	var ink := Color(.07, .07, .07, a)
	draw.draw_line(c + Vector2(-99, 0) * s, c + Vector2(-46, 0) * s, ink, 1.4)
	draw.draw_line(c + Vector2(46, 0) * s, c + Vector2(99, 0) * s, ink, 1.4)
	draw.draw_line(c + Vector2(0, 58) * s, c + Vector2(0, 99) * s, ink, 1.4)
	var amber := Color(1, .6, .1, a)
	draw.draw_polyline(PackedVector2Array([c + Vector2(-9, 11) * s, c + Vector2(0, -1) * s, c + Vector2(9, 11) * s]), amber, 2.6 * s * .5 + 1.5, true)
	draw.draw_line(c + Vector2(0, -1) * s, c + Vector2(0, 18) * s, Color(amber, .85 * a), 1)


func _minimap(vp: Vector2) -> void:
	var g = game
	var N := clampf(vp.y * .26, 84, 160)
	var big := map_big
	var q := .92 * (minf(vp.y * .78, vp.x * .6) / 320.0) if big else mm_q * (N / 320.0)
	var sz := minf(vp.y * .78, vp.x * .6) if big else N
	var ctr := vp / 2 if big else Vector2(vp.x * .02 + N / 2, vp.y * .04 + N / 2)
	var cy := cos(g.yaw)
	var sy := sin(g.yaw)
	var pt := func(x: float, z: float) -> Vector2:
		return ctr + Vector2((x - g.P.x) * cy - (z - g.P.z) * sy, (x - g.P.x) * sy + (z - g.P.z) * cy) * q
	# clip by drawing inside a circle: approximate by drawing then masking with the frame ring
	if big:
		draw.draw_rect(Rect2(ctr - Vector2(sz, sz) / 2, Vector2(sz, sz)), Color("#0a0620e6"))
	else:
		draw.draw_circle(ctr, sz / 2, Color("#0b2550"))
	var bd: Array = g.col.bounds
	_poly([pt.call(bd[0], bd[2]), pt.call(bd[1], bd[2]), pt.call(bd[1], bd[3]), pt.call(bd[0], bd[3])], Color("#120c26"), ctr, sz, big)
	for b in _boxes():
		_poly([pt.call(b[0], b[2]), pt.call(b[1], b[2]), pt.call(b[1], b[3]), pt.call(b[0], b[3])], Color("#2e2456"), ctr, sz, big)
	var bs := maxf(2, q * 2)
	for k in g.block_nodes:
		var p: Vector2 = pt.call(k.x * 2 + 1, k.z * 2 + 1)
		if _inside(p, ctr, sz, big):
			draw.draw_rect(Rect2(p - Vector2(bs, bs) / 2, Vector2(bs, bs)), Color("#5b3aa8"))
	var o: Vector2 = pt.call(0, 0)
	draw.draw_arc(o, 16.5 * q, 0, TAU, 40, Color("#8a3bff"), 2)
	for e in g.EN:
		var p2: Vector2 = pt.call(e.m.global_position.x, e.m.global_position.z)
		if _inside(p2, ctr, sz, big):
			var es := 12 * (sz / 320.0)
			draw.draw_rect(Rect2(p2 - Vector2(es, es) / 2, Vector2(es, es)), Color.WHITE if e.stun > 0 else RED)
	# frame and player arrow
	if big:
		draw.draw_rect(Rect2(ctr - Vector2(sz, sz) / 2, Vector2(sz, sz)), CYA, false, 1)
	else:
		draw.draw_arc(ctr, sz / 2, 0, TAU, 64, CYA, 1, true)
	var a := sz / 320.0
	draw.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -22) * a, ctr + Vector2(14, 14) * a, ctr + Vector2(-14, 14) * a]), CYA)


var _bx: Array = []

func _boxes() -> Array:
	if _bx.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/collision/proxies.json"))
		_bx = data.boxes
	return _bx


func _inside(p: Vector2, c: Vector2, sz: float, big: bool) -> bool:
	if big:
		return absf(p.x - c.x) < sz / 2 and absf(p.y - c.y) < sz / 2
	return p.distance_to(c) < sz / 2 - 2


func _poly(pts: Array, colr: Color, c: Vector2, sz: float, big: bool) -> void:
	# clip the (convex) shape against the map disc / square so no vertex is ever folded over
	var shape := PackedVector2Array(pts)
	var clip := PackedVector2Array()
	if big:
		var h := sz / 2
		clip = PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
	else:
		for k in 48:
			clip.append(c + Vector2.from_angle(TAU * k / 48.0) * (sz / 2 - 1))
	if Geometry2D.is_polygon_clockwise(shape):
		shape.reverse()
	for piece in Geometry2D.intersect_polygons(shape, clip):
		if piece.size() >= 3 and not Geometry2D.triangulate_polygon(piece).is_empty():
			draw.draw_colored_polygon(piece, colr)