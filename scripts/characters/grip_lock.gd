@tool
class_name GripLock
extends SkeletonModifier3D
## Last word on the hands (docs: first-person animation guide, "GripLock"). Whatever ran before (animation, spine,
## IK falling short at the edge of reach), each holding hand is put exactly on its wrist target: the hand bone slides
## the remaining distance (a little forearm stretch, capped), so a grip never floats off the weapon.

@export_range(0.0, 1.0) var weight := 0.0
@export var right_target := Vector3.ZERO      ## world space (same targets as FullBodyIK)
@export var left_target := Vector3.ZERO
@export var max_slide := 0.2


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or weight <= 0.001:
		return
	var inv := sk.global_transform.affine_inverse()
	for side in [["RightHand", right_target], ["LeftHand", left_target]]:
		var b := sk.find_bone(side[0])
		if b < 0:
			continue
		var gp := sk.get_bone_global_pose(b)
		var t: Vector3 = inv * (side[1] as Vector3)
		var d := (t - gp.origin) * weight
		if d.length() < 0.0005:
			continue
		d = d.limit_length(max_slide)
		var p := sk.get_bone_parent(b)
		var pb := sk.get_bone_global_pose(p).basis.orthonormalized()
		sk.set_bone_pose_position(b, sk.get_bone_pose_position(b) + pb.inverse() * d)
