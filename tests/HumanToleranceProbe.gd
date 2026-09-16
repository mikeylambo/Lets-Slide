extends Node

## Noisy delayed autopilot. A course that only a perfect centreline controller can
## clear is not human-readable enough to ship. This probe applies ~190 ms input
## latency and deterministic steering error before attempting the safe line.

const MAX_SECONDS = 260.0
const LOOKAHEAD = 30.0
const REACTION_SECONDS = 0.19
const STEER_NOISE = 0.075

var _scene: CourseScene
var _builder: TrackBuilder
var _queue: Array[Dictionary] = []
var _clock = 0.0
var _index = 0
var _respawns = 0
var _reported = false
var _rng = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 424242
	print("── LET'S SLIDE human-tolerance probe ──")
	await get_tree().process_frame
	var args = OS.get_cmdline_user_args()
	var data: CourseData = Courses.all()[0]
	var seed_override = -1
	var region_override = 0
	for a in args:
		if a.begins_with("--course="):
			var found = Courses.by_id(a.trim_prefix("--course="))
			if found != null:
				data = found
		elif a.begins_with("--seed="):
			seed_override = int(a.trim_prefix("--seed="))
		elif a.begins_with("--region="):
			region_override = clampi(int(a.trim_prefix("--region=")), 0, 4)
	if seed_override >= 0:
		data = CourseGenerator.generate(seed_override, region_override, 32.0, "tolerance_%d" % seed_override, "TOLERANCE")
	Main.instance.play_course(data)
	await get_tree().process_frame
	_scene = Main.instance.world.get_child(Main.instance.world.get_child_count() - 1)
	_builder = _scene._built["builder"]
	_scene.slider.external_input = _drive
	_scene.run.respawned.connect(func(): _respawns += 1)
	_scene.run.run_finished.connect(_on_finish)

func _drive(inp: MotorInput, body: SlideBody) -> void:
	_index = _nearest_index(body.global_position, _index)
	var ahead = mini(_index + int(LOOKAHEAD / TrackBuilder.STEP), _builder.samples.size() - 1)
	var goal: Vector3 = _builder.samples[ahead]["pos"]
	var to_goal = goal - body.global_position
	to_goal.y = 0.0
	var desired = 0.0
	if to_goal.length() > 0.01:
		to_goal = to_goal.normalized()
		var vel = body.state.flat_velocity()
		var heading = vel.normalized() if vel.length() > 1.0 else Vector3(sin(body.state.facing_yaw), 0.0, cos(body.state.facing_yaw))
		var angle = atan2(heading.cross(to_goal).y, clampf(heading.dot(to_goal), -1.0, 1.0))
		desired = clampf(-angle * 1.35 / (1.0 + body.state.speed * 0.018), -1.0, 1.0)
	_queue.append({"at": _clock + REACTION_SECONDS, "steer": desired})
	while _queue.size() > 1 and float(_queue[1]["at"]) <= _clock:
		_queue.pop_front()
	var delayed = float(_queue[0]["steer"]) if not _queue.is_empty() and float(_queue[0]["at"]) <= _clock else 0.0
	inp.steer = clampf(delayed + _rng.randf_range(-STEER_NOISE, STEER_NOISE), -1.0, 1.0)
	inp.tuck = not body.state.grounded

func _nearest_index(pos: Vector3, from: int) -> int:
	var best = from
	var best_d = INF
	for i in range(maxi(0, from - 12), mini(_builder.samples.size() - 1, from + 90) + 1):
		var d = pos.distance_squared_to(_builder.samples[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best

func _physics_process(delta: float) -> void:
	_clock += delta
	if not _reported and _clock > MAX_SECONDS:
		_report(false, 0.0)

func _on_finish(result: Dictionary) -> void:
	_report(bool(result.get("finished", false)), float(result.get("time", 0.0)))

func _report(finished: bool, time: float) -> void:
	if _reported:
		return
	_reported = true
	print("  course      : %s" % _scene.course.id)
	print("  finished    : %s" % ("yes" if finished else "NO"))
	print("  time        : %.2f" % time)
	print("  respawns    : %d" % _respawns)
	print("  tolerance   : %s" % ("PASS" if finished and _respawns <= 1 else "REJECT"))
	print("── tolerance probe done ──")
	get_tree().quit(0 if finished and _respawns <= 1 else 2)
