class_name RunCodeScreen
extends Control

## Paste a run code from a friend (or Discord) and either watch it or race it:
## the run re-simulates live through the real motor as a translucent rival.
## Your own PB runs are listed below with a one-tap copy.

var _input: TextEdit
var _status: Label
var _info: VBoxContainer
var _watch: Button
var _race: Button
var _replay: Replay

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 56); margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 10); margin.add_child(col)
	col.add_child(UiKit.title("RUN CODES", "paste a run · watch it · race it"))

	_input = TextEdit.new()
	_input.placeholder_text = "Paste a run code (starts with SLRP1:)"
	_input.custom_minimum_size = Vector2(0, 96)
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.text_changed.connect(_decode)
	col.add_child(_input)
	_status = UiKit.label("", UiKit.BODY, UiKit.TEXT_DIM)
	col.add_child(_status)
	_info = VBoxContainer.new(); col.add_child(_info)

	var actions = HBoxContainer.new(); actions.add_theme_constant_override("separation", 12); col.add_child(actions)
	var paste = UiKit.button("PASTE")
	paste.pressed.connect(func(): _input.text = DisplayServer.clipboard_get(); _decode())
	actions.add_child(paste)
	_race = UiKit.button("RACE IT", true); _race.disabled = true
	_race.pressed.connect(func(): _launch({"rival": _replay}))
	actions.add_child(_race)
	_watch = UiKit.button("WATCH"); _watch.disabled = true
	_watch.pressed.connect(func(): _launch({"watch": _replay}))
	actions.add_child(_watch)

	col.add_child(UiKit.spacer(10))
	col.add_child(UiKit.label("YOUR PB RUNS", UiKit.H3, UiKit.LINE))
	var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	var any = false
	for c in Courses.all():
		var r = Replay.load_path(Replay.pb_path(c.id))
		if r == null or not r.valid(): continue
		any = true
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 14); list.add_child(row)
		var name = UiKit.label("%s   %s" % [c.title, RunController.format_time(r.time_seconds())], UiKit.BODY)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(name)
		var copy = UiKit.button("COPY CODE"); copy.custom_minimum_size = Vector2(170, 36)
		var code = r.to_code()
		copy.pressed.connect(func(): DisplayServer.clipboard_set(code); copy.text = "COPIED")
		row.add_child(copy)
	if not any:
		list.add_child(UiKit.label("Set a personal best and it appears here.", UiKit.BODY, UiKit.TEXT_DIM))

	var back = UiKit.button("BACK"); back.pressed.connect(func(): Main.instance.show_menu()); col.add_child(back)
	paste.grab_focus()

func _decode() -> void:
	for c in _info.get_children(): c.queue_free()
	_replay = null
	var text = _input.text.strip_edges()
	_watch.disabled = true; _race.disabled = true
	if text == "":
		_status.text = ""; return
	var r = Replay.from_code(text)
	if r == null:
		_status.text = "That isn't a run code. Codes start with SLRP1: and are copied from a results screen."
		_status.add_theme_color_override("font_color", UiKit.WARN); return
	var course = Courses.by_id(r.course_id)
	if course == null:
		_status.text = "This run is on a course you don't have (%s)." % r.course_id
		_status.add_theme_color_override("font_color", UiKit.WARN); return
	_replay = r
	_status.text = "Run decoded."
	_status.add_theme_color_override("font_color", UiKit.GOOD)
	_info.add_child(UiKit.row("COURSE", course.title, UiKit.LINE))
	_info.add_child(UiKit.row("TIME", RunController.format_time(r.time_seconds()) if r.finished else "UNFINISHED", UiKit.GOOD))
	var mine = float(Game.record_for(course.id)["best_time"])
	if mine > 0.0 and r.finished:
		var d = mine - r.time_seconds()
		_info.add_child(UiKit.row("YOUR BEST", "%s  (%s%.3f)" % [RunController.format_time(mine), "+" if d >= 0.0 else "−", absf(d)], UiKit.TEXT))
	_info.add_child(UiKit.row("RECORDED", r.recorded_at if r.recorded_at != "" else "—", UiKit.TEXT_DIM))
	_watch.disabled = false
	_race.disabled = not Game.course_unlocked(course)
	if _race.disabled: _status.text = "Unlock this course to race it. You can still watch."

func _launch(opts: Dictionary) -> void:
	if _replay == null: return
	Game.set_mode(Game.Mode.TIME_TRIAL)
	Main.instance.play_course(Courses.by_id(_replay.course_id), null, opts)
