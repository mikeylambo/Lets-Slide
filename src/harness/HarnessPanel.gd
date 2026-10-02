extends PanelContainer

## F1 live tuning dock. Every MotorParams field is here, generated from
## MotorParams.SCHEMA, with the headline feel fields pinned at the top.
##
## Controller: D-pad up/down moves between rows, left/right nudges a slider
## (1/50 of its range per press), A / Enter on a slider resets it to the saved
## preset value, RB (or F1) closes. Mouse works everywhere.

const FEEL = [
	["max_speed", "Max speed"],
	["slope_accel", "Accel · slope pull"],
	["gravity", "Gravity"],
	["steering_strength", "Turn rate"],
	["flat_friction", "Friction · flat"],
	["downhill_friction", "Friction · downhill"],
	["uphill_friction", "Friction · uphill"],
	["weight_transfer_strength", "Pop · weight transfer"],
	["crest_release", "Pop · crest release"],
	["compression_bonus", "Pop · compression load"],
	["air_steering", "Air control · steer"],
	["air_lateral_accel", "Air control · lateral"],
	["author_avg_speed", "Author avg speed  ⟳ rebuilds course"],
]
const KIT = [
	["fov_kick_deg", "FOV kick (deg at max)", 0.0, 30.0, 0.5],
	["speed_line_threshold", "Speed lines from (× max)", 0.3, 1.0, 0.01],
	["wind_volume", "Wind volume", 0.0, 2.0, 0.01],
	["click_volume", "Click volume", 0.0, 2.0, 0.01],
]

var harness
var _rows = {}             ## prop -> {slider, value, delta, step}
var _kit_rows = {}
var _content: VBoxContainer
var _tuning: VBoxContainer
var _blind_note: Label
var _slot_buttons: Array[Button] = []
var _picker: OptionButton
var _name_edit: LineEdit
var _toggles = {}
var _first_focus: Control

func setup(h) -> void:
	harness = h
	_build()
	refresh()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -480.0
	offset_right = -14.0
	offset_top = 14.0
	offset_bottom = -14.0
	add_theme_stylebox_override("panel", UiKit._box(Color(0.035, 0.045, 0.07, 0.95),
		Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, 0.45), 1, 14))
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open() -> void:
	visible = true
	refresh()
	if _first_focus:
		_first_focus.grab_focus()

func close() -> void:
	visible = false
	var owner_c = get_viewport().gui_get_focus_owner()
	if owner_c and is_ancestor_of(owner_c):
		owner_c.release_focus()

func toggle() -> void:
	if visible: close()
	else: open()

func editing_text() -> bool:
	return visible and _name_edit != null and _name_edit.has_focus()

