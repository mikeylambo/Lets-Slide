class_name TutorialCoach
extends Control

## Guided first descent on Course 01. One prompt at a time, each cleared by
## actually doing it, phrased for whichever device the player last touched.
## Never blocks the run and never repeats once the tutorial is finished.

const STEPS = [
	{"id": "steer", "text": "STEER", "key": "A  /  D", "pad": "LEFT STICK"},
	{"id": "tuck", "text": "TUCK ON STRAIGHTS FOR SPEED", "key": "HOLD SHIFT", "pad": "HOLD X / SQUARE"},
	{"id": "crest", "text": "LEAN BACK AS THE GROUND FALLS AWAY", "key": "HOLD S", "pad": "STICK DOWN"},
	{"id": "land", "text": "LAND FLAT TO KEEP YOUR SPEED", "key": "", "pad": ""},
	{"id": "retry", "text": "RETRY ANY TIME. IT'S INSTANT.", "key": "R", "pad": "Y / TRIANGLE"},
]

var slider: SlideBody
var run: RunController
var builder: TrackBuilder
var step = 0
var _held = 0.0
var _pad = false
var _timer = 0.0
var _crest_from = INF
var _idx = 0
var _card: PanelContainer
var _title: Label
var _glyph: Label

static func wanted(course: CourseData) -> bool:
	return course.id == "course_01" and bool(Game.settings.get("tutorial_hints", true)) and not bool(Game.profile.get("tutorial_done", false))

func setup(player: SlideBody, controller: RunController, b: TrackBuilder) -> void:
	slider = player; run = controller; builder = b
	for r in b.segment_ranges:
		if str(r["kind"]) == "crest": _crest_from = float(r["from"]); break
	slider.took_off.connect(func(_s): if _current() == "crest": _advance())
	slider.landed.connect(func(_q, _s): if _current() == "land": _timer = 1.6)
	run.run_finished.connect(_on_finished)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Upper centre: the rider and the line ahead stay unobstructed.
	var wrap = CenterContainer.new(); wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wrap.offset_top = 150; wrap.offset_bottom = 230; wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit._box(Color(0.03, 0.04, 0.06, 0.82), UiKit.LINE, 1, 18))
	wrap.add_child(_card)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 18); _card.add_child(row)
	_glyph = UiKit.mono("", UiKit.H3, UiKit.BG)
	_glyph.add_theme_stylebox_override("normal", UiKit._box(UiKit.LINE, UiKit.LINE, 0, 10))
	row.add_child(_glyph)
	_title = UiKit.label("", UiKit.H3, UiKit.TEXT)
	row.add_child(_title)
	_show()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion: _pad = true
	elif event is InputEventKey: _pad = false
	if event.is_action_pressed("retry") and _current() == "retry": _advance()

func _current() -> String:
	return STEPS[step]["id"] if step < STEPS.size() else ""

func _process(delta: float) -> void:
	if step >= STEPS.size() or run == null: return
	_show()
	if run.state != RunController.State.RUNNING: return
	match _current():
		"steer":
			_held += delta if absf(slider.input.steer) > 0.3 else 0.0
			if _held > 0.5: _advance()
		"tuck":
			_held += delta if slider.input.tuck else 0.0
			if _held > 0.8: _advance()
			elif _near_crest(): step = 2; _held = 0.0      # the crest outranks tuck
		"land":
			if _timer > 0.0:
				_timer -= delta
				if _timer <= 0.0: _advance()

func _near_crest() -> bool:
	if _crest_from == INF: return false
	var n = builder.samples.size()
	var best_d = INF
	for i in range(maxi(0, _idx - 20), mini(n, _idx + 40)):
		var d = slider.global_position.distance_squared_to(builder.samples[i]["pos"])
		if d < best_d: best_d = d; _idx = i
	return float(builder.samples[_idx]["dist"]) > _crest_from - 45.0

func _advance() -> void:
	step += 1; _held = 0.0
	_show()

func _show() -> void:
	if _card == null: return
	if step >= STEPS.size():
		_card.visible = false; return
	var s: Dictionary = STEPS[step]
	_card.visible = true
	_title.text = s["text"]
	var g = str(s["pad"] if _pad else s["key"])
	_glyph.text = g
	_glyph.visible = g != ""

func _on_finished(result: Dictionary) -> void:
	if bool(result.get("finished", false)):
		Game.profile["tutorial_done"] = true
		Game.save_profile()
		step = STEPS.size(); _show()
