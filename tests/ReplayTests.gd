extends Node

## Replay determinism gate:  godot --headless -- --replay-test
##
## Drives Course 01 with a scripted, input-busy line (steer, lean, tuck,
## brake), records it, round-trips the replay through a share code, re-runs it
## through the real motor and requires the rider to land on the identical spot.
## This is the property leaderboard validation and async duels depend on.

const CHECK_TICK = 1500              ## 12.5 s at 120 Hz

var failures = 0
var checks = 0
var _probe_pos = Vector3.INF
var _probe_speed = 0.0
var _scene: CourseScene

func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok: print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _ready() -> void:
	print("── SLIDE replay determinism ──")
	await get_tree().process_frame
	_test_codec()

	# ---- 1. live run with scripted input ---------------------------------
	Main.instance.play_course(Courses.all()[0])
	_scene = Main.instance.current_world()
	var tick = [0]
	_scene.slider.external_input = func(inp: MotorInput, _b):
		var t = float(tick[0]) / 120.0
		inp.steer = sin(t * 1.3) * 0.7 + sin(t * 3.1) * 0.2
		inp.lean = cos(t * 0.8) * 0.6
		inp.tuck = int(t * 2.0) % 5 == 0
		inp.brake = int(t * 3.0) % 17 == 0
		tick[0] += 1
	await _until_tick(CHECK_TICK)
	var live_pos = _probe_pos
	var live_speed = _probe_speed
	var live_replay: Replay = _scene.run.replay
	check("live run reached the probe tick", live_pos != Vector3.INF)
	check("race time is tick-exact", is_equal_approx(_scene.run.time, float(_scene.run.ticks) / 120.0), "%f vs %d" % [_scene.run.time, _scene.run.ticks])
	check("replay recorded every controlled tick", live_replay.tick_count() >= CHECK_TICK, str(live_replay.tick_count()))
	check("recorded axes are quantised", absf(Replay.quantize(0.3337) - round(0.3337 * 127.0) / 127.0) < 1e-9)

	# ---- 2. share-code round trip ----------------------------------------
	var code = live_replay.to_code()
	var decoded = Replay.from_code(code)
	check("share code decodes", decoded != null and decoded.tick_count() == live_replay.tick_count(), "%d chars" % code.length())
	print("       share code for %d ticks: %d chars" % [live_replay.tick_count(), code.length()])

	# ---- 3. replay through the real motor ---------------------------------
	_scene.slider.external_input = Callable()
	_probe_pos = Vector3.INF
	check("replay accepted for its course", _scene.run.play_replay(decoded))
	await _until_tick(CHECK_TICK)
	var err = live_pos.distance_to(_probe_pos)
	check("replay re-simulates bit-for-bit", err < 1e-5, "drift %.8f m" % err)
	check("replay speed matches", absf(live_speed - _probe_speed) < 1e-5, "%f vs %f" % [live_speed, _probe_speed])
	check("watching never records results", _scene.run.watching and not _scene.run.record_results)
	_scene.run.retry()
	check("retry takes control back from a replay", not _scene.run.watching and _scene.run.record_results and not _scene.slider.external_input.is_valid())

	check("replay refuses another course", not _scene.run.play_replay(_foreign(decoded)))
	print("── %d checks, %d failures ──" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _test_codec() -> void:
	var r = Replay.begin_for("course_01", MotorParams.new())
	var inp = MotorInput.new()
	for i in 300:
		inp.steer = Replay.quantize(sin(float(i) * 0.1)); inp.lean = Replay.quantize(-0.5)
		inp.tuck = i % 3 == 0; inp.brake = i % 7 == 0
		r.push(inp)
	r.finish(300, true, 120)
	var back = Replay.from_bytes(r.to_bytes())
	var out = MotorInput.new()
	back.read(150, out)
	check("codec round-trips inputs", back.tick_count() == 300 and is_equal_approx(out.steer, Replay.quantize(sin(15.0))) and out.tuck == (150 % 3 == 0))
	check("codec keeps finish time", is_equal_approx(back.time_seconds(), 2.5))
	check("valid() only for production finishes", back.valid())
	check("garbage codes are rejected", Replay.from_code("SLRP1:AAAA") == null and Replay.from_code("hello") == null)

func _foreign(r: Replay) -> Replay:
	var f = Replay.from_bytes(r.to_bytes())
	f.course_id = "course_99"
	return f

func _physics_process(_delta: float) -> void:
	if _scene and is_instance_valid(_scene) and _scene.run.state == RunController.State.RUNNING and _scene.run.ticks == CHECK_TICK and _probe_pos == Vector3.INF:
		_probe_pos = _scene.slider.global_position
		_probe_speed = _scene.slider.state.speed

func _until_tick(_n: int) -> void:
	var end = Time.get_ticks_msec() + 60000
	while _probe_pos == Vector3.INF and Time.get_ticks_msec() < end:
		await get_tree().process_frame
