class_name HUD
extends Control

## Run HUD. The information hierarchy is deliberate: time is the loudest thing
## on screen, speed is second, and the next medal target sits where your eye
## rests between corners. Score is present but quiet — it is a reason to take a
## different line, not the point of the run.

var run: RunController
var slider: SlideBody

var _time_label: Label
var _speed_label: Label
var _score_label: Label
var _combo_label: Label
var _target_label: Label
var _delta_label: Label
var _countdown: Label
var _flash: Label
var _model_badge: Label
var _flow_label: Label
var _mode_label: Label
var _telemetry: TelemetryPanel
var _flash_timer = 0.0
var _best_time = 0.0
var _pb_ghost: Ghost

func setup(controller: RunController, player: SlideBody, pb_ghost: Ghost = null) -> void:
	run = controller
	slider = player
	_pb_ghost = pb_ghost
	_best_time = float(Game.record_for(run.course.id)["best_time"])
	run.score_changed.connect(_on_score)
	run.flow_changed.connect(_on_flow)
	run.checkpoint_reached.connect(_on_checkpoint)
	run.respawned.connect(func(): _flash_message("RESPAWN", UiKit.WARN))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- top left: time -----------------------------------------------------
	var tl = VBoxContainer.new()
	tl.position = Vector2(46, 34)
	tl.add_theme_constant_override("separation", 0)
	add_child(tl)
	tl.add_child(UiKit.label("TIME", UiKit.BODY, UiKit.TEXT_DIM))
	_time_label = UiKit.mono("00:00.000", 46, UiKit.TEXT)
	tl.add_child(_time_label)
	_delta_label = UiKit.mono("", UiKit.H3, UiKit.TEXT_DIM)
	tl.add_child(_delta_label)

	# --- top right: speed ---------------------------------------------------
	var tr = VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-260, 34)
	tr.alignment = BoxContainer.ALIGNMENT_END
	add_child(tr)
	var sp_key = UiKit.label("SPEED", UiKit.BODY, UiKit.TEXT_DIM)
	sp_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sp_key.custom_minimum_size = Vector2(214, 0)
	tr.add_child(sp_key)
	_speed_label = UiKit.mono("0 km/h", 40, UiKit.LINE)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_label.custom_minimum_size = Vector2(214, 0)
	tr.add_child(_speed_label)
	_model_badge = UiKit.mono("", UiKit.BODY, UiKit.ACCENT)
	_model_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_model_badge.custom_minimum_size = Vector2(214, 0)
	tr.add_child(_model_badge)
	_mode_label = UiKit.mono(Game.mode_name(), UiKit.BODY, UiKit.TEXT_DIM)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mode_label.custom_minimum_size = Vector2(214, 0)
	tr.add_child(_mode_label)

	# --- bottom left: score -------------------------------------------------
	var bl = VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(46, -110)
	add_child(bl)
	_score_label = UiKit.mono("0", 32, UiKit.TEXT)
	bl.add_child(_score_label)
	_combo_label = UiKit.mono("", UiKit.H3, UiKit.ACCENT)
	bl.add_child(_combo_label)
	_flow_label = UiKit.mono("", UiKit.H3, UiKit.ACCENT)
	bl.add_child(_flow_label)

	# --- bottom right: target ----------------------------------------------
	_target_label = UiKit.mono("", UiKit.H3, UiKit.WARN)
	_target_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_target_label.position = Vector2(-360, -66)
	_target_label.custom_minimum_size = Vector2(314, 0)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_target_label)

	# --- centre: countdown + flashes ---------------------------------------
	_countdown = UiKit.mono("", 120, UiKit.LINE)
	_countdown.set_anchors_preset(Control.PRESET_CENTER)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.position = Vector2(-160, -120)
	_countdown.custom_minimum_size = Vector2(320, 0)
	add_child(_countdown)

	_flash = UiKit.mono("", 36, UiKit.GOOD)
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.position = Vector2(-260, 40)
	_flash.custom_minimum_size = Vector2(520, 0)
	add_child(_flash)

	_telemetry = TelemetryPanel.new()
	_telemetry.position = Vector2(46, 170)
	_telemetry.visible = bool(Game.settings.get("show_telemetry", false))
	add_child(_telemetry)

func _process(delta: float) -> void:
	if run == null or slider == null:
		return

	_time_label.text = RunController.format_time(run.time)
	_speed_label.text = UiKit.speed_string(slider.state.speed)

	if run.state == RunController.State.COUNTDOWN:
		var n = run.countdown_value()
		_countdown.text = str(n) if n > 0 else "GO"
	elif _countdown.text != "":
		_countdown.text = ""


	if Game.current_mode == Game.Mode.SCORE_ATTACK:
		_target_label.text = "PAR SCORE  %d" % run.course.par_score
	elif Game.current_mode == Game.Mode.SURVIVAL:
		_target_label.text = "LIVES  %d" % Game.survival_lives
	elif Game.current_mode == Game.Mode.ENDLESS:
		_target_label.text = "PRESTIGE  %d" % (Game.endless_prestige + 1)
	elif Game.current_mode == Game.Mode.DAILY:
		var daily = Game.daily_record()
		_target_label.text = "FIRST SIGHT  %s" % RunController.format_time(float(daily.get("first_sight", 0.0)))
	else:
		var target = run.course.next_medal(run.time if run.time > 0.0 else 0.0)
		if target.is_empty(): _target_label.text = "AUTHOR PACE"
		else: _target_label.text = "%s  %s" % [target["name"], RunController.format_time(target["time"])]

	if slider.params.model == MotorParams.Model.SM64_REFERENCE:
		_model_badge.text = "SM64 REFERENCE  %d Hz" % Engine.physics_ticks_per_second
	else:
		_model_badge.text = ""

	if _flash_timer > 0.0:
		_flash_timer -= delta
		_flash.modulate.a = clampf(_flash_timer / 0.5, 0.0, 1.0)
		if _flash_timer <= 0.0:
			_flash.text = ""

	if _telemetry.visible:
		_telemetry.update_values(slider.telemetry())

func toggle_telemetry() -> void:
	_telemetry.visible = not _telemetry.visible

func _on_score(score: int, combo: int) -> void:
	_score_label.text = str(score)
	_combo_label.text = ("CHAIN x%d" % combo) if combo > 1 else ""

func _on_flow(seconds: float, tier: int, multiplier: int) -> void:
	var name = FlowSystem.NAMES[tier] if tier >= 0 and tier < FlowSystem.NAMES.size() else ""
	_flow_label.text = ("%s  x%d   %.1fs" % [name, multiplier, seconds]) if name != "" else ""

func _on_checkpoint(index: int) -> void:
	var split = ""
	if _pb_ghost and _pb_ghost.has_data():
		var cp_pos = run.checkpoint_position(index)
		if cp_pos != Vector3.INF:
			var pb_t = _pb_ghost.time_near_position(cp_pos)
			if pb_t >= 0.0:
				var d = run.time - pb_t
				_delta_label.text = "%s%.2f vs PB" % ["+" if d >= 0.0 else "", d]
				_delta_label.add_theme_color_override("font_color", UiKit.WARN if d >= 0.0 else UiKit.GOOD)
				split = "   %s%.2f" % ["+" if d >= 0.0 else "", d]
	_flash_message("CHECKPOINT %d   %s%s" % [index + 1, RunController.format_time(run.time), split], UiKit.LINE)

func _flash_message(text: String, color: Color) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	_flash.modulate.a = 1.0
	_flash_timer = 1.6
