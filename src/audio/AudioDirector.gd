class_name AudioDirector
extends Node

## Procedural audio spine. This is intentionally asset-free so every course,
## including generated ones, already communicates speed, surface and Flow. The
## final original OST can replace/augment the same tier hooks without changing
## gameplay code.

var slider: SlideBody
var flow: FlowSystem
var _player: AudioStreamPlayer
var _gen: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _phase = 0.0
var _flow_phase = 0.0
var _duck = 1.0
var _rng = RandomNumberGenerator.new()
var _tier = 0
var _region = 0

func setup(player: SlideBody, flow_system: FlowSystem, region_index: int = 0) -> void:
	slider = player
	flow = flow_system
	_region = clampi(region_index, 0, 4)
	flow.tier_changed.connect(func(t): _tier = int(t))
	flow.flow_broken.connect(func(_reason): _duck = minf(_duck, 0.18))
	slider.bonked.connect(func(_s): _duck = 0.05)

func _ready() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = 44100.0
	_gen.buffer_length = 0.18
	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	_player.volume_db = linear_to_db(float(Game.settings.get("master_volume", 0.9)))
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_rng.seed = 9137

func _process(delta: float) -> void:
	_duck = lerpf(_duck, 1.0, clampf(delta * 5.0, 0.0, 1.0))
	if _playback == null or slider == null: return
	var frames = mini(_playback.get_frames_available(), 2048)
	var speed_t = clampf(slider.state.speed / maxf(slider.params.max_speed, 1.0), 0.0, 1.0)
	var surface = slider.state.surface_class
	var surface_tone = 90.0 + float(surface) * 18.0 + speed_t * 170.0
	var flow_freq = 146.0 + float(_region) * 21.0 + float(_tier) * 72.0
	var wind_amp = 0.015 + speed_t * 0.055
	var surface_amp = (0.018 + speed_t * 0.035) * (1.4 if slider.state.grounded else 0.25)
	var flow_amp = float(_tier) * 0.012
	for i in range(frames):
		_phase = fmod(_phase + TAU * surface_tone / _gen.mix_rate, TAU)
		_flow_phase = fmod(_flow_phase + TAU * flow_freq / _gen.mix_rate, TAU)
		var noise = _rng.randf_range(-1.0, 1.0)
		var sample = (noise * wind_amp + sin(_phase) * surface_amp + sin(_flow_phase) * flow_amp) * _duck
		_playback.push_frame(Vector2(sample, sample))
