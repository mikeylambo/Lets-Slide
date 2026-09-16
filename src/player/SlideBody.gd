class_name SlideBody
extends CharacterBody3D

## The driver. It owns collision, ground probing and position; it does NOT own
## movement. Both motors see the identical world through MotionState, which is
## what makes the A/B comparison honest — nothing about the terrain, probe or
## collision response changes when you flip models.

signal landed(quality: float, speed: float)
signal took_off(speed: float)
signal bonked(speed: float)
signal model_changed(model: int)

const BODY_RADIUS = 0.45
const MAX_SLIDE_ITERATIONS = 4

var params: MotorParams
var state = MotionState.new()
var input = MotorInput.new()

var production_motor = SlideMotor.new()
var reference_motor = Sm64Motor.new()
var active_motor: RefCounted

var control_enabled = true
var camera_basis = Basis.IDENTITY   ## set by the camera each frame
var external_input = Callable()     ## optional: drives input instead of the device

var _visual: Node3D
var _board: MeshInstance3D
var _core: MeshInstance3D
var _trail: Node3D
var _shape: CollisionShape3D
var _spawn_position = Vector3.ZERO
var _spawn_yaw = 0.0

func _ready() -> void:
	if params == null:
		params = MotorParams.new()
	active_motor = production_motor if params.model == MotorParams.Model.PRODUCTION else reference_motor
	_build_body()
	_build_visual()
	apply_simulation_rate()
	state.reset(global_position)
	_spawn_position = global_position

func _build_body() -> void:
	_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = BODY_RADIUS
	_shape.shape = sphere
	add_child(_shape)
	# We resolve collisions ourselves; the built-in floor logic would fight the
	# motor's surface handling.
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.02

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var board_mesh = BoxMesh.new()
	board_mesh.size = Vector3(0.72, 0.09, 1.7)
	_board = MeshInstance3D.new()
	_board.mesh = board_mesh
	_board.position = Vector3(0, -0.36, 0)
	var palette = Game.cosmetic_palette()
	_board.material_override = _neon_material(palette["board"], 1.8)
	_visual.add_child(_board)

	var core_mesh = CapsuleMesh.new()
	core_mesh.radius = 0.26
	core_mesh.height = 1.0
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	_core.position = Vector3(0, 0.12, -0.05)
	_core.rotation_degrees = Vector3(-12, 0, 0)
	_core.material_override = _neon_material(palette["core"], 1.2)
	_visual.add_child(_core)

	_trail = SpeedTrail.new()
	_trail.top_level = true
	add_child(_trail)

static func _neon_material(c: Color, energy: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.55)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.35
	m.metallic = 0.1
	return m

# ------------------------------------------------------------------- control
func set_model(model: int) -> void:
	if params.model == model:
		return
	params.model = model
	active_motor = production_motor if model == MotorParams.Model.PRODUCTION else reference_motor
	apply_simulation_rate()
	model_changed.emit(model)

func toggle_model() -> void:
	set_model(MotorParams.Model.SM64_REFERENCE if params.model == MotorParams.Model.PRODUCTION else MotorParams.Model.PRODUCTION)

func apply_simulation_rate() -> void:
	## The reference genuinely runs at 30 Hz. Anything else is a reinterpretation,
	## so we move the whole physics clock rather than sub-stepping it.
	var hz: float = params.sm64_hz if params.model == MotorParams.Model.SM64_REFERENCE else params.simulation_hz
	Engine.physics_ticks_per_second = int(clampf(hz, 10.0, 480.0))

func set_spawn(pos: Vector3, yaw: float = 0.0) -> void:
	_spawn_position = pos
	_spawn_yaw = yaw

func respawn(pos: Vector3 = Vector3.INF, yaw: float = 0.0) -> void:
	var target: Vector3 = _spawn_position if pos == Vector3.INF else pos
	var y: float = _spawn_yaw if pos == Vector3.INF else yaw
	global_position = target
	velocity = Vector3.ZERO
	state.reset(target, y)
	if _trail and _trail.has_method("clear_trail"):
		_trail.call("clear_trail")

func launch(v: Vector3) -> void:
	state.velocity = v
	state.grounded = false

