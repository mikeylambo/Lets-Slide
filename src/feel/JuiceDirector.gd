class_name JuiceDirector
extends CanvasLayer

## Presentation-only game-feel layer. It reads existing MotionState/Flow signals
## and never writes gameplay state. Safe to tune independently of the motor.

var slider: SlideBody
var flow: FlowSystem
var run: RunController
var _fx: Control
var _landing_flash = 0.0
var _bonk_flash = 0.0
var _finish_flash = 0.0
var _speed_t = 0.0
var _flow_tier = 0

func setup(player: SlideBody, flow_system: FlowSystem, run_controller: RunController) -> void:
	slider = player
	flow = flow_system
	run = run_controller
	layer = 6
	_fx = SpeedFx.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	if slider:
		slider.landed.connect(_on_landed)
		slider.bonked.connect(_on_bonked)
	if flow:
		flow.tier_changed.connect(func(t: int): _flow_tier = t)

func finish_burst() -> void:
	_finish_flash = 1.0

func _on_landed(quality: float, speed: float) -> void:
	var q = clampf(quality, 0.0, 1.0)
	_landing_flash = maxf(_landing_flash, (0.25 + 0.45 * q) * clampf(speed / 45.0, 0.25, 1.0))

func _on_bonked(speed: float) -> void:
	_bonk_flash = maxf(_bonk_flash, clampf(speed / 35.0, 0.35, 1.0))

func _process(delta: float) -> void:
	if slider:
		_speed_t = clampf(slider.state.speed / maxf(slider.params.max_speed, 1.0), 0.0, 1.0)
	_landing_flash = maxf(0.0, _landing_flash - delta * 4.2)
	_bonk_flash = maxf(0.0, _bonk_flash - delta * 7.5)
	_finish_flash = maxf(0.0, _finish_flash - delta * 3.5)
	if _fx:
		_fx.speed_t = _speed_t * float(Game.settings.get("speed_effects", 1.0))
		_fx.flow_tier = _flow_tier
		_fx.flow_intensity = float(Game.settings.get("flow_effects", 1.0))
		_fx.landing_flash = _landing_flash
		_fx.bonk_flash = _bonk_flash
		_fx.finish_flash = _finish_flash
		_fx.queue_redraw()

class SpeedFx:
	extends Control
	var speed_t = 0.0
	var flow_tier = 0
	var flow_intensity = 1.0
	var landing_flash = 0.0
	var bonk_flash = 0.0
	var finish_flash = 0.0

	func _draw() -> void:
		var size = get_viewport_rect().size
		var centre = size * 0.5
		# Speed lines begin late enough that low-speed teaching sections stay calm.
		var line_t = clampf((speed_t - 0.48) / 0.52, 0.0, 1.0)
		if line_t > 0.0:
			var count = int(10 + line_t * 24.0)
			for i in range(count):
				var a = TAU * (float(i) / float(maxi(count, 1))) + sin(float(i) * 4.17) * 0.13
				var radius = minf(size.x, size.y) * (0.26 + 0.20 * fmod(float(i) * 0.381, 1.0))
				var len = 18.0 + 78.0 * line_t * (0.4 + 0.6 * fmod(float(i) * 0.619, 1.0))
				var dir = Vector2(cos(a), sin(a))
				var start = centre + dir * radius
				var end = start + dir * len
				draw_line(start, end, Color(0.78, 0.93, 1.0, 0.04 + line_t * 0.14), 1.0 + line_t)
		# Flow adds a restrained edge pulse rather than obscuring terrain.
		if flow_tier > 0 and flow_intensity > 0.0:
			var alpha = 0.018 * float(flow_tier) * flow_intensity
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.88, 1.0, alpha), false, 3.0 + float(flow_tier))
		if landing_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.96, 1.0, landing_flash * 0.07), true)
		if bonk_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.16, 0.24, bonk_flash * 0.15), true)
		if finish_flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.95, 0.76, finish_flash * 0.18), true)
