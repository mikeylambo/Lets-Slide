class_name MainMenu
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT); var live_bg=MenuBackdrop.new(); add_child(live_bg); add_child(UiKit.backdrop(0.80))
	var margin = MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",90); margin.add_theme_constant_override("margin_top",70); margin.add_theme_constant_override("margin_bottom",60); add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation",10); margin.add_child(col)
	col.add_child(UiKit.title("LET'S SLIDE", "terrain is the moveset")); col.add_child(UiKit.spacer(28))
	var buttons = VBoxContainer.new(); buttons.add_theme_constant_override("separation",8); col.add_child(buttons)
	var play = UiKit.button("PLAY", true); play.pressed.connect(func(): Main.instance.show_mode_select()); buttons.add_child(play)
	var daily = UiKit.button("DAILY DESCENT"); daily.pressed.connect(func(): Game.set_mode(Game.Mode.DAILY); Main.instance.start_daily()); buttons.add_child(daily)
	var lab = UiKit.button("MOVEMENT LAB"); lab.pressed.connect(func(): Main.instance.open_lab()); buttons.add_child(lab)
	var records = UiKit.button("RECORDS"); records.pressed.connect(func(): Main.instance.show_records()); buttons.add_child(records)
	var boards = UiKit.button("LEADERBOARDS"); boards.pressed.connect(func(): Main.instance.show_leaderboards()); buttons.add_child(boards)
	var rider = UiKit.button("RIDER"); rider.pressed.connect(func(): Main.instance.show_cosmetics()); buttons.add_child(rider)
	var options = UiKit.button("OPTIONS"); options.pressed.connect(func(): Main.instance.show_options()); buttons.add_child(options)
	var quit = UiKit.button("QUIT"); quit.pressed.connect(func(): get_tree().quit()); buttons.add_child(quit)
	col.add_child(UiKit.spacer(20))
	var stats = HBoxContainer.new(); stats.add_theme_constant_override("separation",26)
	stats.add_child(UiKit.label("MEDALS  %d / 25" % Game.medal_total(), UiKit.BODY, UiKit.WARN))
	stats.add_child(UiKit.label("RUNS  %d" % int(Game.profile["total_runs"]), UiKit.BODY, UiKit.TEXT_DIM))
	stats.add_child(UiKit.label("DISTANCE  %.1f km" % (float(Game.profile["total_distance"])/1000.0), UiKit.BODY, UiKit.TEXT_DIM)); col.add_child(stats)
	play.grab_focus()
