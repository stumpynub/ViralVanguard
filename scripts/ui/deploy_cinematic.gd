class_name DeployCinematic
extends CanvasLayer
## v74 deployment screen: letterboxed fly-throughs of the map's districts with sector titles, a tip and a
## loading bar. Any key / click / jump skips. Solo it plays with the match paused; online the match is already
## live, so the local player is kept invulnerable until it ends.

signal finished

const MAPK := 0.765
const DUR := 2.3
const FADE := 0.35
const TIPS := [
	"Stand in a cyan lift beam to ride up to highways, bridges and the Spire deck.",
	"Blue launch pads throw you onto the sky-bridge roofs.",
	"Hold jump in mid-air to burn your jetpack (Warden and Ascendant frames).",
	"Tap 180 to whip round on spiders closing from behind.",
	"Shoot the base of a stack to drop the blocks above it.",
	"Grapple near a roof edge to pull yourself up onto the ledge.",
	"Scoped rifles zoom to 4x when you aim down sights.",
	"Shoot out the sky-bridge glass to get inside the corridors.",
]

## Each shot: camera moves a -> b while looking from la -> lb. Plain world positions (edit freely).
var shots := [
	_shot("CENTRAL SPIRE PLAZA", "Ground zero. The Spire still broadcasts over the Grand Plaza.", _vs(-46, 6, 58), _vs(-30, 16, 40), Vector3(0, 24, 0), Vector3(0, 70, 0)),
	_shot("GRAND PLAZA MARKET", "Neon stalls, transit canopy and close-quarters cover.", _vs(76, 3.2, 46), _vs(62, 4.5, 42), _vs(48, 2.5, 26), _vs(40, 4, 18)),
	_shot("SKY-BRIDGE ROW", "Glass corridors 22-32 m up, threaded through the towers. Launch pads put you on the roofs.", _vs(-20, 62, 70), _vs(-12, 50, 55), Vector3(-40 * MAPK, 28, -77 * MAPK), Vector3(-20 * MAPK, 28, -77 * MAPK)),
	_shot("THE BAY", "Black water, sea walls and the mountains of the far shore.", _vs(-205, 40, 72), _vs(-198, 50, 30), _vs(-110, 4, -30), _vs(-60, 30, -90)),
	_shot("CENTRAL SPIRE PLAZA", "The podium lifts ride the Spire to its first observation deck.", _vs(26, 2.2, -22), _vs(19, 3.2, -27), Vector3(0, 22, 0), Vector3(0, 95, 0)),
	_shot("GRAND PLAZA MARKET", "Transit canopy overhead; launch pads throw you onto its roof.", _vs(28, 2.6, 6), _vs(36, 3.4, 10), _vs(56, 2.4, 30), _vs(62, 3, 34)),
	_shot("SKY-BRIDGE ROW", "Shoot out the glass to get inside the corridors.", Vector3(-66.91, 16, -40.2), Vector3(-53.33, 22, -44.13), Vector3(-34.43, 30, -58.9), Vector3(-7.91, 30, -62.63)),
]

@onready var _fade: ColorRect = %Fade
@onready var _caption: Control = %Caption
@onready var _sector: Label = %Sector
@onready var _title: Label = %Title
@onready var _desc: Label = %Desc
@onready var _bar: ProgressBar = %Bar
@onready var _tip: Label = %Tip

var _cam: Camera3D
var _t := 0.0
var _i := -1
var _skip := false
var _was_paused := false


static func _vs(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * MAPK, y, z * MAPK)


static func _shot(n: String, d: String, a: Vector3, b: Vector3, la: Vector3, lb: Vector3) -> Dictionary:
	return {"n": n, "d": d, "a": a, "b": b, "la": la, "lb": lb}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func play(world: Node3D) -> void:
	_cam = Camera3D.new()
	_cam.far = 1500.0
	world.add_child(_cam)
	_cam.make_current()
	_t = 0.0
	_i = -1
	_skip = false
	_tip.text = "TIP  ·  " + TIPS[randi() % TIPS.size()]
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_was_paused = get_tree().paused
	if not Net.is_online():
		get_tree().paused = true


func playing() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed) \
			or event.is_action_pressed("jump") or event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		_skip = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or _cam == null:
		return
	_t += delta
	var total := shots.size() * DUR
	var i := mini(shots.size() - 1, floori(maxf(0.0, _t) / DUR))
	var u := clampf((_t - i * DUR) / DUR, 0.0, 1.0)
	var s: Dictionary = shots[i]
	var e := u * u * (3.0 - 2.0 * u)
	var pos: Vector3 = s.a.lerp(s.b, e)
	_cam.look_at_from_position(pos, s.la.lerp(s.lb, e))
	_cam.rotate_object_local(Vector3.BACK, sin(_t * 0.7) * 0.01)
	_cam.fov = 58.0 - 6.0 * u
	if i != _i:
		_i = i
		_sector.text = "SECTOR %02d" % (i + 1)
		_title.text = s.n
		_desc.text = s.d
	var a := minf(1.0, u * DUR / 0.5)
	_caption.modulate.a = a
	_caption.position.x = (1.0 - a) * -24.0
	var f := minf(1.0, minf(u * DUR / FADE, (DUR - u * DUR) / FADE))
	_fade.color.a = 1.0 - maxf(0.0, f)
	_bar.value = minf(100.0, _t / total * 100.0)
	if _t >= total or _skip:
		_end()


func _end() -> void:
	visible = false
	if is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	if not Net.is_online():
		get_tree().paused = _was_paused
	finished.emit()
