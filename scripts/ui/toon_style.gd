class_name ToonStyle
extends RefCounted
## Converts a model's materials to the menu's cel look: assets/shaders/menu/toon.gdshader (keeping each
## material's albedo texture / colour) with an inverted-hull ink outline as next_pass.

const TOON := preload("res://assets/shaders/menu/toon.gdshader")
const OUTLINE := preload("res://assets/shaders/menu/outline.gdshader")


## opts: outline width (m at 1 m), desaturate, rim colour, bands, emission threshold, vertex colours...
static func apply(root: Node, opts := {}) -> void:
	var outline: ShaderMaterial = null
	if opts.get("outline", 0.011) > 0.0:
		outline = ShaderMaterial.new()
		outline.shader = OUTLINE
		outline.set_shader_parameter("width", opts.get("outline", 0.011))
		outline.set_shader_parameter("max_width", opts.get("outline_max", 0.04))
	var cache := {}
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i)
			if not stylable(src):
				continue
			if not cache.has(src):
				cache[src] = to_toon(src, outline, opts)
			mi.set_surface_override_material(i, cache[src])


## Flashes, glints, glows and other unshaded / see-through materials keep their look.
static func stylable(m: Material) -> bool:
	if m == null:
		return true
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return b.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and b.blend_mode == BaseMaterial3D.BLEND_MODE_MIX
	return false      # custom shaders (facades, glass, beams...) are already styled


static func to_toon(src: Material, outline: Material, opts: Dictionary) -> ShaderMaterial:
	var t := ShaderMaterial.new()
	t.shader = TOON
	if src is BaseMaterial3D:
		var b := src as BaseMaterial3D
		if b.albedo_texture:
			t.set_shader_parameter("albedo_tex", b.albedo_texture)
		t.set_shader_parameter("tint", b.albedo_color * opts.get("tint", Color.WHITE))
		t.set_shader_parameter("use_vertex_color", b.vertex_color_use_as_albedo)
		if b.emission_enabled:
			if b.emission_texture:
				t.set_shader_parameter("emission_tex", b.emission_texture)
				t.set_shader_parameter("emission_energy", b.emission_energy_multiplier * 0.8)
			else:
				t.set_shader_parameter("emission_color", b.emission * b.emission_energy_multiplier * 0.6)
	if not (src is BaseMaterial3D) and opts.has("tint"):
		t.set_shader_parameter("tint", opts["tint"])
	for k in ["desaturate", "bands", "rim_color", "rim_strength", "rim_width", "emission_threshold", "shadow_color", "spec_size", "wet"]:
		if opts.has(k):
			t.set_shader_parameter(k, opts[k])
	t.next_pass = outline
	return t
