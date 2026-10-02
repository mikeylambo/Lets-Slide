extends Node

## T3 community courses gate:  godot --headless --fixed-fps 120 -- --community-test
## Course codec (including hostile input), storage, editor operations, and the
## verify → share → import → race-the-author round trip. Sandboxed.

var failures = 0
var checks = 0

func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok: print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _ready() -> void:
	print("── SLIDE community courses ──")
	Game.use_sandbox_profile()
	CustomCourses.root = "user://test_courses"
	_wipe()
	await get_tree().process_frame
	_codec()
	_hostile()
	_storage()
	await _editor()
	await _verify_share_import()
	_wipe()
	print("── %d checks, %d failures ──" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _wipe() -> void:
	for c in CustomCourses.all(): CustomCourses.delete(c.id)

func _codec() -> void:
	var c = CustomCourses.template()
	check("template is playable and structurally valid", c.spec.size() == 5 and GenerationValidator.validate(c.spec)["ok"])
	check("ids are stable for identical geometry", CourseCodec.course_id(c.spec, 0) == c.id and c.id.begins_with("c_"))
	var edited = c.spec.duplicate(true); edited[0]["slope"] = 15.0
	check("any geometry edit makes a new id", CourseCodec.course_id(edited, 0) != c.id)
	check("theme region is part of identity", CourseCodec.course_id(c.spec, 2) != c.id)
	var r = CourseCodec.from_code(CourseCodec.to_code(c))
	check("course code round-trips", r.has("course") and r["course"].id == c.id and r["course"].title == c.title)
	var built = CourseFactory.build(r["course"], 32.0)
	check("imported course builds real geometry", built["builder"].total_length > 100.0 and built.has("finish"))
	built["root"].free()

func _hostile() -> void:
	var bad = CourseCodec.sanitize_spec([
		{"kind": "straight", "bars": 99999.0, "slope": -500.0, "width": 1e9, "evil": "x"},
		{"kind": "rm -rf", "bars": 2.0},
		"not a dict",
		{"kind": "crest", "crest": NAN, "bars": 2.0},
		{"kind": "hazard", "hazards": 9999},
	])
	check("unknown verbs and junk entries dropped", bad.size() == 3, str(bad))
	check("numbers clamped to buildable limits", bad[0]["bars"] <= 16.0 and bad[0]["slope"] >= -20.0 and bad[0]["width"] <= 30.0)
	check("unknown keys stripped", not bad[0].has("evil"))
	check("non-finite values dropped", not bad[1].has("crest"))
	check("integer keys stay integers", bad[2]["hazards"] == 6)
	var many = []
	for i in 500: many.append({"kind": "straight", "bars": 1.0})
	check("segment count capped", CourseCodec.sanitize_spec(many).size() == CourseCodec.MAX_SEGMENTS)
	check("garbage codes rejected with a reason", CourseCodec.from_code("hello").has("error") and CourseCodec.from_code("SLCS1:AAAA").has("error"))
	# Claiming an author time without the author's run is downgraded.
	var c = CustomCourses.template()
	var d = CourseCodec.from_course(c); d["author_time"] = 1.0; d["author_run"] = "SLRP1:bogus"
	c = CourseCodec.to_course(d)
	var code = CourseCodec.to_code(c)
	var back: CourseData = CourseCodec.from_code(code)["course"]
	check("fake author times are not trusted", not CourseCodec.is_verified(back))

func _storage() -> void:
	var c = CustomCourses.template()
	check("save", CustomCourses.save(c))
	check("list", CustomCourses.all().size() == 1)
	check("Courses.by_id finds custom courses", Courses.by_id(c.id) != null and Courses.by_id(c.id).title == c.title)
	CustomCourses.delete(c.id)
	check("delete", CustomCourses.all().is_empty())

func _editor() -> void:
	var c = CustomCourses.template()
	Main.instance.show_course_editor(c)
	await get_tree().process_frame
	var e: CourseEditor = Main.instance._screen
	check("editor builds one row per segment", e._rows.get_child_count() == 5)
	e.insert_after(1)
	await get_tree().process_frame
	check("insert adds a segment", c.spec.size() == 6 and e._rows.get_child_count() == 6)
	var first = c.spec[0]["kind"]; e.move(0, 1)
	check("move reorders", c.spec[1]["kind"] == first)
	e.set_kind(2, "ramp")
	check("changing verb applies its defaults", c.spec[2]["kind"] == "ramp" and c.spec[2].has("launch"))
	e.remove(2); e.remove(2); e.remove(2)
	check("never below three segments", c.spec.size() == 3, str(c.spec.size()))
	check("edits re-derive the id", c.id == CourseCodec.course_id(c.spec, c.region_index))
	check("share locked while unverified", e._share.disabled)

func _verify_share_import() -> void:
	var c = CustomCourses.template()
	CustomCourses.save(c)
	Game.editor_course = c
	Game.verifying_course = true
	Game.set_mode(Game.Mode.TIME_TRIAL)
	Main.instance.play_course(c)
	var s: CourseScene = Main.instance.current_world()
	while s.run.state != RunController.State.RUNNING: await get_tree().physics_frame
	for i in 240: await get_tree().physics_frame
	s.run.finish_run(true)
	await get_tree().process_frame
	check("verify run sets the author time", CourseCodec.is_verified(c) and is_equal_approx(c.author_time, s.run.time), "%f vs %f" % [c.author_time, s.run.time])
	check("verified course embeds the author's run", CourseCodec.author_replay(c) != null)
	check("results announce verification", s._results != null and bool(s._results.result.get("verified", false)))
	check("medals scale from the author time", is_equal_approx(c.gold_time, c.author_time * 1.08))
	s._results.exit_requested.emit()
	await get_tree().process_frame
	check("leaving a test ride returns to the editor", Main.instance._screen is CourseEditor)

	var code = CourseCodec.to_code(c)
	CustomCourses.delete(c.id)
	Main.instance.show_courses()
	await get_tree().process_frame
	var screen: CoursesScreen = Main.instance._screen
	screen._code.text = code
	screen.import_code()
	var imported = CustomCourses.load_course(c.id)
	check("import restores the verified course", imported != null and CourseCodec.is_verified(imported))
	check("import keeps the author's run", imported != null and CourseCodec.author_replay(imported) != null)
	print("       course code with author run: %d chars" % code.length())

	Game.editor_course = null
	Main.instance.play_course(imported, null, {"rival": CourseCodec.author_replay(imported)})
	s = Main.instance.current_world()
	check("you can race the author on an imported course", s.rival != null)
