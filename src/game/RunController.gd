class_name RunController
extends Node

signal state_changed(state: int)
signal score_changed(score: int, combo: int)
signal flow_changed(seconds: float, tier: int, multiplier: int)
signal checkpoint_reached(index: int)
signal run_finished(result: Dictionary)
signal respawned()
signal run_restarted(fast: bool)
signal badge_found(course_id: String, first_time: bool)
signal split_reached(index: int, time: float, delta_pb: float, gold: bool)

enum State { READY, COUNTDOWN, RUNNING, FINISHED, PAUSED }
const COUNTDOWN_TIME = 2.4
const STUCK_TIME = 2.6
const RESPAWN_SPEED = 13.0
const CHAIN_WINDOW = 2.0

var state: int = State.READY
## Tooling hooks. Gameplay leaves the defaults; the dev playtest harness uses
## them for sub-300 ms retries and sandboxed runs that never touch records.
var retry_countdown = 0.55
var record_results = true
var ghost_path = ""                  ## empty = the per-course PB ghost
var course: CourseData
var slider: SlideBody
var ghost: Ghost
var flow: FlowSystem
var time = 0.0                       ## race time: running physics ticks x tick length
var ticks = 0                        ## physics ticks since the start signal
var replay: Replay                   ## inputs of the current run (production model)
var watching = false                 ## true while a replay drives the rider
var splits: Array = []               ## race time at each checkpoint, then the finish (-1 = missed)
var pb_splits: Array = []            ## snapshot of the PB run's splits at begin()
var split_golds: Array = []          ## true where that segment beat the best segment
var best_segments: Array = []        ## best ever time for each checkpoint-to-checkpoint segment
var rival: SlideBody                 ## optional replay-driven rider racing alongside
var rival_replay: Replay
var _rival_event = 0
var _record_results_before = true
var _starting_replay = false
var score = 0
var combo = 0
var pickups_taken = 0
var mastery_taken = 0
var distance = 0.0
var bonks = 0
var respawns = 0
var _course_nodes = {}
var _countdown = 0.0
var _chain_timer = 0.0
var _momentum_sum = 0.0
var _momentum_samples = 0
var _stuck_timer = 0.0
var _last_checkpoint = -1
var _spawn_pos = Vector3.ZERO
var _spawn_yaw = 0.0
var _kill_y = -1000.0
var _top_speed = 0.0

func setup(course_data: CourseData, built: Dictionary, player: SlideBody, ghost_node: Ghost, flow_system: FlowSystem = null) -> void:
	course = course_data; slider = player; ghost = ghost_node; flow = flow_system; _course_nodes = built
	_spawn_pos = built["start_position"]; _spawn_yaw = built["start_yaw"]; _kill_y = float(built.get("kill_y",-1000.0))
	course.pickup_count = built["pickups"].size() - (1 if built.get("badge") else 0); slider.set_spawn(_spawn_pos,_spawn_yaw)
	slider.input_tap = _on_input_tick
	slider.bonked.connect(func(_s): bonks += 1)
	for p in built["pickups"]: p.collected.connect(_on_pickup)
	for cp in built["checkpoints"]: cp.triggered.connect(_on_checkpoint)
	built["finish"].triggered.connect(_on_finish)
	if flow:
		flow.flow_changed.connect(func(v,t,m): flow_changed.emit(v,t,m))
	begin(false)

