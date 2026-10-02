class_name EdRig
extends RefCounted

## Poses Ed's rigged model (the Meshy humanoid skeleton) into a side-on board
## stance, every frame, from the motor's state. No authored clips: the body is
## built from frames and two-bone IK so it always stays planted on the board.
##
## The stance is a regular-footed rider: left foot leading, chest square to the
## board's toe edge, shoulders opened toward travel, head turned to look down
## the line. Tuck folds him low with hands at his knees; in the air he sinks
## into the board and throws both arms wide and high.
##
## Everything works in skeleton space, where the glTF model faces +Z, so
## +Z is the direction of travel and -X (Ed's chest after the turn) is the toe
## edge of the board.

const REQUIRED = [
	"Hips", "Spine02", "Spine01", "Spine", "neck", "Head",
	"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot",
]
const SPINE = ["Spine02", "Spine01", "Spine"]          ## hips -> chest

const TRAVEL = Vector3(0, 0, 1)
const TOE = Vector3(-1, 0, 0)
const UP = Vector3.UP

var skel: Skeleton3D
var _b = {}            ## bone name -> index
var _rest_l = {}       ## index -> rest local Transform3D
var _rest_g = {}       ## index -> rest global Transform3D
var _g = {}            ## index -> posed global Transform3D (this frame)
var _order: Array[int] = []
var _leg = 1.0         ## hip-to-ankle length
var _arm = 1.0         ## shoulder-to-wrist length
var _ankle_y = 0.0
var _center = Vector3.ZERO

## Returns null when the skeleton is not the humanoid we expect, so the caller
## can fall back to showing the model as authored.
static func create(skeleton: Skeleton3D) -> EdRig:
	for n in REQUIRED:
		if skeleton.find_bone(n) < 0: return null
	var rig = EdRig.new()
	rig._setup(skeleton)
	return rig

func _setup(skeleton: Skeleton3D) -> void:
	skel = skeleton
	for n in REQUIRED: _b[n] = skel.find_bone(n)
	for i in skel.get_bone_count():
		_rest_l[i] = skel.get_bone_rest(i)
		_rest_g[i] = skel.get_bone_global_rest(i)
	_leg = _len("LeftLeg") + _len("LeftFoot")
	_arm = _len("LeftForeArm") + _len("LeftHand")
	_ankle_y = (_rest_g[_b["LeftFoot"]].origin.y + _rest_g[_b["RightFoot"]].origin.y) * 0.5
	var hips: Vector3 = _rest_g[_b["Hips"]].origin
	_center = Vector3(hips.x, 0.0, hips.z)

func _len(child: String) -> float:
	return (_rest_l[_b[child]] as Transform3D).origin.length()

# ------------------------------------------------------------------- solver
## Where a bone sits this frame: posed if set, else carried by its parents.
func _global(i: int) -> Transform3D:
	if i < 0: return Transform3D.IDENTITY
	return _g[i] if _g.has(i) else _follow(i)

func _follow(i: int) -> Transform3D:
	return _global(skel.get_bone_parent(i)) * _rest_l[i]

func _put(i: int, xf: Transform3D) -> void:
	_g[i] = xf
	_order.append(i)

## Orients a bone absolutely: its rest frame (facing +Z, up +Y, as authored in
## the T-pose) is turned to face `fwd` with `up`.
func _orient(name: String, fwd: Vector3, up: Vector3) -> void:
	var i: int = _b[name]
	var u = _follow(i)
	u.basis = Basis.looking_at(-fwd, up) * (_rest_g[i] as Transform3D).basis
	_put(i, u)

## Swings a bone (minimal rotation) so it points at `target`.
func _aim(name: String, child: String, target: Vector3) -> void:
	var i: int = _b[name]
	var u = _follow(i)
	var cur = (u.basis * (_rest_l[_b[child]] as Transform3D).origin).normalized()
	var want = (target - u.origin).normalized()
	if cur.dot(want) < 0.9999:
		u.basis = Basis(Quaternion(cur, want)) * u.basis
	_put(i, u)

