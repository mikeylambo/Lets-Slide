class_name SlideMotor
extends RefCounted

## Production slide model.
##
## The governing principle, inherited from SM64 and kept deliberately:
## steering BENDS the existing velocity vector, it does not author a new one.
## Every turn therefore costs speed, and the cost scales with how hard you turn.
## Banking gives that cost back — steering into a banked surface buys extra
## rotation for the same momentum loss, which is what makes reading terrain the
## actual skill rather than holding a direction.

const MIN_DIR = 0.0001

func step(s: MotionState, p: MotorParams, inp: MotorInput, dt: float) -> void:
	s.entry_speed = s.velocity.length()
	s.tuck = move_toward(s.tuck, 1.0 if inp.tuck else 0.0, dt * 6.0)

	if s.bonk_timer > 0.0:
		s.bonk_timer = maxf(0.0, s.bonk_timer - dt)

	if s.grounded:
		_step_ground(s, p, inp, dt)
		s.ground_time += dt
		s.air_time = 0.0
	else:
		_step_air(s, p, inp, dt)
		s.air_time += dt
		s.ground_time = 0.0

	s.speed = s.velocity.length()
	s.ground_speed = s.flat_speed()
	s.momentum_retention = 1.0 if s.entry_speed < 0.01 else clampf(s.speed / s.entry_speed, 0.0, 2.0)

# ------------------------------------------------------------------- ground
func _step_ground(s: MotionState, p: MotorParams, inp: MotorInput, dt: float) -> void:
	var n = s.floor_normal
	var v = s.velocity

	# Re-seat velocity into the ground plane without silently deleting momentum.
	# The old projection shortened the velocity vector every time the floor normal
	# rotated toward the rider, so rolling terrain could drain speed before gravity
	# or friction were even evaluated. Terrain should redirect momentum; climbing,
	# braking, steering and explicit friction are what spend it.
	var incoming_speed: float = v.length()
	var into_surface: float = v.dot(n)
	if into_surface < 0.0:
		var tangent: Vector3 = v - n * into_surface
		if tangent.length() > MIN_DIR and incoming_speed > MIN_DIR:
			v = tangent.normalized() * incoming_speed
		else:
			v = tangent

	# Steepest-descent direction on this plane.
	var down = (Vector3.DOWN - n * Vector3.DOWN.dot(n))
	var slope_sin = down.length()
	s.downhill = down.normalized() if slope_sin > MIN_DIR else Vector3.ZERO
	s.slope_deg = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))

	# 1. Gravity along the slope. The curve exponent is what separates
	#    "gentle ramps do nothing" from "everything is a black diamond".
	if slope_sin > MIN_DIR:
		var pull = p.slope_accel * pow(slope_sin, p.slope_accel_curve)
		v += s.downhill * pull * dt

	var speed = v.length()
	var dir = v / speed if speed > MIN_DIR else Vector3.ZERO

	# 2. Friction, direction-aware. Gravity already pays the main cost of climbing.
	# Extra uphill friction therefore fades in only on genuinely steep ascents;
	# shallow rollers should carry momentum instead of behaving like hidden brakes.
	if speed > MIN_DIR:
		var alignment = dir.dot(s.downhill) if slope_sin > MIN_DIR else 0.0
		var directional: float = p.downhill_friction
		if alignment < 0.0:
			var steep_uphill: float = smoothstep(0.30, 0.72, clampf(slope_sin, 0.0, 1.0))
			directional = lerpf(p.flat_friction, p.uphill_friction, steep_uphill)
		var fric: float = lerpf(p.flat_friction, directional, clampf(slope_sin, 0.0, 1.0))
		fric *= SurfaceKind.friction_scale(s.surface_class)
		fric += p.drag_quadratic * speed * speed
		if inp.brake:
			fric += p.brake_decel
		speed = maxf(0.0, speed - fric * dt)

	# 3. External-momentum surfaces. These are explicit terrain verbs: they add
	# energy because the world is moving, never because the player pressed a
	# hidden throttle.
	if s.surface_class == SurfaceKind.BOOST:
		speed += p.boost_accel * dt
	elif s.surface_class == SurfaceKind.CONVEYOR:
		speed += p.conveyor_accel * dt
	elif s.surface_class == SurfaceKind.AVALANCHE:
		speed += p.avalanche_accel * dt

	# 4. Steering: rotate the vector, pay for the rotation.
	var steer = 0.0 if s.bonk_timer > 0.0 else clampf(inp.steer, -1.0, 1.0)
	s.steer_delta_deg = 0.0
	if absf(steer) > 0.001 and speed > MIN_DIR:
		var rate = p.steering_strength * _speed_falloff(speed, p)
		rate *= _bank_assist(s, dir, steer, p)
		rate *= _countersteer_scale(s, dir, steer, p)
		var delta = deg_to_rad(rate) * steer * dt
		# Rotate about the surface normal so turns follow the terrain rather
		# than a world-up plane — this is what makes bowls and walls work.
		dir = dir.rotated(n.normalized(), -delta).normalized()
		s.steer_delta_deg = rad_to_deg(delta)

		var lock = clampf(absf(rate * steer) / maxf(p.steering_strength, 1.0), 0.0, 1.5)
		var keep = 1.0 - (1.0 - p.momentum_retention) * lock * (dt * 60.0)
		speed *= clampf(keep, 0.5, 1.0)

	# 4b. Weight transfer. The stick changes retention only when the terrain is
	# changing under the rider. Flat terrain has curvature ~= 0 and therefore
	# receives no bonus. Positive lean loads compressions; negative lean releases
	# crests. This cannot be pumped for free speed on a plane.
	var curvature: float = clampf(s.floor_normal.angle_to(s.previous_floor_normal) / maxf(dt, 0.001), 0.0, 2.0)
	var vertical_change: float = s.floor_normal.y - s.previous_floor_normal.y
	if curvature > 0.001 and absf(inp.lean) > 0.05:
		var timing = 0.0
		if vertical_change < -0.0005 and inp.lean > 0.0:
			timing = inp.lean * p.compression_bonus
		elif vertical_change > 0.0005 and inp.lean < 0.0:
			timing = -inp.lean * p.crest_release
		if timing > 0.0:
			# Scale by time: this is a small retention benefit over the curved beat,
			# not a per-tick multiplicative pump. Flat terrain still yields zero.
			speed *= 1.0 + timing * p.weight_transfer_strength * minf(curvature, 1.0) * dt * 4.0

	# 5. Caps and the stop threshold.
	speed = minf(speed, p.max_speed)
	if speed < p.min_slide_speed and slope_sin < 0.09:
		speed = 0.0

	v = dir * speed
	if s.surface_class == SurfaceKind.AVALANCHE and dir.length() > MIN_DIR:
		var avalanche_side = dir.cross(n).normalized()
		v += avalanche_side * sin(Time.get_ticks_msec() * 0.0023) * p.avalanche_drift * dt
	# Let gravity keep pressing into the surface so we hug convex terrain
	# instead of ballooning off every crest; the driver's snap does the rest.
	v += n * -absf(p.gravity) * dt * 0.15

	if p.enable_jump and inp.jump_pressed:
		v += n * p.jump_impulse
		s.grounded = false

	s.velocity = v
	_track_facing(s, p, dt, true)

