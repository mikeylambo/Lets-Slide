class_name OptionsScreen
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 60)
	add_child(margin)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)
	col.add_child(UiKit.title("OPTIONS"))
	col.add_child(UiKit.spacer(10))

	col.add_child(_slider("Master volume", "master_volume", 0.0, 1.0, 0.01))
	col.add_child(_slider("Music volume", "music_volume", 0.0, 1.0, 0.01))
	col.add_child(_slider("SFX volume", "sfx_volume", 0.0, 1.0, 0.01))
	col.add_child(_slider("Camera shake", "camera_shake", 0.0, 2.0, 0.05))
	col.add_child(_slider("Speed effects", "speed_effects", 0.0, 1.0, 0.05))
	col.add_child(_slider("Flow / INVERT intensity", "flow_effects", 0.0, 1.0, 0.05))
	col.add_child(_slider("Ghost opacity", "ghost_opacity", 0.05, 0.75, 0.05))
	col.add_child(_slider("FOV scale", "fov_scale", 0.80, 1.20, 0.02))
	col.add_child(_toggle("Show personal-best ghost", "show_ghost"))
	col.add_child(_toggle("Show telemetry in run", "show_telemetry"))
	col.add_child(_toggle("Invert steering", "invert_steer"))
	col.add_child(_toggle("Metric units (km/h)", "units_metric"))
	col.add_child(_toggle("Show touch controls", "touch_controls"))
	col.add_child(_toggle("Tilt steering on mobile", "tilt_steering"))
	col.add_child(_slider("Tilt sensitivity", "tilt_sensitivity", 0.05, 0.5, 0.01))

	col.add_child(UiKit.spacer(20))
	col.add_child(UiKit.label("CONTROLS", UiKit.H3, UiKit.LINE))
	for line in [
		"Steer            A / D  ·  Left stick",
		"Lean / extend    W / S  ·  Left stick Y",
		"Tuck             Shift  ·  X / Square",
		"Brake            Space  ·  B / Circle",
		"Retry            R  ·  Y / Triangle",
		"Pause            Esc  ·  Start",
		"Movement Lab     F1        Telemetry      F2",
		"Course Inspector F4        Swap model     configured key",
	]:
		col.add_child(UiKit.label(line, UiKit.BODY, UiKit.TEXT_DIM))

	col.add_child(UiKit.spacer(20))
	var back = UiKit.button("BACK")
	back.pressed.connect(func(): Main.instance.show_menu())
	col.add_child(back)
	back.grab_focus()

func _slider(text: String, key: String, lo: float, hi: float, step: float) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l = UiKit.label(text, UiKit.BODY)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings.get(key, lo))
	s.custom_minimum_size = Vector2(340, 24)
	var v = UiKit.mono("%.2f" % s.value, UiKit.BODY, UiKit.LINE)
	s.value_changed.connect(func(val: float):
		v.text = "%.2f" % val
		Game.set_setting(key, val))
	h.add_child(s)
	h.add_child(v)
	return h

func _toggle(text: String, key: String) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l = UiKit.label(text, UiKit.BODY)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var c = CheckButton.new()
	c.button_pressed = bool(Game.settings.get(key, false))
	c.toggled.connect(func(on: bool): Game.set_setting(key, on))
	h.add_child(c)
	return h