# ------------------------------------------------------------------ build
func _build() -> void:
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	scroll.add_child(_content)

	var head = HBoxContainer.new()
	head.add_child(UiKit.label("PLAYTEST HARNESS", UiKit.H3, UiKit.LINE))
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	head.add_child(UiKit.label("F1 / RB", 13, UiKit.TEXT_DIM))
	_content.add_child(head)
	_content.add_child(UiKit.rule())

	# A/B slots
	_content.add_child(_caption("A / B SLOTS  ·  Tab / LB swaps mid-run"))
	var slots = HBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	for i in 2:
		var b = _button("")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.clip_text = true
		var idx = i
		b.pressed.connect(func(): harness.activate_slot(idx))
		slots.add_child(b)
		_slot_buttons.append(b)
	_content.add_child(slots)
	_first_focus = _slot_buttons[0]

	# presets
	_content.add_child(_caption("PRESETS  ·  user://presets/*.json"))
	var load_row = HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 4)
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.custom_minimum_size = Vector2(0, 32)
	_picker.clip_text = true
	load_row.add_child(_picker)
	for i in 2:
		var idx = i
		var lb = _button("→ " + ["A", "B"][i])
		lb.custom_minimum_size = Vector2(52, 32)
		lb.pressed.connect(func():
			if _picker.selected >= 0:
				harness.load_into_slot(idx, _picker.get_item_text(_picker.selected)))
		load_row.add_child(lb)
	_content.add_child(load_row)
	var save_row = HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 4)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "save active slot as…"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_name_edit)
	var save = _button("SAVE")
	save.custom_minimum_size = Vector2(72, 32)
	save.pressed.connect(func():
		var n = _name_edit.text.strip_edges()
		harness.save_active(n if n != "" else harness.slot_name(harness.active))
		_name_edit.text = "")
	_name_edit.text_submitted.connect(func(_t): save.pressed.emit())
	save_row.add_child(save)
	_content.add_child(save_row)

	# session toggles
	_content.add_child(_caption("SESSION"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	for t in [["kit", "Readability kit  F2"], ["click", "174 BPM click  M"], ["blind", "Blind A/B  B"], ["rating", "Rate each run"]]:
		var key: String = t[0]
		var cb = CheckButton.new()
		cb.text = t[1]
		cb.add_theme_font_size_override("font_size", 14)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(func(on: bool): harness.set_toggle(key, on))
		grid.add_child(cb)
		_toggles[key] = cb
	_content.add_child(grid)

	_blind_note = UiKit.label("Values hidden in blind mode — turn Blind off to tune.", 14, UiKit.WARN)
	_blind_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_blind_note)

	_tuning = VBoxContainer.new()
	_tuning.add_theme_constant_override("separation", 4)
	_content.add_child(_tuning)

	var schema = {}
	for row in MotorParams.SCHEMA:
		schema[row[0]] = row
	var pinned = []
	var feel_body = _group(_tuning, "FEEL", true)
	for f in FEEL:
		var r: Array = schema[f[0]]
		feel_body.add_child(_param_row(f[0], f[1], float(r[3]), float(r[4]), float(r[5])))
		pinned.append(f[0])

	var kit_body = _group(_tuning, "READABILITY KIT", false)
	for k in KIT:
		kit_body.add_child(_kit_row(k))

	for g in MotorParams.GROUP_ORDER:
		var rows = MotorParams.SCHEMA.filter(func(r): return r[2] == g and not pinned.has(r[0]))
		if rows.is_empty():
			continue
		var body = _group(_tuning, g.to_upper(), false)
		for r in rows:
			body.add_child(_param_row(r[0], r[1], float(r[3]), float(r[4]), float(r[5])))

	_content.add_child(UiKit.spacer(8))
	var legend = UiKit.label("D-pad ↑↓ move · ←→ nudge · A/Enter resets slider to saved value\nR/Y retry · N/Select marker · Tab/LB A↔B · F2/L3 kit · T telemetry · Esc/Start pause", 13, UiKit.TEXT_DIM)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(legend)

func _caption(text: String) -> Label:
	var l = UiKit.label(text, 13, UiKit.TEXT_DIM)
	return l

func _button(text: String) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("focus", _focus_box())
	return b

static func _focus_box() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = UiKit.ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	return sb

func _group(parent: Control, title: String, expanded: bool) -> VBoxContainer:
	var header = _button(("▾  " if expanded else "▸  ") + title)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0, 30)
	parent.add_child(header)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.visible = expanded
	parent.add_child(body)
	header.pressed.connect(func():
		body.visible = not body.visible
		header.text = ("▾  " if body.visible else "▸  ") + title)
	return body

func _slider(lo: float, hi: float, step: float) -> HSlider:
	var s = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	# D-pad nudges by 1/50 of the range (snapped to the field's step) instead
	# of the raw step, so a 0.0001-step field is still ~50 presses end to end.
	var nudge = maxf(snappedf((hi - lo) / 50.0, step), step)
	s.gui_input.connect(func(ev: InputEvent):
		var dir = 0.0
		if ev.is_action_pressed("ui_right", true): dir = 1.0
		elif ev.is_action_pressed("ui_left", true): dir = -1.0
		if dir != 0.0:
			s.value = clampf(s.value + dir * nudge, lo, hi)
			s.accept_event())
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(0, 20)
	s.add_theme_stylebox_override("focus", _focus_box())
	return s

