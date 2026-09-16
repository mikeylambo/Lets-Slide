class_name SlideCamera
extends Node3D

## Chase camera whose pivot is physically anchored to the rider. The old rig
## projected the pivot down-track, which could literally push the player out of
## frame. Here lookahead changes aim/pitch only; framing remains invariant.

var params = CameraParams.new()
var target: SlideBody
var _arm: SpringArm3D
var _camera: Camera3D
var _yaw = 0.0
var _pitch = 0.0
var _roll = 0.0
var _fov = 70.0
var _anchor = Vector3.ZERO
var _shake = 0.0
var _shake_seed = 0.0
var _initialised = false
var _intro_active = false
var _intro_elapsed = 0.0
var _intro_start_yaw = 0.0
var _intro_end_yaw = 0.0

func _ready() -> void:
	_arm = SpringArm3D.new()
	_arm.spring_length = params.follow_distance
	_arm.margin = 0.3
	_arm.collision_mask = 1
	add_child(_arm)
	_camera = Camera3D.new()
	_camera.fov = params.fov_base
	_camera.near = 0.08
	_camera.far = 3000.0
	_camera.current = true
	_arm.add_child(_camera)
	_fov = params.fov_base
	_shake_seed = randf() * 100.0
	set_as_top_level(true)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func bind(slider: SlideBody) -> void:
	target = slider
	# The spring arm casts through world layer 1, so explicitly exclude the
	# rider's CharacterBody or the camera can collapse into the player capsule.
	if _arm != null:
		_arm.add_excluded_object(slider.get_rid())
	if not slider.landed.is_connected(_on_landed): slider.landed.connect(_on_landed)
	if not slider.bonked.is_connected(_on_bonked): slider.bonked.connect(_on_bonked)
	snap_to_target()

func get_camera() -> Camera3D: return _camera

func snap_to_target() -> void:
	if target == null: return
	_anchor = target.global_position + Vector3.UP * params.follow_height
	var flat = target.state.flat_velocity()
	var travel_yaw = atan2(flat.x, flat.z) if flat.length() > 0.5 else target.state.facing_yaw
	_yaw = wrapf(travel_yaw + PI, -PI, PI)
	_pitch = deg_to_rad(params.pitch_base)
	_roll = 0.0
	_intro_active = false
	_initialised = true
	_apply(0.0, true)

func play_start_swivel(travel_yaw: float) -> void:
	if target == null: return
	_anchor = target.global_position + Vector3.UP * params.follow_height
	_pitch = deg_to_rad(params.pitch_base)
	_roll = 0.0
	_intro_elapsed = 0.0
	# Start in FRONT (+Z travel direction) looking back at the rider, then orbit
	# into the normal behind-rider chase shot during countdown.
	_intro_start_yaw = wrapf(travel_yaw, -PI, PI)
	_intro_end_yaw = wrapf(travel_yaw + PI, -PI, PI)
	_yaw = _intro_start_yaw
	_intro_active = params.intro_swivel_enabled
	if not _intro_active: _yaw = _intro_end_yaw
	_initialised = true
	_apply(0.0, true)

func _process(delta: float) -> void:
	if target == null: return
	if not _initialised: snap_to_target(); return
	_apply(delta, false)

