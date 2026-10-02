class_name ControlsScreen
extends Control

## Rebind keys and pad buttons. Select CHANGE, then press the new key or
## button. Esc cancels a pending change. Stick axes are not remappable.

const LABELS = {"steer_left": "Steer left", "steer_right": "Steer right", "lean_forward": "Lean forward",
	"lean_back": "Lean back", "tuck": "Tuck", "brake": "Brake", "retry": "Retry", "pause_menu": "Pause"}

var _waiting_action = ""
var _waiting_pad = false
var _rows = {}
var _status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 90)
	margin.add_theme_constant_override("margin_top", 56); margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 8); margin.add_child(col)
	col.add_child(UiKit.title("CONTROLS", "keyboard and controller"))
	var hdr = HBoxContainer.new(); col.add_child(hdr)
	for h in [["ACTION", 260], ["KEY", 330], ["CONTROLLER", 330]]:
		var l = UiKit.label(h[0], 14, UiKit.TEXT_DIM); l.custom_minimum_size = Vector2(h[1], 0); hdr.add_child(l)
	var first: Button
	for action in Game.REMAPPABLE:
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); col.add_child(row)
		var name = UiKit.label(LABELS[action], UiKit.BODY); name.custom_minimum_size = Vector2(260, 0); row.add_child(name)
		var key = UiKit.button(""); key.custom_minimum_size = Vector2(320, 40); key.add_theme_font_size_override("font_size", 16)
		key.pressed.connect(func(): _begin(action, false)); row.add_child(key)
		var pad = UiKit.button(""); pad.custom_minimum_size = Vector2(320, 40); pad.add_theme_font_size_override("font_size", 16)
		pad.pressed.connect(func(): _begin(action, true)); row.add_child(pad)
		_rows[action] = {"key": key, "pad": pad}
		if first == null: first = key
	_status = UiKit.label("Select a binding, then press the new key or button.", UiKit.BODY, UiKit.TEXT_DIM)
	col.add_child(_status)
	var actions = HBoxContainer.new(); actions.add_theme_constant_override("separation", 12); col.add_child(actions)
	var reset = UiKit.button("RESET TO DEFAULTS"); reset.pressed.connect(func(): Game.reset_bindings(); _refresh(); _status.text = "Defaults restored.")
	actions.add_child(reset)
	var back = UiKit.button("BACK"); back.pressed.connect(func(): Main.instance.show_options()); actions.add_child(back)
	_refresh()
	first.grab_focus()

func _refresh() -> void:
	for action in _rows.keys():
		var t = Game.binding_text(action)
		_rows[action]["key"].text = str(t["key"])
		_rows[action]["pad"].text = str(t["pad"])

func _begin(action: String, pad: bool) -> void:
	_waiting_action = action; _waiting_pad = pad
	_rows[action]["pad" if pad else "key"].text = "PRESS A BUTTON…" if pad else "PRESS A KEY…"
	_status.text = "Waiting for %s for %s. Esc cancels." % ["a controller button" if pad else "a key", LABELS[action]]

func _input(event: InputEvent) -> void:
	if _waiting_action == "": return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_waiting_action = ""; _refresh(); _status.text = "Cancelled."
		get_viewport().set_input_as_handled(); return
	var accept = (not _waiting_pad and event is InputEventKey and event.pressed and not event.echo) or \
		(_waiting_pad and event is InputEventJoypadButton and event.pressed)
	if not accept: return
	var e: InputEvent
	if event is InputEventKey:
		var k = InputEventKey.new(); k.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode; e = k
	else:
		var b = InputEventJoypadButton.new(); b.button_index = event.button_index; e = b
	Game.rebind(_waiting_action, e)
	_status.text = "%s set." % LABELS[_waiting_action]
	_waiting_action = ""
	_refresh()
	get_viewport().set_input_as_handled()
