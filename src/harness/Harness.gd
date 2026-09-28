extends Node

## LET'S SLIDE — Playtest Harness (dev-only).
##
##   Tools/playtest.sh            (Windows: Playtest.cmd / Tools\playtest.ps1)
##   godot --path . -- --harness [--course=course_01] [--preset="Name"] [--b="Name"] [--blind]
##
## Main.gd loads this file by path only in debug builds; nothing in the shipping
## game references src/harness/ and every export preset excludes it.
##
## It drives the real CourseScene (same motor, camera, HUD, Flow, audio) with a
## live MotorParams instance the panel edits in place, so every change lands on
## the very next physics tick.

const PresetStore = preload("res://src/harness/PresetStore.gd")
const RunLog = preload("res://src/harness/RunLog.gd")
const TrackLocator = preload("res://src/harness/TrackLocator.gd")
const SessionReport = preload("res://src/harness/SessionReport.gd")
const HarnessPanel = preload("res://src/harness/HarnessPanel.gd")
const HarnessOverlay = preload("res://src/harness/HarnessOverlay.gd")
const ReadabilityKit = preload("res://src/harness/ReadabilityKit.gd")

const RETRY_COUNTDOWN = 0.1          ## control returns ~100 ms after R / Y
const REBUILD_DEBOUNCE = 0.4
const SLOT_COLORS = [Color(0.22, 0.95, 1.0, 0.34), Color(1.0, 0.35, 0.88, 0.34)]
const BLIND_COLOR = Color(0.9, 0.92, 1.0, 0.30)
const ACTIONS = {
	"harness_panel": [KEY_F1, JOY_BUTTON_RIGHT_SHOULDER],
	"harness_kit": [KEY_F2, JOY_BUTTON_LEFT_STICK],
	"harness_swap": [KEY_TAB, JOY_BUTTON_LEFT_SHOULDER],
	"harness_marker": [KEY_N, JOY_BUTTON_BACK],
	"harness_blind": [KEY_B, -1],
	"harness_click": [KEY_M, -1],
	"harness_telemetry": [KEY_T, -1],
}

## Set before add_child to override command-line options (used by tests).
var config: Dictionary = {}

var course: CourseData
var params = MotorParams.new()       ## the live instance the slider reads every tick
var presets
var kit
var panel
var overlay
var scene: CourseScene
var locator

var slots: Array = [{}, {}]          ## {name, motor, camera, working}
var active = 0
var blind = false
var blind_labels = ["X", "Y"]
var blind_reveal: Array = []
var rating_prompt = true

var session: Dictionary = {}
var runs: Array = []
var markers: Array = []
var variants: Dictionary = {}
var last_retry_ms = -1.0

var _log
var _run_counter = 0
var _rebuild_timer = -1.0
var _retry_usec = 0
var _finalized = false
var _quit_on_exit = true
var _root = "user://"
var _ui: CanvasLayer
var _marker_nodes: Array = []
var _variant_cache = {"dict": {}, "id": ""}

# ================================================================ lifecycle
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 900
	_parse_config()
	_register_actions()
	presets = PresetStore.new(_root.path_join("presets"))
	presets.ensure_seeded(Game.presets)
	var names: Array = presets.names()
	var a_name = str(config.get("preset", "Current Candidate"))
	if not presets.exists(a_name): a_name = str(names[0])
	var b_name = str(config.get("b", "Arcade Clean"))
	if not presets.exists(b_name) or b_name == a_name:
		b_name = str(names[1 if names.size() > 1 and names[0] == a_name else 0])
	_fill_slot(0, a_name)
	_fill_slot(1, b_name)
	params.from_dict(slots[0]["working"])
	_open_session()

	kit = ReadabilityKit.new()
	add_child(kit)
	_ui = CanvasLayer.new()
	_ui.layer = 30
	add_child(_ui)
	overlay = HarnessOverlay.new()
	overlay.setup(self)
	_ui.add_child(overlay)
	overlay.rated.connect(_on_rated)
	panel = HarnessPanel.new()
	_ui.add_child(panel)
	panel.setup(self)
	if bool(config.get("blind", false)):
		set_toggle("blind", true)

	print("PLAYTEST HARNESS · %s · A=%s B=%s · session %s" % [course.id, a_name, b_name, ProjectSettings.globalize_path(session["dir"])])
	_launch(false)

