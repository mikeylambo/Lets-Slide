class_name UiKit
extends RefCounted

## One visual vocabulary for the whole game, defined once in code.
##
## Every screen is built from these factories rather than hand-authored scenes.
## That keeps the look consistent for free and means a restyle later is one file
## — which matters a lot when the art direction is still moving.

const BG = Color(0.035, 0.04, 0.06)
const PANEL = Color(0.07, 0.085, 0.12, 0.92)
const LINE = Color(0.22, 0.95, 1.0)
const ACCENT = Color(1.0, 0.35, 0.88)
const TEXT = Color(0.90, 0.94, 1.0)
const TEXT_DIM = Color(0.55, 0.62, 0.72)
const GOOD = Color(0.42, 1.0, 0.68)
const WARN = Color(1.0, 0.72, 0.30)

const H1 = 62
const H2 = 34
const H3 = 22
const BODY = 17
const MONO = 20

static func root_control() -> Control:
	var c = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c

static func backdrop(alpha: float = 1.0) -> ColorRect:
	var r = ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.color = Color(BG.r, BG.g, BG.b, alpha)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func label(text: String, size: int = BODY, color: Color = TEXT) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func mono(text: String, size: int = MONO, color: Color = TEXT) -> Label:
	var l = label(text, size, color)
	l.add_theme_constant_override("line_spacing", 2)
	return l

static func title(text: String, sub: String = "") -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var t = label(text, H1, TEXT)
	t.add_theme_color_override("font_shadow_color", LINE)
	t.add_theme_constant_override("shadow_outline_size", 2)
	box.add_child(t)
	if sub != "":
		box.add_child(label(sub, H3, TEXT_DIM))
	box.add_child(rule())
	return box

static func rule(color: Color = LINE, height: int = 2) -> ColorRect:
	var r = ColorRect.new()
	r.color = Color(color.r, color.g, color.b, 0.55)
	r.custom_minimum_size = Vector2(0, height)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

static func spacer(h: float = 12.0) -> Control:
	var c = Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

static func button(text: String, accent: bool = false) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 46)
	b.add_theme_font_size_override("font_size", H3)
	b.focus_mode = Control.FOCUS_ALL
	var c: Color = ACCENT if accent else LINE
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", BG)
	b.add_theme_color_override("font_focus_color", BG)
	b.add_theme_stylebox_override("normal", _box(Color(c.r, c.g, c.b, 0.10), c, 1))
	b.add_theme_stylebox_override("hover", _box(Color(c.r, c.g, c.b, 0.85), c, 1))
	b.add_theme_stylebox_override("focus", _box(Color(c.r, c.g, c.b, 0.85), c, 2))
	b.add_theme_stylebox_override("pressed", _box(Color(c.r, c.g, c.b, 1.0), c, 2))
	return b

static func panel(padding: int = 18) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(PANEL, Color(LINE.r, LINE.g, LINE.b, 0.35), 1, padding))
	return p

static func _box(bg: Color, border: Color, width: int, padding: int = 8) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = maxi(6, int(padding * 0.55))
	sb.content_margin_bottom = maxi(6, int(padding * 0.55))
	return sb

## Two-column key/value row — used by records, results and the telemetry list.
static func row(key: String, value: String, value_color: Color = TEXT, key_size: int = BODY) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var k = label(key, key_size, TEXT_DIM)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v = mono(value, key_size + 1, value_color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(k)
	h.add_child(v)
	return h

static func bar(value: float, color: Color = LINE, width: float = 220.0) -> Control:
	var wrap = Control.new()
	wrap.custom_minimum_size = Vector2(width, 10)
	var back = ColorRect.new()
	back.color = Color(1, 1, 1, 0.08)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(back)
	var fill = ColorRect.new()
	fill.color = color
	fill.position = Vector2.ZERO
	fill.size = Vector2(width * clampf(value, 0.0, 1.0), 10)
	wrap.add_child(fill)
	return wrap

static func centered(child: Control) -> CenterContainer:
	var c = CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c

static func speed_string(speed_ms: float) -> String:
	if Game.settings.get("units_metric", true):
		return "%3.0f km/h" % (speed_ms * 3.6)
	return "%3.0f mph" % (speed_ms * 2.23694)
