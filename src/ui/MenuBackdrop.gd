class_name MenuBackdrop
extends Control

## Lightweight contour-map menu identity plus an idle attract loop. The attract
## loop is intentionally non-interactive presentation: it previews an author line
## without loading gameplay or mutating records.

const ATTRACT_DELAY := 18.0
var idle = 0.0
var phase = 0.0
var attract = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		idle = 0.0
		attract = false
		queue_redraw()

func _process(delta: float) -> void:
	phase += delta
	idle += delta
	if idle >= ATTRACT_DELAY:
		attract = true
	queue_redraw()

func _draw() -> void:
	var s = size
	if s.x <= 0.0 or s.y <= 0.0: return
	# Animated contour field: readable, cheap, and specific to a terrain-reading game.
	for row in range(15):
		var pts = PackedVector2Array()
		var y0 = s.y * (0.10 + float(row) * 0.058)
		for x in range(0, int(s.x) + 30, 30):
			var nx = float(x) / maxf(s.x, 1.0)
			var wave = sin(nx * TAU * 2.0 + float(row) * 0.63 + phase * 0.12) * (8.0 + float(row) * 0.8)
			wave += sin(nx * TAU * 5.0 - phase * 0.08) * 3.0
			pts.append(Vector2(float(x), y0 + wave))
		if pts.size() > 1:
			draw_polyline(pts, Color(0.24, 0.70, 0.86, 0.08 + float(row % 3) * 0.015), 1.0)
	# Beat-grid ticks quietly pulse at 174 BPM.
	var beat = fmod(phase, 60.0 / Tempo.BPM) / (60.0 / Tempo.BPM)
	for i in range(12):
		var x = s.x * (float(i + 1) / 13.0)
		var a = 0.025 + (1.0 - beat) * 0.035 if i % 4 == 0 else 0.018
		draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, a), 1.0)
	if attract:
		var panel = Rect2(s.x * 0.60, s.y * 0.12, s.x * 0.32, s.y * 0.28)
		draw_rect(panel, Color(0.02, 0.03, 0.05, 0.70), true)
		draw_rect(panel, Color(0.25, 0.95, 1.0, 0.22), false, 1.0)
		var t = fmod((idle - ATTRACT_DELAY) * 0.16, 1.0)
		var path = PackedVector2Array()
		for i in range(80):
			var u = float(i) / 79.0
			var px = panel.position.x + panel.size.x * (0.08 + u * 0.84)
			var py = panel.position.y + panel.size.y * (0.18 + u * 0.68 + sin(u * TAU * 2.2) * 0.08)
			path.append(Vector2(px, py))
		draw_polyline(path, Color(0.65, 0.52, 1.0, 0.50), 2.0)
		var idx = clampi(int(t * 79.0), 0, 79)
		draw_circle(path[idx], 6.0, Color(1.0, 0.38, 0.88, 0.95))
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(14, 24), "AUTHOR LINE // THRESHOLD 03", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.82, 0.90, 1.0, 0.72))
