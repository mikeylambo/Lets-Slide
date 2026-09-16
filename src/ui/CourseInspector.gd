class_name CourseInspector
extends Control

## Internal developer inspector (F4). It is intentionally plain: edit a segment
## kind/bars/slope in-place, hot-rebuild, or copy the current verb list.

signal rebuild_requested(spec: Array)
var course: CourseData
var _rows = VBoxContainer.new()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.backdrop(0.92))
	var margin = MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 45); margin.add_theme_constant_override("margin_right", 45)
	margin.add_theme_constant_override("margin_top", 35); margin.add_theme_constant_override("margin_bottom", 35); add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 8); margin.add_child(col)
	col.add_child(UiKit.title("COURSE INSPECTOR", course.id if course else ""))
	var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	_rows = VBoxContainer.new(); _rows.add_theme_constant_override("separation", 5); scroll.add_child(_rows)
	_build_rows()
	var actions = HBoxContainer.new(); col.add_child(actions)
	var rebuild = UiKit.button("HOT REBUILD", true); rebuild.pressed.connect(func(): course.total_bars = CourseCatalog.spec_bars(course.spec); rebuild_requested.emit(course.spec)); actions.add_child(rebuild)
	var copy = UiKit.button("COPY SPEC"); copy.pressed.connect(func(): DisplayServer.clipboard_set(JSON.stringify(course.spec, "  "))); actions.add_child(copy)
	var close = UiKit.button("CLOSE (F4)"); close.pressed.connect(queue_free); actions.add_child(close)

func _build_rows() -> void:
	if course == null: return
	for i in range(course.spec.size()):
		var seg: Dictionary = course.spec[i]
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); _rows.add_child(row)
		var idx = UiKit.mono("%02d" % (i+1), 15, UiKit.TEXT_DIM); idx.custom_minimum_size = Vector2(36,0); row.add_child(idx)
		var kind = OptionButton.new(); kind.custom_minimum_size = Vector2(170,38)
		for name in VerbLibrary.all_names(): kind.add_item(name)
		kind.select(maxi(0, VerbLibrary.all_names().find(str(seg.get("kind","straight")))))
		kind.item_selected.connect(func(n): seg["kind"] = VerbLibrary.all_names()[n])
		row.add_child(kind)
		row.add_child(UiKit.label("BARS", UiKit.BODY, UiKit.TEXT_DIM))
		var bars = SpinBox.new(); bars.min_value=0.25; bars.max_value=16.0; bars.step=0.25; bars.value=float(seg.get("bars",2.0)); bars.custom_minimum_size=Vector2(110,38)
		bars.value_changed.connect(func(v): seg["bars"] = VerbLibrary.quantize_bars_for(str(seg.get("kind","straight")), v); course.total_bars = CourseCatalog.spec_bars(course.spec)); row.add_child(bars)
		row.add_child(UiKit.label("SLOPE", UiKit.BODY, UiKit.TEXT_DIM))
		var slope = SpinBox.new(); slope.min_value=-20; slope.max_value=80; slope.step=0.5; slope.value=float(seg.get("slope",10)); slope.custom_minimum_size=Vector2(110,38)
		slope.value_changed.connect(func(v): seg["slope"] = v); row.add_child(slope)
