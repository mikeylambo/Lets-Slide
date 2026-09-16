extends Node

signal records_changed(course_id: String)
signal settings_changed()
signal mode_changed(mode: int)
signal progression_changed()

const PROFILE_PATH = "user://profile.json"
const PRESET_PATH = "user://presets.json"

enum Mode { CAMPAIGN, TIME_TRIAL, SCORE_ATTACK, SURVIVAL, DAILY, ENDLESS }

var current_mode: int = Mode.CAMPAIGN
var profile = {
	"name": "SLIDER",
	"total_runs": 0,
	"total_distance": 0.0,
	"records": {},
	"daily": {},
	"cosmetics": {"equipped": "core", "unlocked": ["core"]},
	"prestige": 0,
}
var settings = {
	"master_volume": 0.9,
	"music_volume": 0.85,
	"sfx_volume": 0.95,
	"camera_shake": 1.0,
	"speed_effects": 1.0,
	"flow_effects": 1.0,
	"ghost_opacity": 0.28,
	"fov_scale": 1.0,
	"show_ghost": true,
	"show_telemetry": false,
	"invert_steer": false,
	"units_metric": true,
	"touch_controls": false,
	"tilt_steering": false,
	"tilt_sensitivity": 0.18,
}
var presets = {}
var pending_course: CourseData
var last_result = {}
var survival_lives = 3
var survival_course_index = 0
var endless_prestige = 0

func _ready() -> void:
	load_all()

func set_mode(mode: int) -> void:
	current_mode = mode
	if mode == Mode.SURVIVAL:
		survival_lives = 3
		survival_course_index = 0
	if mode == Mode.ENDLESS:
		endless_prestige = 0
	mode_changed.emit(mode)

func mode_name(mode: int = -1) -> String:
	var m = current_mode if mode < 0 else mode
	match m:
		Mode.CAMPAIGN: return "CAMPAIGN"
		Mode.TIME_TRIAL: return "TIME TRIAL"
		Mode.SCORE_ATTACK: return "SCORE ATTACK"
		Mode.SURVIVAL: return "SURVIVAL"
		Mode.DAILY: return "DAILY DESCENT"
		Mode.ENDLESS: return "ENDLESS"
	return "PLAY"

# ------------------------------------------------------------------ records
func record_for(course_id: String) -> Dictionary:
	if not profile["records"].has(course_id):
		profile["records"][course_id] = {
			"best_time": 0.0, "best_score": 0, "best_rank": "", "best_medal": "",
			"pickups": 0, "mastery": 0, "runs": 0, "finished": 0,
			"best_flow": 0.0,
		}
	var rec: Dictionary = profile["records"][course_id]
	if not rec.has("best_flow"): rec["best_flow"] = 0.0
	return rec

func submit_result(course_id: String, result: Dictionary) -> Dictionary:
	var rec = record_for(course_id)
	var beaten = {"time": false, "score": false, "rank": false, "pickups": false, "mastery": false, "flow": false}
	rec["runs"] = int(rec["runs"]) + 1
	if bool(result.get("finished", false)):
		rec["finished"] = int(rec["finished"]) + 1
		var t = float(result.get("time", 0.0))
		if t > 0.0 and (float(rec["best_time"]) <= 0.0 or t < float(rec["best_time"])):
			rec["best_time"] = t
			rec["best_medal"] = str(result.get("medal", ""))
			beaten["time"] = true
		var sc = int(result.get("score", 0))
		if sc > int(rec["best_score"]): rec["best_score"] = sc; beaten["score"] = true
		var pk = int(result.get("pickups", 0))
		if pk > int(rec["pickups"]): rec["pickups"] = pk; beaten["pickups"] = true
		var ms = int(result.get("mastery", 0))
		if ms > int(rec["mastery"]): rec["mastery"] = ms; beaten["mastery"] = true
		var flow = float(result.get("max_flow", 0.0))
		if flow > float(rec["best_flow"]): rec["best_flow"] = flow; beaten["flow"] = true
		var rank = str(result.get("rank", ""))
		if rank != "" and Rank.is_better(rank, str(rec["best_rank"])):
			rec["best_rank"] = rank
			beaten["rank"] = true

	profile["total_runs"] = int(profile["total_runs"]) + 1
	profile["total_distance"] = float(profile["total_distance"]) + float(result.get("distance", 0.0))
	last_result = result
	_update_daily(result)
	_update_cosmetics()
	save_profile()
	records_changed.emit(course_id)
	progression_changed.emit()
	return beaten

func medal_total() -> int:
	var total = 0
	for c in Courses.all():
		var rec = record_for(c.id)
		if str(rec.get("best_medal", "")) != "": total += 1
	return total

func medal_points() -> int:
	var total = 0
	for c in Courses.all():
		match str(record_for(c.id).get("best_medal", "")):
			"BRONZE": total += 1
			"SILVER": total += 2
			"GOLD": total += 3
			"AUTHOR": total += 4
	return total

func course_unlocked(course: CourseData) -> bool:
	return medal_total() >= course.unlock_medals

func region_unlocked(region_index: int) -> bool:
	if region_index < 0 or region_index >= CourseCatalog.REGIONS.size(): return false
	return medal_total() >= int(CourseCatalog.REGIONS[region_index]["gate"])

func daily_key() -> String:
	var d = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func daily_record() -> Dictionary:
	var key = daily_key()
	if not profile["daily"].has(key):
		profile["daily"][key] = {"first_sight": 0.0, "best_time": 0.0, "best_score": 0, "attempts": 0}
	return profile["daily"][key]

