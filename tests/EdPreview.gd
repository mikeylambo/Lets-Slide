extends Node3D

## Visual check for the rider (no assertions):  -- --ed-preview[=pose]
## Renders Ed on the board from three angles in a lit void; used with the web
## build + headless Chromium to eyeball the model without a display.

func _ready() -> void:
	var env = WorldEnvironment.new(); var e = Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.09, 0.1, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.55, 0.58, 0.65); e.ambient_light_energy = 0.8
	env.environment = e; add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 35, 0); sun.light_energy = 1.3; add_child(sun)
	var pose = "ride"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ed-preview="): pose = a.trim_prefix("--ed-preview=")
	var views = [Vector3(0, 0.6, 2.6), Vector3(2.4, 0.7, 0.8), Vector3(0.6, 0.9, -2.6)]
	for i in 3:
		var vp = SubViewportContainer.new(); vp.stretch = true
		vp.position = Vector2(i * 533, 0); vp.size = Vector2(533, 900)
		var sv = SubViewport.new(); sv.own_world_3d = false; vp.add_child(sv)
		var cam = Camera3D.new(); cam.fov = 40
		cam.look_at_from_position(views[i], Vector3(0, 0.2, 0))
		sv.add_child(cam)
		var ui = CanvasLayer.new(); add_child(ui); ui.add_child(vp)
	var body = SlideBody.new()
	add_child(body)
	body.set_physics_process(false)
	var board = body.get_node("Visual")
	match pose:
		"tuck": body.rider.pose(1.0, 0.0, 1.0)
		"air": body.rider.pose(0.0, 1.0, 0.6)
		_: body.rider.pose(0.0, 0.0, 0.6)

	_shoot()

## --shot=<path>: save a screenshot after a few frames, then quit.
func _shoot() -> void:
	var path = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): path = a.trim_prefix("--shot=")
	if path == "": return
	for i in 12: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
