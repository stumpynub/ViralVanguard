class_name CharacterModel
extends Node3D
## The rigged operative (scenes/characters/sick_operative.tscn): Skeleton3D with humanoid bone names,
## a skinned body mesh, an AnimationPlayer and a weapon mount on the UpperChest bone.
## Animations: idle, walk, run, jump, death, and *_rifle variants that hold a gun at the WeaponMount grip.

@export var skeleton: Skeleton3D
@export var animation_player: AnimationPlayer
@export var weapon_grip: Marker3D
## The point between the eyes; the player camera is aligned to it in first person.
@export var eye: Marker3D
@export var ik: FullBodyIK
## Look bend + eye (FirstPersonHead), chest hold (SpineStabilizer), final hand lock (GripLock). Optional: older
## character scenes only have an AimModifier.
@export var fp_head: FirstPersonHead
@export var spine: SpineStabilizer
@export var grip_lock: GripLock
## First person: body pixels closer than `fp_fade_near` to the camera dither out, fully solid by `fp_fade_far`
## (keeps the collar / chest plate from filling the screen when you look down).
@export var fp_fade_near := 0.12
@export var fp_fade_far := 0.22

var _fp_material: Material
var _toon: Array[Material] = []      ## cel-shaded body surfaces (stylize()); empty = the model's own materials
## Look up / down: bends Spine, Chest and UpperChest after the animation (see AimModifier).
@export_range(-1.5, 1.5) var aim_pitch := 0.0:
	set(v):
		aim_pitch = v
		if fp_head:
			fp_head.pitch = v
		var m := get_node_or_null("Skeleton/AimModifier")
		if m:
			m.pitch = v

var _current := &""


## Where the eyes are after this frame's pose (head-driven), or the Eye marker on older rigs.
func eye_world() -> Vector3:
	return fp_head.eye_world if fp_head and fp_head.eye_valid else eye.global_position


func play(anim: StringName, blend := 0.2, speed := 1.0) -> void:
	if anim == _current:
		animation_player.speed_scale = speed
		return
	_current = anim
	animation_player.play(anim, blend, speed)
	animation_player.speed_scale = speed


## Cel / ink look (assets/shaders/menu/toon.gdshader) on every surface, kept through first / third person switches.
func stylize(opts := {}) -> void:
	var body: MeshInstance3D = skeleton.get_node("Body")
	ToonStyle.apply(self, opts)
	_toon.clear()
	for i in body.mesh.get_surface_count():
		_toon.append(body.get_surface_override_material(i))
	_fp_material = null


## Third person / hangar: everything renders. First person: the whole body renders except the helmet surface
## (the camera sits inside it); the helmet still casts its shadow.
func set_first_person(on: bool) -> void:
	var body: MeshInstance3D = skeleton.get_node("Body")
	var helmet := skeleton.get_node_or_null("HelmetShadow") as MeshInstance3D
	if on and helmet == null:
		helmet = MeshInstance3D.new()
		helmet.name = "HelmetShadow"
		helmet.mesh = body.mesh
		helmet.skeleton = NodePath("..")
		helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		helmet.set_surface_override_material(0, _invisible())
		skeleton.add_child(helmet)
	if helmet:
		helmet.visible = on
	var own1: Material = _toon[1] if _toon.size() > 1 else null
	var own0: Material = _toon[0] if _toon.size() > 0 else null
	body.set_surface_override_material(1, _invisible() if on else own1)
	if on and _fp_material == null:
		if own0 is ShaderMaterial:
			_fp_material = own0.duplicate()
			_fp_material.next_pass = null          # no ink hull hanging in front of the camera
			_fp_material.set_shader_parameter("fade_near", fp_fade_near)
			_fp_material.set_shader_parameter("fade_far", fp_fade_far)
		else:
			var src := body.mesh.surface_get_material(0) as BaseMaterial3D
			if src:
				var m: BaseMaterial3D = src.duplicate()
				m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
				m.distance_fade_min_distance = fp_fade_near
				m.distance_fade_max_distance = fp_fade_far
				_fp_material = m
	body.set_surface_override_material(0, _fp_material if on else own0)


static var _hidden: Material


static func _invisible() -> Material:
	if _hidden == null:
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;\nvoid fragment() { ALBEDO = vec3(0.0); ALPHA = 0.0; discard; }\n"
		sm.shader = sh
		_hidden = sm
	return _hidden


## Grow / shrink the first-person near fade (the player widens it while looking down).
func set_fp_fade(near: float, far: float) -> void:
	if _fp_material is ShaderMaterial:
		_fp_material.set_shader_parameter("fade_near", near)
		_fp_material.set_shader_parameter("fade_far", far)
	elif _fp_material is BaseMaterial3D:
		_fp_material.distance_fade_min_distance = near
		_fp_material.distance_fade_max_distance = far


## Legacy helper (shadow-only body).
func set_shadow_only(on: bool) -> void:
	var body: MeshInstance3D = skeleton.get_node("Body")
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