func _apply(delta: float, snap: bool) -> void:
	var s = target.state
	var speed = s.speed
	var speed_t = clampf(speed / maxf(target.params.max_speed, 1.0), 0.0, 1.0)
	var blend = func(rate: float) -> float: return 1.0 if snap else clampf(1.0 - exp(-rate * delta), 0.0, 1.0)

	# Player-anchored pivot. This is the framing guarantee.
	var anchor_height = params.follow_height + params.height_speed_gain * speed
	if not s.grounded: anchor_height += params.air_height_bonus * clampf(s.air_time / 1.2, 0.0, 1.0)
	var desired_anchor = target.global_position + Vector3.UP * anchor_height
	_anchor = _anchor.lerp(desired_anchor, blend.call(params.position_damping))

	var flat = s.flat_velocity()
	var travel_yaw = atan2(flat.x, flat.z) if flat.length() > 1.2 else s.facing_yaw
	var chase_yaw = wrapf(travel_yaw + PI, -PI, PI)
	if _intro_active:
		_intro_elapsed += delta
		var duration = maxf(params.intro_swivel_duration, 0.001)
		var raw_t = clampf((_intro_elapsed - params.intro_hold) / duration, 0.0, 1.0)
		var eased = raw_t * raw_t * (3.0 - 2.0 * raw_t)
		_yaw = lerp_angle(_intro_start_yaw, _intro_end_yaw, eased)
		if raw_t >= 1.0: _intro_active = false; _yaw = _intro_end_yaw
	elif flat.length() > 1.2:
		var tighten = params.yaw_damping * (1.0 + params.yaw_speed_tighten * speed_t)
		var next = _damp_angle(_yaw, chase_yaw, tighten, delta if not snap else 1.0)
		var max_step = deg_to_rad(params.yaw_max_rate) * maxf(delta, 0.0001)
		var d = wrapf(next - _yaw, -PI, PI)
		_yaw += clampf(d, -max_step, max_step)

	var want_pitch = deg_to_rad(params.pitch_base)
	if not _intro_active:
		var lead = s.velocity * params.lookahead_time
		if lead.length() > params.lookahead_max: lead = lead.normalized() * params.lookahead_max
		var horiz = Vector2(lead.x, lead.z).length()
		if horiz > 0.1: want_pitch += atan2(-lead.y, horiz) * 0.18
		var ahead = _probe_ahead(travel_yaw)
		if ahead.has("drop"):
			want_pitch += atan2(float(ahead["drop"]) * params.vertical_lookahead, maxf(params.terrain_anticipation, 1.0)) * params.pitch_slope_follow
		if not s.grounded:
			var landing = _predict_landing()
			if landing.has("point"):
				var to_land: Vector3 = landing["point"] - target.global_position
				var lh = Vector2(to_land.x, to_land.z).length()
				var aim = atan2(-to_land.y, maxf(lh, 1.0))
				want_pitch = lerpf(want_pitch, aim, params.landing_aim_weight)
	want_pitch = clampf(want_pitch, deg_to_rad(params.pitch_min), deg_to_rad(params.pitch_max))
	_pitch = lerpf(_pitch, want_pitch, blend.call(params.pitch_damping))

	var want_roll = 0.0
	if s.grounded:
		var travel_fwd = Vector3(sin(travel_yaw), 0.0, cos(travel_yaw)).normalized()
		var side = travel_fwd.cross(Vector3.UP).normalized()
		var bank = clampf(s.floor_normal.dot(side), -1.0, 1.0)
		want_roll = asin(bank) * params.roll_from_bank
	want_roll = clampf(want_roll, -deg_to_rad(params.roll_max), deg_to_rad(params.roll_max))
	_roll = lerpf(_roll, want_roll, blend.call(params.roll_damping))

	var dist = params.follow_distance + params.distance_speed_gain * speed
	if not s.grounded: dist += params.air_distance_bonus * clampf(s.air_time / 1.2, 0.0, 1.0)
	_arm.spring_length = dist
	global_position = _anchor
	var b = Basis.IDENTITY
	b = b.rotated(Vector3.UP, _yaw)
	b = b.rotated(b.x, -_pitch)
	b = b.rotated(b.z, _roll)
	global_basis = b.orthonormalized()

	var fx_scale = float(Game.settings.get("speed_effects", 1.0))
	var fov_scale = float(Game.settings.get("fov_scale", 1.0))
	var want_fov = minf((params.fov_base + params.fov_speed_gain * speed * fx_scale) * fov_scale, params.fov_max * maxf(fov_scale, 0.5))
	var rate = params.fov_attack if want_fov > _fov else params.fov_release
	_fov = lerpf(_fov, want_fov, blend.call(rate))
	_camera.fov = _fov

	if _shake > 0.001:
		_shake = maxf(0.0, _shake - params.shake_decay * delta * _shake)
		var shake_setting = float(Game.settings.get("camera_shake", 1.0))
		var t = Time.get_ticks_msec() * 0.001 + _shake_seed
		_camera.position = Vector3(sin(t * 47.0), cos(t * 39.0), sin(t * 61.0)) * _shake * 0.12 * shake_setting
		_camera.rotation.z = sin(t * 53.0) * _shake * 0.025 * shake_setting
	else:
		_camera.position = Vector3.ZERO
		_camera.rotation.z = 0.0

func _probe_ahead(travel_yaw: float) -> Dictionary:
	if params.terrain_anticipation <= 0.1: return {}
	var space = target.get_world_3d().direct_space_state
	var fwd = Vector3(sin(travel_yaw), 0.0, cos(travel_yaw)).normalized()
	var origin = target.global_position + fwd * params.terrain_anticipation + Vector3.UP * 7.0
	var q = PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 240.0)
	q.exclude = [target.get_rid()]
	var hit = space.intersect_ray(q)
	if hit.is_empty(): return {"drop": 38.0}
	return {"drop": target.global_position.y - float(hit["position"].y)}

func _predict_landing() -> Dictionary:
	var space = target.get_world_3d().direct_space_state
	var p = target.global_position
	var v = target.state.velocity
	var g = target.params.gravity
	var dt = 0.09
	for i in 34:
		var next = p + v * dt
		v.y -= g * dt
		var q = PhysicsRayQueryParameters3D.create(p, next)
		q.exclude = [target.get_rid()]
		var hit = space.intersect_ray(q)
		if not hit.is_empty(): return {"point": hit["position"], "time": float(i) * dt}
		p = next
	return {}

func add_shake(amount: float) -> void: _shake = minf(_shake + amount, 2.5)
func _on_landed(quality: float, speed: float) -> void:
	add_shake(params.shake_landing * (1.0 - clampf(quality, 0.0, 1.0)) * clampf(speed / 40.0, 0.2, 1.4))
func _on_bonked(speed: float) -> void: add_shake(params.shake_bonk * clampf(speed / 35.0, 0.3, 1.5))
static func _damp_angle(current: float, target_a: float, rate: float, delta: float) -> float:
	var d = wrapf(target_a - current, -PI, PI)
	return current + d * clampf(1.0 - exp(-rate * delta), 0.0, 1.0)
