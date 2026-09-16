class_name MovementLab
extends Node3D

## The Movement Lab is permanent. It is not a prototype scene to be deleted once
## the game exists — it is the instrument we tune with for the life of the
## project, and it stays shipped in the project (dev-only) forever.
##
## Its one non-negotiable feature is the model switch: SM64 REFERENCE and SLIDE
## running on identical geometry, identical probes and identical collision, one
## keypress apart. Everything else here exists to make that comparison legible.

const STATIONS = [
	["START", 6.0],
	["STEEP", 100.0],
	["BANK L", 190.0],
	["BANK R", 270.0],
	["BOWL", 345.0],
	["LAUNCH", 400.0],
	["LANDING", 480.0],
	["WALLS", 570.0],
	["GRAVEL", 640.0],
	["BOOST", 680.0],
]

const RIG = [
	{"kind": "straight", "length": 30.0, "slope": 0.0, "width": 22.0},
	{"kind": "straight", "length": 60.0, "slope": 10.0, "width": 20.0},
	{"kind": "drop", "length": 60.0, "slope": 25.0, "width": 20.0},
	{"kind": "bank", "length": 80.0, "slope": 14.0, "turn": -60.0, "bank": 26.0, "width": 16.0},
	{"kind": "bank", "length": 80.0, "slope": 14.0, "turn": 60.0, "bank": -26.0, "width": 16.0},
	{"kind": "bowl", "length": 70.0, "slope": 8.0, "bowl": 6.0, "width": 24.0},
	{"kind": "ramp", "length": 40.0, "slope": 6.0, "launch": 18.0, "width": 12.0},
	{"kind": "gap", "length": 24.0, "slope": 24.0},
	{"kind": "drop", "length": 70.0, "slope": 24.0, "width": 20.0},
	{"kind": "wall", "length": 90.0, "slope": 10.0, "wall": 8.0, "width": 14.0},
	{"kind": "straight", "length": 40.0, "slope": 6.0, "width": 18.0, "surface": SurfaceKind.HIGH_FRICTION},
	{"kind": "straight", "length": 40.0, "slope": 8.0, "width": 16.0, "surface": SurfaceKind.BOOST},
	{"kind": "straight", "length": 60.0, "slope": 4.0, "width": 24.0},
]

var slider: SlideBody
var camera: SlideCamera
var params = MotorParams.new()
var camera_params = CameraParams.new()

var _builder: TrackBuilder
var _panel: LabPanel
var _telemetry: TelemetryPanel
var _ui = CanvasLayer.new()
var _model_button: Button
var _jump_button: Button
var _status: Label
var _slowmo = false
var _frozen = false

func _ready() -> void:
	WorldKit.add_environment(self)
	WorldKit.add_sun(self)

	_builder = TrackBuilder.new()
	var track = _builder.build(RIG, Vector3(0, 120, 0), 0.0)
	add_child(track)

	# Three surface lanes over the same 25° pitch: the fastest way to feel what
	# a friction class actually does.
	_builder.add_parallel_route(92.0, 148.0, -12.0, 0.4, 7.0, SurfaceKind.SLIPPERY, "LaneSlippery")
	_builder.add_parallel_route(92.0, 148.0, 12.0, 0.4, 7.0, SurfaceKind.NOT_SLIPPERY, "LaneGrip")

	slider = SlideBody.new()
	slider.params = params
	add_child(slider)
	var start = _builder.sample_at(6.0)
	slider.global_position = start["pos"] + start["u"] * 0.55
	slider.set_spawn(slider.global_position, atan2(start["f"].x, start["f"].z))

	camera = SlideCamera.new()
	camera.params = camera_params
	add_child(camera)
	camera.bind(slider)

	_build_ui()
	_apply_rates()

func _process(_delta: float) -> void:
	if camera and slider:
		slider.camera_basis = camera.get_camera().global_basis
	if _telemetry:
		_telemetry.update_values(slider.telemetry())
	if _status:
		_status.text = "%s   ·   %d Hz   ·   %s%s" % [
			"SM64 REFERENCE" if params.model == MotorParams.Model.SM64_REFERENCE else "SLIDE (production)",
			Engine.physics_ticks_per_second,
			"SLOW-MO  " if _slowmo else "",
			"FROZEN" if _frozen else "",
		]

