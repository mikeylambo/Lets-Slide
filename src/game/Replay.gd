class_name Replay
extends RefCounted

## Deterministic input replay: the exact MotorInput packet for every tick the
## rider had control, plus the tuning it ran on. Feeding it back through the
## real motor on the same course reproduces the run tick-for-tick, which is
## what makes it useful as a PB file, a shareable duel, and (later) proof that
## a leaderboard time is real.
##
## 3 bytes per tick (steer i8, lean i8, flags), zstd-compressed on disk.
## A 60 s run is ~21 KB raw, typically 2–5 KB stored.

const MAGIC = "SLRP"
const VERSION = 1
const CODE_PREFIX = "SLRP1:"
const FLAG_TUCK = 1
const FLAG_BRAKE = 2
const FLAG_JUMP = 4

var course_id = ""
var params: Dictionary = {}
var hz = 120
var finish_ticks = -1                ## -1 = unfinished / aborted
var finished = false
var recorded_at = ""
var _bytes = PackedByteArray()

static func begin_for(course: String, motor: MotorParams) -> Replay:
	var r = Replay.new()
	r.course_id = course
	r.params = motor.to_dict()
	return r

static func quantize(v: float) -> float:
	return float(roundi(clampf(v, -1.0, 1.0) * 127.0)) / 127.0

func push(inp: MotorInput) -> void:
	var flags = (FLAG_TUCK if inp.tuck else 0) | (FLAG_BRAKE if inp.brake else 0) | (FLAG_JUMP if inp.jump_pressed else 0)
	_bytes.append(roundi(inp.steer * 127.0) & 0xff)
	_bytes.append(roundi(inp.lean * 127.0) & 0xff)
	_bytes.append(flags)

## Writes tick `i` into `inp`; past the end the input is neutral.
func read(i: int, inp: MotorInput) -> void:
	inp.clear()
	var o = i * 3
	if o + 2 >= _bytes.size():
		return
	inp.steer = float(_s8(_bytes[o])) / 127.0
	inp.lean = float(_s8(_bytes[o + 1])) / 127.0
	var f = _bytes[o + 2]
	inp.tuck = (f & FLAG_TUCK) != 0
	inp.brake = (f & FLAG_BRAKE) != 0
	inp.jump_pressed = (f & FLAG_JUMP) != 0

func tick_count() -> int:
	return _bytes.size() / 3

func finish(at_ticks: int, did_finish: bool, tick_rate: int) -> void:
	finish_ticks = at_ticks if did_finish else -1
	finished = did_finish
	hz = tick_rate
	recorded_at = Time.get_datetime_string_from_system(true, true)

func time_seconds() -> float:
	return float(finish_ticks) / float(hz) if finish_ticks > 0 else 0.0

## Only production-model finishes are replayable; the reference model runs on
## its own clock and is a dev tool.
func valid() -> bool:
	return finished and finish_ticks > 0 and int(params.get("model", 0)) == MotorParams.Model.PRODUCTION

# ------------------------------------------------------------ serialization
func to_bytes() -> PackedByteArray:
	var meta = {"v": VERSION, "course": course_id, "params": params, "hz": hz,
		"finish_ticks": finish_ticks, "finished": finished, "at": recorded_at}
	var raw = var_to_bytes({"meta": meta, "inputs": _bytes})
	var packed = raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out = MAGIC.to_ascii_buffer()
	var size = PackedByteArray(); size.resize(4); size.encode_u32(0, raw.size())
	out.append_array(size)
	out.append_array(packed)
	return out

static func from_bytes(data: PackedByteArray) -> Replay:
	if data.size() < 8 or data.slice(0, 4).get_string_from_ascii() != MAGIC:
		return null
	var raw_size = data.decode_u32(4)
	if raw_size <= 0 or raw_size > 16 * 1024 * 1024:
		return null
	var raw = data.slice(8).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return null
	var d = bytes_to_var(raw)     # plain data only: objects are never decoded
	if not (d is Dictionary) or not d.has("meta") or not (d.get("inputs") is PackedByteArray):
		return null
	var meta: Dictionary = d["meta"]
	if int(meta.get("v", 0)) != VERSION:
		return null
	var r = Replay.new()
	r.course_id = str(meta.get("course", ""))
	r.params = meta.get("params", {}) if meta.get("params") is Dictionary else {}
	r.hz = int(meta.get("hz", 120))
	r.finish_ticks = int(meta.get("finish_ticks", -1))
	r.finished = bool(meta.get("finished", false))
	r.recorded_at = str(meta.get("at", ""))
	r._bytes = d["inputs"]
	return r

## Text form for pasting into chat / Discord: "SLRP1:<base64>".
func to_code() -> String:
	return CODE_PREFIX + Marshalls.raw_to_base64(to_bytes())

static func from_code(code: String) -> Replay:
	var c = code.strip_edges()
	if not c.begins_with(CODE_PREFIX):
		return null
	return from_bytes(Marshalls.base64_to_raw(c.trim_prefix(CODE_PREFIX)))

static func pb_path(course: String) -> String:
	return "user://replays/%s.slrp" % course

func save(path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(to_bytes())
	f.close()
	return true

static func load_path(path: String) -> Replay:
	if not FileAccess.file_exists(path):
		return null
	return from_bytes(FileAccess.get_file_as_bytes(path))

static func _s8(b: int) -> int:
	return b - 256 if b > 127 else b
