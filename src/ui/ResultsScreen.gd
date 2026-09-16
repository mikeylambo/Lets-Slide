class_name ResultsScreen
extends Control

## The screen that has to make you press retry.
##
## So it leads with the delta against your own best, shows exactly which records
## you beat, breaks the rank into the four things it graded, and puts the next
## medal time in front of you before you have decided to stop.

signal retry_requested()
signal exit_requested()
signal next_requested()

var result = {}
var course: CourseData

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop(0.86))

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_right", 110)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var beaten: Dictionary = result.get("beaten", {})
	var new_record: bool = beaten.get("time", false)

	col.add_child(UiKit.title("FINISH" if bool(result.get("finished", false)) else "RUN OVER", "%s · %s" % [Game.mode_name(), course.title]))
	col.add_child(UiKit.spacer(6))

	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 46)
	col.add_child(top)

	# --- left: time and rank -----------------------------------------------
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)

	left.add_child(UiKit.label("TIME", UiKit.BODY, UiKit.TEXT_DIM))
	left.add_child(UiKit.mono(RunController.format_time(float(result.get("time", 0.0))), 58,
		UiKit.GOOD if new_record else UiKit.TEXT))

	var prev: float = float(result.get("previous_best", 0.0))
	if new_record:
		left.add_child(UiKit.label("NEW PERSONAL BEST", UiKit.H3, UiKit.GOOD))
		if prev > 0.0:
			left.add_child(UiKit.label("−%.3f s" % (prev - float(result["time"])), UiKit.BODY, UiKit.GOOD))
	elif prev > 0.0:
		left.add_child(UiKit.label("+%.3f s off your best" % (float(result["time"]) - prev), UiKit.H3, UiKit.WARN))

	left.add_child(UiKit.spacer(14))
	var medal: String = str(result.get("medal", ""))
	left.add_child(UiKit.row("MEDAL", medal if medal != "" else "NONE", course.medal_color(medal), UiKit.H3))
	var next_target = course.next_medal(float(result.get("time", 0.0)))
	if not next_target.is_empty():
		left.add_child(UiKit.row("NEXT", "%s  %s" % [next_target["name"], RunController.format_time(next_target["time"])], UiKit.WARN))

	# --- right: rank and breakdown -----------------------------------------
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)

	var rank: String = str(result.get("rank", "D"))
	right.add_child(UiKit.label("RANK", UiKit.BODY, UiKit.TEXT_DIM))
	right.add_child(UiKit.mono(rank, 72, Rank.color_for(rank)))

	var bd: Dictionary = result.get("grade_breakdown", {})
	right.add_child(UiKit.spacer(6))
	right.add_child(_bar_row("TIME", float(bd.get("time_score", 0.0)), UiKit.LINE))
	right.add_child(_bar_row("MOMENTUM", float(bd.get("momentum_score", 0.0)), UiKit.GOOD))
	right.add_child(_bar_row("SCORE", float(bd.get("score_score", 0.0)), UiKit.WARN))
	right.add_child(_bar_row("MASTERY", float(bd.get("mastery_score", 0.0)), UiKit.ACCENT))

	# --- stats --------------------------------------------------------------
	col.add_child(UiKit.spacer(10))
	var stats = UiKit.panel(16)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 60)
	stats.add_child(grid)
	grid.add_child(UiKit.row("Score", str(int(result.get("score", 0))), UiKit.GOOD if beaten.get("score", false) else UiKit.TEXT))
	grid.add_child(UiKit.row("Collectibles", "%d / %d" % [int(result.get("pickups", 0)), int(result.get("total_pickups", 0))]))
	grid.add_child(UiKit.row("Mastery", "%d / %d" % [int(result.get("mastery", 0)), course.mastery_count],
		UiKit.ACCENT if int(result.get("mastery", 0)) > 0 else UiKit.TEXT_DIM))
	grid.add_child(UiKit.row("Top speed", UiKit.speed_string(float(result.get("top_speed", 0.0))), UiKit.LINE))
	grid.add_child(UiKit.row("Avg momentum", "%.1f %%" % (float(result.get("avg_momentum", 0.0)) * 100.0)))
	grid.add_child(UiKit.row("Bonks", str(int(result.get("bonks", 0))), UiKit.WARN if int(result.get("bonks", 0)) > 0 else UiKit.TEXT))
	grid.add_child(UiKit.row("Best Flow", "%.1f s" % float(result.get("max_flow", 0.0)), UiKit.ACCENT))
	grid.add_child(UiKit.row("Flow time", "%.1f s" % float(result.get("flow_seconds", 0.0)), UiKit.ACCENT))
	grid.add_child(UiKit.row("Respawns", str(int(result.get("respawns", 0))), UiKit.WARN if int(result.get("respawns", 0)) > 0 else UiKit.TEXT))
	col.add_child(stats)

	# --- local/offline leaderboard. ShellBridge is the backend seam; when the
	# online service lands this panel does not change.
	var board = ShellBridge.leaderboard(course.id)
	if not board.is_empty():
		col.add_child(UiKit.spacer(6))
		col.add_child(UiKit.label("LEADERBOARD", UiKit.H3, UiKit.LINE))
		for i in range(mini(3, board.size())):
			var row: Dictionary = board[i]
			var value = str(int(row.get("score",0))) if Game.current_mode == Game.Mode.SCORE_ATTACK else RunController.format_time(float(row.get("time",0.0)))
			col.add_child(UiKit.row("%d  %s" % [i+1, str(row.get("name","SLIDER"))], value, UiKit.GOOD if i==0 else UiKit.TEXT))

	# --- actions ------------------------------------------------------------
	col.add_child(UiKit.spacer(14))
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)

	var retry = UiKit.button("RETRY   (R)", true)
	retry.pressed.connect(func(): retry_requested.emit())
	actions.add_child(retry)

	if Game.current_mode in [Game.Mode.SURVIVAL, Game.Mode.ENDLESS]:
		var next = UiKit.button("NEXT DESCENT", true)
		next.pressed.connect(func(): next_requested.emit())
		actions.add_child(next)

	var back = UiKit.button("COURSE SELECT")
	back.pressed.connect(func(): exit_requested.emit())
	actions.add_child(back)

	retry.grab_focus()
	# Fast presentation beat: results arrive immediately, then resolve in less
	# than half a second. Retry is focusable from frame one.
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.16)

func _bar_row(text: String, value: float, color: Color) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l = UiKit.label(text, UiKit.BODY, UiKit.TEXT_DIM)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	h.add_child(UiKit.bar(value, color, 240.0))
	h.add_child(UiKit.mono("%3.0f%%" % (value * 100.0), 15, color))
	return h

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("retry"):
		retry_requested.emit()
		get_viewport().set_input_as_handled()