func begin(fast: bool = false) -> void:
	if watching and not _starting_replay: stop_replay()   # retry takes control back
	time=0.0; ticks=0; score=0; combo=0; pickups_taken=0; mastery_taken=0; distance=0.0; bonks=0; respawns=0; _top_speed=0.0
	_momentum_sum=0.0; _momentum_samples=0; _stuck_timer=0.0; _chain_timer=0.0; _last_checkpoint=-1; _countdown=retry_countdown if fast else COUNTDOWN_TIME
	for p in _course_nodes["pickups"]: p.restore()
	for cp in _course_nodes["checkpoints"]: cp.reset()
	_course_nodes["finish"].reset()
	slider.respawn(_spawn_pos,_spawn_yaw); slider.control_enabled=false
	# Riders hold still until GO, so every run (and every replay of it) starts
	# from the identical state no matter how long the countdown was.
	slider.set_physics_process(false)
	splits.clear(); splits.resize(_course_nodes["checkpoints"].size() + 1); splits.fill(-1.0)
	split_golds.clear(); split_golds.resize(splits.size()); split_golds.fill(false)
	var rec = Game.record_for(course.id)
	pb_splits = rec.get("splits", []).duplicate()
	best_segments = rec.get("best_segments", []).duplicate()
	_rival_event = 0
	if rival:
		rival.respawn(_spawn_pos,_spawn_yaw); rival.control_enabled=false; rival.set_physics_process(false)
		var cursor = [0]
		rival.external_input = func(inp: MotorInput, _b): rival_replay.read(cursor[0], inp); cursor[0] += 1
	if flow: flow.reset()
	replay = Replay.begin_for(course.id, slider.params)
	_set_state(State.COUNTDOWN); score_changed.emit(score,combo)
	if ghost:
		var loaded = ghost.load_path(ghost_path) if ghost_path != "" else ghost.load_from(course.id)
		if bool(Game.settings.get("show_ghost",true)) and loaded: ghost.start_playback()
		else: ghost.stop_playback()
	run_restarted.emit(fast)

func retry() -> void: begin(true)

func respawn_at_checkpoint() -> void:
	var cps: Array = _course_nodes["checkpoints"]
	var yaw = _spawn_yaw
	if _last_checkpoint >= 0 and _last_checkpoint < cps.size():
		var cp: TrackTrigger = cps[_last_checkpoint]; slider.respawn(cp.respawn_position,cp.respawn_yaw); yaw=cp.respawn_yaw
	else: slider.respawn(_spawn_pos,_spawn_yaw)
	slider.state.velocity = Vector3(sin(yaw),0.0,cos(yaw))*RESPAWN_SPEED
	if replay and state == State.RUNNING and not watching:
		var p = slider.global_position; var v = slider.state.velocity
		replay.respawns.append([ticks, p.x, p.y, p.z, yaw, v.x, v.y, v.z])
	combo=0; _stuck_timer=0.0; respawns += 1
	if flow: flow.break_flow("RESPAWN")
	score_changed.emit(score,combo); respawned.emit()

func pause_run() -> void:
	if state in [State.RUNNING,State.COUNTDOWN]: _set_state(State.PAUSED); slider.control_enabled=false
func resume_run() -> void:
	if state==State.PAUSED: _set_state(State.RUNNING); slider.control_enabled=true; slider.set_physics_process(true)

## Races a recorded run: the rival re-simulates the replay live through the
## real motor, alongside the player, without ever touching the player.
func setup_rival(body: SlideBody, r: Replay) -> void:
	rival = body; rival_replay = r
	rival.is_player = false
	rival.set_spawn(_spawn_pos, _spawn_yaw)
	begin(false)

## Replays the recorded run's respawns on the same tick they happened. The
## rival is added to the tree before this controller, so its step for this
## tick has already run, exactly as the player's had when it was recorded.
func _apply_rival_respawns() -> void:
	if rival == null: return
	var ev: Array = rival_replay.respawns
	while _rival_event < ev.size() and int(ev[_rival_event][0]) <= ticks:
		var e: Array = ev[_rival_event]
		if int(e[0]) == ticks:
			rival.respawn(Vector3(e[1], e[2], e[3]), float(e[4]))
			rival.state.velocity = Vector3(e[5], e[6], e[7])
		_rival_event += 1

func rival_time() -> float:
	return rival_replay.time_seconds() if rival_replay else 0.0

