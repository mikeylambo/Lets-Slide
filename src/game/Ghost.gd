class_name Ghost
extends Node3D

## Records and replays a run. Deliberately built before it is strictly needed:
## a ghost is the cheapest way to make a time trial legible, and retrofitting
## one after the run loop exists is always uglier than shipping it inside it.
##
## Storage is a flat binary blob (t, pos, yaw) at a fixed rate — small enough to
## keep every course's PB in user:// without thinking about it.

const RATE = 20.0                  ## samples per second
const MAGIC = 0x534C4447           ## "SLDG"
const VERSION = 1

var recording = false
var playing = false
var duration = 0.0

var _frames: Array = []             ## [time, x, y, z, yaw]
var _accum = 0.0
var _time = 0.0
var _mesh: MeshInstance3D
var _material: StandardMaterial3D

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var cap = CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.2
	_mesh.mesh = cap
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.6, 0.85, 1.0, 0.28)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.mesh = cap
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false

# ---------------------------------------------------------------- recording
func start_recording() -> void:
	_frames.clear()
	_accum = 0.0
	_time = 0.0
	recording = true

func record(delta: float, pos: Vector3, yaw: float) -> void:
	if not recording:
		return
	_time += delta
	_accum += delta
	var step = 1.0 / RATE
	while _accum >= step:
		_accum -= step
		_frames.append([_time, pos.x, pos.y, pos.z, yaw])

func stop_recording() -> void:
	recording = false
	duration = _time

# ---------------------------------------------------------------- playback
func start_playback() -> void:
	if _frames.is_empty():
		visible = false
		return
	playing = true
	_time = 0.0
	visible = true

func stop_playback() -> void:
	playing = false
	visible = false

func advance(delta: float) -> void:
	if not playing or _frames.size() < 2:
		return
	_time += delta
	var last: Array = _frames[_frames.size() - 1]
	if _time >= float(last[0]):
		global_position = Vector3(last[1], last[2], last[3])
		return
	var idx: int = clampi(int(_time * RATE), 0, _frames.size() - 2)
	var a: Array = _frames[idx]
	var b: Array = _frames[idx + 1]
	var span: float = maxf(float(b[0]) - float(a[0]), 0.0001)
	var t: float = clampf((_time - float(a[0])) / span, 0.0, 1.0)
	global_position = Vector3(a[1], a[2], a[3]).lerp(Vector3(b[1], b[2], b[3]), t)
	rotation.y = lerp_angle(float(a[4]), float(b[4]), t)

func time_near_position(pos: Vector3) -> float:
	if _frames.is_empty(): return -1.0
	var best_t = -1.0
	var best_d = INF
	for fr in _frames:
		var p = Vector3(float(fr[1]), float(fr[2]), float(fr[3]))
		var d = p.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best_t = float(fr[0])
	return best_t

func has_data() -> bool:
	return _frames.size() > 1


func set_color(c: Color) -> void:
	if _material:
		_material.albedo_color = c

func load_author(builder: TrackBuilder, target_time: float) -> bool:
	_frames.clear()
	if builder == null or builder.samples.size() < 2 or target_time <= 0.0:
		return false
	var step = 1.0 / RATE
	var t = 0.0
	while t <= target_time:
		var d = builder.total_length * (t / target_time)
		var s = builder.sample_at(d)
		if not s.is_empty():
			var pos: Vector3 = s["pos"] + s["u"] * 0.72
			var yaw = atan2(s["f"].x, s["f"].z)
			_frames.append([t, pos.x, pos.y, pos.z, yaw])
		t += step
	duration = target_time
	return _frames.size() > 1

# ------------------------------------------------------------------- files
static func path_for(course_id: String) -> String:
	return "user://ghost_%s.dat" % course_id

func save(course_id: String) -> void:
	if _frames.size() < 2:
		return
	var f = FileAccess.open(path_for(course_id), FileAccess.WRITE)
	if f == null:
		return
	f.store_32(MAGIC)
	f.store_32(VERSION)
	f.store_float(duration)
	f.store_32(_frames.size())
	for fr in _frames:
		for v in fr:
			f.store_float(float(v))
	f.close()

func load_from(course_id: String) -> bool:
	_frames.clear()
	var path = path_for(course_id)
	if not FileAccess.file_exists(path):
		return false
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	if f.get_32() != MAGIC or f.get_32() != VERSION:
		f.close()
		return false
	duration = f.get_float()
	var count = f.get_32()
	for i in count:
		_frames.append([f.get_float(), f.get_float(), f.get_float(), f.get_float(), f.get_float()])
	f.close()
	return _frames.size() > 1
