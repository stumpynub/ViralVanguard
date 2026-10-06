@tool
class_name Building
extends Node3D
## A city block: facade (procedural windows), optional lit shop band at street level, roof slab with a neon trim
## and a solid collision box. Resize it in the inspector; the child nodes follow.

enum Kind { RESIDENTIAL, COMMERCIAL, INDUSTRIAL }

const FACADES: Array[Material] = [
	preload("res://assets/materials/facade_residential.tres"),
	preload("res://assets/materials/facade_commercial.tres"),
	preload("res://assets/materials/facade_industrial.tres"),
]
const TRIMS: Array[Material] = [
	preload("res://assets/materials/glow_magenta.tres"),
	preload("res://assets/materials/glow_cyan.tres"),
	preload("res://assets/materials/glow_orange.tres"),
]
const SHOP_HEIGHT := 4.5

@export var size := Vector3(16, 24, 16):
	set(v):
		size = v
		_rebuild()
@export var kind := Kind.RESIDENTIAL:
	set(v):
		kind = v
		_rebuild()
@export var shops := false:
	set(v):
		shops = v
		_rebuild()
## Background skyline blocks are not solid (they sit outside the playfield).
@export var solid := true:
	set(v):
		solid = v
		_rebuild()
@export var seed := 0.0:
	set(v):
		seed = v
		_rebuild()
## Gate towers straddling a street: the tower body starts this high (legs and soffit are separate nodes).
@export var elevation := 0.0:
	set(v):
		elevation = v
		_rebuild()
@export var rooftop_clutter := true:
	set(v):
		rooftop_clutter = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var base := maxf(elevation, SHOP_HEIGHT if shops else 0.0)
	var facade: MeshInstance3D = $Facade
	(facade.mesh as BoxMesh).size = Vector3(size.x, size.y - base, size.z)
	facade.position = Vector3(0, base + (size.y - base) * 0.5, 0)
	facade.material_override = FACADES[kind]

	var shop: MeshInstance3D = $ShopBand
	shop.visible = shops and elevation <= 0.0
	(shop.mesh as BoxMesh).size = Vector3(size.x, SHOP_HEIGHT, size.z)
	shop.position = Vector3(0, SHOP_HEIGHT * 0.5, 0)
	var ledge: MeshInstance3D = $ShopLedge
	ledge.visible = shops and elevation <= 0.0
	(ledge.mesh as BoxMesh).size = Vector3(size.x + 0.2, 0.18, size.z + 0.2)
	ledge.position = Vector3(0, SHOP_HEIGHT + 0.05, 0)

	var roof: MeshInstance3D = $Roof
	(roof.mesh as BoxMesh).size = Vector3(size.x + 0.3, 0.3, size.z + 0.3)
	roof.position = Vector3(0, size.y + 0.15, 0)
	var trim: MeshInstance3D = $RoofTrim
	(trim.mesh as BoxMesh).size = Vector3(size.x + 0.3, 0.06, 0.06)
	trim.position = Vector3(0, size.y + 0.32, size.z * 0.5 + 0.13)
	trim.material_override = TRIMS[kind]

	var body: StaticBody3D = $Body
	body.collision_layer = 1 if solid else 0
	var shape: CollisionShape3D = $Body/Shape
	(shape.shape as BoxShape3D).size = Vector3(size.x, size.y - elevation, size.z)
	shape.position = Vector3(0, elevation + (size.y - elevation) * 0.5, 0)
	shape.disabled = not solid
	_build_clutter()


## HVAC housings, tanks and antennas scattered on the roof (generated, not saved with the scene).
func _build_clutter() -> void:
	var old := get_node_or_null("_Clutter")
	if old:
		remove_child(old)
		old.queue_free()
	if not rooftop_clutter:
		return
	var root := Node3D.new()
	root.name = "_Clutter"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) ^ hash(size)
	var dark := preload("res://assets/materials/metal_dark.tres")
	var n := int(size.x * size.z / 60.0) + 1
	for i in mini(n, 8):
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.8, 1.8), rng.randf_range(0.6, 1.2), rng.randf_range(0.8, 1.8))
		m.mesh = b
		m.material_override = dark
		m.position = Vector3(rng.randf_range(-size.x * 0.5 + 1, size.x * 0.5 - 1), size.y + 0.3 + b.size.y * 0.5, rng.randf_range(-size.z * 0.5 + 1, size.z * 0.5 - 1))
		root.add_child(m)
	if rng.randf() < 0.5:
		var mast := MeshInstance3D.new()
		var c := CylinderMesh.new()
		var h := rng.randf_range(4, 10)
		c.top_radius = 0.08
		c.bottom_radius = 0.08
		c.height = h
		mast.mesh = c
		mast.material_override = dark
		mast.position = Vector3(rng.randf_range(-size.x / 3, size.x / 3), size.y + h * 0.5, rng.randf_range(-size.z / 3, size.z / 3))
		root.add_child(mast)
		var lamp := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.36
		lamp.mesh = s
		lamp.material_override = preload("res://assets/materials/glow_red.tres")
		lamp.position = mast.position + Vector3(0, h * 0.5, 0)
		root.add_child(lamp)
