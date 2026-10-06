@tool
class_name AimModifier
extends SkeletonModifier3D
## Adds a look-up / look-down bend, split across the spine bones, on top of whatever the AnimationPlayer posed.

@export var pitch := 0.0
@export var bones: PackedStringArray = ["Spine", "Chest", "UpperChest"]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or absf(pitch) < 0.0001:
		return
	var q := Quaternion(Vector3.RIGHT, -pitch / bones.size())
	for b in bones:
		var i := sk.find_bone(b)
		if i >= 0:
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * q)
