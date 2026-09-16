class_name Sm64Motor
extends RefCounted

## SM64 REFERENCE.
##
## This is a transcription of the slide equations from the Super Mario 64
## decompilation (`update_sliding`, `update_sliding_angle`, and the air step),
## working in the original units/frame domain at the original 30 Hz. It is the
## baseline we compare against — it is deliberately NOT improved, smoothed, or
## reinterpreted. When our model starts feeling wrong six months from now, this
## is the thing that still tells the truth about where we started.
##
## Faithful: constants, equation structure, the s16 angle domain, the 0x200
## per-frame facing correction, the quadrant clamps, the late speed cap, the
## intendedMag/forward loss factor, the velocity renormalisation after the
## sideward nudge.
##
## Not faithful: the ROM's sine lookup table and f32 rounding. We use doubles.
## Collision is Godot's, not SM64's triangle/wall-displacement pipeline.

const AIR_TERMINAL = -75.0        ## units/frame
const AIR_DRAG_THRESHOLD = 32.0
const AIR_FORWARD_GAIN = 1.5
const AIR_FACE_GAIN = 512.0
const BONK_SPEED = 16.0           ## units/frame — SM64's wall bonk threshold

func step(s: MotionState, p: MotorParams, inp: MotorInput, dt: float) -> void:
	var hz: float = maxf(p.sm64_hz, 1.0)
	var to_units: float = Sm64Math.M_TO_UNITS / hz   # m/s -> units/frame
	var to_ms: float = Sm64Math.UNITS_TO_M * hz      # units/frame -> m/s

	s.entry_speed = s.velocity.length()

	s.sm64_slide_vel_x = s.velocity.x * to_units
	s.sm64_slide_vel_z = s.velocity.z * to_units
	var vel_y: float = s.velocity.y * to_units

	var intended_yaw = inp.intended_yaw_s16(s.sm64_face_yaw)
	var intended_mag: float = inp.stick_magnitude() * 32.0

	if s.grounded:
		_update_sliding(s, p, intended_yaw, intended_mag)
		vel_y = -1.0  # SM64 keeps a small downward bias while grounded
		s.slope_deg = rad_to_deg(acos(clampf(s.floor_normal.y, -1.0, 1.0)))
		s.ground_time += dt
		s.air_time = 0.0
	else:
		vel_y = maxf(vel_y - p.sm64_gravity, AIR_TERMINAL)
		_update_air(s, p, intended_yaw, intended_mag)
		s.slope_deg = 0.0
		s.air_time += dt
		s.ground_time = 0.0

	s.velocity = Vector3(s.sm64_slide_vel_x, vel_y, s.sm64_slide_vel_z) * to_ms
	s.facing_yaw = Sm64Math.s16_to_rad(s.sm64_face_yaw)
	s.speed = s.velocity.length()
	s.ground_speed = s.flat_speed()
	s.momentum_retention = 1.0 if s.entry_speed < 0.01 else clampf(s.speed / s.entry_speed, 0.0, 2.0)
	s.tuck = 0.0  # no tuck in the reference model

