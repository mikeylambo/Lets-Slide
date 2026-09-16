class_name LabPanel
extends PanelContainer

## The tuning dock. Every control in it is generated from MotorParams.SCHEMA and
## CameraParams.SCHEMA — there is no hand-maintained list of widgets, so a new
## tunable is one line in the schema and it shows up here.

signal param_changed(prop: String)
signal preset_applied(preset_name: String)

var motor: MotorParams
var camera: CameraParams

var _rows = {}                  ## prop -> {slider, value_label, source}
var _groups = {}                ## group name -> VBoxContainer
var _preset_picker: OptionButton
var _preset_name: LineEdit
var _content: VBoxContainer

func bind(m: MotorParams, c: CameraParams) -> void:
	motor = m
	camera = c
	_build()

func _ready() -> void:
	custom_minimum_size = Vector2(438, 0)
	add_theme_stylebox_override("panel", UiKit._box(Color(0.045, 0.055, 0.085, 0.94),
		Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, 0.35), 1, 14))

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	scroll.add_child(_content)

	_content.add_child(UiKit.label("MOVEMENT LAB", UiKit.H3, UiKit.LINE))
	_content.add_child(UiKit.rule())
	_content.add_child(_preset_block())
	_content.add_child(UiKit.spacer(6))

	for g in MotorParams.GROUP_ORDER:
		_add_group(g, MotorParams.SCHEMA, motor, g in ["Slide"])
	for g in CameraParams.GROUP_ORDER:
		_add_group(g, CameraParams.SCHEMA, camera, false)

# ------------------------------------------------------------------ presets
func _preset_block() -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	_preset_picker = OptionButton.new()
	_preset_picker.custom_minimum_size = Vector2(0, 32)
	_refresh_presets()
	_preset_picker.item_selected.connect(func(idx: int):
		var n = _preset_picker.get_item_text(idx)
		if Game.load_preset(n, motor, camera):
			refresh_all()
			preset_applied.emit(n))
	box.add_child(_preset_picker)

	var save_row = HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 4)
	_preset_name = LineEdit.new()
	_preset_name.placeholder_text = "preset name"
	_preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_preset_name)

	var save = Button.new()
	save.text = "SAVE"
	save.pressed.connect(func():
		var n: String = _preset_name.text.strip_edges()
		if n == "":
			n = "Preset %d" % (Game.presets.size() + 1)
		Game.save_preset(n, motor, camera)
		_refresh_presets(n))
	save_row.add_child(save)

	var del = Button.new()
	del.text = "DEL"
	del.pressed.connect(func():
		if _preset_picker.selected >= 0:
			Game.delete_preset(_preset_picker.get_item_text(_preset_picker.selected))
			_refresh_presets())
	save_row.add_child(del)
	box.add_child(save_row)

	var reset = Button.new()
	reset.text = "RESET SM64 REFERENCE CONSTANTS"
	reset.pressed.connect(func():
		motor.reset_reference_constants()
		refresh_all()
		param_changed.emit("sm64_hz"))
	box.add_child(reset)

	return box

func _refresh_presets(select: String = "") -> void:
	_preset_picker.clear()
	var names = Game.preset_names()
	for i in names.size():
		_preset_picker.add_item(names[i])
		if names[i] == select:
			_preset_picker.select(i)

# ------------------------------------------------------------------- groups
func _add_group(group: String, schema: Array, source: Object, expanded: bool) -> void:
	var rows = []
	for row in schema:
		if row[2] == group:
			rows.append(row)
	if rows.is_empty():
		return

	var header = Button.new()
	header.text = ("▾  " if expanded else "▸  ") + group.to_upper()
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 15)
	header.custom_minimum_size = Vector2(0, 28)
	_content.add_child(header)

	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 1)
	body.visible = expanded
	_content.add_child(body)
	_groups[group] = body

	header.pressed.connect(func():
		body.visible = not body.visible
		header.text = ("▾  " if body.visible else "▸  ") + group.to_upper())

	for row in rows:
		body.add_child(_param_row(row, source))

func _param_row(row: Array, source: Object) -> Control:
	var prop: String = row[0]
	var wrap = VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)

	var head = HBoxContainer.new()
	var name_label = UiKit.label(row[1], 14, UiKit.TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label = UiKit.mono(_fmt(float(source.get(prop)), float(row[5])), 14, UiKit.LINE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(name_label)
	head.add_child(value_label)
	wrap.add_child(head)

	var s = HSlider.new()
	s.min_value = float(row[3])
	s.max_value = float(row[4])
	s.step = float(row[5])
	s.value = float(source.get(prop))
	s.custom_minimum_size = Vector2(0, 18)
	s.value_changed.connect(func(v: float):
		source.set(prop, v)
		value_label.text = _fmt(v, float(row[5]))
		param_changed.emit(prop))
	wrap.add_child(s)

	_rows[prop] = {"slider": s, "label": value_label, "source": source, "step": float(row[5])}
	return wrap

func refresh_all() -> void:
	for prop in _rows.keys():
		var r: Dictionary = _rows[prop]
		var v: float = float(r["source"].get(prop))
		r["slider"].set_value_no_signal(v)
		r["label"].text = _fmt(v, float(r["step"]))

static func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(v))
	if step >= 0.01:
		return "%.2f" % v
	return "%.4f" % v