func _parse_config() -> void:
	for arg in OS.get_cmdline_user_args():
		for key in ["course", "preset", "b"]:
			if arg.begins_with("--%s=" % key) and not config.has(key):
				config[key] = arg.trim_prefix("--%s=" % key).trim_prefix("\"").trim_suffix("\"")
		if arg == "--blind" and not config.has("blind"):
			config["blind"] = true
	_root = str(config.get("root", "user://"))
	_quit_on_exit = bool(config.get("quit_on_exit", true))
	course = Courses.by_id(str(config.get("course", "course_01")))
	if course == null:
		push_warning("Harness: unknown course '%s', using course_01" % config.get("course"))
		course = Courses.all()[0]

func _register_actions() -> void:
	for action in ACTIONS.keys():
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.5)
		var key = InputEventKey.new()
		key.physical_keycode = ACTIONS[action][0]
		InputMap.action_add_event(action, key)
		if int(ACTIONS[action][1]) >= 0:
			var pad = InputEventJoypadButton.new()
			pad.button_index = ACTIONS[action][1]
			InputMap.action_add_event(action, pad)

func _open_session() -> void:
	var id = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var dir = _root.path_join("playtests").path_join(id)
	var n = 2
	while DirAccess.dir_exists_absolute(dir):
		dir = _root.path_join("playtests").path_join("%s_%d" % [id, n]); n += 1
	DirAccess.make_dir_recursive_absolute(dir)
	var commit = OS.get_environment("LETS_SLIDE_COMMIT")
	session = {
		"id": dir.get_file(), "dir": dir, "started_unix": Time.get_unix_time_from_system(),
		"commit": commit if commit != "" else "local", "godot": Engine.get_version_info()["string"],
	}

func _launch(fast: bool) -> void:
	Main.instance.play_course(course, params)
	_adopt(Main.instance.current_world(), fast)

func _adopt(s: CourseScene, fast: bool) -> void:
	scene = s
	s.show_results = false
	var run: RunController = s.run
	run.retry_countdown = RETRY_COUNTDOWN
	run.record_results = false
	run.ghost_path = _ghost_path(active)
	locator = TrackLocator.new(s._built["builder"])
	run.run_restarted.connect(_on_run_restarted)
	run.run_finished.connect(_on_run_finished)
	run.state_changed.connect(_on_state_changed)
	run.checkpoint_reached.connect(func(i): _event("checkpoint", "cp=%d" % i))
	run.respawned.connect(func(): _event("respawn", ""))
	s.slider.took_off.connect(func(v): _event("pop", "launch=%.2f" % v))
	s.slider.landed.connect(_on_landed)
	s.slider.bonked.connect(func(v): _event("bonk", "speed=%.2f" % v))
	s.camera.params.from_dict(slots[active]["camera"])
	kit.attach(s)
	_respawn_marker_nodes()
	# CourseScene already began a run inside _ready; restart so the ghost path,
	# countdown and our signal hooks all apply from tick zero.
	run.begin(fast)

func _process(delta: float) -> void:
	if _finalized:
		return
	var current = Main.instance.current_world() if Main.instance else null
	if current != scene:
		if current is CourseScene:
			_adopt(current, true)       # F4 inspector rebuilt the course
		else:
			finalize()                  # pause menu → exit ends the session
			if _quit_on_exit: get_tree().quit()
			return
	if _rebuild_timer > 0.0:
		_rebuild_timer -= delta
		if _rebuild_timer <= 0.0:
			_rebuild()
	if scene and is_instance_valid(scene) and scene.ghost:
		scene.ghost.set_color(BLIND_COLOR if blind else SLOT_COLORS[active])

