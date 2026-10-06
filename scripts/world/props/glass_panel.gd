class_name GlassPanel
extends StaticBody3D
## Sky-bridge window: solid until shot, then it bursts into shards and opens the corridor.
## Shattering goes through Arena.shatter_glass() so every peer sees it.

@export var shards_scene: PackedScene = preload("res://scenes/fx/glass_shards.tscn")

var broken := false


func _ready() -> void:
	add_to_group("glass")


func shatter() -> void:
	if broken:
		return
	broken = true
	var fx: Node3D = shards_scene.instantiate()
	get_parent().add_child(fx)
	fx.global_transform = $Mesh.global_transform
	for i in 3:
		Sfx.play_at("glass", global_position + global_basis.z * (i - 1) * 2.0, 0.8)
	queue_free()
