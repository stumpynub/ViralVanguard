extends SceneTree
## Mean brightness of shots: quick way to see which bisection removed the black cover.
func _init() -> void:
	for f in OS.get_cmdline_user_args():
		var img := Image.load_from_file("res://build/shots/%s.png" % f)
		var s := 0.0
		var n := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				var c := img.get_pixel(x, y)
				s += (c.r + c.g + c.b) / 3.0
				n += 1
		print(f, "  mean ", snappedf(s / n, 0.001))
	quit()