func _physics_process(delta: float) -> void:
	if _log == null or scene == null or not is_instance_valid(scene):
		return
	if scene.run.state != RunController.State.RUNNING:
		return
	_ensure_numbered()
	_log.sample(delta, scene.slider, locator.locate(scene.slider.global_position))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finalize()

func _exit_tree() -> void:
	finalize()

# ==================================================================== input
func _input(event: InputEvent) -> void:
	if _finalized or scene == null or not is_instance_valid(scene):
		return
	if event.is_action_pressed("harness_panel"):
		panel.toggle(); _handled(); return
	if panel.editing_text():
		return
	if overlay.handle_rating_input(event):
		_handled(); return
	if event.is_action_pressed("retry"):
		retry(); _handled()
	elif event.is_action_pressed("harness_swap"):
		swap_slots(); _handled()
	elif event.is_action_pressed("harness_marker"):
		drop_marker(); _handled()
	elif event.is_action_pressed("harness_kit"):
		set_toggle("kit", not kit.enabled); _handled()
	elif event.is_action_pressed("harness_click"):
		set_toggle("click", not kit.click_enabled); _handled()
	elif event.is_action_pressed("harness_blind"):
		set_toggle("blind", not blind); _handled()
	elif event.is_action_pressed("harness_telemetry"):
		scene.hud.toggle_telemetry(); _handled()
	elif event.is_action_pressed("toggle_lab"):
		_handled()                      # F1 belongs to the harness here

func _handled() -> void:
	get_viewport().set_input_as_handled()

# ===================================================================== runs
func retry() -> void:
	if scene == null or not is_instance_valid(scene):
		return
	if get_tree().paused:
		return
	overlay.hide_card()
	_retry_usec = Time.get_ticks_usec()
	scene.run.retry()

func _on_run_restarted(_fast: bool) -> void:
	_close_log("retry")
	_log = RunLog.new()
	_log.course_id = course.id
	_log.preset = slot_name(active)
	_log.slot = ["A", "B"][active]
	_log.seen_as = slot_label(active)
	_log.blind = blind
	_log.camera_start = slots[active]["camera"].duplicate(true)
	locator.reset()
	kit.on_run_stopped()

func _on_state_changed(state: int) -> void:
	if state == RunController.State.RUNNING:
		if _retry_usec > 0:
			last_retry_ms = float(Time.get_ticks_usec() - _retry_usec) / 1000.0
			_retry_usec = 0
		if _log and not _log.started:
			_log.started = true
			_log.started_at = Time.get_datetime_string_from_system(false, true)
			_log.params_start = params.to_dict()
			_log.variant = current_variant()
			_track_variant()
			kit.on_run_started()

func _on_landed(quality: float, speed: float) -> void:
	if _log and scene.run.state == RunController.State.RUNNING:
		_log.add_landing(quality)
	_event("land", "q=%.2f speed=%.2f" % [quality, speed])

func _event(kind: String, detail: String) -> void:
	if _log and scene and scene.run.state == RunController.State.RUNNING:
		_log.event(kind, detail)

func _on_run_finished(result: Dictionary) -> void:
	kit.on_run_stopped()
	if _log == null:
		return
	var best_before = session_best(_log.key())
	var finished = bool(result.get("finished", false))
	_log.result = result
	_ensure_numbered()
	_close_log("finished" if finished else "failed")
	var last: Dictionary = runs[runs.size() - 1]
	if finished and not bool(last["mixed"]):
		var gpath = _ghost_path(active)
		var prev = Ghost.peek_duration(gpath)
		if prev <= 0.0 or float(result["time"]) < prev:
			if scene.ghost.save_path(gpath):
				overlay.toast("NEW %s GHOST · %s" % [slot_display(active, false), RunController.format_time(float(result["time"]))], UiKit.GOOD)
	overlay.show_result(result, best_before, rating_prompt)

