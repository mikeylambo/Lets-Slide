class_name OptionsScreen
extends Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var outer = VBoxContainer.new(); outer.add_theme_constant_override("separation", 10); margin.add_child(outer)
	outer.add_child(UiKit.title("OPTIONS"))
	var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus = true
	outer.add_child(scroll)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
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
	col.add_child(_toggle("Show input display (speedrun overlay)", "show_inputs"))
	col.add_child(_toggle("Invert steering", "invert_steer"))
	col.add_child(_toggle("Metric units (km/h)", "units_metric"))
	col.add_child(_toggle("Show touch controls", "touch_controls"))
	col.add_child(_toggle("Tilt steering on mobile", "tilt_steering"))
	col.add_child(_slider("Tilt sensitivity", "tilt_sensitivity", 0.05, 0.5, 0.01))

	col.add_child(UiKit.spacer(14))
	col.add_child(UiKit.label("ACCESSIBILITY", UiKit.H3, UiKit.LINE))
	col.add_child(_toggle("Reduce flashes (no screen flashes or INVERT)", "reduce_flashes"))
	col.add_child(_toggle("Tuck toggles instead of hold", "tuck_toggle"))
	col.add_child(_slider("Interface scale", "ui_scale", 0.75, 1.5, 0.05))
	col.add_child(_toggle("Tutorial hints on Course 01", "tutorial_hints"))

	col.add_child(UiKit.spacer(20))
	col.add_child(UiKit.label("CONTROLS", UiKit.H3, UiKit.LINE))
	var lines = [
		"Steer            A / D  ·  Left stick",
		"Lean / extend    W / S  ·  Left stick Y",
		"Tuck             Shift  ·  X / Square",
		"Brake            Space  ·  B / Circle",
		"Retry            R  ·  Y / Triangle",
		"Pause            Esc  ·  Start",
		"Telemetry        F2",
	]
	if Game.dev_tools:
		lines.append("Dev: Movement Lab F1 · Swap reference model F3 · Course Inspector F4")
	for line in lines:
		col.add_child(UiKit.label(line, UiKit.BODY, UiKit.TEXT_DIM))

	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	outer.add_child(row)
	var controls = UiKit.button("CONTROLS", true)
	controls.pressed.connect(func(): Main.instance.show_controls())
	row.add_child(controls)
	var back = UiKit.button("BACK")
	back.pressed.connect(func(): Main.instance.show_menu())
	row.add_child(back)
	controls.grab_focus()

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
