@tool
class_name FirstPersonHead
extends SkeletonModifier3D
## The camera bend (docs: first-person animation guide, section 3, "camera follows head").
## The view's pitch is shared out over the spine chain so the head ends up turned by exactly the view's pitch:
## looking down curls you over your feet, looking up leans you back, and the chest / arms / gun stay out in front.
## After bending it records where the eye is (from the animated head), which the player copies onto its camera
## every drawn frame (position only: the look stays the player's own).

@export var pitch := 0.0                      ## radians, + = looking up
@export var bones: PackedStringArray = ["Spine", "Chest", "UpperChest", "Neck", "Head"]
@export var shares: PackedFloat32Array = [0.1, 0.15, 0.2, 0.2, 0.35]
## Third person bends less of the body (the head does most of it).
@export var body_limit := 1.5
## The eye in the head bone's frame (between the eyes, in front of the skull).
@export var eye_offset := Vector3(0, 0.06, 0.11)

var eye_world := Vector3.ZERO                 ## valid after each skeleton update
var eye_valid := false


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var p := clampf(pitch, -body_limit, body_limit)
	if absf(p) > 0.0001:
		for i in bones.size():
			var b := sk.find_bone(bones[i])
			if b < 0:
				continue
			SpineStabilizer._rotate_global(sk, b, Quaternion(Vector3.RIGHT, -p * shares[i]))
	var h := sk.find_bone("Head")
	if h >= 0:
		eye_world = sk.global_transform * (sk.get_bone_global_pose(h) * eye_offset)
		eye_valid = true
