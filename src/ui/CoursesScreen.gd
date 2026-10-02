class_name CoursesScreen
extends Control

## Community courses: your own and imported ones. Codes are text, so sharing
## works over chat, Discord or a forum post with no server.

var _list: VBoxContainer
var _code: TextEdit
var _status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 50); margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 10); margin.add_child(col)
	col.add_child(UiKit.title("COURSES", "build · verify · share"))
	var top = HBoxContainer.new(); top.add_theme_constant_override("separation", 12); col.add_child(top)
	var new_b = UiKit.button("NEW COURSE", true)
	new_b.pressed.connect(func(): Main.instance.show_course_editor(CustomCourses.template()))
	top.add_child(new_b)
	_code = TextEdit.new(); _code.placeholder_text = "Paste a course code (SLCS1:…) to import"
	_code.custom_minimum_size = Vector2(520, 46); _code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_code)
	var imp = UiKit.button("IMPORT"); imp.custom_minimum_size = Vector2(150, 46); imp.pressed.connect(import_code)
	top.add_child(imp)
	_status = UiKit.label("", UiKit.BODY, UiKit.TEXT_DIM); col.add_child(_status)
	var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	_list = VBoxContainer.new(); _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6); scroll.add_child(_list)
	var back = UiKit.button("BACK"); back.pressed.connect(func(): Main.instance.show_menu()); col.add_child(back)
	_populate()
	new_b.grab_focus()

func _populate() -> void:
	for c in _list.get_children(): c.queue_free()
	var courses = CustomCourses.all()
	if courses.is_empty():
		_list.add_child(UiKit.label("No courses yet. Build one, or import a code from a friend.", UiKit.BODY, UiKit.TEXT_DIM))
	for c in courses:
		_list.add_child(_row(c))

func _row(c: CourseData) -> PanelContainer:
	var p = UiKit.panel(10)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); p.add_child(row)
	var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
	info.add_child(UiKit.label(c.title, UiKit.H3))
	var verified = CourseCodec.is_verified(c)
	var best = float(Game.record_for(c.id)["best_time"])
	info.add_child(UiKit.label("%s · %s · %.0f bars · %s · best %s" % [c.subtitle, c.region,
		c.total_bars, ("author " + RunController.format_time(c.author_time)) if verified else "unverified",
		RunController.format_time(best)], 14, UiKit.GOOD if verified else UiKit.TEXT_DIM))
	var play = _small("PLAY", func(): Game.editor_course = null; Game.verifying_course = false; Game.set_mode(Game.Mode.TIME_TRIAL); Main.instance.play_course(c))
	row.add_child(play)
	var author = CourseCodec.author_replay(c)
	if author:
		row.add_child(_small("RACE AUTHOR", func(): Game.editor_course = null; Game.set_mode(Game.Mode.TIME_TRIAL); Main.instance.play_course(c, null, {"rival": author})))
	row.add_child(_small("EDIT", func(): Main.instance.show_course_editor(c)))
	var share = _small("COPY CODE", func(): pass)
	share.disabled = not verified
	share.pressed.connect(func(): DisplayServer.clipboard_set(CourseCodec.to_code(c)); share.text = "COPIED")
	row.add_child(share)
	var del = _small("DELETE", func(): pass)
	del.pressed.connect(func():
		if del.text == "DELETE": del.text = "CONFIRM"
		else: CustomCourses.delete(c.id); _populate())
	row.add_child(del)
	return p

func _small(text: String, f: Callable) -> Button:
	var b = UiKit.button(text); b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 15); b.pressed.connect(f); return b

func import_code() -> void:
	var r = CourseCodec.from_code(_code.text)
	if r.has("error"):
		_status.text = r["error"]; _status.add_theme_color_override("font_color", UiKit.WARN); return
	var c: CourseData = r["course"]
	CustomCourses.save(c)
	_code.text = ""
	_status.text = "Imported %s%s." % [c.title, " with the author's run" if CourseCodec.author_replay(c) else " (unverified)"]
	_status.add_theme_color_override("font_color", UiKit.GOOD)
	_populate()
