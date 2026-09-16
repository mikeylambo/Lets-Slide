class_name LeaderboardsScreen
extends Control

var _mode = Game.Mode.TIME_TRIAL
var _course_index = 0
var _body = VBoxContainer.new()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 45)
	add_child(margin)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)
	col.add_child(UiKit.title("LEADERBOARDS", "offline board · ShellBridge backend seam"))
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	col.add_child(controls)
	var mode_pick = OptionButton.new()
	mode_pick.custom_minimum_size = Vector2(220, 42)
	for m in [Game.Mode.TIME_TRIAL, Game.Mode.SCORE_ATTACK, Game.Mode.CAMPAIGN]:
		mode_pick.add_item(Game.mode_name(m), m)
	mode_pick.select(0)
	mode_pick.item_selected.connect(func(i): _mode = mode_pick.get_item_id(i); _refresh())
	controls.add_child(mode_pick)
	var course_pick = OptionButton.new()
	course_pick.custom_minimum_size = Vector2(390, 42)
	for c in Courses.all(): course_pick.add_item("%02d · %s" % [c.region_index * 5 + c.course_index + 1, c.title])
	course_pick.item_selected.connect(func(i): _course_index = i; _refresh())
	controls.add_child(course_pick)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	var back = UiKit.button("BACK", true)
	back.pressed.connect(func(): Main.instance.show_menu())
	col.add_child(back)
	back.grab_focus()
	_refresh()

func _refresh() -> void:
	for child in _body.get_children(): child.queue_free()
	var courses = Courses.all()
	if courses.is_empty(): return
	_course_index = clampi(_course_index, 0, courses.size() - 1)
	var course: CourseData = courses[_course_index]
	var old_mode = Game.current_mode
	Game.current_mode = _mode
	var rows: Array = ShellBridge.leaderboard(course.id)
	Game.current_mode = old_mode
	_body.add_child(UiKit.label("%s · %s" % [course.title, Game.mode_name(_mode)], UiKit.H3, UiKit.LINE))
	if rows.is_empty():
		_body.add_child(UiKit.label("No local submissions yet. Finish a run in this mode.", UiKit.BODY, UiKit.TEXT_DIM))
		return
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var metric = "%d" % int(row.get("score", 0)) if _mode == Game.Mode.SCORE_ATTACK else RunController.format_time(float(row.get("time", 0.0)))
		_body.add_child(UiKit.row("%02d   %s" % [i + 1, str(row.get("name", "SLIDER"))], metric, UiKit.ACCENT if i == 0 else UiKit.TEXT))
