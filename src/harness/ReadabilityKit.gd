extends Node

## F2 Readability Kit — greybox-phase aids for reading speed and rhythm.
##   · world-space grid on every ribbon surface (hazards keep their colour)
##   · FOV kick scaled to speed, layered on top of the tuned camera
##   · screen-edge speed lines above a fraction of max_speed (default 70%)
##   · wind loop: band-passed noise whose pitch + level follow velocity
##   · optional 174 BPM click, bar-accented, phase-locked to run start (Tempo.gd)
## Presentation only: it never writes gameplay state.

const GRID_SHADER = preload("res://src/harness/greybox_grid.gdshader")
const MIX_RATE = 44100.0

var enabled = true
var click_enabled = false
var fov_kick_deg = 10.0
var speed_line_threshold = 0.70
var wind_volume = 0.8
var click_volume = 0.7

var scene: CourseScene
var _originals = {}          ## MeshInstance3D -> original material_override
var _grid_mat: ShaderMaterial
var _layer: CanvasLayer
var _lines: SpeedLines
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _rng = RandomNumberGenerator.new()
var _speed_t = 0.0
var _air = 0.0
var _wind_gain = 0.0
var _svf_low = 0.0
var _svf_band = 0.0
var _rumble = 0.0
var _gust_phase = 0.0
var _click_running = false
var _click_sample = 0        ## samples since the run's beat 0
var _click_env = 0.0
var _click_phase = 0.0
var _click_freq = 1320.0

func _ready() -> void:
	process_priority = 1000       # after SlideCamera writes its own FOV
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 174
	_grid_mat = ShaderMaterial.new()
	_grid_mat.shader = GRID_SHADER
	_layer = CanvasLayer.new()
	_layer.layer = 7
	add_child(_layer)
	_lines = SpeedLines.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_lines)
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.06
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback

func attach(s: CourseScene) -> void:
	scene = s
	_originals.clear()
	if enabled:
		_apply_grid(true)

func set_enabled(on: bool) -> void:
	enabled = on
	_apply_grid(on)
	if not on:
		_lines.intensity = 0.0
		_lines.queue_redraw()

func greyboxed_count() -> int:
	return _originals.size()

## Called when a run leaves its countdown: beat 0 == race time 0.
func on_run_started() -> void:
	_click_running = true
	_click_sample = 0

func on_run_stopped() -> void:
	_click_running = false

func fov_kick_for(speed_t: float) -> float:
	return fov_kick_deg * smoothstep(0.30, 1.0, clampf(speed_t, 0.0, 1.0))

func _apply_grid(on: bool) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var root: Node = scene._built.get("root")
	if root == null:
		return
	if on:
		for body in _ribbon_bodies(root):
			for c in body.get_children():
				if c is MeshInstance3D and not _originals.has(c):
					_originals[c] = c.material_override
					c.material_override = _grid_mat
	else:
		for mi in _originals.keys():
			if is_instance_valid(mi):
				mi.material_override = _originals[mi]
		_originals.clear()

static func _ribbon_bodies(root: Node) -> Array:
	var out = []
	var stack = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D and n.has_meta("surface_class") and not str(n.name).begins_with("Hazard"):
			out.append(n)
		stack.append_array(n.get_children())
	return out

func _process(delta: float) -> void:
	var live = scene != null and is_instance_valid(scene) and scene.slider != null
	var target_t = 0.0
	if live:
		var slider = scene.slider
		target_t = clampf(slider.state.speed / maxf(slider.params.max_speed, 1.0), 0.0, 1.0)
		_air = move_toward(_air, 0.0 if slider.state.grounded else 1.0, delta * 4.0)
	_speed_t = lerpf(_speed_t, target_t, clampf(delta * 8.0, 0.0, 1.0))
	if enabled and live and scene.camera:
		scene.camera.get_camera().fov += fov_kick_for(_speed_t)
	var line_t = 0.0
	if enabled and speed_line_threshold < 1.0:
		line_t = clampf((_speed_t - speed_line_threshold) / (1.0 - speed_line_threshold), 0.0, 1.0)
	_lines.intensity = line_t
	_lines.advance(delta, _speed_t)
	_fill_audio()

