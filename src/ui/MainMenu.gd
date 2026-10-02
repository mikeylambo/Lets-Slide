class_name MainMenu
extends Control

## Three tiers: the four ways to ride, then everything about your riding,
## then settings. A brand-new profile's PLAY goes straight into the guided
## first descent instead of a menu.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); var live_bg=MenuBackdrop.new(); add_child(live_bg); add_child(UiKit.backdrop(0.80))
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",90); margin.add_theme_constant_override("margin_top",64); margin.add_theme_constant_override("margin_bottom",50); add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation",10); margin.add_child(col)
	var head = UiKit.title("LET'S SLIDE", "terrain is the moveset"); head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.custom_minimum_size.x = 620; col.add_child(head); col.add_child(UiKit.spacer(18))

	var primary = VBoxContainer.new(); primary.add_theme_constant_override("separation",8); col.add_child(primary)
	primary.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var first_time = int(Game.profile.get("total_runs", 0)) == 0
	var play = UiKit.button("START YOUR FIRST DESCENT" if first_time else "PLAY", true)
	play.custom_minimum_size.x = 616
	play.pressed.connect(func():
		if int(Game.profile.get("total_runs", 0)) == 0:
			Game.set_mode(Game.Mode.CAMPAIGN); Main.instance.play_course(Courses.all()[0])
		else: Main.instance.show_mode_select())
	primary.add_child(play)
	for item in [["DAILY DESCENT", func(): Game.set_mode(Game.Mode.DAILY); Main.instance.start_daily()],
			["ONLINE", func(): Main.instance.show_lobby()],
			["COURSES", func(): Main.instance.show_courses()]]:
		var b = UiKit.button(item[0]); b.custom_minimum_size.x = 616; b.pressed.connect(item[1]); primary.add_child(b)

	col.add_child(UiKit.spacer(10))
	var grid = GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	var secondary = [["RUN CODES", func(): Main.instance.show_run_codes()], ["CODEX", func(): Main.instance.show_codex()],
		["RECORDS", func(): Main.instance.show_records()], ["LEADERBOARDS", func(): Main.instance.show_leaderboards()],
		["RIDER", func(): Main.instance.show_cosmetics()], ["OPTIONS", func(): Main.instance.show_options()]]
	if Game.dev_tools: secondary.append(["MOVEMENT LAB", func(): Main.instance.open_lab()])
	secondary.append(["QUIT", func(): get_tree().quit()])
	for item in secondary:
		var b = UiKit.button(item[0]); b.custom_minimum_size = Vector2(200, 40)
		b.add_theme_font_size_override("font_size", 16); b.pressed.connect(item[1]); grid.add_child(b)

	col.add_child(UiKit.spacer(16))
	var stats = HBoxContainer.new(); stats.add_theme_constant_override("separation",26)
	stats.add_child(UiKit.label("MEDALS  %d / 25" % Game.medal_total(), UiKit.BODY, UiKit.WARN))
	stats.add_child(UiKit.label("BADGES  %d / %d" % [Game.badge_total(), Courses.all().size()], UiKit.BODY, Color(1.0, 0.86, 0.22)))
	stats.add_child(UiKit.label("TECH  %d / %d" % [Game.profile["tech"].size(), TechTracker.TECHS.size()], UiKit.BODY, UiKit.LINE))
	stats.add_child(UiKit.label("RUNS  %d" % int(Game.profile["total_runs"]), UiKit.BODY, UiKit.TEXT_DIM))
	stats.add_child(UiKit.label("DISTANCE  %.1f km" % (float(Game.profile["total_distance"])/1000.0), UiKit.BODY, UiKit.TEXT_DIM)); col.add_child(stats)
	play.grab_focus()
