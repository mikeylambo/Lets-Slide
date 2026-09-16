class_name RecordsScreen
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT); add_child(UiKit.backdrop())
	var margin=MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",70); margin.add_theme_constant_override("margin_right",70); margin.add_theme_constant_override("margin_top",45); margin.add_theme_constant_override("margin_bottom",40); add_child(margin)
	var col=VBoxContainer.new(); col.add_theme_constant_override("separation",10); margin.add_child(col)
	col.add_child(UiKit.title("RECORDS", "%d / 25 medals · %d medal points" % [Game.medal_total(),Game.medal_points()]))
	var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; col.add_child(scroll)
	var body=VBoxContainer.new(); body.add_theme_constant_override("separation",10); scroll.add_child(body)
	for r in range(5):
		body.add_child(UiKit.label(str(CourseCatalog.REGIONS[r]["name"]),UiKit.H3,UiKit.LINE))
		var grid=GridContainer.new(); grid.columns=5; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); body.add_child(grid)
		for course in Courses.region_courses(r): grid.add_child(_card(course))
	var daily=Game.daily_record(); body.add_child(UiKit.spacer(10)); body.add_child(UiKit.label("DAILY · %s"%Game.daily_key(),UiKit.H3,UiKit.ACCENT))
	body.add_child(UiKit.row("First Sight",RunController.format_time(float(daily.get("first_sight",0.0))),UiKit.ACCENT))
	body.add_child(UiKit.row("Daily best",RunController.format_time(float(daily.get("best_time",0.0))),UiKit.GOOD))
	body.add_child(UiKit.row("Highest Endless prestige",str(int(Game.profile.get("prestige",0))),UiKit.WARN))
	var back=UiKit.button("BACK"); back.pressed.connect(func():Main.instance.show_menu()); col.add_child(back); back.grab_focus()

func _card(course:CourseData)->PanelContainer:
	var rec=Game.record_for(course.id); var p=UiKit.panel(10); p.custom_minimum_size=Vector2(250,165)
	var box=VBoxContainer.new(); p.add_child(box)
	box.add_child(UiKit.label(course.title,UiKit.BODY,UiKit.TEXT)); box.add_child(UiKit.row("TIME",RunController.format_time(float(rec["best_time"])),UiKit.LINE))
	box.add_child(UiKit.row("SCORE",str(int(rec["best_score"]))))
	box.add_child(UiKit.row("RANK",str(rec["best_rank"]) if str(rec["best_rank"])!="" else "—",Rank.color_for(str(rec["best_rank"]))))
	box.add_child(UiKit.row("MEDAL",str(rec["best_medal"]) if str(rec["best_medal"])!="" else "—",course.medal_color(str(rec["best_medal"]))))
	box.add_child(UiKit.row("FLOW","%.1fs"%float(rec.get("best_flow",0.0)),UiKit.ACCENT)); return p