# ------------------------------------------------------------------ the tick
func _physics_process(delta: float) -> void:
	_gather_input()
	state.position = global_position

	var was = state.grounded
	state.was_grounded = was
	state.previous_floor_normal = state.floor_normal
	_probe_ground()

	if state.grounded and not was:
		active_motor.call("on_landing", state, params)
		if params.model == MotorParams.Model.PRODUCTION and absf(input.lean) > 0.05:
			# Weight transfer can improve how much of the incoming momentum survives
			# the landing, but can never create more speed than arrived with the rider.
			var retained = state.velocity.length()
			var bonus = params.landing_match_bonus * state.last_landing_quality * absf(input.lean)
			var target_speed = minf(state.last_landing_speed, retained * (1.0 + bonus))
			if retained > 0.001:
				state.velocity = state.velocity.normalized() * target_speed
		landed.emit(state.last_landing_quality, state.last_landing_speed)
	elif not state.grounded and was:
		active_motor.call("on_takeoff", state, params)
		took_off.emit(state.last_launch_speed)

	active_motor.call("step", state, params, input, delta)
	_integrate(delta)
	_snap_to_ground()

	state.position = global_position
	velocity = state.velocity
	_update_visual(delta)

func _gather_input() -> void:
	if not control_enabled:
		input.clear()
		return
	# An external controller (autopilot probe, future replay or AI) can drive
	# the same input packet the player uses, so it exercises the real motor.
	if external_input.is_valid():
		input.clear()
		external_input.call(input, self)
		return
	var raw = Input.get_vector("steer_left", "steer_right", "lean_forward", "lean_back")
	input.steer = raw.x
	input.lean = -raw.y
	var fwd = -camera_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right = Vector3.UP.cross(fwd).normalized() * -1.0
	input.move_dir = (right * raw.x + fwd * -raw.y)
	if input.move_dir.length() > 1.0:
		input.move_dir = input.move_dir.normalized()
	input.tuck = Input.is_action_pressed("tuck")
	input.brake = Input.is_action_pressed("brake")
	input.jump_pressed = params.enable_jump and Input.is_action_just_pressed("dev_jump")

## Multi-direction adhesion probe. Downward rays reacquire ordinary terrain;
## once grounded, a second fan follows the previous surface normal so bank-to-
## wall, corkscrew and full-pipe geometry remain a continuous ride instead of
## turning into arbitrary wall collisions near vertical.
func _probe_ground() -> void:
	var space = get_world_3d().direct_space_state
	var reach: float = BODY_RADIUS + maxf(params.ground_snap_distance, 0.01)
	var probe_dirs: Array[Vector3] = [Vector3.DOWN]
	if state.was_grounded:
		probe_dirs.append(-state.previous_floor_normal.normalized())
		probe_dirs.append((Vector3.DOWN - state.previous_floor_normal).normalized())

	var best_distance = INF
	var best_hit: Dictionary = {}
	var tangent_a = Vector3.RIGHT
	var tangent_b = Vector3.FORWARD
	if state.was_grounded:
		tangent_a = state.previous_floor_normal.cross(Vector3.FORWARD)
		if tangent_a.length() < 0.01:
			tangent_a = state.previous_floor_normal.cross(Vector3.RIGHT)
		tangent_a = tangent_a.normalized()
		tangent_b = state.previous_floor_normal.cross(tangent_a).normalized()
	var r: float = params.ground_probe_radius
	var offsets = [Vector3.ZERO, tangent_a * r, -tangent_a * r, tangent_b * r, -tangent_b * r]

	for probe_dir in probe_dirs:
		if probe_dir.length() < 0.01:
			continue
		probe_dir = probe_dir.normalized()
		for off in offsets:
			var from: Vector3 = global_position + off
			var to: Vector3 = from + probe_dir * (reach + 0.28)
			var q = PhysicsRayQueryParameters3D.create(from, to)
			q.exclude = [get_rid()]
			q.collide_with_areas = false
			var hit = space.intersect_ray(q)
			if hit.is_empty():
				continue
			var n: Vector3 = hit["normal"].normalized()
			var acceptable = false
			if state.was_grounded:
				acceptable = rad_to_deg(n.angle_to(state.previous_floor_normal)) <= params.surface_normal_follow_angle
			else:
				acceptable = rad_to_deg(acos(clampf(n.y, -1.0, 1.0))) <= params.ground_reacquire_angle
			if not acceptable:
				continue
			var d: float = from.distance_to(hit["position"])
			if d < best_distance:
				best_distance = d
				best_hit = hit

	if best_hit.is_empty():
		state.grounded = false
		# Keep the old normal during the first airborne tick; it is useful for
		# visual continuity and for reacquiring a surface immediately after a crest.
		return

	var n: Vector3 = best_hit["normal"].normalized()
	var within: bool = best_distance <= reach + params.edge_tolerance
	var separating: bool = state.velocity.dot(n) > 2.2 and not state.was_grounded
	state.grounded = within and not separating
	state.floor_normal = n
	if best_hit["collider"] and best_hit["collider"].has_meta("surface_class"):
		state.surface_class = int(best_hit["collider"].get_meta("surface_class"))