# ------------------------------------------------------------ update_sliding
func _update_sliding(s: MotionState, p: MotorParams, intended_yaw: int, intended_mag: float) -> void:
	var intended_dyaw = Sm64Math.wrap_s16(intended_yaw - s.sm64_slide_yaw)
	var forward = Sm64Math.coss(intended_dyaw)
	var sideward = Sm64Math.sins(intended_dyaw)

	# Pulling back at speed is damped rather than instant — the original's
	# "you cannot simply decide to stop" rule.
	if forward < 0.0 and s.sm64_forward_vel >= 0.0:
		forward *= 0.5 + 0.5 * s.sm64_forward_vel / 100.0

	var accel: float = p.sm64_accel_for(s.surface_class)
	var loss_base: float = p.sm64_loss_base_for(s.surface_class)
	var mag_div: float = 32.0 if s.surface_class == SurfaceKind.VERY_SLIPPERY or s.surface_class == SurfaceKind.BOOST else 8.0
	var loss_factor: float = intended_mag / mag_div * forward * 0.02 + loss_base

	var old_speed = sqrt(s.sm64_slide_vel_x * s.sm64_slide_vel_x + s.sm64_slide_vel_z * s.sm64_slide_vel_z)

	# The sideward nudge: it rotates the vector, and the renormalisation below
	# takes the speed straight back. This pair is the reason SM64 sliding feels
	# physical instead of like driving — turning redirects momentum, it does
	# not manufacture it.
	s.sm64_slide_vel_x += s.sm64_slide_vel_z * (intended_mag / 32.0) * sideward * 0.05
	s.sm64_slide_vel_z -= s.sm64_slide_vel_x * (intended_mag / 32.0) * sideward * 0.05

	var new_speed = sqrt(s.sm64_slide_vel_x * s.sm64_slide_vel_x + s.sm64_slide_vel_z * s.sm64_slide_vel_z)
	if old_speed > 0.0 and new_speed > 0.0:
		s.sm64_slide_vel_x = s.sm64_slide_vel_x * old_speed / new_speed
		s.sm64_slide_vel_z = s.sm64_slide_vel_z * old_speed / new_speed

	_update_sliding_angle(s, p, accel, loss_factor)

	if s.slope_deg < 1.0 and absf(s.sm64_forward_vel) < p.sm64_stop_speed:
		s.sm64_forward_vel = 0.0
		s.sm64_slide_vel_x = 0.0
		s.sm64_slide_vel_z = 0.0

# ------------------------------------------------------ update_sliding_angle
func _update_sliding_angle(s: MotionState, p: MotorParams, accel: float, loss_factor: float) -> void:
	var n = s.floor_normal
	var slope_angle = Sm64Math.atan2s(n.z, n.x)
	var steepness = sqrt(n.x * n.x + n.z * n.z)

	s.downhill = Vector3(n.x, 0.0, n.z).normalized() if steepness > 0.0001 else Vector3.ZERO

	s.sm64_slide_vel_x += accel * steepness * Sm64Math.sins(slope_angle)
	s.sm64_slide_vel_z += accel * steepness * Sm64Math.coss(slope_angle)

	s.sm64_slide_vel_x *= loss_factor
	s.sm64_slide_vel_z *= loss_factor

	s.sm64_slide_yaw = Sm64Math.atan2s(s.sm64_slide_vel_z, s.sm64_slide_vel_x)

	# Facing chases the slide direction 0x200 (512) units per frame, with the
	# original's quadrant handling — including the fact that a facing exactly
	# perpendicular to the slide never resolves.
	var step_amt = int(p.sm64_facing_correction)
	var facing_dyaw = Sm64Math.wrap_s16(s.sm64_face_yaw - s.sm64_slide_yaw)
	var new_dyaw = facing_dyaw

	if new_dyaw > 0 and new_dyaw <= 0x4000:
		new_dyaw -= step_amt
		if new_dyaw < 0:
			new_dyaw = 0
	elif new_dyaw > -0x4000 and new_dyaw < 0:
		new_dyaw += step_amt
		if new_dyaw > 0:
			new_dyaw = 0
	elif new_dyaw > 0x4000 and new_dyaw < 0x8000:
		new_dyaw += step_amt
		if new_dyaw > 0x8000:
			new_dyaw = 0x8000
	elif new_dyaw > -0x8000 and new_dyaw < -0x4000:
		new_dyaw -= step_amt
		if new_dyaw < -0x8000:
			new_dyaw = -0x8000

	s.sm64_face_yaw = Sm64Math.wrap_s16(s.sm64_slide_yaw + new_dyaw)

	s.sm64_forward_vel = sqrt(s.sm64_slide_vel_x * s.sm64_slide_vel_x + s.sm64_slide_vel_z * s.sm64_slide_vel_z)

	# The cap is applied a frame late in the original. Preserved.
	if s.sm64_forward_vel > p.sm64_speed_cap:
		var k: float = p.sm64_speed_cap / s.sm64_forward_vel
		s.sm64_slide_vel_x *= k
		s.sm64_slide_vel_z *= k
		s.sm64_forward_vel = p.sm64_speed_cap

	if new_dyaw < -0x4000 or new_dyaw > 0x4000:
		s.sm64_forward_vel *= -1.0

	s.steer_delta_deg = rad_to_deg(Sm64Math.s16_to_rad(Sm64Math.wrap_s16(new_dyaw - facing_dyaw)))

