class_name CourseScene
extends Node3D

var course: CourseData
var slider: SlideBody
var camera: SlideCamera
var run: RunController
var ghost: Ghost
var author_ghost: Ghost
var hud: HUD
var flow: FlowSystem
var audio: AudioDirector
var _env: WorldEnvironment
var _visual_flow: FlowVisualDirector
var _built = {}
var _ui = CanvasLayer.new()
var _results: ResultsScreen
var _pause: PauseMenu
var _inspector: CourseInspector
var _juice: JuiceDirector

func _ready() -> void:
	if course == null: course = Courses.all()[0]
	_env = WorldKit.add_environment(self,course.region_index); WorldKit.add_sun(self,course.region_index)
	slider = SlideBody.new(); slider.params=MotorParams.new()
	var camera_params = CameraParams.new(); Game.load_preset("Current Candidate",slider.params,camera_params)
	_built = CourseFactory.build(course, slider.params.author_avg_speed); add_child(_built["root"])
	WorldKit.add_shelf_architecture(self,_built["builder"],course.region_index)

	add_child(slider)
	var start_pos:Vector3=_built["start_position"]; var start_yaw:float=float(_built["start_yaw"])
	slider.global_position=start_pos; slider.state.reset(start_pos,start_yaw); slider.set_spawn(start_pos,start_yaw)

	camera=SlideCamera.new(); camera.params=camera_params; add_child(camera); camera.bind(slider)
	ghost=Ghost.new(); add_child(ghost)
	author_ghost=Ghost.new(); add_child(author_ghost)
	author_ghost.set_color(Color(0.72,0.46,1.0,0.18 + 0.34 * float(Game.settings.get("ghost_opacity",0.28))))
	if author_ghost.load_author(_built["builder"],course.author_time): author_ghost.start_playback()

	flow=FlowSystem.new(); add_child(flow); flow.setup(slider)
	audio=AudioDirector.new(); add_child(audio); audio.setup(slider,flow,course.region_index)
	_visual_flow=FlowVisualDirector.new(); add_child(_visual_flow); _visual_flow.setup(_env,slider,flow)

	_ui.layer=8; add_child(_ui); hud=HUD.new(); _ui.add_child(hud)
	run=RunController.new(); add_child(run); run.run_restarted.connect(_on_run_restarted)
	run.setup(course,_built,slider,ghost,flow); audio.bind_run(run); hud.setup(run,slider,ghost)
	_juice=JuiceDirector.new(); add_child(_juice); _juice.setup(slider,flow,run)
	run.run_finished.connect(_on_run_finished)
	if Game.current_mode==Game.Mode.SURVIVAL: run.respawned.connect(_on_survival_respawn)
	if bool(Game.settings.get("touch_controls",false)) or DisplayServer.is_touchscreen_available():
		var touch=TouchControls.new(); _ui.add_child(touch); touch.bind(slider)

func _process(delta:float)->void:
	if camera and slider: slider.camera_basis=camera.get_camera().global_basis
	if author_ghost and author_ghost.playing and run and run.state == RunController.State.RUNNING: author_ghost.advance(delta)

func _unhandled_input(event:InputEvent)->void:
	if event.is_action_pressed("pause_menu"): _toggle_pause(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry") and run.state!=RunController.State.FINISHED: run.retry(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_model"): slider.toggle_model(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_lab"): Main.instance.open_lab(); get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode==KEY_F2: hud.toggle_telemetry(); get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode==KEY_F4: _toggle_inspector(); get_viewport().set_input_as_handled()

func _on_run_restarted(fast: bool = false)->void:
	if camera:
		if fast: camera.snap_to_target()
		else: camera.play_start_swivel(float(_built["start_yaw"]))
	if author_ghost:
		author_ghost.stop_playback()
		if author_ghost.load_author(_built["builder"],course.author_time): author_ghost.start_playback()

func _on_survival_respawn()->void:
	Game.survival_lives-=1
	if Game.survival_lives<=0: run.fail("OUT OF LIVES")

func _on_run_finished(result: Dictionary) -> void:
	if _juice: _juice.finish_burst()
	# Survival and Endless are continuous modes. A successful section rolls into
	# the next descent without inserting a results modal; failures still surface
	# the full feedback screen.
	if bool(result.get("finished", false)) and Game.current_mode in [Game.Mode.SURVIVAL, Game.Mode.ENDLESS]:
		await get_tree().create_timer(0.55).timeout
		Main.instance.next_mode_course()
		return
	_results = ResultsScreen.new()
	_results.result = result
	_results.course = course
	_results.retry_requested.connect(_on_retry)
	_results.exit_requested.connect(func(): Main.instance.show_mode_select())
	_results.next_requested.connect(func(): Main.instance.next_mode_course())
	_ui.add_child(_results)

func _on_retry()->void:
	if _results and is_instance_valid(_results): _results.queue_free(); _results=null
	run.retry()

func _toggle_inspector()->void:
	if _inspector and is_instance_valid(_inspector): _inspector.queue_free(); _inspector=null; return
	_inspector = CourseInspector.new()
	_inspector.course = course
	_inspector.rebuild_requested.connect(_on_inspector_rebuild)
	_ui.add_child(_inspector)

func _on_inspector_rebuild(spec: Array) -> void:
	course.spec = spec.duplicate(true)
	Main.instance.play_course(course)

func _toggle_pause()->void:
	if _pause and is_instance_valid(_pause): _close_pause(); return
	if run.state==RunController.State.FINISHED:return
	get_tree().paused=true; run.pause_run(); _pause=PauseMenu.new(); _pause.process_mode=Node.PROCESS_MODE_ALWAYS
	_pause.resume_requested.connect(_close_pause); _pause.retry_requested.connect(func():_close_pause();run.retry())
	_pause.exit_requested.connect(func():get_tree().paused=false;Main.instance.quit_to_menu()); _ui.add_child(_pause)
func _close_pause()->void:
	if _pause and is_instance_valid(_pause):_pause.queue_free();_pause=null
	get_tree().paused=false;run.resume_run()
func _exit_tree()->void:get_tree().paused=false
