@tool
class_name TintedProp
extends Node3D
## Shared helper for props with one paint colour and one glow colour (cars, lamps, vending machines, barriers).
## `paint_targets` get the paint colour as albedo, `glow_targets` get the glow colour as albedo + emission,
## and any GeometryInstance3D using an instance-uniform `color` (light pools) gets the glow colour too.

@export var paint := Color("#2a2a3a"):
	set(v):
		paint = v
		_apply()
@export var glow := Color("#21e6ff"):
	set(v):
		glow = v
		_apply()
@export var paint_targets: Array[NodePath] = []
@export var glow_targets: Array[NodePath] = []
@export var pool_targets: Array[NodePath] = []


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	for p in paint_targets:
		var g := get_node_or_null(p) as GeometryInstance3D
		if g and g.material_override is StandardMaterial3D:
			(g.material_override as StandardMaterial3D).albedo_color = paint
	for p in glow_targets:
		var g := get_node_or_null(p) as GeometryInstance3D
		if g and g.material_override is StandardMaterial3D:
			var m := g.material_override as StandardMaterial3D
			m.albedo_color = glow
			m.emission = glow
	for p in pool_targets:
		var g := get_node_or_null(p) as GeometryInstance3D
		if g:
			var m := g.material_override as ShaderMaterial
			if m:
				m.set_shader_parameter("color", glow)
