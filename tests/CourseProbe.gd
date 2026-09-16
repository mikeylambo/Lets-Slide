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
var _segment_index = -1
var _segment_entry_speed = 0.0
var _last_grounded = false
var _last_lateral = 0.0
var _last_vertical = 0.0

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
	_print_segment_sequence(data)
	_validate_boundaries()
	_scene.run.run_finished.connect(_on_finish)
	_scene.run.respawned.connect(_on_respawn)
	_scene.slider.bonked.connect(func(_s): _bonks += 1)
	_scene.slider.external_input = _drive

## Steer toward the centreline point LOOKAHEAD metres down-track.
func _drive(inp: MotorInput, body: SlideBody) -> void:
	_index = _nearest_index(body.global_position, _index)
	_furthest = maxf(_furthest, float(_builder.samples[_index]["dist"]))
	var next_segment := _segment_at(float(_builder.samples[_index]["dist"]))
	if next_segment != _segment_index:
		_segment_index = next_segment
		_segment_entry_speed = body.state.speed
		var info: Dictionary = _builder.segment_ranges[_segment_index]
		print("  transition      : segment=%d kind=%s dist=%.0f entry_speed=%.1f grounded=%s" % [
			_segment_index, info["kind"], float(info["from"]), _segment_entry_speed, body.state.grounded])
	var ahead: int = mini(_index + int(LOOKAHEAD / TrackBuilder.STEP), _builder.samples.size() - 1)
	var ahead_sample: Dictionary = _builder.samples[ahead]
	var goal: Vector3 = ahead_sample["pos"] + ahead_sample["r"] * _safe_line_offset(float(ahead_sample["dist"]))

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
		var seg_i := _segment_at(float(fr["dist"]))
		var info: Dictionary = _builder.segment_ranges[seg_i]
		print("  failure         : course=%s segment=%d kind=%s into=%.0f speed_entry=%.1f speed_fail=%.1f grounded=%s lateral=%.1f vertical=%.1f checkpoint=%d respawns=%d class=%s" % [
			_scene.run.course.id, seg_i, info["kind"], float(fr["dist"]) - float(info["from"]),
			_segment_entry_speed, _fail_speed, _fail_grounded, off.dot(fr["r"]), off.dot(fr["u"]),
			_scene.run._last_checkpoint, _respawns, _classify_failure(true)])

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
		var frame: Dictionary = _builder.samples[_index]
		var offset: Vector3 = _scene.slider.global_position - frame["pos"]
		_last_lateral = offset.dot(frame["r"])
		_last_vertical = offset.dot(frame["u"])
		_last_grounded = s.grounded
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
	if not finished:
		var info: Dictionary = _builder.segment_ranges[_segment_index]
		print("  failure detail  : course=%s segment=%d kind=%s into=%.0f speed_entry=%.1f speed_fail=%.1f grounded=%s lateral=%.1f vertical=%.1f checkpoint=%d respawns=%d class=%s" % [
			course.id, _segment_index, info["kind"], _furthest - float(info["from"]), _segment_entry_speed,
			_scene.slider.state.speed, _last_grounded, _last_lateral, _last_vertical,
			_scene.run._last_checkpoint, _respawns, _classify_failure(false)])
	var accepted = finished and _respawns <= 1 and _stall_ticks == 0
	print("  probe gate      : %s" % ("PASS" if accepted else "REJECT"))
	print("── probe done ──")
	get_tree().quit(0 if accepted else 2)

func _segment_at(distance: float) -> int:
	for i in _builder.segment_ranges.size():
		if distance <= float(_builder.segment_ranges[i]["to"]) + TrackBuilder.STEP * 0.5:
			return i
	return _builder.segment_ranges.size() - 1

func _safe_line_offset(distance: float) -> float:
	for route in _builder.parallel_routes:
		var from_d: float = float(route["from"])
		var to_d: float = float(route["to"])
		var margin := LOOKAHEAD * 1.5
		if distance < from_d - margin or distance > to_d + margin:
			continue
		var enter_blend := smoothstep(from_d - margin, from_d, distance)
		var exit_blend := 1.0 - smoothstep(to_d, to_d + margin, distance)
		var blend: float = minf(enter_blend, exit_blend)
		var lateral: float = float(route["lateral"])
		# Stay on the main ribbon's unobstructed side until the elevated branch
		# and its collision merge are fully behind the rider.
		return -signf(lateral) * (float(route["width"]) * 0.5 + 0.8) * blend
	return 0.0

func _print_segment_sequence(course: CourseData) -> void:
	print("  course          : %s  serialized=%s  bars=%.2f author_speed=%.1f" % [
		course.id, ResourceLoader.exists("res://content/courses/%s.tres" % course.id), course.total_bars, _builder.author_avg_speed])
	var sequence: Array[String] = []
	for i in _builder.segment_ranges.size():
		var info: Dictionary = _builder.segment_ranges[i]
		sequence.append("%d:%s[%.0f..%.0f]" % [i, info["kind"], float(info["from"]), float(info["to"])])
	print("  segments        : %s" % " -> ".join(sequence))

func _validate_boundaries() -> void:
	for i in range(1, _builder.segment_ranges.size()):
		var distance: float = float(_builder.segment_ranges[i]["from"])
		var before: Dictionary = _builder.sample_at(distance - TrackBuilder.STEP)
		var after: Dictionary = _builder.sample_at(distance + TrackBuilder.STEP)
		var pos_step: float = before["pos"].distance_to(after["pos"])
		var tangent_dot: float = Vector3(before["f"]).dot(Vector3(after["f"]))
		var normal_dot: float = Vector3(before["u"]).dot(Vector3(after["u"]))
		var previous_width: float = float(_builder.segment_ranges[i - 1]["seg"].get("width", 14.0))
		var next_width: float = float(_builder.segment_ranges[i]["seg"].get("width", previous_width))
		var valid := pos_step <= TrackBuilder.STEP * 2.5 and tangent_dot > 0.85 and normal_dot > 0.75
		print("  boundary %02d    : %s->%s pos=%.2f tangent=%.3f normal=%.3f width=%.1f->%.1f gap=%s valid=%s" % [
			i, _builder.segment_ranges[i - 1]["kind"], _builder.segment_ranges[i]["kind"], pos_step,
			tangent_dot, normal_dot, previous_width, next_width, before["gap"] or after["gap"], valid])

func _classify_failure(at_respawn: bool) -> String:
	if absf(_last_vertical) > 8.0 or (at_respawn and not _fail_grounded):
		return "fell_through_or_left_geometry"
	if _scene.slider.state.speed < 1.5 or _stall_ticks > 120:
		return "stalled"
	if absf(_last_lateral) > float(_builder.samples[_index].get("width", 18.0)) * 0.5:
		return "left_intended_line"
	if _air > 8.0:
		return "overshot_or_unreachable_landing"
	return "physically_unreachable"
