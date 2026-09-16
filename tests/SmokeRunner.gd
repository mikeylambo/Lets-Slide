extends Node

## Runtime smoke test, run from inside the real project (autoloads and all):
##
##   godot --headless -- --smoke
##
## The unit gate proves the maths; this proves the game boots, the slider
## actually descends, the model swap works mid-run, retry resets state, and the
## lab opens. Those are the five things most likely to break on a refactor and
## least likely to be caught by a parse check.

var _stage = 0
var _frames = 0
var _scene: CourseScene
var _lab: MovementLab
var _start_pos = Vector3.ZERO
var _failures = 0

func _ready() -> void:
	print("── SLIDE smoke test ──")

func check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _process(_delta: float) -> void:
	_frames += 1
	var main = Main.instance
	match _stage:
		0:
			check("autoloads available", Game != null and Game.settings.has("show_ghost"))
			main.play_course(Courses.all()[0])
			_stage = 1
			_frames = 0
		1:
			if _frames == 2:
				_scene = main.world.get_child(main.world.get_child_count() - 1)
				check("course scene instanced", _scene != null)
			if _frames == 14:
				_start_pos = _scene.slider.global_position
			if _frames > 620:
				var moved: float = _start_pos.distance_to(_scene.slider.global_position)
				check("run controller running", _scene.run.state == RunController.State.RUNNING, str(_scene.run.state))
				# With no input the slider only has the 6° start pad to work with,
				# so this asserts "gravity moved it downhill", not a big drop.
				check("slider descended under gravity",
					_scene.slider.global_position.y < _start_pos.y - 1.5,
					"%.2f -> %.2f" % [_start_pos.y, _scene.slider.global_position.y])
				check("slider travelled down the course", moved > 12.0, "%.2f m" % moved)
				check("speed is finite and sane",
					is_finite(_scene.slider.state.speed) and _scene.slider.state.speed < 500.0,
					str(_scene.slider.state.speed))
				check("production clock is 120 Hz", Engine.physics_ticks_per_second == 120,
					str(Engine.physics_ticks_per_second))
				var travel = _scene.slider.state.flat_velocity().normalized()
				if travel.length() > 0.1:
					var camera_offset = _scene.camera.get_camera().global_position - _scene.slider.global_position
					check("camera settles behind rider", camera_offset.dot(travel) < -0.5, str(camera_offset))
				check("timer advanced", _scene.run.time > 0.5, str(_scene.run.time))
				_scene.slider.toggle_model()
				_stage = 2
				_frames = 0
		2:
			if _frames > 90:
				check("reference model engaged",
					_scene.slider.params.model == MotorParams.Model.SM64_REFERENCE)
				check("reference moved the clock to 30 Hz",
					Engine.physics_ticks_per_second == 30, str(Engine.physics_ticks_per_second))
				check("reference speed is finite", is_finite(_scene.slider.state.speed),
					str(_scene.slider.state.speed))
				_scene.run.retry()
				_stage = 3
				_frames = 0
		3:
			if _frames > 12:
				check("retry reset the timer", _scene.run.time < 0.6, str(_scene.run.time))
				if not _scene._built["pickups"].is_empty():
					check("retry restored pickups", not _scene._built["pickups"][0].is_taken())
				else:
					check("tutorial intentionally has no pickups", _scene.course.par_score == 0)
				check("camera is rider anchored", _scene.camera.global_position.distance_to(_scene.slider.global_position) < 5.0, str(_scene.camera.global_position))
				check("Flow system instanced", _scene.flow != null)
				main.open_lab()
				_stage = 4
				_frames = 0
		4:
			if _frames == 2:
				_lab = main.world.get_child(main.world.get_child_count() - 1)
				check("movement lab instanced", _lab != null)
			if _frames > 240:
				check("lab slider is live", is_finite(_lab.slider.state.speed), str(_lab.slider.state.speed))
				check("lab telemetry reads back", _lab.slider.telemetry().has("speed"))
				check("lab built its tuning dock", _lab._panel != null)
				_lab._teleport(400.0)
				_stage = 5
				_frames = 0
		5:
			if _frames > 60:
				check("teleport to a station worked", is_finite(_lab.slider.global_position.length()))
				print("── smoke test: %s ──" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
				get_tree().quit(1 if _failures > 0 else 0)