# ---------------------------------------------------- update_air_without_turn
func _update_air(s: MotionState, p: MotorParams, intended_yaw: int, intended_mag: float) -> void:
	var fwd: float = sqrt(s.sm64_slide_vel_x * s.sm64_slide_vel_x + s.sm64_slide_vel_z * s.sm64_slide_vel_z)
	if s.sm64_forward_vel < 0.0:
		fwd = -fwd

	var drag: float = p.sm64_air_steer  # decomp: approach_f32(fwd, 0, 0.35, 0.35)
	fwd = move_toward(fwd, 0.0, drag)

	if intended_mag > 0.5:
		var dyaw = Sm64Math.wrap_s16(intended_yaw - s.sm64_face_yaw)
		var mag: float = intended_mag / 32.0
		fwd += AIR_FORWARD_GAIN * Sm64Math.coss(dyaw) * mag
		s.sm64_face_yaw = Sm64Math.wrap_s16(s.sm64_face_yaw + int(round(AIR_FACE_GAIN * Sm64Math.sins(dyaw) * mag)))

	if fwd > AIR_DRAG_THRESHOLD:
		fwd -= 1.0
	if fwd < -16.0:
		fwd += 2.0

	s.sm64_forward_vel = fwd
	s.sm64_slide_vel_x = fwd * Sm64Math.sins(s.sm64_face_yaw)
	s.sm64_slide_vel_z = fwd * Sm64Math.coss(s.sm64_face_yaw)
	s.sm64_slide_yaw = s.sm64_face_yaw

# ------------------------------------------------------------------- events
func on_takeoff(s: MotionState, _p: MotorParams) -> void:
	s.last_launch_speed = s.velocity.length()
	s.airborne_launch_pos = s.position

func on_landing(s: MotionState, _p: MotorParams) -> void:
	## SM64 does not convert fall speed into ground speed. Landing simply
	## resumes the slide with whatever horizontal velocity survived. That gap
	## versus our model is one of the most informative A/B comparisons we have.
	var flat = Vector3(s.velocity.x, 0.0, s.velocity.z)
	s.last_landing_speed = s.velocity.length()
	var n = s.floor_normal
	var planar = flat - n * flat.dot(n)
	if planar.length() > 0.0001:
		s.velocity = planar.normalized() * flat.length()
	else:
		s.velocity = flat
	s.last_landing_quality = 1.0

func on_wall(s: MotionState, p: MotorParams, wall_normal: Vector3) -> bool:
	var hz: float = maxf(p.sm64_hz, 1.0)
	var units: float = s.velocity.length() * Sm64Math.M_TO_UNITS / hz
	if units > BONK_SPEED:
		var back = wall_normal * (BONK_SPEED * 0.5) * Sm64Math.UNITS_TO_M * hz
		s.velocity = Vector3(back.x, s.velocity.y, back.z)
		s.sm64_forward_vel = -BONK_SPEED * 0.5
		s.bonk_timer = 0.5
		s.last_bonk_speed = units * Sm64Math.UNITS_TO_M * hz
		return true
	var along = s.velocity.slide(wall_normal)
	s.velocity = along
	return false
