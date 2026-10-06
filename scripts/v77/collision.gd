class_name V77Col
extends RefCounted
## v77's movement collision, exactly: a 1 m grid over the city where each cell has a ground height (SG) and up to four
## solid spans [bottom, top) above it (decks, bridges, sky-bridge floors and roofs, lobby furniture...). The grid is
## baked from the original game's own CITY.sol (tools/bake/grid.js), so sol() answers exactly as v77 does.
## Destructible crate blocks are a sparse 2 m grid on top (v77's B map); solid() = blocks or city.

const CELL_OUTSIDE := -1

var x0 := -130
var z0 := -107
var nx := 260
var nz := 214
var sg := PackedFloat32Array()          ## ground height per cell (NAN outside the city)
var spans: Array = []                   ## per cell: PackedFloat32Array [b0, t0, b1, t1, ...] or null
var bounds := [-126.225, 126.225, -103.275, 103.275]
var lifts: Array = []                   ## [x, z, top]
var pads: Array = []                    ## [x, z, vx, vy, vz, deckY?]
var blocks := {}                        ## Vector3i(i, j, k) -> block info (v77 B)


func load_baked(dir := "res://assets/baked/collision/") -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "grid.json"))
	x0 = int(meta.x0)
	z0 = int(meta.z0)
	nx = int(meta.x1) - x0
	nz = int(meta.z1) - z0
	bounds = meta.bounds
	lifts = meta.lifts
	pads = meta.pads
	var bin := FileAccess.get_file_as_bytes(dir + "grid.bin")
	sg.resize(nx * nz)
	spans.resize(nx * nz)
	var p := 0
	for i in nx * nz:
		sg[i] = bin.decode_float(p)
		var n: int = bin[p + 4]
		p += 8
		if n > 0:
			var s := PackedFloat32Array()
			s.resize(n * 2)
			for k in n:
				s[k * 2] = bin.decode_float(p)
				s[k * 2 + 1] = bin.decode_float(p + 4)
				p += 8
			spans[i] = s


func ci(x: float, z: float) -> int:
	var gx := int(floor(x)) - x0
	var gz := int(floor(z)) - z0
	if gx < 0 or gz < 0 or gx >= nx or gz >= nz:
		return CELL_OUTSIDE
	return gz * nx + gx


## v77 CITY.sol: inside the city's solid at (x, y, z)?
func sol(x: float, y: float, z: float) -> bool:
	var i := ci(x, z)
	if i < 0:
		return false
	var g := sg[i]
	if is_nan(g):
		return false
	if y < g:
		return true
	var s = spans[i]
	if s != null:
		var a: PackedFloat32Array = s
		for k in range(0, a.size(), 2):
			if y >= a[k] and y < a[k + 1]:
				return true
	return false


## v77 CITY.hAt: ground height of the cell.
func h_at(x: float, z: float) -> float:
	var i := ci(x, z)
	if i < 0 or is_nan(sg[i]):
		return 0.0
	return sg[i]


## v77 solid(): crate blocks (2 m grid) or the city.
func solid(x: float, y: float, z: float) -> bool:
	return blocks.has(Vector3i(floori(x / 2.0), floori(y / 2.0), floori(z / 2.0))) or sol(x, y, z)


## v77 hit(): the player's body sampled at three heights and four corners.
func hit(x: float, y: float, z: float) -> bool:
	for h in [.1, .9, 1.7]:
		for a in [-.35, .35]:
			for b in [-.35, .35]:
				if solid(x + a, y + h, z + b):
					return true
	return false


## v77 CITY.liftAt: the lift top if (x, y, z) is in a lift beam, else -1.
func lift_at(x: float, y: float, z: float) -> float:
	for l in lifts:
		if (x - l[0]) * (x - l[0]) + (z - l[1]) * (z - l[1]) < 1.9 and y < l[2] + .2 and y > -.5:
			return l[2]
	return -1.0


## v77 CITY.padAt: the launch pad under the player (ground pads, or raised deck pads with a deck height).
func pad_at(x: float, y: float, z: float):
	var gr := y <= .8 + h_at(x, z)
	for p in pads:
		if (x - p[0]) * (x - p[0]) + (z - p[1]) * (z - p[1]) >= 3.2:
			continue
		if p.size() > 5 and p[5] != null:
			if y > float(p[5]) - .3 and y < float(p[5]) + .8:
				return p
		elif gr:
			return p
	return null


## Make cells solid / free (v77 sets SG for doors and shattered glass this way).
func set_ground(i: int, h: float) -> void:
	if i >= 0:
		sg[i] = h
