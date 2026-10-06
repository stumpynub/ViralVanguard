class_name V77World
extends Node3D
## Hosts a baked v77 scene and recreates v77's renderer state around it: background colour, FogExp2 and the
## hemisphere light (as shader globals), the moon aimed at its target, no ambient / reflections / tone mapping, and
## the output pass that undoes Godot's sRGB encoding so the screen shows exactly what v77's shaders compute.

@export var scene_path := "res://assets/baked/city/city.scn"
var city: Node3D


func _ready() -> void:
	city = load(scene_path).instantiate()
	add_child(city)
	var env_data: Dictionary = city.get_meta("v77_env", {})
	var bg: Array = env_data.get("background", [0.0196, 0.0157, 0.0549]) if env_data.get("background") else [0.0196, 0.0157, 0.0549]
	var fog: Dictionary = env_data.get("fog", {}) if env_data.get("fog") is Dictionary else {}
	RenderingServer.global_shader_parameter_set("v77_fog_color", Vector3(fog.color[0], fog.color[1], fog.color[2]) if fog.has("color") else Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("v77_fog_density", float(fog.get("density", 0.0)))
	for n in city.find_children("*", "Node3D", true, false):
		if n.has_meta("v77_hemi"):
			var h: Array = n.get_meta("v77_hemi")
			var k := float(h[2])
			RenderingServer.global_shader_parameter_set("v77_hemi_sky", Vector3(h[0][0], h[0][1], h[0][2]) * k)
			RenderingServer.global_shader_parameter_set("v77_hemi_ground", Vector3(h[1][0], h[1][1], h[1][2]) * k)
		if n is DirectionalLight3D and n.has_meta("v77_target"):
			var t: Array = n.get_meta("v77_target")
			var target := Vector3(t[12], t[13], t[14])
			var p := (n as Node3D).global_position
			if p.distance_to(target) > 0.01:
				(n as Node3D).look_at_from_position(p, target, Vector3.UP if absf((target - p).normalized().y) < 0.99 else Vector3.FORWARD)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(bg[0], bg[1], bg[2]).linear_to_srgb()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.fog_enabled = false
	we.environment = env
	add_child(we)
	var layer := CanvasLayer.new()
	layer.layer = -10
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://shaders/v77_output.gdshader")
	rect.material = sm
	layer.add_child(rect)
	add_child(layer)
