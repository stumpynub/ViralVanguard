@tool
class_name SpineStabilizer
extends SkeletonModifier3D
## Holds the chest steady while something is held (docs: first-person animation guide, "SpineStabilizer").
## Walk / run clips swing the shoulders; with the hands locked onto a gun in camera space that makes the arms swim.
## This turns Spine, Chest and UpperChest (a share each) until the chest faces its rest direction (+ an optional lean).
## The hips and legs keep animating. `strength` is driven by the character (arm IK weight while holding).

@export_range(0.0, 1.0) var strength := 0.0
@export var lean := 0.0                       ## radians forward lean of the held chest
@export var bones: PackedStringArray = ["Spine", "Chest", "UpperChest"]
@export var shares: PackedFloat32Array = [0.25, 0.35, 0.4]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or strength <= 0.001:
		return
	var top := sk.find_bone(bones[bones.size() - 1])
	if top < 0:
		return
	var g := sk.get_bone_global_pose(top).basis.orthonormalized()
	var want := Basis(Vector3.RIGHT, lean)          # skeleton space: upright, facing +Z
	var delta := (want * g.inverse()).get_rotation_quaternion()
	for i in bones.size():
		var b := sk.find_bone(bones[i])
		if b < 0:
			continue
		var q := Quaternion.IDENTITY.slerp(delta, shares[i] * strength)
		_rotate_global(sk, b, q)


static func _rotate_global(sk: Skeleton3D, b: int, q: Quaternion) -> void:
	var gp := sk.get_bone_global_pose(b)
	var p := sk.get_bone_parent(b)
	var pg := sk.get_bone_global_pose(p).basis if p >= 0 else Basis()
	var nb := Basis(q) * gp.basis
	sk.set_bone_pose_rotation(b, (pg.orthonormalized().inverse() * nb.orthonormalized()).get_rotation_quaternion())
