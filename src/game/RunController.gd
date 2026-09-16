class_name RunController
extends Node

signal state_changed(state: int)
signal score_changed(score: int, combo: int)
signal flow_changed(seconds: float, tier: int, multiplier: int)
signal checkpoint_reached(index: int)
signal run_finished(result: Dictionary)
signal respawned()
signal run_restarted(fast: bool)

enum State { READY, COUNTDOWN, RUNNING, FINISHED, PAUSED }
const COUNTDOWN_TIME = 2.4
const STUCK_TIME = 2.6
const RESPAWN_SPEED = 13.0
const CHAIN_WINDOW = 2.0

var state: int = State.READY
var course: CourseData
var slider: SlideBody
var ghost: Ghost
var flow: FlowSystem
var time = 0.0
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
	course.pickup_count = built["pickups"].size(); slider.set_spawn(_spawn_pos,_spawn_yaw)
	slider.bonked.connect(func(_s): bonks += 1)
	for p in built["pickups"]: p.collected.connect(_on_pickup)
	for cp in built["checkpoints"]: cp.triggered.connect(_on_checkpoint)
	built["finish"].triggered.connect(_on_finish)
	if flow:
		flow.flow_changed.connect(func(v,t,m): flow_changed.emit(v,t,m))
	begin(false)

func begin(fast: bool = false) -> void:
	time=0.0; score=0; combo=0; pickups_taken=0; mastery_taken=0; distance=0.0; bonks=0; respawns=0; _top_speed=0.0
	_momentum_sum=0.0; _momentum_samples=0; _stuck_timer=0.0; _chain_timer=0.0; _last_checkpoint=-1; _countdown=0.55 if fast else COUNTDOWN_TIME
	for p in _course_nodes["pickups"]: p.restore()
	for cp in _course_nodes["checkpoints"]: cp.reset()
	_course_nodes["finish"].reset()
	slider.respawn(_spawn_pos,_spawn_yaw); slider.control_enabled=false
	if flow: flow.reset()
	_set_state(State.COUNTDOWN); score_changed.emit(score,combo)
	if ghost:
		if bool(Game.settings.get("show_ghost",true)) and ghost.load_from(course.id): ghost.start_playback()
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
	combo=0; _stuck_timer=0.0; respawns += 1
	if flow: flow.break_flow("RESPAWN")
	score_changed.emit(score,combo); respawned.emit()

func pause_run() -> void:
	if state in [State.RUNNING,State.COUNTDOWN]: _set_state(State.PAUSED); slider.control_enabled=false
func resume_run() -> void:
	if state==State.PAUSED: _set_state(State.RUNNING); slider.control_enabled=true

func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown -= delta
			if _countdown <= 0.0:
				slider.control_enabled=true; _set_state(State.RUNNING)
				if ghost: ghost.start_recording()
		State.RUNNING: _tick_running(delta)
	if ghost and ghost.playing: ghost.advance(delta)

func _tick_running(delta: float) -> void:
	time += delta
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
	pickups_taken += 1
	if p.kind == Pickup.Kind.MASTERY: mastery_taken += 1
	if p.kind == Pickup.Kind.CHAIN: combo += 1; _chain_timer=CHAIN_WINDOW
	var flow_mul = flow.multiplier() if flow else 1
	score += p.value * maxi(1,combo) * flow_mul
	score_changed.emit(score,combo)

func _on_checkpoint(t: TrackTrigger) -> void:
	if state != State.RUNNING: return
	_last_checkpoint=maxi(_last_checkpoint,t.index); checkpoint_reached.emit(t.index)

func _on_finish(_t: TrackTrigger) -> void:
	if state != State.RUNNING: return
	finish_run(true,"")

func fail(reason: String) -> void:
	if state == State.FINISHED: return
	finish_run(false,reason)

func finish_run(finished: bool, fail_reason: String = "") -> void:
	_set_state(State.FINISHED); slider.control_enabled=false
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
	var previous_best = float(Game.record_for(course.id)["best_time"])
	result["previous_best"] = previous_best
	var beaten = Game.submit_result(course.id, result)
	result["beaten"] = beaten
	if ghost and finished and beaten.get("time", false):
		ghost.save(course.id)
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
