class_name NetOverlay
extends Control

## In-round chrome for online time attack: round clock, live standings, and
## the final standings card when the host's clock runs out.

var net: NetSession
var _clock: Label
var _rows: VBoxContainer
var _final: PanelContainer

func setup(session: NetSession) -> void:
	net = session
	net.scoreboard_changed.connect(_fill)
	net.round_ended.connect(_show_final)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box = VBoxContainer.new()
	UiKit.pin(box, Control.PRESET_TOP_RIGHT, Vector2(46, 190))
	box.custom_minimum_size = Vector2(260, 0)
	add_child(box)
	_clock = UiKit.mono("", UiKit.H3, UiKit.ACCENT)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_clock)
	_rows = VBoxContainer.new(); _rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)
	if net: _fill(net.scoreboard_rows())

func _process(_d: float) -> void:
	if net == null: return
	var left = int(ceil(net.round_left))
	_clock.text = "ROUND  %d:%02d" % [left / 60, left % 60] if net.round_active else "ROUND OVER"

func _fill(rows: Array) -> void:
	for c in _rows.get_children(): c.queue_free()
	var me = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for i in mini(rows.size(), 8):
		var r: Dictionary = rows[i]
		var t = float(r["best"])
		var line = UiKit.row("%d  %s" % [i + 1, r["name"]], RunController.format_time(t) if t > 0.0 else "—",
			UiKit.GOOD if int(r["id"]) == me else UiKit.TEXT, 15)
		_rows.add_child(line)

func _show_final(rows: Array) -> void:
	if _final: _final.queue_free()
	_final = UiKit.panel(22)
	UiKit.pin(_final, Control.PRESET_CENTER)
	_final.custom_minimum_size = Vector2(520, 0)
	_final.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_final)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 6); _final.add_child(col)
	col.add_child(UiKit.label("ROUND OVER", UiKit.H2, UiKit.ACCENT))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var t = float(r["best"])
		col.add_child(UiKit.row("%d  %s" % [i + 1, r["name"]], (RunController.format_time(t) + "   %d runs" % int(r["runs"])) if t > 0.0 else "no finish", UiKit.GOOD if i == 0 and t > 0.0 else UiKit.TEXT))
	var lobby = UiKit.button("BACK TO LOBBY", true)
	lobby.pressed.connect(func(): Main.instance.show_lobby())
	col.add_child(lobby)
	lobby.grab_focus()
