extends Control
## Centre reticle: a glowing ring with a dot; turns green when the grapple has a target.
@export var color := Color("#e6e2da")
@export var grapple_color := Color("#3dffc8")
var grapple_ok := false

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var col := grapple_color if grapple_ok else color
	draw_arc(c, 13, 0, TAU, 40, Color(col, 0.25 * modulate.a), 5.0)
	draw_arc(c, 11, 0, TAU, 40, col, 2.0)
	draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