func _on_rated(stars: int) -> void:
	if runs.is_empty():
		return
	var last: Dictionary = runs[runs.size() - 1]
	last["rating"] = stars
	if _last_closed:
		_last_closed.rating = stars
		_last_closed.write(session["dir"])
	write_summary()

var _last_closed

func _close_log(outcome: String) -> void:
	if _log == null:
		return
	var lg = _log
	_log = null
	if not lg.has_content():
		return
	lg.outcome = outcome
	lg.params_end = params.to_dict()
	lg.write(session["dir"])
	runs.append(lg.summary())
	_last_closed = lg
	write_summary()

func _ensure_numbered() -> void:
	if _log and _log.number == 0:
		_run_counter += 1
		_log.number = _run_counter

func current_run_number() -> int:
	return _log.number if _log and _log.number > 0 else _run_counter + 1

# ================================================================== markers
func drop_marker() -> void:
	if scene == null or not is_instance_valid(scene):
		return
	if _log == null:
		_on_run_restarted(true)
	_ensure_numbered()
	var st = scene.slider.state
	var pos = scene.slider.global_position
	var loc = locator.locate(pos)
	var m = {
		"n": markers.size() + 1, "run": _log.number, "t": snappedf(scene.run.time, 0.001),
		"preset": slot_name(active), "preset_key": current_key(), "slot": ["A", "B"][active],
		"seen_as": slot_label(active), "position": pos, "speed": snappedf(st.speed, 0.01),
		"grounded": st.grounded, "bar": snappedf(float(loc["bar"]), 0.01), "dist": snappedf(float(loc["dist"]), 0.1),
		"segment": int(loc["segment"]), "kind": str(loc["kind"]),
		"avg_speed": params.author_avg_speed,
	}
	markers.append(m)
	_log.markers.append(m)
	_log.event("marker", "#%d bar=%.2f" % [m["n"], m["bar"]])
	_spawn_marker_node(m)
	overlay.toast("MARKER %d  ·  BAR %.2f  ·  %s  ·  %.0f km/h" % [m["n"], m["bar"], m["kind"], st.speed * 3.6], UiKit.WARN)
	write_summary()

func _spawn_marker_node(m: Dictionary) -> void:
	if scene == null or not is_equal_approx(float(m["avg_speed"]), params.author_avg_speed):
		return
	var root = Node3D.new()
	root.position = m["position"]
	var pole = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.06; mesh.bottom_radius = 0.06; mesh.height = 3.2
	pole.mesh = mesh
	pole.position.y = 1.6
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = UiKit.WARN
	pole.material_override = mat
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pole)
	var label = Label3D.new()
	label.text = "M%d · bar %.2f" % [m["n"], m["bar"]]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = UiKit.WARN
	label.font_size = 48
	label.pixel_size = 0.01
	label.position.y = 3.6
	root.add_child(label)
	scene.add_child(root)
	_marker_nodes.append(root)

func _respawn_marker_nodes() -> void:
	_marker_nodes.clear()
	for m in markers:
		_spawn_marker_node(m)

# ==================================================================== slots
func _fill_slot(i: int, preset_name: String) -> bool:
	var p = presets.load_preset(preset_name)
	if p.is_empty():
		return false
	var base = MotorParams.new()
	base.from_dict(p["motor"])
	slots[i] = {"name": str(p["name"]), "motor": base.to_dict(), "camera": p["camera"], "working": base.to_dict()}
	return true

func slot_name(i: int) -> String:
	return str(slots[i].get("name", "—"))

func slot_label(i: int) -> String:
	return blind_labels[i] if blind else ["A", "B"][i]

