@tool
class_name FullBodyIK
extends SkeletonModifier3D
## Full-body IK layered on top of the animation:
##  - rifle stance: twists the UpperChest so the support shoulder comes forward (neck counter-twists)
##  - arms: two-bone IK putting the wrists on world-space targets (gun grip / handguard / magazine)
##  - legs: two-bone IK planting each foot on the real ground under it. The animation's ground plane (y = 0 in
##    skeleton space) is remapped onto whatever is under each foot, so stairs, curbs and a lowered body all work.

@export_range(0.0, 1.0) var arm_weight := 0.0
@export_range(0.0, 1.0) var leg_weight := 1.0
@export var chest_twist := -0.5          ## radians about the body's up axis while arm_weight > 0
@export var right_target := Vector3.ZERO  ## world-space wrist targets
@export var left_target := Vector3.ZERO
## World-space directions the fingers should point (wrist -> fingertips). Zero = keep the animated hand.
@export var right_hand_dir := Vector3.ZERO
@export var left_hand_dir := Vector3.ZERO
## World-space directions the palms should face (rolls the hand about its finger axis). Zero = fingers only.
@export var right_palm_dir := Vector3.ZERO
@export var left_palm_dir := Vector3.ZERO
## Finger / thumb curl 0..1 (rigs with finger chains): wrap a grip, pinch a bolt knob, cup a handguard.
@export_range(0.0, 1.0) var right_curl := 0.0
@export_range(0.0, 1.0) var left_curl := 0.0
@export_range(0.0, 1.0) var right_thumb := 0.0
@export_range(0.0, 1.0) var left_thumb := 0.0
## Clavicles swing up to this much toward a hand target that is near the limit of reach.
@export var clavicle_reach := 0.45
@export var ground_mask := 1
@export var foot_probe_up := 0.7
@export var foot_probe_down := 1.0
@export var right_arm_pole := Vector3(-0.6, -1.0, -0.4)
@export var left_arm_pole := Vector3(0.6, -1.0, -0.4)
@export var knee_pole := Vector3(0, 0.2, 1.0)