## Two-bone IK: upper -> lower -> end reaches `target`, bending toward `pole`.
func _limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var a = _follow(_b[upper]).origin
	var l1 = _len(lower); var l2 = _len(end)
	var to = target - a
	var d = clampf(to.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var dir = to.normalized() if to.length() > 0.0001 else -UP
	var cos_a = clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var side = pole - dir * pole.dot(dir)
	side = side.normalized() if side.length() > 0.0001 else TOE
	var knee = a + dir * l1 * cos_a + side * l1 * sqrt(1.0 - cos_a * cos_a)
	_aim(upper, lower, knee)
	_aim(lower, end, a + dir * d)

func _commit() -> void:
	for i in _order:
		var p = skel.get_bone_parent(i)
		var local = _global(p).affine_inverse() * (_g[i] as Transform3D)
		skel.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
		if p < 0 or i == _b["Hips"]:
			skel.set_bone_pose_position(i, local.origin)

## A body frame: turned `yaw_deg` from travel (negative turns toward the toe
## edge) and bent `bend_deg` forward from vertical.
static func _frame(yaw_deg: float, bend_deg: float) -> Array:
	var y = deg_to_rad(yaw_deg)
	var f0 = Vector3(sin(y), 0.0, cos(y))
	var k = UP.cross(f0).normalized()
	var b = deg_to_rad(bend_deg)
	return [f0.rotated(k, b), UP.rotated(k, b)]

# --------------------------------------------------------------------- pose
## tuck, air, speed 0..1; squash 0..1 on landing; t is a running clock (s).
func pose(tuck: float, air: float, speed: float, squash: float, t: float) -> void:
	_g.clear(); _order.clear()
	var calm = (1.0 - air) * (1.0 - tuck)
	var breathe = sin(t * 2.4) * calm

	# Hips: low and a touch behind the board's centre so the lean balances.
	var drop = _leg * (0.25 + 0.13 * tuck + 0.08 * air + 0.04 * speed + 0.12 * squash + 0.008 * breathe)
	var hips_rest: Vector3 = (_rest_g[_b["Hips"]] as Transform3D).origin
	var hips_pos = hips_rest + Vector3(0, -drop, 0) - TOE * _leg * (0.05 + 0.07 * tuck)
	var bend = 14.0 + 22.0 * tuck + 6.0 * air + 6.0 * squash
	var f = _frame(-74.0, bend)
	var i: int = _b["Hips"]
	_put(i, Transform3D(Basis.looking_at(-f[0], f[1]) * (_rest_g[i] as Transform3D).basis, hips_pos))

	# Spine: curls forward up the chain and opens the shoulders toward travel,
	# surf-style, so the arms read wide from the chase camera behind him.
	for s in 3:
		f = _frame(-64.0 + 9.0 * s, bend + (5.0 + 4.0 * s) * (1.0 + tuck) + 1.5 * breathe)
		_orient(SPINE[s], f[0], f[1])

	# Head and neck: eyes down the line, held level against the lean.
	var look = Vector3(0, -0.12 - 0.1 * tuck + 0.15 * air, 0)
	var neck_f = (TOE * 0.6 + TRAVEL * 0.8 + look).normalized()
	var head_f = (TOE * 0.18 + TRAVEL + look).normalized()
	var lean_up = (UP + TOE * 0.12 * (1.0 + tuck)).normalized()
	_orient("neck", neck_f, lean_up)
	_orient("Head", head_f, (UP + TOE * 0.06).normalized())

	# Legs: wide stance across the board, knees tracking over the toes.
	var spread = _leg * 0.5
	for side in [1.0, -1.0]:
		var prefix = "Left" if side > 0.0 else "Right"
		var ankle = _center + Vector3(0, _ankle_y, 0) + TRAVEL * spread * side
		var pole = TOE + TRAVEL * 0.35 * side + UP * 0.1
		_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", ankle, pole)
		# Feet flat on the deck, ducked: lead toes forward, rear toes back.
		var foot_f = _frame(-90.0 + (16.0 if side > 0.0 else -10.0), 0.0)
		_orient(prefix + "Foot", foot_f[0], UP)

	# Arms: out for balance on the ground, in at the knees when tucking, flung
	# wide and high in the air.
	var sway = sin(t * 1.7) * 0.06 * calm
	for side in [1.0, -1.0]:
		var prefix = "Left" if side > 0.0 else "Right"
		var shoulder = _follow(_b[prefix + "Arm"]).origin
		var ride: Vector3
		var tucked: Vector3
		var flying: Vector3
		if side > 0.0:
			ride = shoulder + (TRAVEL * 0.75 - TOE * 0.45 - UP * (0.3 + sway)).normalized() * _arm * 0.93
			tucked = shoulder + (TOE * 0.6 + TRAVEL * 0.3 - UP * 0.75).normalized() * _arm * 0.8
			flying = shoulder + (TRAVEL * 0.6 - TOE * 0.35 + UP * 0.7).normalized() * _arm * 0.95
		else:
			ride = shoulder + (-TRAVEL * 0.7 + TOE * 0.55 - UP * (0.35 - sway)).normalized() * _arm * 0.93
			tucked = shoulder + (TOE * 0.55 - TRAVEL * 0.25 - UP * 0.8).normalized() * _arm * 0.8
			flying = shoulder + (-TRAVEL * 0.6 + TOE * 0.45 + UP * 0.6).normalized() * _arm * 0.95
		var hand = ride.lerp(tucked, tuck).lerp(flying, air)
		_limb(prefix + "Arm", prefix + "ForeArm", prefix + "Hand", hand, -UP - TOE * 0.6 - TRAVEL * 0.2 * side)

	_commit()

## Clears the procedural pose (back to the authored T-pose).
func reset() -> void:
	skel.reset_bone_poses()
