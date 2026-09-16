class_name ModeSelect
extends Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90); margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 60); margin.add_theme_constant_override("margin_bottom", 50); add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 10); margin.add_child(col)
	col.add_child(UiKit.title("LET'S SLIDE", "choose the exam")); col.add_child(UiKit.spacer(14))
	var modes = [
		["CAMPAIGN", "25 authored courses · medals · mastery", Game.Mode.CAMPAIGN],
		["TIME TRIAL", "Pure time · PB ghost · author pace", Game.Mode.TIME_TRIAL],
		["SCORE ATTACK", "Flow + pickups · time is informational", Game.Mode.SCORE_ATTACK],
		["SURVIVAL", "Continuous authored descents · 3 lives", Game.Mode.SURVIVAL],
		["DAILY DESCENT", "Shared deterministic seed · First Sight + unlimited retries", Game.Mode.DAILY],
		["ENDLESS", "Generated sight-reading · rising prestige", Game.Mode.ENDLESS],
	]
	var first: Button
	for item in modes:
		var panel = UiKit.panel(14); col.add_child(panel)
		var row = HBoxContainer.new(); panel.add_child(row)
		var text = VBoxContainer.new(); text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(text)
		text.add_child(UiKit.label(item[0], UiKit.H3)); text.add_child(UiKit.label(item[1], UiKit.BODY, UiKit.TEXT_DIM))
		var b = UiKit.button("PLAY", first == null); b.pressed.connect(_launch.bind(int(item[2]))); row.add_child(b)
		if first == null: first = b
	col.add_child(UiKit.spacer(10))
	var back = UiKit.button("BACK"); back.pressed.connect(func(): Main.instance.show_menu()); col.add_child(back)
	if first: first.grab_focus()

func _launch(mode: int) -> void:
	Game.set_mode(mode)
	match mode:
		Game.Mode.DAILY: Main.instance.start_daily()
		Game.Mode.ENDLESS: Main.instance.start_endless()
		Game.Mode.SURVIVAL: Main.instance.start_survival()
		_: Main.instance.show_course_select()
