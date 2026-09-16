class_name TelemetryPanel
extends PanelContainer

## The numbers we actually tune against. Having these on screen while you play
## is the difference between "it feels floaty" and "landing retention is eating
## 30% and the slope curve is flattening past 20 degrees".

const ROWS = [
	["MODEL", "model"],
	["HZ", "hz"],
	["SPEED", "speed"],
	["GROUND SPD", "ground_speed"],
	["SLOPE", "slope_deg"],
	["STEER Δ", "steer_delta_deg"],
	["MOMENTUM", "momentum"],
	["SURFACE", "surface"],
	["STATE", "grounded"],
	["AIR TIME", "air_time"],
	["LAUNCH SPD", "launch_speed"],
	["LANDING SPD", "landing_speed"],
	["LANDING Q", "landing_quality"],
]

var _labels = {}

func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit._box(Color(0.04, 0.05, 0.08, 0.85),
		Color(UiKit.LINE.r, UiKit.LINE.g, UiKit.LINE.b, 0.30), 1, 14))
	custom_minimum_size = Vector2(292, 0)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	col.add_child(UiKit.label("TELEMETRY", UiKit.BODY, UiKit.LINE))
	col.add_child(UiKit.rule())

	for r in ROWS:
		var h = HBoxContainer.new()
		var k = UiKit.label(r[0], 14, UiKit.TEXT_DIM)
		k.custom_minimum_size = Vector2(132, 0)
		var v = UiKit.mono("—", 15, UiKit.TEXT)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(v)
		col.add_child(h)
		_labels[r[1]] = v

func update_values(t: Dictionary) -> void:
	_put("model", str(t.get("model", "—")), UiKit.ACCENT if str(t.get("model", "")) == "SM64 REFERENCE" else UiKit.LINE)
	_put("hz", str(t.get("hz", 0)))
	_put("speed", "%6.2f m/s" % float(t.get("speed", 0.0)))
	_put("ground_speed", "%6.2f m/s" % float(t.get("ground_speed", 0.0)))
	_put("slope_deg", "%5.1f°" % float(t.get("slope_deg", 0.0)))
	_put("steer_delta_deg", "%+5.2f°" % float(t.get("steer_delta_deg", 0.0)))
	var mom: float = float(t.get("momentum", 1.0))
	_put("momentum", "%5.1f %%" % (mom * 100.0), UiKit.GOOD if mom >= 0.999 else (UiKit.WARN if mom > 0.985 else UiKit.ACCENT))
	_put("surface", str(t.get("surface", "—")))
	_put("grounded", "GROUNDED" if bool(t.get("grounded", false)) else "AIR",
		UiKit.TEXT if bool(t.get("grounded", false)) else UiKit.ACCENT)
	_put("air_time", "%5.2f s" % float(t.get("air_time", 0.0)))
	_put("launch_speed", "%6.2f m/s" % float(t.get("launch_speed", 0.0)))
	_put("landing_speed", "%6.2f m/s" % float(t.get("landing_speed", 0.0)))
	var q: float = float(t.get("landing_quality", 1.0))
	_put("landing_quality", "%5.1f %%" % (q * 100.0), UiKit.GOOD if q > 0.75 else UiKit.WARN)

func _put(key: String, value: String, color: Color = UiKit.TEXT) -> void:
	if not _labels.has(key):
		return
	var l: Label = _labels[key]
	l.text = value
	l.add_theme_color_override("font_color", color)
