class_name V77World
extends Node3D
## Hosts a baked v77 scene and recreates v77's renderer state around it: background colour, FogExp2 and the
## hemisphere light (as shader globals), the moon aimed at its target, no ambient / reflections / tone mapping, and
## the output pass that undoes Godot's sRGB encoding so the screen shows exactly what v77's shaders compute.
## On top of that, Neon Core's look v2 (shaders/v77_material.gdshaderinc): the contact-AO map, a little more sky /
## ground fill, and the wet-street reflection - the active camera mirrored under the street, rendered at reduced size
## into two viewports that take turns, so the one being drawn is never the one the street samples.

const LOOK_FILL := 1.5           ## hemisphere fill, so dark surfaces keep their shape
const REFL_SCALE := 0.4          ## reflection resolution, relative to the screen

@export var scene_path := "res://assets/baked/city/city.scn"
@export var reflections := true
var city: Node3D
var _refl: Array = []            ## [[SubViewport, Camera3D], [SubViewport, Camera3D]]


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
			RenderingServer.global_shader_parameter_set("v77_hemi_sky", Vector3(h[0][0], h[0][1], h[0][2]) * k * LOOK_FILL)
			RenderingServer.global_shader_parameter_set("v77_hemi_ground", Vector3(h[1][0], h[1][1], h[1][2]) * k * LOOK_FILL)
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
	_setup_look()


func _setup_look() -> void:
	if ResourceLoader.exists("res://assets/baked/collision/look_ao.res"):
		var ao: Texture2D = load("res://assets/baked/collision/look_ao.res")
		RenderingServer.global_shader_parameter_set("look_ao", ao)
		RenderingServer.global_shader_parameter_set("look_ao_rect", ao.get_meta("rect"))
	if not reflections:
		return
	for i in 2:
		var vp := SubViewport.new()
		vp.world_3d = get_viewport().find_world_3d()
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		var cam := Camera3D.new()
		vp.add_child(cam)
		cam.current = true
		_refl.append([vp, cam])


func _process(_dt: float) -> void:
	if _refl.is_empty() or not is_visible_in_tree():
		return
	var main_cam := get_viewport().get_camera_3d()
	if main_cam == null or main_cam.global_position.y < 0.2:
		return
	# odd sizes, so the reflection pass can tell its own viewport apart (the screen and icon viewports are even)
	var vs := get_viewport().get_visible_rect().size * REFL_SCALE
	var size := Vector2i(maxi(16, int(vs.x)) | 1, maxi(16, int(vs.y)) | 1)
	var k := Engine.get_frames_drawn() % 2
	var vp: SubViewport = _refl[k][0]
	var cam: Camera3D = _refl[k][1]
	vp.size = size
	RenderingServer.global_shader_parameter_set("look_refl_size", Vector2(size))
	var o := main_cam.global_position
	var f := -main_cam.global_basis.z
	var u := main_cam.global_basis.y
	cam.fov = main_cam.fov
	cam.near = main_cam.near
	cam.far = minf(main_cam.far, 400.0)
	cam.look_at_from_position(Vector3(o.x, -o.y, o.z), Vector3(o.x, -o.y, o.z) + Vector3(f.x, -f.y, f.z), Vector3(u.x, -u.y, u.z))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.global_shader_parameter_set("look_refl", (_refl[1 - k][0] as SubViewport).get_texture())
