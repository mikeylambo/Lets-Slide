extends Control

## Always-on harness chrome: status strip, toasts, retry latency, the end-of-run
## card with the optional 1–5 rating, and a fading key legend.

signal rated(stars: int)

var harness
var _strip_slot: Label
var _strip_text: Label
var _toasts: VBoxContainer
var _legend: Label
var _legend_t = 7.0
var _card: PanelContainer
var _card_time: Label
var _card_sub: Label
var _card_stars: HBoxContainer
var _card_hint: Label
var _rating_open = false
var _rating_choice = 3
var _card_fade = 0.0
var _strip_tick = 0.0

func setup(h) -> void:
	harness = h

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	var strip_wrap = CenterContainer.new()
	strip_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip_wrap.offset_top = -52
	strip_wrap.offset_bottom = -14
	strip_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip_wrap)
	var strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiKit._box(Color(0.03, 0.04, 0.06, 0.78), Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, 0.28), 1, 12))
	strip_wrap.add_child(strip)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	strip.add_child(h)
	_strip_slot = UiKit.mono("A", 18, UiKit.BG)
	_strip_slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_strip_slot.custom_minimum_size = Vector2(30, 0)
	h.add_child(_strip_slot)
	_strip_text = UiKit.mono("", 15, UiKit.TEXT)
	h.add_child(_strip_text)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.offset_top = -150
	_toasts.offset_bottom = -60
	_toasts.offset_left = -300
	_toasts.offset_right = 300
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	_legend = UiKit.label("F1/RB tune · Tab/LB swap A↔B · R/Y retry · N/Select marker · F2/L3 readability kit · M click · B blind · T telemetry", 13, UiKit.TEXT_DIM)
	_legend.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.offset_top = 10
	add_child(_legend)

	_build_card()

func _build_card() -> void:
	var wrap = CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit._box(Color(0.03, 0.04, 0.065, 0.93), UiKit.LINE, 1, 26))
	_card.custom_minimum_size = Vector2(440, 0)
	_card.visible = false
	wrap.add_child(_card)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_card.add_child(v)
	_card_time = UiKit.mono("", 48, UiKit.TEXT)
	_card_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_time)
	_card_sub = UiKit.mono("", 16, UiKit.TEXT_DIM)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_sub)
	v.add_child(UiKit.rule())
	_card_stars = HBoxContainer.new()
	_card_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_stars.add_theme_constant_override("separation", 10)
	v.add_child(_card_stars)
	for i in 5:
		var s = UiKit.label("★", 40, UiKit.TEXT_DIM)
		_card_stars.add_child(s)
	_card_hint = UiKit.label("", 14, UiKit.TEXT_DIM)
	_card_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_card_hint)

func rating_open() -> bool:
	return _rating_open

func show_result(result: Dictionary, best_before: float, ask_rating: bool) -> void:
	var t = float(result.get("time", 0.0))
	var finished = bool(result.get("finished", false))
	_card_time.text = RunController.format_time(t) if finished else str(result.get("fail_reason", "DNF"))
	var sub = harness.slot_display(harness.active)
	if finished and best_before > 0.0:
		var d = t - best_before
		sub += "   %s%.3f vs best" % ["+" if d >= 0.0 else "−", absf(d)]
		_card_time.add_theme_color_override("font_color", UiKit.GOOD if d < 0.0 else UiKit.TEXT)
	elif finished:
		sub += "   first finish"
		_card_time.add_theme_color_override("font_color", UiKit.GOOD)
	_card_sub.text = sub
	_card.visible = true
	_card.modulate.a = 1.0
	_card_fade = 0.0
	_rating_open = ask_rating
	_card_stars.visible = ask_rating
	_rating_choice = 3
	_paint_stars(_rating_choice, false)
	_card_hint.text = "1–5 or ←→ + A to rate  ·  R / Y retry (skips)" if ask_rating else "R / Y retry"

func hide_card() -> void:
	_rating_open = false
	_card.visible = false

## Returns true when the event was consumed by the rating prompt.
func handle_rating_input(event: InputEvent) -> bool:
	if not _rating_open:
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_5:
		submit_rating(event.keycode - KEY_0)
		return true
	if event.is_action_pressed("ui_left"):
		_rating_choice = maxi(1, _rating_choice - 1); _paint_stars(_rating_choice, false); return true
	if event.is_action_pressed("ui_right"):
		_rating_choice = mini(5, _rating_choice + 1); _paint_stars(_rating_choice, false); return true
	if event.is_action_pressed("ui_accept"):
		submit_rating(_rating_choice)
		return true
	return false

func submit_rating(stars: int) -> void:
	if not _rating_open:
		return
	_rating_open = false
	_paint_stars(stars, true)
	_card_hint.text = "Rated %d/5 · saved to run log · R / Y retry" % stars
	_card_fade = 1.6
	rated.emit(stars)

func _paint_stars(n: int, locked: bool) -> void:
	for i in _card_stars.get_child_count():
		var l: Label = _card_stars.get_child(i)
		var on = i < n
		l.add_theme_color_override("font_color", (UiKit.WARN if locked else UiKit.LINE) if on else Color(1, 1, 1, 0.14))

func toast(text: String, color: Color = UiKit.LINE) -> void:
	var l = UiKit.mono(text, 17, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		var old = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw = l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func _process(delta: float) -> void:
	if _legend_t > 0.0:
		_legend_t -= delta
		_legend.modulate.a = clampf(_legend_t, 0.0, 1.0)
	if _card_fade > 0.0:
		_card_fade -= delta
		if _card_fade <= 0.5:
			_card.modulate.a = clampf(_card_fade / 0.5, 0.0, 1.0)
		if _card_fade <= 0.0:
			_card.visible = false
	_strip_tick -= delta
	if _strip_tick > 0.0 or harness == null:
		return
	_strip_tick = 0.1
	var slot_c: Color = UiKit.LINE if harness.active == 0 or harness.blind else UiKit.ACCENT
	_strip_slot.text = harness.slot_label(harness.active)
	var sb = UiKit._box(slot_c, slot_c, 0, 6)
	_strip_slot.add_theme_stylebox_override("normal", sb)
	var parts = PackedStringArray()
	parts.append(harness.slot_display(harness.active, false))
	parts.append("RUN %d" % harness.current_run_number())
	var best = harness.session_best(harness.current_key())
	parts.append("BEST " + (RunController.format_time(best) if best > 0.0 else "—"))
	parts.append("BAR %5.1f" % harness.current_bar())
	parts.append("KIT " + ("ON" if harness.kit.enabled else "OFF") + (" · CLICK" if harness.kit.click_enabled else ""))
	if harness.last_retry_ms >= 0.0:
		parts.append("RETRY %d ms" % int(round(harness.last_retry_ms)))
	_strip_text.text = "   ·   ".join(parts)