# ---------------------------------------------------------------------- air
func _step_air(s: MotionState, p: MotorParams, inp: MotorInput, dt: float) -> void:
	var v = s.velocity
	var tuck: float = s.tuck

	var g: float = p.gravity * lerpf(1.0, p.tuck_gravity_scale, tuck)
	v.y -= g * dt
	if inp.lean < -0.1:
		v.y += p.extend_lift * -inp.lean * dt
	v.y = maxf(v.y, -p.terminal_velocity)

	var flat = Vector3(v.x, 0.0, v.z)
	var flat_speed = flat.length()
	if flat_speed > MIN_DIR:
		var fdir = flat / flat_speed
		var steer = 0.0 if s.bonk_timer > 0.0 else clampf(inp.steer, -1.0, 1.0)
		if absf(steer) > 0.001:
			var rate: float = minf(p.air_steering, p.air_max_rotation_rate)
			var delta = deg_to_rad(rate) * steer * dt
			fdir = fdir.rotated(Vector3.UP, -delta).normalized()
			s.steer_delta_deg = rad_to_deg(delta)
			# Lateral shove on top of the rotation: this is the difference
			# between "aiming" in the air and actually correcting a bad line.
			var side = fdir.cross(Vector3.UP).normalized()
			flat_speed = flat_speed
			flat = fdir * flat_speed + side * (p.air_lateral_accel * -steer * dt)
			flat_speed = flat.length()
			fdir = flat / maxf(flat_speed, MIN_DIR)
		else:
			s.steer_delta_deg = 0.0

		if inp.lean > 0.1:
			flat_speed += p.air_forward_accel * inp.lean * dt

		var drag: float = p.air_drag * lerpf(1.0, p.tuck_drag_scale, tuck)
		flat_speed = maxf(0.0, flat_speed - drag * flat_speed * flat_speed * dt)
		flat = fdir * flat_speed

	v.x = flat.x
	v.z = flat.z
	s.velocity = v
	s.slope_deg = 0.0
	_track_facing(s, p, dt, false)