## The race clock is the physics clock. Counting ticks (not frames) makes a
## time identical on every machine and frame rate, and makes runs replayable:
## the start signal, every input and the finish all land on exact ticks.
func _physics_process(_delta: float) -> void:
	var step = 1.0 / float(Engine.physics_ticks_per_second)   # immune to time_scale
	match state:
		State.COUNTDOWN:
			_countdown -= step
			if _countdown <= 0.000001:
				slider.set_physics_process(true); slider.control_enabled=true
				if rival: rival.set_physics_process(true); rival.control_enabled=true
				_set_state(State.RUNNING)
				if ghost: ghost.start_recording()
		State.RUNNING: _tick_running(step)

func _process(delta: float) -> void:
	# The ghost runs on race time, not countdown time, or it leaves early.
	if ghost and ghost.playing and state == State.RUNNING: ghost.advance(delta)

## SlideBody reports the exact input packet each tick it had control.
func _on_input_tick(inp: MotorInput) -> void:
	if state == State.RUNNING and replay: replay.push(inp)

## Re-runs a recorded replay through the real motor. Returns false when the
## replay belongs to another course.
func play_replay(r: Replay) -> bool:
	if r == null or r.course_id != course.id: return false
	var cursor = [0]
	slider.params.from_dict(r.params)
	slider.external_input = func(inp: MotorInput, _body): r.read(cursor[0], inp); cursor[0] += 1
	if not watching: _record_results_before = record_results
	watching = true
	record_results = false             # watching a run never touches records
	_starting_replay = true
	begin(false)
	_starting_replay = false
	return true

func stop_replay() -> void:
	slider.external_input = Callable()
	if watching:
		watching = false
		record_results = _record_results_before

func _tick_running(delta: float) -> void:
	ticks += 1
	time = float(ticks) * delta
	_apply_rival_respawns()
	var s = slider.state; distance += s.speed*delta; _top_speed=maxf(_top_speed,s.speed)
	_momentum_sum += clampf(s.speed/maxf(slider.params.max_speed,1.0),0.0,1.0); _momentum_samples += 1
	if _chain_timer > 0.0:
		_chain_timer -= delta
		if _chain_timer <= 0.0 and combo > 0: combo=0; score_changed.emit(score,combo)
	if ghost: ghost.record(delta,slider.global_position,s.facing_yaw)
	if slider.global_position.y < _kill_y: respawn_at_checkpoint(); return
	if s.grounded and s.speed < 1.5:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIME: respawn_at_checkpoint()
	else: _stuck_timer=0.0

func countdown_value() -> int: return int(ceil(_countdown))

func checkpoint_position(index: int) -> Vector3:
	var cps: Array = _course_nodes.get("checkpoints", [])
	if index < 0 or index >= cps.size(): return Vector3.INF
	var cp: TrackTrigger = cps[index]
	return cp.global_position

func _on_pickup(p: Pickup) -> void:
	if state != State.RUNNING: p.restore(); return
	if p.kind == Pickup.Kind.BADGE:
		var first = record_results and Game.collect_badge(course.id)
		badge_found.emit(course.id, first)
		return
	pickups_taken += 1
	if p.kind == Pickup.Kind.MASTERY: mastery_taken += 1
	if p.kind == Pickup.Kind.CHAIN: combo += 1; _chain_timer=CHAIN_WINDOW
	var flow_mul = flow.multiplier() if flow else 1
	score += p.value * maxi(1,combo) * flow_mul
	score_changed.emit(score,combo)

func _on_checkpoint(t: TrackTrigger) -> void:
	if state != State.RUNNING: return
	_last_checkpoint=maxi(_last_checkpoint,t.index); checkpoint_reached.emit(t.index)
	_record_split(t.index)

func _record_split(index: int) -> void:
	if index < 0 or index >= splits.size() or float(splits[index]) >= 0.0: return
	splits[index] = time
	var delta = INF
	if index < pb_splits.size() and float(pb_splits[index]) > 0.0: delta = time - float(pb_splits[index])
	var seg = segment_time(splits, index)
	var gold = seg > 0.0 and (index >= best_segments.size() or float(best_segments[index]) <= 0.0 or seg < float(best_segments[index]))
	split_golds[index] = gold
	split_reached.emit(index, time, delta, gold)

