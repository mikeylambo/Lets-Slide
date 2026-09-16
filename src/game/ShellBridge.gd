class_name ShellBridge
extends RefCounted

static func best_time(course_id:String)->float: return float(Game.record_for(course_id)["best_time"])
static func best_score(course_id:String)->int: return int(Game.record_for(course_id)["best_score"])
static func best_rank(course_id:String)->String: return str(Game.record_for(course_id)["best_rank"])
static func mastery(course_id:String)->int: return int(Game.record_for(course_id)["mastery"])
static func submit(course_id:String,result:Dictionary)->Dictionary: return Game.submit_result(course_id,result)
static func setting(key:String,fallback=null): return Game.settings.get(key,fallback)
static func set_setting(key:String,value)->void: Game.set_setting(key,value)

## Offline board now; replace these two methods with platform/SLU backend calls.
## The gameplay contract is already mode-pure: time boards receive time, score
## boards receive score, and Daily additionally preserves First Sight locally.
static func submit_leaderboard(course_id:String,result:Dictionary)->void:
	var path = "user://leaderboards.json"; var all = Game._read_json(path)
	var key = "%s:%d" % [course_id,Game.current_mode]
	if not all.has(key): all[key]=[]
	var rows:Array=all[key]; rows.append({"name":Game.profile.get("name","SLIDER"),"time":result.get("time",0.0),"score":result.get("score",0),"rank":result.get("rank",""),"stamp":Time.get_unix_time_from_system()})
	if Game.current_mode==Game.Mode.SCORE_ATTACK: rows.sort_custom(func(a,b): return int(a["score"])>int(b["score"]))
	else: rows.sort_custom(func(a,b): return float(a["time"])<float(b["time"]))
	while rows.size()>20: rows.pop_back()
	all[key]=rows; Game._write_json(path,all)
static func leaderboard(course_id:String)->Array:
	var all=Game._read_json("user://leaderboards.json"); return all.get("%s:%d"%[course_id,Game.current_mode],[])