func _integrate(delta: float) -> void:
	var motion = state.velocity * delta
	for i in MAX_SLIDE_ITERATIONS:
		if motion.length() < 0.00001:
			break
		var col = move_and_collide(motion)
		if col == null:
			break
		var n = col.get_normal().normalized()
		var normal_delta = rad_to_deg(n.angle_to(state.floor_normal)) if state.grounded else 180.0
		if normal_delta > params.surface_normal_follow_angle:
			var was_bonk: bool = active_motor.call("on_wall", state, params, n)
			if was_bonk:
				bonked.emit(state.last_bonk_speed)
				motion = Vector3.ZERO
				break
		else:
			# Floor-ish contact: shed the into-surface component and carry on.
			if state.velocity.dot(n) < 0.0:
				state.velocity -= n * state.velocity.dot(n)
		motion = col.get_remainder().slide(n)

func _snap_to_ground() -> void:
	if not state.grounded:
		return
	var space = get_world_3d().direct_space_state
	var probe_dir = -state.floor_normal.normalized()
	var from = global_position
	var to = from + probe_dir * (BODY_RADIUS + params.ground_snap_distance + params.edge_tolerance + 0.35)
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return
	var n: Vector3 = hit["normal"].normalized()
	if rad_to_deg(n.angle_to(state.floor_normal)) > params.surface_normal_follow_angle:
		return
	var desired: Vector3 = hit["position"] + n * BODY_RADIUS
	var delta_pos = desired - global_position
	var max_snap = params.ground_snap_distance + params.edge_tolerance
	if delta_pos.length() <= max_snap + 0.35:
		global_position += delta_pos.limit_length(max_snap)
		state.floor_normal = n

func _update_visual(delta: float) -> void:
	if _visual == null:
		return
	var up: Vector3 = state.floor_normal if state.grounded else Vector3.UP
	var fwd = Vector3(sin(state.facing_yaw), 0.0, cos(state.facing_yaw))
	fwd = (fwd - up * fwd.dot(up))
	if fwd.length() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var target = Basis.looking_at(fwd, up)

	# Lean into the turn — reads the drift the motor is already producing.
	var lean: float = clampf(state.steer_delta_deg * 2.4, -32.0, 32.0)
	target = target.rotated(fwd, deg_to_rad(lean))
	_visual.basis = _visual.basis.slerp(target, clampf(delta * 14.0, 0.0, 1.0)).orthonormalized()

	var tuck_offset: float = -0.16 * state.tuck
	_core.position.y = lerpf(_core.position.y, 0.12 + tuck_offset, clampf(delta * 10.0, 0.0, 1.0))

	if _trail and _trail is SpeedTrail:
		var trail = _trail as SpeedTrail
		trail.intensity_scale = float(Game.settings.get("speed_effects", 1.0))
		trail.push_point(global_position - _visual.basis.y * 0.34, state.speed / maxf(params.max_speed, 1.0))


func set_flow_tier(tier: int) -> void:
	if _trail and _trail is SpeedTrail:
		(_trail as SpeedTrail).flow_tier = tier
	var board_mat = _board.material_override as StandardMaterial3D if _board else null
	var core_mat = _core.material_override as StandardMaterial3D if _core else null
	if board_mat:
		board_mat.emission_energy_multiplier = 1.8 + float(tier) * 0.55
	if core_mat:
		core_mat.emission_energy_multiplier = 1.2 + float(tier) * 0.65

func telemetry() -> Dictionary:
	var d = state.snapshot()
	d["model"] = "SM64 REFERENCE" if params.model == MotorParams.Model.SM64_REFERENCE else "SLIDE"
	d["hz"] = Engine.physics_ticks_per_second
	d["launch_speed"] = state.last_launch_speed
	d["landing_speed"] = state.last_landing_speed
	return d
