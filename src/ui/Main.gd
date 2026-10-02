class_name Main
extends Node

## Dev-only playtest harness. Loaded by path (never by class name) so shipping
## code has no dependency on it; export presets exclude the folder entirely.
const HARNESS_ENTRY = "res://src/harness/Harness.gd"

static var instance: Main
var world: Node3D
var ui: CanvasLayer
var _world_child: Node
var _screen: Control

func _ready() -> void:
	instance = self
	world = Node3D.new(); world.name = "World"; add_child(world)
	ui = CanvasLayer.new(); ui.name = "UI"; ui.layer = 10; add_child(ui)
	var args = OS.get_cmdline_user_args()
	if "--unit" in args:
		add_child(load("res://tests/HeadlessTests.gd").new())
		return
	if "--smoke" in args:
		add_child(load("res://tests/SmokeRunner.gd").new())
		return
	if "--probe" in args:
		add_child(load("res://tests/CourseProbe.gd").new())
		return
	if "--human-probe" in args:
		add_child(load("res://tests/HumanToleranceProbe.gd").new())
		return
	if "--generate" in args:
		add_child(load("res://tests/GeneratorBatch.gd").new())
		return
	if "--export-courses" in args:
		add_child(load("res://tests/CourseExporter.gd").new())
		return
	if "--community-test" in args:
		add_child(load("res://tests/CommunityTests.gd").new())
		return
	if "--speedrun-test" in args:
		add_child(load("res://tests/SpeedrunTests.gd").new())
		return
	if "--replay-test" in args:
		add_child(load("res://tests/ReplayTests.gd").new())
		return
	if "--apply-medals" in args:
		add_child(load("res://tests/MedalWriter.gd").new())
		return
	if "--harness" in args or "--harness-test" in args:
		if harness_available():
			var runner = HARNESS_ENTRY if "--harness" in args else "res://tests/HarnessTests.gd"
			add_child(load(runner).new())
			return
		push_warning("Playtest harness requires a debug build from source; opening menu.")
	if "--lab" in args and Game.dev_tools: open_lab()
	else: show_menu()

func show_menu() -> void: _clear_world(); _set_screen(MainMenu.new())
func show_mode_select() -> void: _clear_world(); _set_screen(ModeSelect.new())
func show_course_select() -> void: _clear_world(); _set_screen(CourseSelect.new())
func show_records() -> void: _set_screen(RecordsScreen.new())
func show_options() -> void: _set_screen(OptionsScreen.new())
func show_cosmetics() -> void: _set_screen(CosmeticsScreen.new())
func show_leaderboards() -> void: _set_screen(LeaderboardsScreen.new())

static func harness_available() -> bool:
	return OS.is_debug_build() and ResourceLoader.exists(HARNESS_ENTRY)

func current_world() -> Node: return _world_child

## opts: {"rival": Replay} races a recorded run, {"watch": Replay} plays one back.
func play_course(data: CourseData, params_override: MotorParams = null, opts: Dictionary = {}) -> void:
	_set_screen(null); _clear_world()
	var scene = CourseScene.new(); scene.course = data; scene.params_override = params_override
	scene.rival_replay = opts.get("rival"); scene.watch_replay = opts.get("watch")
	_world_child = scene; world.add_child(scene)

func start_daily() -> void:
	Game.set_mode(Game.Mode.DAILY); play_course(CourseGenerator.daily())
func start_endless() -> void:
	Game.set_mode(Game.Mode.ENDLESS); play_course(CourseGenerator.endless(Game.endless_prestige))
func start_marathon(region: int) -> void:
	Game.start_marathon(region); play_course(Courses.region_courses(region)[0])
func show_run_codes() -> void: _clear_world(); _set_screen(RunCodeScreen.new())
func show_codex() -> void: _set_screen(CodexScreen.new())
func show_courses() -> void: _clear_world(); _set_screen(CoursesScreen.new())
func show_course_editor(c: CourseData) -> void:
	_clear_world(); var e = CourseEditor.new(); e.course = c; _set_screen(e)
## Leaving a course returns to the editor after a test ride, else mode select.
func leave_course() -> void:
	get_tree().paused = false
	if Game.editor_course: show_course_editor(Game.editor_course)
	else: show_mode_select()
func start_survival() -> void:
	Game.set_mode(Game.Mode.SURVIVAL); Game.survival_lives = 3; Game.survival_course_index = 0; play_course(Courses.all()[0])

func next_mode_course() -> void:
	match Game.current_mode:
		Game.Mode.SURVIVAL:
			Game.survival_course_index += 1
			if Game.survival_course_index >= Courses.all().size(): Game.survival_course_index = 0
			play_course(Courses.all()[Game.survival_course_index])
		Game.Mode.ENDLESS:
			Game.endless_prestige += 1
			Game.profile["prestige"] = maxi(int(Game.profile.get("prestige",0)), Game.endless_prestige)
			Game.save_profile(); play_course(CourseGenerator.endless(Game.endless_prestige))
		Game.Mode.DAILY: start_daily()
		Game.Mode.MARATHON:
			var list = Courses.region_courses(int(Game.marathon["region"]))
			play_course(list[int(Game.marathon["index"])])
		_: show_course_select()

func open_lab() -> void:
	if not Game.dev_tools: return
	_set_screen(null); _clear_world(); var lab = MovementLab.new(); _world_child = lab; world.add_child(lab)
func quit_to_menu() -> void: get_tree().paused = false; show_menu()

func _set_screen(screen: Control) -> void:
	if _screen and is_instance_valid(_screen): _screen.queue_free()
	_screen = screen
	if screen: ui.add_child(screen)
func _clear_world() -> void:
	if _world_child and is_instance_valid(_world_child): _world_child.queue_free()
	_world_child = null; Engine.physics_ticks_per_second = 120
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: Game.save_profile()
