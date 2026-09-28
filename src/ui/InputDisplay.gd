class_name InputDisplay
extends Control

## Speedrun-style input overlay: steer and lean as bipolar bars, tuck and brake
## as lamps. Reads the exact packet the motor received this tick, so what it
## shows is what a replay will reproduce.

const W = 196.0
const H = 64.0

var slider: SlideBody

func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if slider == null:
		return
	var inp: MotorInput = slider.input
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.03, 0.04, 0.06, 0.62))
	_bipolar(Rect2(10, 10, 120, 16), inp.steer, UiKit.LINE, "STEER")
	_bipolar(Rect2(10, 38, 120, 16), inp.lean, UiKit.ACCENT, "LEAN")
	_lamp(Rect2(140, 10, 46, 16), inp.tuck, "TUCK", UiKit.GOOD)
	_lamp(Rect2(140, 38, 46, 16), inp.brake, "BRAKE", UiKit.WARN)

func _bipolar(r: Rect2, v: float, c: Color, label: String) -> void:
	draw_rect(r, Color(1, 1, 1, 0.07))
	var mid = r.position.x + r.size.x * 0.5
	var w = r.size.x * 0.5 * clampf(v, -1.0, 1.0)
	draw_rect(Rect2(minf(mid, mid + w), r.position.y, absf(w), r.size.y), c)
	draw_line(Vector2(mid, r.position.y - 2), Vector2(mid, r.end.y + 2), Color(1, 1, 1, 0.35), 1.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(3, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.55))

func _lamp(r: Rect2, on: bool, label: String, c: Color) -> void:
	draw_rect(r, c if on else Color(1, 1, 1, 0.07))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiKit.BG if on else Color(1, 1, 1, 0.55))
