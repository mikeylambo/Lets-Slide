class_name CourseSelect
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT); add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",70); margin.add_theme_constant_override("margin_right",70); margin.add_theme_constant_override("margin_top",45); margin.add_theme_constant_override("margin_bottom",40); add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation",10); margin.add_child(col)
	col.add_child(UiKit.title(Game.mode_name(), "%d medals · physics never changes" % Game.medal_total()))
	var scroll = ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	var regions = VBoxContainer.new(); regions.add_theme_constant_override("separation",18); scroll.add_child(regions)
	var first: Button = null
	for r in range(5):
		var info: Dictionary = CourseCatalog.REGIONS[r]
		var unlocked = Game.region_unlocked(r)
		regions.add_child(UiKit.label("%s   %s" % [info["name"], "" if unlocked else "LOCKED · %d MEDALS" % int(info["gate"])], UiKit.H3, UiKit.LINE if unlocked else UiKit.TEXT_DIM))
		if not unlocked: continue
		var grid = GridContainer.new(); grid.columns = 5; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); regions.add_child(grid)
		for course in Courses.region_courses(r):
			var card = _card(course); grid.add_child(card)
			var b: Button = card.get_meta("start_button")
			if first == null and not b.disabled: first = b
	var back = UiKit.button("BACK"); back.pressed.connect(func(): Main.instance.show_mode_select()); col.add_child(back)
	if first: first.grab_focus()

func _card(course: CourseData) -> PanelContainer:
	var rec = Game.record_for(course.id); var p = UiKit.panel(12); p.custom_minimum_size=Vector2(265,170)
	var col = VBoxContainer.new(); p.add_child(col)
	col.add_child(UiKit.label("%02d  %s" % [course.region_index*5+course.course_index+1, course.title], UiKit.BODY, UiKit.TEXT))
	col.add_child(UiKit.label("DESCENT" if course.is_descent else course.subtitle, 13, UiKit.TEXT_DIM)); col.add_child(UiKit.spacer(5))
	col.add_child(UiKit.row("BEST", RunController.format_time(float(rec["best_time"])), UiKit.LINE))
	col.add_child(UiKit.row("RANK", str(rec["best_rank"]) if str(rec["best_rank"])!="" else "—", Rank.color_for(str(rec["best_rank"]))))
	col.add_child(UiKit.row("MEDAL", str(rec["best_medal"]) if str(rec["best_medal"])!="" else "—", course.medal_color(str(rec["best_medal"]))))
	if course.medal_source != "probe":
		col.add_child(UiKit.label("PROVISIONAL TARGETS", 11, UiKit.WARN))
	if course.signature_moment != "":
		var hook = UiKit.label(course.signature_moment, 11, UiKit.TEXT_DIM)
		hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(hook)
	var start = UiKit.button("START", false); start.disabled = not Game.course_unlocked(course); start.pressed.connect(func(): Main.instance.play_course(course)); col.add_child(start)
	p.set_meta("start_button",start); return p
