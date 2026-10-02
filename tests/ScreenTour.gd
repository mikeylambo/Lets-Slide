extends Node

## Visual QA:  xvfb-run godot --path . --rendering-driver opengl3 -- --screen-tour=<dir>
## Renders every screen (and a live run with Ed) to PNGs for review.

var out = ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen-tour="): out = a.trim_prefix("--screen-tour=")
	DirAccess.make_dir_recursive_absolute(out)
	Game.use_sandbox_profile()
	Game.profile["total_runs"] = 3
	var m = Main.instance
	await _shot("01_menu", func(): m.show_menu())
	await _shot("02_modes", func(): m.show_mode_select())
	await _shot("03_courses_select", func(): Game.set_mode(Game.Mode.MARATHON); m.show_course_select())
	await _shot("04_options", func(): m.show_options())
	await _shot("05_controls", func(): m.show_controls())
	await _shot("06_courses", func(): CustomCourses.root = "user://tour_courses"; CustomCourses.save(CustomCourses.template()); m.show_courses())
	await _shot("07_editor", func(): m.show_course_editor(CustomCourses.template()))
	await _shot("08_lobby", func(): m.show_lobby())
	await _shot("09_codex", func(): Game.discover_tech("crest_release"); m.show_codex())
	await _shot("10_run_codes", func(): m.show_run_codes())
	Game.set_mode(Game.Mode.CAMPAIGN)
	Game.profile["tutorial_done"] = false
	m.play_course(Courses.all()[0])
	var s: CourseScene = m.current_world()
	while s.run.state != RunController.State.RUNNING: await get_tree().process_frame
	s.slider.external_input = func(inp: MotorInput, _b): inp.tuck = true; inp.steer = 0.2
	for i in 150: await get_tree().process_frame
	await _save("11_run")
	s.run.finish_run(true)
	for i in 20: await get_tree().process_frame
	await _save("12_results")
	get_tree().quit()

func _shot(name: String, f: Callable) -> void:
	f.call()
	for i in 6: await get_tree().process_frame
	await _save(name)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