func _fill_audio() -> void:
	if _playback == null:
		return
	var frames = mini(_playback.get_frames_available(), 4096)
	if frames <= 0:
		return
	var sfx = float(Game.settings.get("master_volume", 0.9)) * float(Game.settings.get("sfx_volume", 0.95))
	var target_gain = (0.015 + 0.30 * pow(_speed_t, 1.6)) * (1.0 + 0.3 * _air) * wind_volume * sfx if enabled else 0.0
	var paused = get_tree().paused
	if paused:
		target_gain = 0.0
	var cutoff = 160.0 + 2600.0 * pow(_speed_t, 1.4) + 500.0 * _air
	var f = 2.0 * sin(PI * minf(cutoff, 8000.0) / MIX_RATE)
	var q = 0.9
	var beat_len = int(round(MIX_RATE * Tempo.beat_seconds()))
	var click_gain = click_volume * sfx
	var clicking = enabled and click_enabled and _click_running and not paused
	for i in frames:
		_wind_gain += (target_gain - _wind_gain) * 0.0004
		_gust_phase = fmod(_gust_phase + TAU * 0.23 / MIX_RATE, TAU)
		var noise = _rng.randf_range(-1.0, 1.0)
		# Chamberlin state-variable filter: band output = the "pitch" of the air.
		_svf_low += f * _svf_band
		var high = noise - _svf_low - q * _svf_band
		_svf_band += f * high
		_rumble += (noise - _rumble) * 0.02
		var gust = 0.82 + 0.18 * sin(_gust_phase)
		var wind = (_svf_band * 0.9 + _rumble * 1.6) * _wind_gain * gust
		var click = 0.0
		if clicking:
			if _click_sample % beat_len == 0:
				var beat_in_bar = (_click_sample / beat_len) % Tempo.BEATS_PER_BAR
				_click_freq = 1760.0 if beat_in_bar == 0 else 1175.0
				_click_env = 1.0 if beat_in_bar == 0 else 0.6
				_click_phase = 0.0
			_click_sample += 1
		if _click_env > 0.0005:
			_click_phase += TAU * _click_freq / MIX_RATE
			click = sin(_click_phase) * _click_env * 0.35 * click_gain
			_click_env *= 0.9985
		elif _click_env > 0.0:
			_click_env = 0.0
		var sample = clampf(wind + click, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))

func _exit_tree() -> void:
	_apply_grid(false)

## Radial streaks confined to the outer band of the screen, so the centre —
## where the terrain is read — stays clean.
class SpeedLines:
	extends Control
	const COUNT = 56
	var intensity = 0.0
	var _time = 0.0

	func advance(delta: float, speed_t: float) -> void:
		_time += delta * (0.6 + 1.8 * speed_t)
		if intensity > 0.0 or visible:
			queue_redraw()

	static func _h(x: float) -> float:
		return fposmod(sin(x) * 43758.5453, 1.0)

	func _draw() -> void:
		if intensity <= 0.0:
			return
		var size = get_viewport_rect().size
		var c = size * 0.5
		var radius = c.length()
		for i in COUNT:
			var s = float(i) * 12.9898
			var a = TAU * _h(s)
			var rate = 0.7 + 0.9 * _h(s * 1.7)
			var phase = fposmod(_time * rate + _h(s * 3.1), 1.0)
			var r0 = radius * (0.58 + 0.42 * phase)
			var length = radius * (0.05 + 0.20 * intensity) * (0.4 + phase)
			var dir = Vector2(cos(a), sin(a))
			var alpha = intensity * 0.5 * sin(phase * PI) * (0.5 + 0.5 * _h(s * 5.3))
			draw_line(c + dir * r0, c + dir * (r0 + length), Color(0.93, 0.97, 1.0, alpha), 1.2 + 1.8 * intensity, true)
