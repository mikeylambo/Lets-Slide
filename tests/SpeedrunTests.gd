extends Node

## T2 speedrun suite gate:  godot --headless --fixed-fps 120 -- --speedrun-test
## Splits + sum of best, chick badges, tech codex, Region Run, run-code screen.
## Runs on a sandbox profile so a developer's real records are never touched.

var failures = 0
var checks = 0

func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok: print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _ready() -> void:
	print("── SLIDE speedrun suite ──")
	Game.use_sandbox_profile()
	await get_tree().process_frame
	_unit()
	await _splits()
	await _badges_and_tech()
	await _region_run()
	await _screens()
	print("── %d checks, %d failures ──" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _unit() -> void:
	check("segment time", is_equal_approx(RunController.segment_time([3.0, 7.5, 12.0], 1), 4.5))
	check("missed split breaks the segment", RunController.segment_time([3.0, -1.0, 12.0], 2) < 0.0)
	check("sum of best", is_equal_approx(RunController.sum_of_best([3.0, 4.0, 4.5]), 11.5) and RunController.sum_of_best([3.0, 0.0]) == 0.0)
	var placed = 0
	for c in Courses.all():
		var built = CourseFactory.build(c, 32.0)
		if built["badge"] != null: placed += 1
		built["root"].free()
	check("every course hides a chick badge", placed == Courses.all().size(), "%d / %d" % [placed, Courses.all().size()])

func _scene() -> CourseScene:
	return Main.instance.current_world()

func _until_running(s: CourseScene) -> void:
	while s.run.state != RunController.State.RUNNING: await get_tree().physics_frame

func _ticks(n: int) -> void:
	for i in n: await get_tree().physics_frame

func _splits() -> void:
	Game.set_mode(Game.Mode.TIME_TRIAL)
	Main.instance.play_course(Courses.all()[0])
	var s = _scene()
	var got = []
	s.run.split_reached.connect(func(i, t, d, g): got.append([i, t, d, g]))
	await _until_running(s)
	await _ticks(120)
	s.run._on_checkpoint(s._built["checkpoints"][0])
	await _ticks(120)
	s.run.finish_run(true)
	check("splits recorded at checkpoint and finish", got.size() == 2 and got[0][0] == 0 and got[1][0] == s.run.splits.size() - 1, str(got))
	check("first run has no PB delta and golds", got[0][2] == INF and bool(got[0][3]))
	check("PB splits saved", Game.record_for("course_01").get("splits", []).size() == s.run.splits.size())
	var segs: Array = Game.record_for("course_01")["best_segments"]
	check("best segments kept for splits that were hit", float(segs[0]) > 0.0 and float(segs[1]) <= 0.0, str(segs))

	await get_tree().process_frame
	s._on_retry() if s._results else s.run.retry()
	got.clear()
	await _until_running(s)
	await _ticks(100)
	s.run._on_checkpoint(s._built["checkpoints"][0])
	check("second run splits against PB", got.size() == 1 and got[0][2] != INF and float(got[0][2]) < 0.0, str(got))
	check("faster segment is gold", got.size() == 1 and bool(got[0][3]))

func _badges_and_tech() -> void:
	var s = _scene()
	var badge: Pickup = s._built["badge"]
	var found = []
	s.run.badge_found.connect(func(c, first): found.append(first))
	var ghost = SlideBody.new(); ghost.is_player = false
	badge._on_body_entered(ghost)
	check("rivals cannot take the badge", found.is_empty() and not badge.is_taken())
	ghost.free()
	badge._on_body_entered(s.slider)
	check("player finds the chick badge", found == [true] and Game.has_badge("course_01"))
	check("badge never counts as a collectible", s.run.pickups_taken == 0)
	badge.restore(); badge._on_body_entered(s.slider)
	check("second find is not a first find", found == [true, false] and Game.badge_total() == 1)

	var techs = []
	s.tech.discovered.connect(func(id, _i): techs.append(id))
	s.slider.input.lean = -0.8
	s.slider.took_off.emit(32.0)
	s.slider.landed.emit(0.99, 31.0)
	check("crest release discovered", techs.has("crest_release"))
	check("flush landing discovered", techs.has("flush_landing"))
	s.slider.took_off.emit(32.0)
	check("tech is only discovered once", techs.count("crest_release") == 1)
	check("codex persists discoveries", Game.profile["tech"].has("crest_release"))

func _region_run() -> void:
	Main.instance.start_marathon(0)
	var courses = Courses.region_courses(0)
	var finished_courses = []
	for i in courses.size():
		var s = _scene()
		finished_courses.append(s.course.id)
		await _until_running(s)
		await _ticks(60)
		s.run.finish_run(true)
		if i < courses.size() - 1:
			var before = s
			while _scene() == before: await get_tree().process_frame
	check("region run plays all five courses in order", finished_courses == courses.map(func(c): return c.id), str(finished_courses))
	await get_tree().process_frame
	var best = Game.marathon_best(0)
	check("region run total recorded", best > 2.0 and is_equal_approx(best, float(Game.marathon["total"])), "%f" % best)
	check("region run total is the sum of course times", absf(float(Game.marathon["splits"][-1]) - best) < 1e-6)
	var s = _scene()
	check("region results show the cumulative time", s._results != null and s._results.result.has("marathon_total"))
	s.restart()
	await get_tree().process_frame
	check("retry restarts the whole region", int(Game.marathon["index"]) == 0 and is_zero_approx(float(Game.marathon["total"])) and _scene().course.id == courses[0].id)

func _screens() -> void:
	var r = Replay.begin_for("course_01", MotorParams.new())
	var inp = MotorInput.new()
	for i in 10: r.push(inp)
	r.finish(10, true, 120)
	Main.instance.show_run_codes()
	await get_tree().process_frame
	var screen: RunCodeScreen = Main.instance._screen
	screen._input.text = r.to_code()
	screen._decode()
	check("run code screen decodes and enables race/watch", screen._replay != null and not screen._watch.disabled and not screen._race.disabled)
	screen._input.text = "nonsense"
	screen._decode()
	check("run code screen explains a bad code", screen._watch.disabled and screen._status.text.begins_with("That isn't"))
	Main.instance.show_codex()
	await get_tree().process_frame
	check("codex screen opens", Main.instance._screen is CodexScreen)
