extends Node

## World-design camera:  xvfb-run godot --path . --rendering-driver opengl3 --
##     --world-shots=<dir> [--course=course_01]
## Loads a course, parks Ed on the line and renders a fixed shot list (chase
## views along the course plus wide establishing shots) to PNGs, so a map can
## be judged and iterated without playing it. Tools/world-shots.sh wraps it.

var out = ""
var course_id = "course_01"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--world-shots="): out = a.trim_prefix("--world-shots=")
		if a.begins_with("--course="): course_id = a.trim_prefix("--course=")
	DirAccess.make_dir_recursive_absolute(out)
	Game.use_sandbox_profile()
	Game.profile["tutorial_done"] = true
	Main.instance.play_course(Courses.by_id(course_id))
	var scene: CourseScene = Main.instance.current_world()
	for i in 4: await get_tree().process_frame
	scene._ui.visible = false
	scene.slider.set_physics_process(false)
	scene.camera.process_mode = Node.PROCESS_MODE_DISABLED
	var cam = Camera3D.new(); cam.fov = 70.0; cam.far = 4000.0
	scene.add_child(cam); cam.make_current()
	var b: TrackBuilder = scene._built["builder"]
	var L = b.total_length
	# [name, distance fraction, camera offset in the track frame (r, u, f), look-ahead metres]
	var shots = [
		["01_start_chase", 0.02, Vector3(0, 2.6, -7.5), 22.0],
		["02_chase", 0.30, Vector3(0, 2.6, -7.5), 22.0],
		["03_chase", 0.62, Vector3(0, 2.6, -7.5), 22.0],
		["04_establishing", 0.35, Vector3(85, 40, -60), 70.0],
		["05_vista", 0.55, Vector3(-60, 14, 150), -60.0],
		["06_finish", 0.97, Vector3(14, 6, -22), 25.0],
	]
	for shot in shots:
		var s = b.sample_at(L * float(shot[1]))
		var basis = Basis(s["r"], s["u"], s["f"])
		scene.slider.global_position = s["pos"] + s["u"] * 0.65
		scene.slider.state.facing_yaw = atan2(s["f"].x, s["f"].z)
		var off: Vector3 = shot[2]
		cam.global_position = s["pos"] + s["r"] * off.x + Vector3.UP * off.y + s["f"] * off.z
		cam.look_at(s["pos"] + s["f"] * float(shot[3]) + Vector3.UP * 1.0, Vector3.UP)
		for i in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(str(shot[0]) + ".png"))
	get_tree().quit()
