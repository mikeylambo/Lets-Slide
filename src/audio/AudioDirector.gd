class_name AudioDirector
extends Node

## Procedural speed/surface audio plus an optional real-music stem harness.
## Drop region stems into:
##   res://content/audio/region_01/{bed,low,mid,high,invert}.ogg
## through region_05. Missing stems are allowed. If no music stems exist for a
## region, the original procedural Flow tone remains as a graceful fallback.

const STEM_NAMES = ["bed", "low", "mid", "high", "invert"]

var slider: SlideBody
var flow: FlowSystem
var _run: RunController
var _player: AudioStreamPlayer
var _gen: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _phase = 0.0
var _flow_phase = 0.0
var _duck = 1.0
var _rng = RandomNumberGenerator.new()
var _tier = 0
var _region = 0
var _stem_players: Array[AudioStreamPlayer] = []
var _has_music_stems = false

func setup(player: SlideBody, flow_system: FlowSystem, region_index: int = 0) -> void:
	slider = player
	flow = flow_system
	_region = clampi(region_index, 0, 4)
	flow.tier_changed.connect(func(t):
		_tier = int(t)
		_update_stem_levels()
	)
	flow.flow_broken.connect(func(_reason): _duck = minf(_duck, 0.18))
	slider.bonked.connect(func(_s): _duck = 0.05)
	_load_region_stems()

func bind_run(run_controller: RunController) -> void:
	_run = run_controller
	_run.state_changed.connect(_on_run_state_changed)
	_run.run_restarted.connect(func(_fast): _stop_stems())

func _ready() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = 44100.0
	_gen.buffer_length = 0.18
	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_rng.seed = 9137
	Game.settings_changed.connect(_apply_volumes)
	_apply_volumes()

func _process(delta: float) -> void:
	_duck = lerpf(_duck, 1.0, clampf(delta * 5.0, 0.0, 1.0))
	_update_stem_levels()
	if _playback == null or slider == null:
		return
	var frames = mini(_playback.get_frames_available(), 2048)
	var speed_t = clampf(slider.state.speed / maxf(slider.params.max_speed, 1.0), 0.0, 1.0)
	var surface = slider.state.surface_class
	var surface_tone = 90.0 + float(surface) * 18.0 + speed_t * 170.0
	var flow_freq = 146.0 + float(_region) * 21.0 + float(_tier) * 72.0
	var sfx_gain = float(Game.settings.get("master_volume", 0.9)) * float(Game.settings.get("sfx_volume", 0.95))
	var wind_amp = (0.015 + speed_t * 0.055) * sfx_gain
	var surface_amp = (0.018 + speed_t * 0.035) * (1.4 if slider.state.grounded else 0.25) * sfx_gain
	var flow_amp = 0.0 if _has_music_stems else float(_tier) * 0.012 * sfx_gain
	for i in range(frames):
		_phase = fmod(_phase + TAU * surface_tone / _gen.mix_rate, TAU)
		_flow_phase = fmod(_flow_phase + TAU * flow_freq / _gen.mix_rate, TAU)
		var noise = _rng.randf_range(-1.0, 1.0)
		var sample = (noise * wind_amp + sin(_phase) * surface_amp + sin(_flow_phase) * flow_amp) * _duck
		_playback.push_frame(Vector2(sample, sample))

func _load_region_stems() -> void:
	_clear_stems()
	var folder = "res://content/audio/region_%02d" % (_region + 1)
	for stem_name in STEM_NAMES:
		var path = "%s/%s.ogg" % [folder, stem_name]
		if not ResourceLoader.exists(path):
			continue
		var stream = load(path)
		if stream == null:
			continue
		var stem = AudioStreamPlayer.new()
		stem.name = "Stem_%s" % stem_name
		stem.stream = stream
		stem.volume_db = -80.0
		add_child(stem)
		stem.set_meta("stem_name", stem_name)
		_stem_players.append(stem)
	_has_music_stems = not _stem_players.is_empty()
	_update_stem_levels()

func _clear_stems() -> void:
	for stem in _stem_players:
		if is_instance_valid(stem):
			stem.stop()
			stem.queue_free()
	_stem_players.clear()
	_has_music_stems = false

func _on_run_state_changed(state: int) -> void:
	if state == RunController.State.RUNNING:
		_start_stems_synced()
	elif state in [RunController.State.FINISHED, RunController.State.PAUSED]:
		if state == RunController.State.PAUSED:
			for stem in _stem_players:
				stem.stream_paused = true
	else:
		for stem in _stem_players:
			stem.stream_paused = false

func _start_stems_synced() -> void:
	if not _has_music_stems:
		return
	for stem in _stem_players:
		stem.stream_paused = false
		stem.stop()
	# Starting all players in the same frame keeps the exported 174-BPM stems
	# phase-aligned. Each source file must begin at bar 1 / beat 1.
	for stem in _stem_players:
		stem.play(0.0)
	_update_stem_levels()

func _stop_stems() -> void:
	for stem in _stem_players:
		stem.stop()

func _update_stem_levels() -> void:
	if not _has_music_stems:
		return
	var master = float(Game.settings.get("master_volume", 0.9))
	var music = float(Game.settings.get("music_volume", 0.85))
	var base_gain = maxf(master * music * _duck, 0.0001)
	for stem in _stem_players:
		var name = str(stem.get_meta("stem_name", ""))
		var active = false
		match name:
			"bed": active = true
			"low": active = _tier >= 1
			"mid": active = _tier >= 2
			"high": active = _tier >= 3
			"invert": active = _tier >= 4
		stem.volume_db = linear_to_db(base_gain) if active else -80.0

func _apply_volumes() -> void:
	if _player:
		_player.volume_db = 0.0
	_update_stem_levels()