## Time spent between split index-1 and index; -1 if either end was missed.
static func segment_time(s: Array, index: int) -> float:
	if index >= s.size() or float(s[index]) < 0.0: return -1.0
	if index == 0: return float(s[0])
	return float(s[index]) - float(s[index - 1]) if float(s[index - 1]) >= 0.0 else -1.0

## Sum of best: the theoretical PB if every best segment were chained.
static func sum_of_best(segments: Array) -> float:
	var total = 0.0
	for v in segments:
		if float(v) <= 0.0: return 0.0
		total += float(v)
	return total

func _on_finish(_t: TrackTrigger) -> void:
	if state != State.RUNNING: return
	finish_run(true,"")

func fail(reason: String) -> void:
	if state == State.FINISHED: return
	finish_run(false,reason)

func finish_run(finished: bool, fail_reason: String = "") -> void:
	_set_state(State.FINISHED); slider.control_enabled=false
	if finished: _record_split(splits.size() - 1)
	if replay:
		replay.finish(ticks, finished, Engine.physics_ticks_per_second)
		replay.splits = splits.duplicate()
	if ghost: ghost.stop_recording()
	var avg_momentum = 0.0 if _momentum_samples==0 else _momentum_sum/float(_momentum_samples)
	avg_momentum=clampf(avg_momentum-0.03*float(bonks),0.0,1.0)
	var result = {
		"finished":finished,"fail_reason":fail_reason,"course_id":course.id,"time":time,"score":score,
		"pickups":pickups_taken,"mastery":mastery_taken,"distance":distance,"top_speed":_top_speed,
		"avg_momentum":avg_momentum,"bonks":bonks,"respawns":respawns,
		"medal":course.medal_for(time) if finished else "","total_pickups":course.pickup_count,
		"max_flow":flow.max_seconds if flow else 0.0,"flow_tier":flow.max_tier if flow else 0,
		"flow_seconds":flow.total_flow_seconds if flow else 0.0,"mode":Game.current_mode,"primary_metric":_primary_metric(),
		"splits":splits.duplicate(),"pb_splits":pb_splits.duplicate(),"split_golds":split_golds.duplicate(),"rival_time":rival_time(),
	}
	if Game.current_mode == Game.Mode.CAMPAIGN and finished:
		var graded = Rank.evaluate(course, result)
		result["rank"] = graded["rank"]
		result["grade_breakdown"] = graded
	else:
		# Competitive modes keep their metric pure. Campaign owns the composite
		# mastery grade; Time Trial/Daily are time, Score Attack is score.
		result["rank"] = ""
		result["grade_breakdown"] = {}
	result["watched"] = watching
	if replay and replay.valid() and not watching: result["replay"] = replay
	if not record_results:
		result["previous_best"] = 0.0
		result["beaten"] = {}
		run_finished.emit(result)
		return
	var previous_best = float(Game.record_for(course.id)["best_time"])
	result["previous_best"] = previous_best
	var beaten = Game.submit_result(course.id, result)
	result["beaten"] = beaten
	if ghost and finished and beaten.get("time", false):
		ghost.save(course.id)
		if replay and replay.valid(): replay.save(Replay.pb_path(course.id))
	if finished:
		ShellBridge.submit_leaderboard(course.id, result)
	run_finished.emit(result)

func _primary_metric() -> String:
	match Game.current_mode:
		Game.Mode.SCORE_ATTACK: return "score"
		Game.Mode.ENDLESS: return "prestige"
		_: return "time"

func _set_state(s: int) -> void: state=s; state_changed.emit(s)

static func format_time(t: float) -> String:
	if t <= 0.0: return "--:--.---"
	var m = int(t/60.0); var sec = t-float(m)*60.0
	return "%02d:%06.3f" % [m,sec]
