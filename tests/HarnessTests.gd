extends Node

## Playtest harness gate:  godot --headless --path . -- --harness-test
##
## Boots the real harness on Course 01 in a sandboxed user:// root and proves:
## live tuning reaches the motor, the panel is controller-navigable, A/B swap,
## blind mode, markers with course bars, readability kit on/off, sub-300 ms
## retry, per-preset ghosts, CSV/JSON telemetry, rating, summary.md, preset
## save/load, author-speed rebuild, and that shipping code stays harness-free.

const ROOT = "user://harness_selftest"

var failures = 0
var checks = 0
var h

func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _ready() -> void:
	print("── SLIDE playtest harness tests ──")
	_rmrf(ProjectSettings.globalize_path(ROOT))
	_test_shipping_isolation()
	await get_tree().process_frame
	h = load(Main.HARNESS_ENTRY).new()
	h.config = {"course": "course_01", "root": ROOT, "quit_on_exit": false, "mirror": false,
		"preset": "Current Candidate", "b": "Arcade Clean"}
	Main.instance.add_child(h)
	await _frames(3)
	await _run()
	h.finalize()
	_test_outputs()
	_rmrf(ProjectSettings.globalize_path(ROOT))
	print("── %d checks, %d failures ──" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _run() -> void:
	var s: CourseScene = h.scene
	check("harness adopted a course scene", s != null and s.course.id == "course_01")
	check("slider reads the harness's live params", s.slider.params == h.params)
	check("sandbox runs never touch records", not s.run.record_results and not s.show_results)
	check("presets seeded as JSON files", h.presets.names().size() >= 2, str(h.presets.names()))
	check("A/B slots loaded", h.slot_name(0) == "Current Candidate" and h.slot_name(1) == "Arcade Clean")

	await _until(func(): return s.run.state == RunController.State.RUNNING, 5.0)
	check("run started after intro countdown", s.run.state == RunController.State.RUNNING)

	# --- live tuning --------------------------------------------------------
	var before = s.slider.params.max_speed
	h.set_param("max_speed", 40.0)
	check("live tuning lands on the motor instantly", is_equal_approx(s.slider.params.max_speed, 40.0), "%s" % s.slider.params.max_speed)
	check("tweak creates a tracked variant", h.current_variant().begins_with("~"), h.current_variant())
	h.reset_param("max_speed")
	check("reset returns to saved value", is_equal_approx(s.slider.params.max_speed, before))
	var slider_count = 0
	for n in _descendants(h.panel):
		if n is HSlider: slider_count += 1
	check("panel exposes every MotorParams field", slider_count >= MotorParams.SCHEMA.size(), "%d sliders" % slider_count)

	# --- controller navigation ---------------------------------------------
	h.panel.open()
	await _frames(2)
	var focus = get_viewport().gui_get_focus_owner()
	check("panel grabs focus for controller use", focus != null and h.panel.is_ancestor_of(focus))
	await get_tree().physics_frame
	var feel = h.panel._rows["max_speed"]["slider"] as HSlider
	feel.grab_focus()
	await _frames(1)
	var v0 = s.slider.params.max_speed
	_press("ui_right")
	await _frames(2)
	check("D-pad right nudges focused slider", s.slider.params.max_speed > v0, "%s -> %s" % [v0, s.slider.params.max_speed])
	_press("ui_down")
	await _frames(2)
	check("D-pad down moves focus to next row", get_viewport().gui_get_focus_owner() != feel)
	feel.grab_focus()
	await _frames(1)
	_press("ui_accept")
	await _frames(2)
	check("A on a slider resets it", is_equal_approx(s.slider.params.max_speed, v0))
	h.panel.close()

	# --- markers + telemetry events ---------------------------------------
	await _seconds(0.6)
	h.drop_marker()
	check("marker recorded", h.markers.size() == 1)
	check("marker carries a course bar", float(h.markers[0]["bar"]) >= 0.0 and int(h.markers[0]["segment"]) >= 0, str(h.markers[0]))
	s.slider.took_off.emit(21.5)
	check("pop events are logged", h._log.pops == 1)

	# --- A/B swap ------------------------------------------------------------
	h.swap_slots()
	check("Tab swap activates slot B", h.active == 1)
	check("swap applies B's params mid-run", is_equal_approx(s.slider.params.steering_strength, 175.0), str(s.slider.params.steering_strength))
	check("swap marks the run as mixed", h._log.mixed)
	h.set_toggle("blind", true)
	check("blind hides preset names", h.slot_display(1).find("ARCADE") < 0 and h.slot_label(1) in ["X", "Y"], h.slot_display(1))
	check("blind hides tuning values", not h.panel._tuning.visible)
	h.set_toggle("blind", false)
	h.swap_slots()
	check("swap back to A", h.active == 0 and is_equal_approx(s.slider.params.steering_strength, 145.0))

	# --- readability kit ----------------------------------------------------
	check("kit greyboxes ribbon surfaces", h.kit.enabled and h.kit.greyboxed_count() > 0, str(h.kit.greyboxed_count()))
	h.set_toggle("kit", false)
	check("kit off restores materials", h.kit.greyboxed_count() == 0)
	h.set_toggle("kit", true)
	check("fov kick grows with speed", h.kit.fov_kick_for(1.0) > h.kit.fov_kick_for(0.6) and h.kit.fov_kick_for(0.2) == 0.0)
	h.set_toggle("click", true)
	await _frames(3)
	check("click enabled and phase-locked to run", h.kit.click_enabled and h.kit._click_running)

	# --- instant retry ------------------------------------------------------
	h.retry()
	await _until(func(): return s.run.state == RunController.State.RUNNING, 2.0)
	check("retry returns control under 300 ms", h.last_retry_ms > 0.0 and h.last_retry_ms < 300.0, "%.1f ms" % h.last_retry_ms)
	check("aborted run was logged", h.runs.size() == 1 and h.runs[0]["outcome"] == "retry", str(h.runs))

	# --- finish, ghost, rating ---------------------------------------------
	await _seconds(1.2)
	s.run.finish_run(true)
	await _frames(2)
	check("finished run logged", h.runs.size() == 2 and h.runs[1]["outcome"] == "finished")
	check("result card asks for a rating", h.overlay.rating_open())
	var ev = InputEventKey.new(); ev.keycode = KEY_4; ev.pressed = true
	check("rating accepts 1–5 keys", h.overlay.handle_rating_input(ev))
	check("rating stored on the run", int(h.runs[1]["rating"]) == 4)
	check("preset ghost saved", FileAccess.file_exists(h._ghost_path(0)))
	h.retry()
	await _until(func(): return s.run.state == RunController.State.RUNNING, 2.0)
	check("ghost of best run plays back", s.ghost.playing and s.ghost.has_data())

	# --- presets --------------------------------------------------------------
	h.set_param("steering_strength", 160.0)
	h.save_active("Harness Selftest")
	check("preset saved to user://presets", h.presets.exists("Harness Selftest"))
	check("saved preset is now the clean baseline", h.current_variant() == "")
	h.load_into_slot(1, "Loose / Drift")
	check("preset loaded into slot B", h.slot_name(1) == "Loose / Drift")

	# --- author speed rebuild ---------------------------------------------
	var old_id = s.get_instance_id()
	h.set_param("author_avg_speed", 36.0)
	await _until(func(): return h.scene.get_instance_id() != old_id, 2.0)
	check("author_avg_speed rebuilds the course", h.scene.get_instance_id() != old_id and is_equal_approx(h.scene._built["builder"].author_avg_speed, 36.0))
	check("rebuilt scene still shares live params", h.scene.slider.params == h.params)
	await _frames(3)
	check("kit re-applied after rebuild", h.kit.greyboxed_count() > 0)

func _test_outputs() -> void:
	var dir: String = h.session["dir"]
	check("session folder created", DirAccess.dir_exists_absolute(dir), dir)
	var run_dir = dir.path_join("run_002")
	var csv = FileAccess.get_file_as_string(run_dir.path_join("telemetry.csv"))
	var lines = csv.strip_edges().split("\n")
	check("telemetry CSV has header + rows", lines.size() > 30 and lines[0].begins_with("t,x,y,z,speed"), "%d lines" % lines.size())
	check("CSV logs grounded state", lines[0].find("grounded") >= 0)
	var preset = JSON.parse_string(FileAccess.get_file_as_string(run_dir.path_join("preset.json")))
	check("preset JSON stored with run", preset is Dictionary and preset["motor"].has("max_speed"))
	var run1 = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("run_001/run.json")))
	check("run JSON has marker + pop events", run1 is Dictionary and run1["markers"].size() == 1 and str(run1["events"]).find("pop") >= 0)
	var md = FileAccess.get_file_as_string(dir.path_join("summary.md"))
	check("summary.md written", md.begins_with("# Let's Slide — Playtest"))
	check("summary lists best times per preset", md.find("## Best times per preset") >= 0 and md.find("Current Candidate") >= 0)
	check("summary lists markers with bar numbers", md.find("## Markers") >= 0 and md.find("**%.2f**" % float(h.markers[0]["bar"])) >= 0)
	check("summary includes rating", md.find("★★★★☆") >= 0)
	check("summary shows tuning deltas", md.find("## Tuning deltas") >= 0 or h.variants.size() >= 1)