# ------------------------------------------------------------------- events
func on_takeoff(s: MotionState, _p: MotorParams) -> void:
	s.last_launch_speed = s.velocity.length()
	s.airborne_launch_pos = s.position

func on_landing(s: MotionState, p: MotorParams) -> void:
	var speed = s.velocity.length()
	s.last_landing_speed = speed
	if speed < MIN_DIR:
		s.last_landing_quality = 1.0
		return

	var n = s.floor_normal
	var dir = s.velocity / speed
	# Flush landing == velocity already parallel to the new surface.
	var q: float = pow(clampf(1.0 - absf(dir.dot(n)), 0.0, 1.0), p.landing_alignment_power)
	s.last_landing_quality = q

	var planar = s.velocity - n * s.velocity.dot(n)
	if planar.length() < MIN_DIR:
		planar = s.downhill * 0.01
	var retention: float = lerpf(p.bad_landing_penalty, p.landing_retention, q)
	s.velocity = planar.normalized() * speed * retention

func on_wall(s: MotionState, p: MotorParams, wall_normal: Vector3) -> bool:
	## Returns true if this was a bonk (hard stop) rather than a graze.
	var speed = s.velocity.length()
	if speed < MIN_DIR:
		return false
	var dir = s.velocity / speed
	var head_on = -dir.dot(wall_normal)

	if head_on >= p.bonk_threshold and speed >= p.bonk_speed_threshold:
		s.last_bonk_speed = speed
		s.bonk_timer = p.bonk_lockout
		var reflected = dir.slide(wall_normal)
		if reflected.length() < MIN_DIR:
			reflected = wall_normal
		s.velocity = reflected.normalized() * speed * p.bonk_restitution
		s.velocity += wall_normal * p.wall_deflection * speed * 0.25
		return true

	# Glancing: keep the line, pay a small tax, get nudged off the wall.
	var along = dir.slide(wall_normal)
	if along.length() < MIN_DIR:
		along = wall_normal
	s.velocity = along.normalized() * speed * p.glancing_retention
	s.velocity += wall_normal * p.wall_deflection
	return false

# ------------------------------------------------------------------ helpers
func _speed_falloff(speed: float, p: MotorParams) -> float:
	## High speed must be harder to turn without ever feeling like input loss.
	var t = clampf(speed / maxf(p.max_speed, 1.0), 0.0, 1.0)
	return 1.0 / (1.0 + p.steering_speed_falloff * t * 2.5)

func _bank_assist(s: MotionState, dir: Vector3, steer: float, p: MotorParams) -> float:
	## Steering into a banked surface earns extra rotation for the same cost.
	if p.carve_grip <= 0.0:
		return 1.0
	var side = dir.cross(Vector3.UP)
	if side.length() < MIN_DIR:
		return 1.0
	side = side.normalized()
	var bank = s.floor_normal.dot(side)  # >0 means the surface banks left
	var into = clampf(-bank * signf(steer), -1.0, 1.0)
	return 1.0 + p.carve_grip * into * 1.2

func _countersteer_scale(s: MotionState, dir: Vector3, steer: float, p: MotorParams) -> float:
	## Recovering a bad line should be more responsive than committing to one.
	var facing = Vector3(sin(s.facing_yaw), 0.0, cos(s.facing_yaw))
	var drift = facing.cross(dir).y
	if absf(drift) < 0.02:
		return 1.0
	return p.countersteer_strength if signf(drift) == signf(steer) else 1.0

func _track_facing(s: MotionState, p: MotorParams, dt: float, grounded: bool) -> void:
	## The body chases the velocity heading with lag; the gap IS the drift the
	## player reads on screen.
	var flat = Vector2(s.velocity.x, s.velocity.z)
	if flat.length() < 0.05:
		return
	var target = atan2(flat.x, flat.y)
	var rate = deg_to_rad(p.air_max_rotation_rate if not grounded else p.air_max_rotation_rate * 1.5)
	s.facing_yaw = _approach_angle(s.facing_yaw, target, rate * dt)

static func _approach_angle(current: float, target: float, max_delta: float) -> float:
	var d = wrapf(target - current, -PI, PI)
	if absf(d) <= max_delta:
		return target
	return current + signf(d) * max_delta