# ----------------------------------------------------------------------- UI
func _build_ui() -> void:
	_ui.layer = 8
	add_child(_ui)

	var root = UiKit.root_control()
	_ui.add_child(root)

	# --- left column: model switch, telemetry, stations ---------------------
	var left = VBoxContainer.new()
	left.position = Vector2(28, 24)
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	_status = UiKit.mono("", 16, UiKit.ACCENT)
	left.add_child(_status)

	_model_button = UiKit.button("SWAP MODEL   (F3)", true)
	_model_button.custom_minimum_size = Vector2(292, 44)
	_model_button.pressed.connect(_toggle_model)
	left.add_child(_model_button)

	_telemetry = TelemetryPanel.new()
	left.add_child(_telemetry)

	left.add_child(UiKit.spacer(6))
	left.add_child(UiKit.label("TELEPORT", UiKit.BODY, UiKit.TEXT_DIM))
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	for st in STATIONS:
		var b = Button.new()
		b.text = st[0]
		b.custom_minimum_size = Vector2(94, 26)
		b.add_theme_font_size_override("font_size", 13)
		var d: float = st[1]
		b.pressed.connect(func(): _teleport(d))
		grid.add_child(b)

	left.add_child(UiKit.spacer(6))
	var toggles = HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 4)
	left.add_child(toggles)

	_jump_button = Button.new()
	_jump_button.text = "JUMP: OFF"
	_jump_button.toggle_mode = true
	_jump_button.custom_minimum_size = Vector2(120, 28)
	_jump_button.toggled.connect(func(on: bool):
		params.enable_jump = on
		_jump_button.text = "JUMP: ON" if on else "JUMP: OFF")
	toggles.add_child(_jump_button)

	var slow = Button.new()
	slow.text = "SLOW-MO"
	slow.toggle_mode = true
	slow.custom_minimum_size = Vector2(100, 28)
	slow.toggled.connect(func(on: bool):
		_slowmo = on
		Engine.time_scale = 0.25 if on else 1.0)
	toggles.add_child(slow)

	var freeze = Button.new()
	freeze.text = "FREEZE"
	freeze.toggle_mode = true
	freeze.custom_minimum_size = Vector2(90, 28)
	freeze.toggled.connect(func(on: bool):
		_frozen = on
		slider.control_enabled = not on
		slider.set_physics_process(not on))
	toggles.add_child(freeze)

	left.add_child(UiKit.spacer(6))
	var nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	left.add_child(nav)
	var reset = Button.new()
	reset.text = "RESET  (R)"
	reset.custom_minimum_size = Vector2(140, 30)
	reset.pressed.connect(func(): slider.respawn())
	nav.add_child(reset)
	var back = Button.new()
	back.text = "MENU  (Esc)"
	back.custom_minimum_size = Vector2(140, 30)
	back.pressed.connect(func(): Main.instance.quit_to_menu())
	nav.add_child(back)

	# --- right column: the tuning dock --------------------------------------
	_panel = LabPanel.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -452.0
	_panel.offset_right = -14.0
	_panel.offset_top = 18.0
	_panel.offset_bottom = -18.0
	root.add_child(_panel)
	_panel.bind(params, camera_params)
	_panel.param_changed.connect(_on_param_changed)
	_panel.preset_applied.connect(func(_n: String): _apply_rates())

func _on_param_changed(prop: String) -> void:
	if prop == "simulation_hz" or prop == "sm64_hz":
		_apply_rates()

func _apply_rates() -> void:
	slider.apply_simulation_rate()

func _toggle_model() -> void:
	slider.toggle_model()
	_apply_rates()

func _teleport(dist: float) -> void:
	var f = _builder.sample_at(dist)
	if f.is_empty():
		return
	slider.respawn(f["pos"] + f["u"] * 0.55, atan2(f["f"].x, f["f"].z))
	camera.snap_to_target()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_model"):
		_toggle_model()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("retry"):
		slider.respawn()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_menu"):
		Main.instance.quit_to_menu()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