func slot_display(i: int, with_label: bool = true) -> String:
	if blind:
		return "%s  ·  ????" % slot_label(i) if with_label else "SLOT %s" % slot_label(i)
	var v = current_variant() if i == active else _variant_of(slots[i]["working"], slots[i]["motor"])
	var text = slot_name(i).to_upper() + v
	return ("%s  ·  %s" % [slot_label(i), text]) if with_label else text

func slot_baseline(i: int) -> Dictionary:
	return slots[i]["motor"]

func activate_slot(i: int) -> void:
	if i != active:
		swap_slots()

func swap_slots() -> void:
	if slots[1 - active].is_empty():
		return
	slots[active]["working"] = params.to_dict()
	var from_label = slot_label(active)
	active = 1 - active
	_apply_active(true)
	_event("swap", "%s->%s" % [from_label, slot_label(active)])
	if _log and scene.run.state == RunController.State.RUNNING:
		_log.mixed = true
	overlay.toast("▶  %s" % slot_display(active), SLOT_COLORS[active] if not blind else UiKit.TEXT)

func load_into_slot(i: int, preset_name: String) -> void:
	if _fill_slot(i, preset_name):
		if i == active: _apply_active(false)
		overlay.toast("%s ← %s" % [["A", "B"][i], preset_name])
		panel.refresh()

func save_active(preset_name: String) -> void:
	var motor = params.to_dict()
	var camera: Dictionary = scene.camera.params.to_dict() if scene else slots[active]["camera"]
	if presets.save(preset_name, motor, camera) == "":
		return
	slots[active] = {"name": preset_name, "motor": motor.duplicate(), "camera": camera, "working": motor.duplicate()}
	if scene: scene.run.ghost_path = _ghost_path(active)
	overlay.toast("SAVED  %s" % preset_name, UiKit.GOOD)
	panel.refresh()

func _apply_active(mid_run: bool) -> void:
	var w: Dictionary = slots[active]["working"]
	var rebuild = not is_equal_approx(float(w.get("author_avg_speed", params.author_avg_speed)), params.author_avg_speed)
	var old_model = params.model
	params.from_dict(w)
	if scene and is_instance_valid(scene):
		var new_model = params.model
		if new_model != old_model:
			params.model = old_model
			scene.slider.set_model(new_model)
		scene.slider.apply_simulation_rate()
		scene.camera.params.from_dict(slots[active]["camera"])
		scene.run.ghost_path = _ghost_path(active)
		if mid_run and scene.ghost:
			if scene.ghost.load_path(scene.run.ghost_path):
				scene.ghost.start_playback()
				scene.ghost.seek(scene.run.time if scene.run.state == RunController.State.RUNNING else 0.0)
			else:
				scene.ghost.stop_playback()
	if rebuild:
		_rebuild_timer = 0.01
	panel.refresh()

# =================================================================== tuning
func set_param(prop: String, value: float) -> void:
	if is_equal_approx(float(params.get(prop)), value):
		return
	params.set(prop, value)
	_event("param", "%s=%s" % [prop, str(snappedf(value, 0.0001))])
	if _log and scene and scene.run.state == RunController.State.RUNNING:
		_log.tweaked = true
	match prop:
		"simulation_hz", "sm64_hz":
			if scene: scene.slider.apply_simulation_rate()
		"author_avg_speed":
			_rebuild_timer = REBUILD_DEBOUNCE
	panel.refresh_values()

func reset_param(prop: String) -> void:
	var base: Dictionary = slots[active]["motor"]
	if base.has(prop):
		set_param(prop, float(base[prop]))

func _rebuild() -> void:
	_rebuild_timer = -1.0
	_close_log("rebuild")
	overlay.toast("COURSE REBUILT @ %.1f m/s author speed" % params.author_avg_speed)
	_launch(true)