const ARMS := [["RightUpperArm", "RightLowerArm", "RightHand", "RightShoulder"], ["LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftShoulder"]]
const HAND_REST_DIR := Vector3(0, -0.17, 0.07)   # wrist -> fingertips in the hand bone's rest frame
const PALM_REST := [Vector3(1, 0, 0), Vector3(-1, 0, 0)]   # arms hanging at rest, palms face the thighs (right, left)
const LEGS := [["RightUpperLeg", "RightLowerLeg", "RightFoot"], ["LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var inv := sk.global_transform.affine_inverse()
	if leg_weight > 0.0 and not Engine.is_editor_hint() and sk.is_inside_tree():
		var space := sk.get_world_3d().direct_space_state
		for leg in LEGS:
			var foot := sk.find_bone(leg[2])
			var w_local := sk.get_bone_global_pose(foot).origin
			var w_world := sk.global_transform * w_local
			var up := sk.global_basis.y.normalized()
			var q := PhysicsRayQueryParameters3D.create(w_world + up * foot_probe_up, w_world - up * foot_probe_down, ground_mask)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var ground_local: Vector3 = inv * (hit.position as Vector3)
			var target := Vector3(w_local.x, ground_local.y + w_local.y, w_local.z)
			_two_bone(sk, leg[0], leg[1], leg[2], target, knee_pole, leg_weight)
	if arm_weight > 0.0:
		_twist(sk, "UpperChest", chest_twist * arm_weight)
		_twist(sk, "Neck", -chest_twist * arm_weight)
		for i in 2:
			var arm: Array = ARMS[i]
			var t: Vector3 = inv * (right_target if i == 0 else left_target)
			_clavicle(sk, arm[3], arm[0], arm[2], t, arm_weight)
			var gl := _two_bone(sk, arm[0], arm[1], arm[2], t, right_arm_pole if i == 0 else left_arm_pole, arm_weight)
			var hd: Vector3 = right_hand_dir if i == 0 else left_hand_dir
			var pd: Vector3 = right_palm_dir if i == 0 else left_palm_dir
			if hd != Vector3.ZERO:
				_aim_hand(sk, arm[2], gl, inv.basis * hd, arm_weight, inv.basis * pd if pd != Vector3.ZERO else Vector3.ZERO, PALM_REST[i])
			_fingers(sk, "Right" if i == 0 else "Left", (right_curl if i == 0 else left_curl) * arm_weight, (right_thumb if i == 0 else left_thumb) * arm_weight)


## Curl the finger chain toward the palm and bring the thumb across it (hand-local axes: fingers -Y, palm ±X).
func _fingers(sk: Skeleton3D, side: String, curl: float, thumb: float) -> void:
	var s := 1.0 if side == "Right" else -1.0       # right palm faces +X at rest, left -X
	var f1 := sk.find_bone(side + "Fingers1")
	if f1 < 0:
		return
	var axis := Vector3(0, 0, s)
	sk.set_bone_pose_rotation(f1, Quaternion(axis, 1.25 * curl))
	sk.set_bone_pose_rotation(sk.find_bone(side + "Fingers2"), Quaternion(axis, 1.35 * curl))
	var t1 := sk.find_bone(side + "Thumb1")
	if t1 >= 0:
		sk.set_bone_pose_rotation(t1, Quaternion(Vector3(0, -s, 0), 0.75 * thumb) * Quaternion(axis, 0.35 * thumb))
		sk.set_bone_pose_rotation(sk.find_bone(side + "Thumb2"), Quaternion(axis, 0.7 * thumb))


func _parent_global(sk: Skeleton3D, b: int) -> Transform3D:
	var p := sk.get_bone_parent(b)
	return sk.get_bone_global_pose(p) if p >= 0 else Transform3D()


func _twist(sk: Skeleton3D, bone: String, angle: float) -> void:
	var b := sk.find_bone(bone)
	if b < 0 or absf(angle) < 0.0001:
		return
	var g := sk.get_bone_global_pose(b)
	var pg := _parent_global(sk, b)
	var nb := Basis(Vector3.UP, angle) * g.basis
	sk.set_bone_pose_rotation(b, (pg.basis.inverse() * nb).get_rotation_quaternion())


## Swing the clavicle toward the target when the arm alone can't reach it.
func _clavicle(sk: Skeleton3D, clav: String, upper: String, end: String, target: Vector3, weight: float) -> void:
	var bc := sk.find_bone(clav)
	var bu := sk.find_bone(upper)
	var c := sk.get_bone_global_pose(bc).origin
	var s := sk.get_bone_global_pose(bu).origin
	var reach := 0.0
	var b := bu
	while b != sk.find_bone(end):
		var child := -1
		for ch in sk.get_bone_children(b):
			child = ch
		reach += sk.get_bone_pose_position(child).length()
		b = child
	var deficit := clampf((s.distance_to(target) - reach * 0.92) / 0.2, 0.0, 1.0)
	if deficit <= 0.0:
		return
	var from := (s - c).normalized()
	var to := (target - c).normalized()
	var ang := minf(from.angle_to(to), clavicle_reach) * deficit * weight
	var axis := from.cross(to)
	if axis.length() < 0.0001:
		return
	var g := sk.get_bone_global_pose(bc)
	var nb := Basis(axis.normalized(), ang) * g.basis
	sk.set_bone_pose_rotation(bc, (_parent_global(sk, bc).basis.inverse() * nb).get_rotation_quaternion())


## Point the hand's fingers along `dir` (skeleton space), given the lower arm's new global transform.
func _aim_hand(sk: Skeleton3D, hand: String, lower_global: Transform3D, dir: Vector3, weight: float, palm := Vector3.ZERO, palm_rest := Vector3.RIGHT) -> void:
	var bh := sk.find_bone(hand)
	var old := sk.get_bone_pose_rotation(bh)
	var gh := lower_global.basis * Basis(old)
	var nb := Basis(Quaternion((gh * HAND_REST_DIR).normalized(), dir.normalized())) * gh
	if palm != Vector3.ZERO:
		# roll about the finger axis until the palm faces `palm`
		var f := dir.normalized()
		var cur := (nb * palm_rest).normalized()
		var want := (palm - f * palm.dot(f)).normalized()
		cur = (cur - f * cur.dot(f)).normalized()
		if want.length() > 0.01 and cur.length() > 0.01:
			nb = Basis(f, cur.signed_angle_to(want, f)) * nb
	sk.set_bone_pose_rotation(bh, old.slerp((lower_global.basis.inverse() * nb).get_rotation_quaternion(), weight))


## Two-bone IK in skeleton space. `target` is where the end bone's head (wrist / ankle) should go.
func _two_bone(sk: Skeleton3D, upper: String, lower: String, end: String, target: Vector3, pole: Vector3, weight: float) -> Transform3D:
	var bu := sk.find_bone(upper)
	var bl := sk.find_bone(lower)
	var be := sk.find_bone(end)
	var gu := sk.get_bone_global_pose(bu)
	var gl := sk.get_bone_global_pose(bl)
	var ge := sk.get_bone_global_pose(be)
	var s := gu.origin
	var e := gl.origin
	var w := ge.origin
	var l1 := s.distance_to(e)
	var l2 := e.distance_to(w)
	var to := target - s
	var d := clampf(to.length(), 0.01, l1 + l2 - 0.002)
	var dir := to.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var pv := pole - dir * pole.dot(dir)
	pv = pv.normalized() if pv.length() > 0.001 else Vector3.FORWARD
	var e2 := s + dir * a + pv * h
	var w2 := s + dir * d
	# upper bone: swing (e - s) onto (e2 - s)
	var pu := _parent_global(sk, bu)
	var nu := Basis(Quaternion((e - s).normalized(), (e2 - s).normalized())) * gu.basis
	var lu_old := sk.get_bone_pose_rotation(bu)
	var lu := lu_old.slerp((pu.basis.inverse() * nu).get_rotation_quaternion(), weight)
	sk.set_bone_pose_rotation(bu, lu)
	var gu2 := pu * Transform3D(Basis(lu), sk.get_bone_pose_position(bu))
	# lower bone: swing its current direction onto (w2 - e2)
	var ll_old := sk.get_bone_pose_rotation(bl)
	var gl2 := gu2 * Transform3D(Basis(ll_old), sk.get_bone_pose_position(bl))
	var w_now := gl2 * sk.get_bone_pose_position(be)
	var nl := Basis(Quaternion((w_now - gl2.origin).normalized(), (w2 - gl2.origin).normalized())) * gl2.basis
	var ll := ll_old.slerp((gu2.basis.inverse() * nl).get_rotation_quaternion(), weight)
	sk.set_bone_pose_rotation(bl, ll)
	return gu2 * Transform3D(Basis(ll), sk.get_bone_pose_position(bl))