func _update_daily(result: Dictionary) -> void:
	if current_mode != Mode.DAILY or not bool(result.get("finished", false)): return
	var rec = daily_record()
	rec["attempts"] = int(rec["attempts"]) + 1
	var t = float(result.get("time", 0.0))
	if float(rec["first_sight"]) <= 0.0: rec["first_sight"] = t
	if float(rec["best_time"]) <= 0.0 or t < float(rec["best_time"]): rec["best_time"] = t
	rec["best_score"] = maxi(int(rec["best_score"]), int(result.get("score", 0)))

func _update_cosmetics() -> void:
	var unlocked: Array = profile["cosmetics"].get("unlocked", ["core"])
	var medals = medal_total()
	for pair in [[5, "prism"], [10, "afterimage"], [15, "voidglass"], [20, "invert_core"], [25, "author_white"]]:
		if medals >= int(pair[0]) and pair[1] not in unlocked: unlocked.append(pair[1])
	profile["cosmetics"]["unlocked"] = unlocked


func cosmetic_palette(name: String = "") -> Dictionary:
	var chosen = name if name != "" else str(profile.get("cosmetics",{}).get("equipped","core"))
	match chosen:
		"prism": return {"board":Color(0.42,0.78,1.0),"core":Color(1.0,0.58,0.25)}
		"afterimage": return {"board":Color(0.25,1.0,0.78),"core":Color(0.72,0.38,1.0)}
		"voidglass": return {"board":Color(0.40,0.46,0.62),"core":Color(0.78,0.18,0.55)}
		"invert_core": return {"board":Color(1.0,0.92,0.68),"core":Color(0.18,0.08,0.18)}
		"author_white": return {"board":Color(0.96,0.98,1.0),"core":Color(0.72,0.58,1.0)}
	return {"board":Color(0.22,0.95,1.0),"core":Color(0.98,0.35,0.85)}

func equip_cosmetic(name: String) -> void:
	var unlocked:Array = profile.get("cosmetics",{}).get("unlocked",["core"])
	if name not in unlocked: return
	profile["cosmetics"]["equipped"] = name
	save_profile()

# ------------------------------------------------------------------ presets
func save_preset(preset_name: String, motor: MotorParams, camera: CameraParams) -> void:
	presets[preset_name] = {"motor": motor.to_dict(), "camera": camera.to_dict()}
	save_presets()

func load_preset(preset_name: String, motor: MotorParams, camera: CameraParams) -> bool:
	if not presets.has(preset_name): return false
	var p: Dictionary = presets[preset_name]
	if p.has("motor"): motor.from_dict(p["motor"])
	if p.has("camera"): camera.from_dict(p["camera"])
	return true

func delete_preset(preset_name: String) -> void:
	presets.erase(preset_name); save_presets()

func preset_names() -> Array:
	var keys = presets.keys(); keys.sort(); return keys

# ----------------------------------------------------------------- storage
func load_all() -> void:
	var p = _read_json(PROFILE_PATH)
	if p.has("records"):
		for k in p.keys(): profile[k] = p[k]
	if p.has("settings"):
		for k in p["settings"]: settings[k] = p["settings"][k]
	if not profile.has("daily"): profile["daily"] = {}
	if not profile.has("cosmetics"): profile["cosmetics"] = {"equipped": "core", "unlocked": ["core"]}
	presets = _read_json(PRESET_PATH)
	if presets.is_empty(): presets = _factory_presets(); save_presets()

func save_profile() -> void:
	var out = profile.duplicate(true); out["settings"] = settings; _write_json(PROFILE_PATH, out)
func save_presets() -> void: _write_json(PRESET_PATH, presets)
func set_setting(key: String, value) -> void:
	settings[key] = value; save_profile(); settings_changed.emit()

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var parsed = JSON.parse_string(f.get_as_text()); f.close()
	return parsed if parsed is Dictionary else {}

static func _write_json(path: String, data: Dictionary) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null: push_warning("Could not write %s" % path); return
	f.store_string(JSON.stringify(data, "\t")); f.close()

func _factory_presets() -> Dictionary:
	var base = MotorParams.new(); var cam = CameraParams.new(); var out = {}
	out["Current Candidate"] = {"motor": base.to_dict(), "camera": cam.to_dict()}
	var arcade = base.duplicate_params(); arcade.steering_strength = 175.0; arcade.momentum_retention = 0.992; arcade.uphill_friction = 3.4; arcade.landing_retention = 0.97
	out["Arcade Clean"] = {"motor": arcade.to_dict(), "camera": cam.to_dict()}
	var heavy = base.duplicate_params(); heavy.steering_strength = 105.0; heavy.momentum_retention = 0.972; heavy.steering_speed_falloff = 0.82; heavy.drag_quadratic = 0.0022; heavy.max_speed = 78.0; heavy.landing_retention = 0.90
	out["Momentum Heavy"] = {"motor": heavy.to_dict(), "camera": cam.to_dict()}
	var grip = base.duplicate_params(); grip.carve_grip = 1.0; grip.steering_strength = 190.0; grip.momentum_retention = 0.978; grip.flat_friction = 2.4
	out["High Grip"] = {"motor": grip.to_dict(), "camera": cam.to_dict()}
	var loose = base.duplicate_params(); loose.carve_grip = 0.45; loose.steering_strength = 125.0; loose.momentum_retention = 0.995; loose.downhill_friction = 0.28; loose.air_steering = 105.0
	out["Loose / Drift"] = {"motor": loose.to_dict(), "camera": cam.to_dict()}
	var ref = base.duplicate_params(); ref.model = MotorParams.Model.SM64_REFERENCE; ref.reset_reference_constants()
	out["SM64 Reference"] = {"motor": ref.to_dict(), "camera": cam.to_dict()}
	return out