func _param_row(prop: String, label: String, lo: float, hi: float, step: float) -> Control:
	var wrap = VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var head = HBoxContainer.new()
	var name_l = UiKit.label(label, 14, UiKit.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.tooltip_text = prop
	var delta_l = UiKit.mono("", 13, UiKit.ACCENT)
	var value_l = UiKit.mono("", 14, UiKit.LINE)
	value_l.custom_minimum_size = Vector2(76, 0)
	value_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(name_l)
	head.add_child(delta_l)
	head.add_child(value_l)
	wrap.add_child(head)
	var s = _slider(lo, hi, step)
	s.value_changed.connect(func(v: float): harness.set_param(prop, v))
	s.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_accept") or (ev is InputEventKey and ev.pressed and ev.keycode in [KEY_BACKSPACE, KEY_DELETE]):
			harness.reset_param(prop)
			s.accept_event())
	wrap.add_child(s)
	_rows[prop] = {"slider": s, "value": value_l, "delta": delta_l, "step": step}
	return wrap

func _kit_row(k: Array) -> Control:
	var prop: String = k[0]
	var wrap = VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var head = HBoxContainer.new()
	var name_l = UiKit.label(k[1], 14, UiKit.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_l = UiKit.mono("", 14, UiKit.LINE)
	head.add_child(name_l)
	head.add_child(value_l)
	wrap.add_child(head)
	var s = _slider(k[2], k[3], k[4])
	s.value = float(harness.kit.get(prop))
	value_l.text = _fmt(s.value, k[4])
	s.value_changed.connect(func(v: float):
		harness.kit.set(prop, v)
		value_l.text = _fmt(v, k[4]))
	wrap.add_child(s)
	_kit_rows[prop] = s
	return wrap

# ---------------------------------------------------------------- refresh
func refresh() -> void:
	if harness == null or _content == null:
		return
	for i in 2:
		var b: Button = _slot_buttons[i]
		var active = i == harness.active
		b.text = ("●  " if active else "○  ") + harness.slot_display(i)
		var c: Color = UiKit.LINE if i == 0 or harness.blind else UiKit.ACCENT
		b.add_theme_stylebox_override("normal", UiKit._box(Color(c.r, c.g, c.b, 0.28 if active else 0.06), Color(c.r, c.g, c.b, 1.0 if active else 0.35), 2 if active else 1))
		b.add_theme_color_override("font_color", UiKit.TEXT if active else UiKit.TEXT_DIM)
	var names: Array = harness.presets.names()
	var keep = _picker.get_item_text(_picker.selected) if _picker.selected >= 0 else ""
	_picker.clear()
	for i in names.size():
		_picker.add_item(names[i])
		if names[i] == keep:
			_picker.select(i)
	for key in _toggles.keys():
		(_toggles[key] as CheckButton).set_pressed_no_signal(harness.get_toggle(key))
	_tuning.visible = not harness.blind
	_blind_note.visible = harness.blind
	refresh_values()

func refresh_values() -> void:
	if harness == null:
		return
	var base: Dictionary = harness.slot_baseline(harness.active)
	for prop in _rows.keys():
		var r: Dictionary = _rows[prop]
		var v = float(harness.params.get(prop))
		(r["slider"] as HSlider).set_value_no_signal(v)
		(r["value"] as Label).text = _fmt(v, float(r["step"]))
		var d = v - float(base.get(prop, v))
		(r["delta"] as Label).text = "" if is_zero_approx(d) else (("+" if d > 0.0 else "") + _fmt(d, float(r["step"])) + "  ")

static func _fmt(v: float, step: float) -> String:
	if step >= 1.0: return "%d" % int(round(v))
	if step >= 0.01: return "%.2f" % v
	if step >= 0.001: return "%.3f" % v
	return "%.4f" % v
