extends Node

## T5 presentation gate:  godot --headless --fixed-fps 120 -- --presentation-test
## Rider model (stand-in and imported GLB), first-run flow and tutorial,
## control remapping, accessibility options. Sandboxed profile.

var failures = 0
var checks = 0

func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok: print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _ready() -> void:
	print("── SLIDE presentation ──")
	Game.use_sandbox_profile()
	await get_tree().process_frame
	await _rider()
	await _first_run_and_tutorial()
	_remap()
	await _accessibility()
	print("── %d checks, %d failures ──" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _rider() -> void:
	var body = SlideBody.new(); add_child(body)
	check("stand-in Ed is built when no model is present", body.rider != null and not body.rider.is_imported and body.rider.get_child_count() > 25, str(body.rider.get_child_count()))
	body.rider.pose(1.0, 1.0, 1.0)
	check("poses are finite at the extremes", body.rider.get_node("head").position.is_finite())
	body.rider.pose(1.0, 0.0, 1.0)
	var hip_low = body.rider.get_node("torso").position.y
	body.rider.pose(0.0, 0.0, 0.0)
	check("tuck lowers the rider", hip_low < body.rider.get_node("torso").position.y)
	body.queue_free()

	# A 2 m tall model exported at runtime is normalised to Ed's 1.2 m.
	var root = Node3D.new(); var mi = MeshInstance3D.new(); var box = BoxMesh.new(); box.size = Vector3(0.6, 2.0, 0.4)
	mi.mesh = box; root.add_child(mi); mi.owner = root
	var doc = GLTFDocument.new(); var st = GLTFState.new()
	doc.append_from_scene(root, st)
	var path = "user://test_rider.glb"
	check("test model exported", doc.write_to_filesystem(st, path) == OK)
	root.free()
	RiderModel.glb_path = path
	var model = RiderModel.new(); add_child(model)
	await get_tree().process_frame
	check("imported model replaces the stand-in", model.is_imported)
	var aabb = RiderModel._aabb(model, Transform3D.IDENTITY)
	check("imported model normalised to riding height", absf(aabb.size.y - RiderModel.HEIGHT * RiderModel.RIDE_SCALE) < 0.01, str(aabb.size))
	check("imported model stands on the board", absf(aabb.position.y - RiderModel.FEET_Y) < 0.01, str(aabb.position))
	model.queue_free()
	RiderModel.glb_path = RiderModel.GLB_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _first_run_and_tutorial() -> void:
	Main.instance.show_menu()
	await get_tree().process_frame
	var labels = []
	for b in Main.instance._screen.find_children("*", "Button", true, false): labels.append(b.text)
	check("new profile is offered the first descent", labels.has("START YOUR FIRST DESCENT"), str(labels))
	var first: Button = Main.instance._screen.find_children("*", "Button", true, false)[0]
	first.pressed.emit()
	await get_tree().process_frame
	var s: CourseScene = Main.instance.current_world()
	check("first descent is Course 01", s != null and s.course.id == "course_01")
	var coach: TutorialCoach = null
	for c in s._ui.get_children():
		if c is TutorialCoach: coach = c
	check("tutorial coach runs on the first descent", coach != null)
	while s.run.state != RunController.State.RUNNING: await get_tree().physics_frame
	s.slider.external_input = func(inp: MotorInput, _b): inp.steer = 0.8
	for i in 90: await get_tree().physics_frame
	await get_tree().process_frame
	check("steering clears the first prompt", coach.step >= 1, str(coach.step))
	s.slider.external_input = func(inp: MotorInput, _b): inp.tuck = true
	for i in 130: await get_tree().physics_frame
	await get_tree().process_frame
	check("tucking clears the next prompt", coach.step >= 2, str(coach.step))
	coach._pad = true; coach._show()
	check("prompts follow the last-used device", coach._glyph.text == "STICK DOWN" or coach._glyph.text == "HOLD X / SQUARE" or coach._glyph.text == "")
	s.run.finish_run(true)
	check("finishing completes the tutorial", bool(Game.profile["tutorial_done"]) and not TutorialCoach.wanted(s.course))

func _remap() -> void:
	var k = InputEventKey.new(); k.physical_keycode = KEY_C
	Game.rebind("tuck", k)
	var has_c = InputMap.action_get_events("tuck").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_C)
	var has_shift = InputMap.action_get_events("tuck").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SHIFT)
	check("rebinding replaces the key", has_c and not has_shift)
	check("controller binding kept when the key changes", InputMap.action_get_events("tuck").any(func(e): return e is InputEventJoypadButton))
	check("binding persisted", int(Game.settings["bindings"]["tuck"]["key"]) == KEY_C)
	check("binding shown by name", Game.binding_text("tuck")["key"] == "C")
	Game.reset_bindings()
	check("reset restores defaults", InputMap.action_get_events("tuck").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SHIFT))
	Game.settings["bindings"] = {"brake": {"pad": 10}}
	Game.apply_bindings()
	check("saved bindings apply at boot", InputMap.action_get_events("brake").any(func(e): return e is InputEventJoypadButton and e.button_index == 10))
	Game.reset_bindings()

func _accessibility() -> void:
	Game.set_setting("ui_scale", 1.25)
	check("interface scale applies", is_equal_approx(get_tree().root.content_scale_factor, 1.25))
	Game.set_setting("ui_scale", 1.0)
	Game.set_setting("reduce_flashes", true)
	Main.instance.play_course(Courses.all()[1])
	var s: CourseScene = Main.instance.current_world()
	s._juice._on_landed(0.2, 40.0)
	await get_tree().process_frame
	check("reduce flashes removes landing flashes", s._juice._fx.landing_flash == 0.0)
	Game.set_setting("reduce_flashes", false)
	Game.set_setting("tuck_toggle", true)
	while s.run.state != RunController.State.RUNNING: await get_tree().physics_frame
	Input.action_press("tuck"); await get_tree().physics_frame; Input.action_release("tuck")
	for i in 5: await get_tree().physics_frame
	check("tuck toggle latches on", s.slider.input.tuck)
	Input.action_press("tuck"); await get_tree().physics_frame; Input.action_release("tuck")
	for i in 5: await get_tree().physics_frame
	check("tuck toggle latches off", not s.slider.input.tuck)
	Game.set_setting("tuck_toggle", false)
