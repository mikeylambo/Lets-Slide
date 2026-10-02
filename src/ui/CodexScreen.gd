class_name CodexScreen
extends Control

## Tech codex. Every technique starts as a hint; doing it for real names it.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 56); margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 10); margin.add_child(col)
	var found = Game.profile["tech"].size()
	col.add_child(UiKit.title("CODEX", "%d / %d techniques · %d / %d chick badges" % [found, TechTracker.TECHS.size(), Game.badge_total(), Courses.all().size()]))
	for t in TechTracker.TECHS:
		var known = Game.profile["tech"].has(t["id"])
		var p = UiKit.panel(14); col.add_child(p)
		var box = VBoxContainer.new(); p.add_child(box)
		box.add_child(UiKit.label(t["name"] if known else "? ? ?", UiKit.H3, UiKit.LINE if known else UiKit.TEXT_DIM))
		var body = UiKit.label(t["desc"] if known else t["hint"], UiKit.BODY, UiKit.TEXT if known else UiKit.TEXT_DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)
	col.add_child(UiKit.spacer(8))
	var back = UiKit.button("BACK"); back.pressed.connect(func(): Main.instance.show_menu()); col.add_child(back)
	back.grab_focus()
