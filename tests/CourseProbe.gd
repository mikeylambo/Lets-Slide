extends Node

## Course probe:  godot --headless -- --probe
##
## Drives the real course with an autopilot that does nothing clever: it aims at
## the track centreline a fixed distance ahead and steers toward it. That is
## roughly "a competent player taking the safe line and never optimising".
##
## Its job is to answer questions no amount of reading the code will: is the
## course traversable, what speed band does it produce, where does it lose
## people, and — most usefully — what a real finishing time looks like, so the
## medal times are calibrated against physics instead of invented.

const MAX_SECONDS = 240.0
const LOOKAHEAD = 26.0

var _scene: CourseScene
var _builder: TrackBuilder
var _t = 0.0
var _peak = 0.0
var _sum = 0.0
var _samples = 0
var _respawns = 0
var _bonks = 0
var _air = 0.0
var _reported = false
var _index = 0
var _furthest = 0.0
var _stall_ticks = 0

func _ready() -> void:
	print("── SLIDE course probe (autopilot, safe line) ──")
	await get_tree().process_frame
	var data: CourseData = Courses.all()[0]
	var seed_override = -1
	var region_override = 0
	var bars_override = 32.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--course="):
			var found = Courses.by_id(arg.trim_prefix("--course="))
			if found != null:
				data = found
		elif arg.begins_with("--seed="):
			seed_override = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--region="):
			region_override = clampi(int(arg.trim_prefix("--region=")), 0, 4)
		elif arg.begins_with("--bars="):
			bars_override = maxf(8.0, float(arg.trim_prefix("--bars=")))
	if seed_override >= 0:
		data = CourseGenerator.generate(seed_override, region_override, bars_override, "probe_%d" % seed_override, "PROBE")
	Main.instance.play_course(data)
	await get_tree().process_frame
	_scene = Main.instance.world.get_child(Main.instance.world.get_child_count() - 1)
	_builder = _scene._built["builder"]
	_scene.run.run_finished.connect(_on_finish)
	_scene.run.respawned.connect(_on_respawn)
	_scene.slider.bonked.connect(func(_s): _bonks += 1)
	_scene.slider.external_input = _drive

## Steer toward the centreline point LOOKAHEAD metres down-track.
func _drive(inp: MotorInput, body: SlideBody) -> void:
	_index = _nearest_index(body.global_position, _index)
	_furthest = maxf(_furthest, float(_builder.samples[_index]["dist"]))
	var ahead: int = mini(_index + int(LOOKAHEAD / TrackBuilder.STEP), _builder.samples.size() - 1)
	var goal: Vector3 = _builder.samples[ahead]["pos"]

	var to_goal = goal - body.global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.01:
		return
	to_goal = to_goal.normalized()

	var vel = body.state.flat_velocity()
	var heading: Vector3 = vel.normalized() if vel.length() > 1.0 else Vector3(sin(body.state.facing_yaw), 0.0, cos(body.state.facing_yaw))

	var cross: float = heading.cross(to_goal).y
	var dot: float = clampf(heading.dot(to_goal), -1.0, 1.0)
	var angle = atan2(cross, dot)
	# Gain falls off with speed for the same reason a player's does: a hard
	# correction at 200 km/h costs more momentum than the line it saves.
	var gain: float = 1.6 / (1.0 + body.state.speed * 0.02)
	if absf(angle) < 0.035:
		angle = 0.0
	inp.steer = clampf(-angle * gain, -1.0, 1.0)
	inp.move_dir = to_goal
	inp.tuck = not body.state.grounded

## Local search from the last index — the slider moves forward, so a full scan
## every tick would be wasted work.
func _nearest_index(pos: Vector3, from: int) -> int:
	var best = from
	var best_d = INF
	var lo: int = maxi(0, from - 12)
	var hi: int = mini(_builder.samples.size() - 1, from + 90)
	for i in range(lo, hi + 1):
		var d: float = pos.distance_squared_to(_builder.samples[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best

func _on_respawn() -> void:
	_respawns += 1
	if _respawns <= 6:
		var s = _scene.slider.state
		var i = _scan_all(_fail_pos)
		var fr: Dictionary = _builder.samples[i]
		var off: Vector3 = _fail_pos - fr["pos"]
		print("  respawn %d  last-ground dist=%.0f  lateral=%.1f m  vertical=%.1f m  speed=%.1f" % [
			_respawns, float(fr["dist"]), off.dot(fr["r"]), off.dot(fr["u"]), _fail_speed])

var _fail_pos = Vector3.ZERO
var _fail_speed = 0.0
var _fail_grounded = false

## Full scan — only used for failure diagnostics, never per-tick.
func _scan_all(pos: Vector3) -> int:
	var best = 0
	var best_d = INF
	for i in _builder.samples.size():
		var d: float = pos.distance_squared_to(_builder.samples[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best

func _physics_process(delta: float) -> void:
	if _scene == null or _reported:
		return
	_t += delta
	if _scene.run.state == RunController.State.RUNNING:
		var s = _scene.slider.state
		_peak = maxf(_peak, s.speed)
		_sum += s.speed
		_samples += 1
		if not s.grounded:
			_air += delta
		elif s.speed < 1.5:
			_stall_ticks += 1
		if s.grounded or _fail_grounded:
			_fail_pos = _scene.slider.global_position
			_fail_speed = s.speed
			_fail_grounded = s.grounded
	if _t > MAX_SECONDS:
		_report(false, 0.0, {})

func _on_finish(result: Dictionary) -> void:
	_report(true, float(result.get("time", 0.0)), result)

func _report(finished: bool, time: float, result: Dictionary = {}) -> void:
	if _reported:
		return
	_reported = true
	var course: CourseData = _scene.run.course
	var avg: float = 0.0 if _samples == 0 else _sum / float(_samples)
	var total: float = float(_scene._built["length"])

	print("  finished        : %s" % ("yes" if finished else "NO"))
	if finished:
		print("  time            : %.2f s   (author target %.2f)" % [time, course.author_time])
		print("  score           : %d" % int(result.get("score", 0)))
		print("  flow seconds    : %.2f" % float(result.get("flow_seconds", 0.0)))
		print("  medal           : %s" % course.medal_for(time))
		print("  suggested times : author %.0f  gold %.0f  silver %.0f  bronze %.0f" % [time * 0.92, time, time * 1.12, time * 1.30])
	print("  reached         : %.0f m of %.0f m (%.0f%%)" % [_furthest, total, _furthest / maxf(total, 1.0) * 100.0])
	print("  peak speed      : %.1f m/s (%.0f km/h)" % [_peak, _peak * 3.6])
	print("  average speed   : %.1f m/s (%.0f km/h)" % [avg, avg * 3.6])
	print("  airborne        : %.1f s" % _air)
	print("  respawns        : %d" % _respawns)
	print("  stall ticks     : %d" % _stall_ticks)
	print("  bonks           : %d" % _bonks)
	var accepted = finished and _respawns <= 1 and _stall_ticks == 0
	print("  probe gate      : %s" % ("PASS" if accepted else "REJECT"))
	print("── probe done ──")
	get_tree().quit(0 if accepted else 2)
