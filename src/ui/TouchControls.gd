class_name TouchControls
extends Control

## One-thumb mobile control surface. Touches/drags on the lower field steer;
## vertical displacement is weight transfer. Tuck and Brake remain explicit.

var slider: SlideBody
var _touch_id = -1
var _origin = Vector2.ZERO
var _axis = Vector2.ZERO
var _tuck = false
var _brake = false

func bind(player: SlideBody) -> void:
	slider = player
	slider.external_input = Callable(self, "_feed_input")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tuck = Button.new()
	tuck.text = "TUCK"
	tuck.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tuck.position = Vector2(-220, -140)
	tuck.custom_minimum_size = Vector2(90, 90)
	tuck.button_down.connect(func(): _tuck = true)
	tuck.button_up.connect(func(): _tuck = false)
	add_child(tuck)
	var brake = Button.new()
	brake.text = "BRAKE"
	brake.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	brake.position = Vector2(-115, -140)
	brake.custom_minimum_size = Vector2(90, 90)
	brake.button_down.connect(func(): _brake = true)
	brake.button_up.connect(func(): _brake = false)
	add_child(brake)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.y > size.y * 0.38 and _touch_id < 0:
			_touch_id = event.index
			_origin = event.position
			_axis = Vector2.ZERO
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_axis = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_axis = (event.position - _origin) / Vector2(130.0, 110.0)
		_axis.x = clampf(_axis.x, -1.0, 1.0)
		_axis.y = clampf(_axis.y, -1.0, 1.0)

func _process(_delta: float) -> void:
	if _touch_id < 0 and bool(Game.settings.get("tilt_steering", false)):
		var accel = Input.get_accelerometer()
		var sensitivity = float(Game.settings.get("tilt_sensitivity", 0.18))
		_axis.x = clampf(-accel.x * sensitivity, -1.0, 1.0)

func _feed_input(inp: MotorInput, _body: SlideBody) -> void:
	inp.steer = _axis.x
	inp.lean = -_axis.y
	inp.tuck = _tuck
	inp.brake = _brake