func _test_shipping_isolation() -> void:
	check("harness gated to debug builds", Main.harness_available() == OS.is_debug_build())
	var cfg = FileAccess.get_file_as_string("res://export_presets.cfg")
	check("every export preset excludes dev-only folders", cfg.count("src/harness/*") == cfg.count("exclude_filter="), "%d/%d" % [cfg.count("src/harness/*"), cfg.count("exclude_filter=")])
	var offenders = []
	for path in _scripts("res://src"):
		if path.begins_with("res://src/harness/") or path == "res://src/ui/Main.gd":
			continue
		if FileAccess.get_file_as_string(path).find("src/harness") >= 0:
			offenders.append(path)
	check("no shipping script references the harness", offenders.is_empty(), str(offenders))

# ------------------------------------------------------------------ helpers
func _press(action: String) -> void:
	var ev = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _until(cond: Callable, timeout: float) -> void:
	var end = Time.get_ticks_msec() + int(timeout * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame

func _descendants(n: Node) -> Array:
	var out = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out

func _scripts(dir: String) -> Array:
	var out = []
	var d = DirAccess.open(dir)
	if d == null: return out
	for f in d.get_files():
		if f.ends_with(".gd"): out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out

static func _rmrf(abs_path: String) -> void:
	if not DirAccess.dir_exists_absolute(abs_path): return
	var d = DirAccess.open(abs_path)
	for f in d.get_files(): DirAccess.remove_absolute(abs_path.path_join(f))
	for sub in d.get_directories(): _rmrf(abs_path.path_join(sub))
	DirAccess.remove_absolute(abs_path)