func set_toggle(key: String, on: bool) -> void:
	match key:
		"kit":
			kit.set_enabled(on)
			overlay.toast("READABILITY KIT " + ("ON" if on else "OFF"))
		"click":
			kit.click_enabled = on
			overlay.toast("174 BPM CLICK " + ("ON" if on else "OFF"))
		"rating":
			rating_prompt = on
		"blind":
			blind = on
			if on:
				blind_labels = ["X", "Y"] if randi() % 2 == 0 else ["Y", "X"]
				blind_reveal.append("%s = %s, %s = %s" % [blind_labels[0], slot_name(0), blind_labels[1], slot_name(1)])
			overlay.toast("BLIND MODE " + ("ON · slots are X / Y" if on else "OFF"))
	panel.refresh()

func get_toggle(key: String) -> bool:
	match key:
		"kit": return kit.enabled
		"click": return kit.click_enabled
		"rating": return rating_prompt
		"blind": return blind
	return false

# ================================================================= variants
## "" when the live params equal the saved preset; otherwise a short stable
## hash so every distinct tuning gets its own row in the summary.
func current_variant() -> String:
	return _variant_of(params.to_dict(), slots[active]["motor"])

func current_key() -> String:
	return slot_name(active) + current_variant()

func _variant_of(now: Dictionary, base: Dictionary) -> String:
	var diff = false
	for k in now.keys():
		if not base.has(k) or not is_equal_approx(float(now[k]), float(base[k])):
			diff = true
			break
	if not diff:
		return ""
	var keys = now.keys()
	keys.sort()
	var parts = PackedStringArray()
	for k in keys:
		parts.append("%s=%s" % [k, str(snappedf(float(now[k]), 0.0001))])
	return "~%04x" % (hash(",".join(parts)) & 0xffff)

func _track_variant() -> void:
	var key = current_key()
	if not variants.has(key):
		variants[key] = {"preset": slot_name(active), "variant": current_variant(),
			"params": params.to_dict(), "baseline": slots[active]["motor"].duplicate()}

func session_best(key: String) -> float:
	var best = 0.0
	for r in runs:
		if r["key"] == key and bool(r["finished"]) and not bool(r["mixed"]):
			if best <= 0.0 or float(r["time"]) < best:
				best = float(r["time"])
	return best

func ghost_best(preset_name: String) -> float:
	return Ghost.peek_duration(presets.ghost_path(course.id, preset_name))

func _ghost_path(i: int) -> String:
	return presets.ghost_path(course.id, slot_name(i))

func current_bar() -> float:
	if locator == null or scene == null or not is_instance_valid(scene):
		return 0.0
	return float(locator.locate(scene.slider.global_position)["bar"])

func total_bars() -> float:
	return locator.total_bars() if locator else course.total_bars

# ================================================================== reports
func write_summary() -> String:
	var md = SessionReport.build(self)
	var path = session["dir"].path_join("summary.md")
	_write_text(path, md)
	var sess = {"session": session, "runs": runs, "markers": markers, "variants": variants, "blind_reveal": blind_reveal}
	_write_text(session["dir"].path_join("session.json"), JSON.stringify(RunLog._jsonable(sess), "\t", false))
	# Running from source: mirror the handoff into <project>/playtests/ so it is
	# one click away (git-ignored). Exported builds never reach this code.
	if bool(config.get("mirror", true)) and OS.has_feature("editor"):
		var proj = ProjectSettings.globalize_path("res://playtests")
		DirAccess.make_dir_recursive_absolute(proj.path_join(session["id"]))
		_write_text(proj.path_join(session["id"]).path_join("summary.md"), md)
		_write_text(proj.path_join("LATEST.md"), md)
	return path

func finalize() -> void:
	if _finalized or session.is_empty():
		return
	_finalized = true
	_close_log("quit")
	var path = write_summary()
	print("PLAYTEST SUMMARY: %s" % ProjectSettings.globalize_path(path))

static func _write_text(path: String, text: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Harness: could not write %s" % path)
		return
	f.store_string(text)
	f.close()
