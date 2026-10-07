extends SceneTree
## Bakes the look v2 contact-AO map from the collision grid: for every 1 m cell, how much of the sky the surrounding
## solids hide (horizon angle in 8 directions out to 5 m). r = AO, g = ground height of the cell. Run after re-baking
## the collision grid:
##   godot --headless --path . --script res://tools/bake_look_ao.gd   -> assets/baked/collision/look_ao.res


func _init() -> void:
	var col := V77Col.new()
	col.load_baked()
	var nx := col.nx
	var nz := col.nz
	var H := PackedFloat32Array()
	H.resize(nx * nz)
	for i in nx * nz:
		H[i] = 0.0 if is_nan(col.sg[i]) else col.sg[i]
	var img := Image.create(nx, nz, false, Image.FORMAT_RGF)
	var dirs := []
	for k in 8:
		dirs.append(Vector2.from_angle(TAU * k / 8.0))
	var steps := [1.0, 2.0, 3.0, 5.0]
	for gz in nz:
		for gx in nx:
			var h0 := H[gz * nx + gx]
			var occ := 0.0
			for d in dirs:
				var best := 0.0
				for s in steps:
					var x := gx + roundi(d.x * s)
					var z := gz + roundi(d.y * s)
					if x < 0 or z < 0 or x >= nx or z >= nz:
						continue
					best = maxf(best, (H[z * nx + x] - h0 - 0.15) / s)
				occ += best / sqrt(1.0 + best * best)
			img.set_pixel(gx, gz, Color(clampf(1.0 - occ / 8.0 * 1.25, 0.25, 1.0), h0, 0.0))
	var tex := ImageTexture.create_from_image(img)
	tex.set_meta("rect", Vector4(col.x0, col.z0, nx, nz))
	var err := ResourceSaver.save(tex, "res://assets/baked/collision/look_ao.res", ResourceSaver.FLAG_COMPRESS)
	print("look_ao: %dx%d cells, saved (%s)" % [nx, nz, error_string(err)])
	quit()
