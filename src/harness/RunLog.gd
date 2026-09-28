extends RefCounted

## One run's telemetry. Rows are buffered in memory and written once at run end
## so disk I/O never lands mid-run.
##
## <session>/run_NNN/telemetry.csv   one row per physics tick
## <session>/run_NNN/preset.json     exact preset used (start + end state)
## <session>/run_NNN/run.json        result, events, markers, rating

const HEADER = "t,x,y,z,speed,h_speed,v_speed,grounded,surface,slope_deg,dist,course_bar,beat_bar,steer,lean,tuck,brake,event,detail"

var number = 0
var preset = ""            ## real preset name
var variant = ""           ## "" = saved preset untouched, "~abcd" = tweaked params
var slot = "A"
var seen_as = "A"          ## label the tester saw (X/Y in blind mode)
var blind = false
var course_id = ""
var params_start: Dictionary = {}
var camera_start: Dictionary = {}
var params_end: Dictionary = {}
var started = false
var clock = 0.0
var mixed = false          ## preset swapped mid-run
var tweaked = false        ## params edited mid-run
var outcome = "open"       ## finished | failed | retry | rebuild | quit
var result: Dictionary = {}
var rating = 0
var events: Array = []
var markers: Array = []
var top_speed = 0.0
var pops = 0
var bonks = 0
var landings = 0
var landing_q_sum = 0.0
var started_at = ""
var dir = ""

var _rows = PackedStringArray()
var _speed_sum = 0.0
var _pending: Array = []

func key() -> String:
	return preset + variant

func sample(dt: float, body: SlideBody, loc: Dictionary) -> void:
	clock += dt
	var s = body.state
	var p = body.global_position
	top_speed = maxf(top_speed, s.speed)
	_speed_sum += s.speed
	var ev = ""
	var detail = ""
	if not _pending.is_empty():
		var kinds = PackedStringArray()
		var details = PackedStringArray()
		for e in _pending:
			kinds.append(str(e["kind"]))
			details.append(str(e["detail"]).replace(",", ";"))
		ev = "|".join(kinds)
		detail = "|".join(details)
		_pending.clear()
	var beat_bar = clock / (Tempo.beat_seconds() * float(Tempo.BEATS_PER_BAR))
	_rows.append("%.4f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%s,%.2f,%.2f,%.3f,%.3f,%.2f,%.2f,%d,%d,%s,%s" % [
		clock, p.x, p.y, p.z, s.speed, s.flat_speed(), s.velocity.y, 1 if s.grounded else 0,
		SurfaceKind.name_of(s.surface_class), s.slope_deg, float(loc.get("dist", 0.0)),
		float(loc.get("bar", 0.0)), beat_bar, body.input.steer, body.input.lean,
		1 if body.input.tuck else 0, 1 if body.input.brake else 0, ev, detail])

func event(kind: String, detail: String, extra: Dictionary = {}) -> void:
	var e = {"t": snappedf(clock, 0.0001), "kind": kind, "detail": detail}
	e.merge(extra)
	events.append(e)
	_pending.append(e)
	match kind:
		"pop": pops += 1
		"bonk": bonks += 1

func add_landing(quality: float) -> void:
	landings += 1
	landing_q_sum += quality

func has_content() -> bool:
	return not _rows.is_empty() or not markers.is_empty()

func row_count() -> int:
	return _rows.size()

func summary() -> Dictionary:
	return {
		"run": number, "preset": preset, "variant": variant, "key": key(), "slot": slot,
		"seen_as": seen_as, "blind": blind, "outcome": outcome,
		"time": float(result.get("time", clock)), "finished": outcome == "finished",
		"top_speed": top_speed, "avg_speed": _speed_sum / float(maxi(_rows.size(), 1)),
		"pops": pops, "bonks": bonks, "respawns": int(result.get("respawns", 0)),
		"landing_quality": landing_q_sum / float(landings) if landings > 0 else -1.0,
		"markers": markers.size(), "rating": rating, "mixed": mixed, "tweaked": tweaked,
		"started_at": started_at, "dir": dir,
	}

func write(session_dir: String) -> void:
	if dir == "":
		dir = session_dir.path_join("run_%03d" % number)
	DirAccess.make_dir_recursive_absolute(dir)
	if not _rows.is_empty() or not FileAccess.file_exists(dir.path_join("telemetry.csv")):
		var f = FileAccess.open(dir.path_join("telemetry.csv"), FileAccess.WRITE)
		if f:
			f.store_line(HEADER)
			f.store_string("\n".join(_rows))
			f.store_string("\n")
			f.close()
	_write_json(dir.path_join("preset.json"), {
		"name": preset, "variant": variant, "slot": slot, "motor": params_start,
		"camera": camera_start, "motor_at_end": params_end,
	})
	var clean_result = result.duplicate(true)
	clean_result.erase("grade_breakdown")
	_write_json(dir.path_join("run.json"), {
		"summary": summary(), "course": course_id, "result": clean_result,
		"events": events, "markers": markers,
	})

static func _write_json(path: String, data: Dictionary) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Harness: could not write %s" % path)
		return
	f.store_string(JSON.stringify(_jsonable(data), "\t", false))
	f.close()

static func _jsonable(v):
	if v is Vector3:
		return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
	if v is Dictionary:
		var out = {}
		for k in v.keys():
			out[str(k)] = _jsonable(v[k])
		return out
	if v is Array:
		var arr = []
		for x in v:
			arr.append(_jsonable(x))
		return arr
	return v
