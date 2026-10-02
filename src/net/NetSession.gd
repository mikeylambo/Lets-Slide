class_name NetSession
extends Node

## Online time-attack rounds. The host is authoritative for the lobby, the
## course, the round clock and the scoreboard; every rider simulates its own
## physics locally (riders pass through each other), so control is instant on
## any connection. Transport is a MultiplayerPeer: ENet today, and Steam's
## peer drops in behind the same API later.
##
## Trust model: clients may only send their own rider state, name and finish
## claims. Every claim is range-checked and every finish must carry a replay
## whose course and tick count match the claimed time.

signal lobby_changed()
signal round_started(course: CourseData, seconds: float)
signal round_ended(results: Array)
signal scoreboard_changed(rows: Array)
signal status(text: String)

const PROTOCOL = 1
const DEFAULT_PORT = 24680
const MAX_PLAYERS = 16
const STATE_HZ = 20.0
const COLORS = [Color(1.0, 0.55, 0.2), Color(0.45, 1.0, 0.55), Color(1.0, 0.9, 0.3), Color(0.6, 0.6, 1.0),
	Color(1.0, 0.45, 0.55), Color(0.4, 0.95, 1.0), Color(0.9, 0.6, 1.0), Color(0.8, 1.0, 0.4)]

var players = {}                      ## peer id -> {name, best, runs, color}
var round_active = false
var round_seconds = 180.0
var round_left = 0.0
var course: CourseData
var course_payload = ""               ## campaign id or SLCS1 community code
var drive_scene = true                ## false: protocol-only session (tests, bots)
var my_name = "SLIDER"

var _scene: CourseScene
var _remotes = {}                     ## peer id -> RemoteRider
var _send_accum = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the round clock never pauses

func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

func online() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

# ------------------------------------------------------------- connection
## ENet is created by name: browser builds of Godot ship without it, and a
## direct class reference would stop the whole script from loading there.
static func available() -> bool:
	return ClassDB.class_exists("ENetMultiplayerPeer")

func _new_peer() -> MultiplayerPeer:
	return ClassDB.instantiate("ENetMultiplayerPeer") if available() else null

func host(port: int = DEFAULT_PORT, name: String = "HOST") -> Error:
	var peer = _new_peer()
	if peer == null:
		status.emit("Online play needs the desktop build."); return ERR_UNAVAILABLE
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		status.emit("Could not host on port %d (is it in use?)" % port); return err
	_attach(peer)
	my_name = _clean_name(name)
	players = {1: _player(my_name, 0)}
	status.emit("Hosting on port %d" % port)
	lobby_changed.emit()
	return OK

func join(address: String, port: int = DEFAULT_PORT, name: String = "SLIDER") -> Error:
	var peer = _new_peer()
	if peer == null:
		status.emit("Online play needs the desktop build."); return ERR_UNAVAILABLE
	var err = peer.create_client(address, port)
	if err != OK:
		status.emit("Could not reach %s:%d" % [address, port]); return err
	_attach(peer)
	my_name = _clean_name(name)
	status.emit("Connecting to %s:%d…" % [address, port])
	return OK

func leave() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear(); round_active = false
	_clear_remotes()
	lobby_changed.emit()

func _attach(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(func(): status.emit("Connection failed."); leave())
		multiplayer.server_disconnected.connect(func(): status.emit("The host left."); leave())

func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, my_name)

func _on_peer_connected(_id: int) -> void:
	pass                                # clients announce themselves via _hello

func _on_peer_disconnected(id: int) -> void:
	if is_host() and players.has(id):
		players.erase(id)
		_broadcast_lobby()
	if _remotes.has(id):
		_remotes[id].queue_free(); _remotes.erase(id)

func _player(name: String, index: int) -> Dictionary:
	return {"name": name, "best": 0.0, "runs": 0, "color": index % COLORS.size()}

static func _clean_name(n: String) -> String:
	var out = ""
	for ch in n.strip_edges().to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch in [" ", "_", "-"]: out += ch
	out = out.substr(0, 16).strip_edges()
	return out if out != "" else "SLIDER"

# -------------------------------------------------------- client → host
@rpc("any_peer", "reliable")
func _hello(protocol: int, name: String) -> void:
	if not is_host(): return
	var id = multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_rejected.rpc_id(id, "Version mismatch: update the game to play together.")
		return
	if players.size() >= MAX_PLAYERS:
		_rejected.rpc_id(id, "That lobby is full."); return
	players[id] = _player(_clean_name(name), players.size())
	_broadcast_lobby()
	if round_active:
		_round_start.rpc_id(id, course_payload, round_left)

@rpc("any_peer", "unreliable_ordered")
func _rider_state(pos: Vector3, yaw: float, speed: float) -> void:
	if not is_host(): return
	var id = multiplayer.get_remote_sender_id()
	if not players.has(id) or not _sane(pos, yaw, speed): return
	_apply_state(id, pos, yaw, speed)
	for pid in players.keys():
		if pid != 1 and pid != id:
			_peer_state.rpc_id(pid, id, pos, yaw, speed)

@rpc("any_peer", "reliable")
func _finish_claim(time: float, replay_code: String) -> void:
	if not is_host(): return
	_accept_finish(multiplayer.get_remote_sender_id(), time, replay_code)

static func _sane(pos: Vector3, yaw: float, speed: float) -> bool:
	return pos.is_finite() and pos.length() < 100000.0 and is_finite(yaw) and is_finite(speed) and speed >= 0.0 and speed < 500.0

## A finish only counts when the attached replay is for this course and its
## tick count reproduces the claimed time exactly.
func verify_claim(time: float, replay_code: String) -> bool:
	if course == null or not is_finite(time) or time <= 0.0 or time > 3600.0: return false
	var r = Replay.from_code(replay_code)
	return r != null and r.valid() and r.course_id == course.id and absf(r.time_seconds() - time) < 0.0005

func _accept_finish(id: int, time: float, replay_code: String) -> bool:
	if not round_active or not players.has(id) or not verify_claim(time, replay_code): return false
	var p: Dictionary = players[id]
	p["runs"] = int(p["runs"]) + 1
	if float(p["best"]) <= 0.0 or time < float(p["best"]): p["best"] = time
	_push_scoreboard()
	return true

# -------------------------------------------------------- host → clients
@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	status.emit(reason); leave()

@rpc("authority", "reliable")
func _lobby(data: Dictionary) -> void:
	players = {}
	for k in data.keys(): players[int(k)] = data[k]
	lobby_changed.emit()

@rpc("authority", "unreliable_ordered")
func _peer_state(id: int, pos: Vector3, yaw: float, speed: float) -> void:
	if _sane(pos, yaw, speed): _apply_state(id, pos, yaw, speed)

@rpc("authority", "reliable")
func _round_start(payload: String, seconds: float) -> void:
	_begin_round(payload, seconds)

@rpc("authority", "reliable")
func _round_end(results: Array) -> void:
	round_active = false
	round_ended.emit(results)

@rpc("authority", "reliable")
func _scoreboard(rows: Array) -> void:
	scoreboard_changed.emit(rows)

@rpc("authority", "unreliable_ordered")
func _clock(left: float) -> void:
	round_left = left

func _broadcast_lobby() -> void:
	_lobby.rpc(players)
	lobby_changed.emit()

# ----------------------------------------------------------------- rounds
## Host only. `c` may be a campaign course or a community course; community
## courses travel as their share code so every peer builds identical geometry.
func start_round(c: CourseData, seconds: float = 180.0) -> void:
	if not is_host(): return
	var payload = c.id if not c.id.begins_with("c_") else CourseCodec.to_code(c)
	for p in players.values(): p["best"] = 0.0; p["runs"] = 0
	_round_start.rpc(payload, seconds)
	_begin_round(payload, seconds)

func _begin_round(payload: String, seconds: float) -> void:
	var c: CourseData = null
	if payload.begins_with(CourseCodec.CODE_PREFIX):
		var r = CourseCodec.from_code(payload)
		c = r.get("course")
	else:
		c = Courses.by_id(payload)
	if c == null:
		status.emit("Couldn't load the round's course."); return
	course = c; course_payload = payload
	round_seconds = clampf(seconds, 30.0, 1800.0); round_left = round_seconds
	round_active = true
	_clear_remotes()
	if drive_scene:
		Game.set_mode(Game.Mode.TIME_TRIAL)
		Main.instance.play_course(c)
	round_started.emit(c, round_seconds)

func end_round() -> void:
	if not is_host(): return
	round_active = false
	var rows = scoreboard_rows()
	_round_end.rpc(rows)
	round_ended.emit(rows)

func scoreboard_rows() -> Array:
	var rows = []
	for id in players.keys():
		var p: Dictionary = players[id]
		rows.append({"id": id, "name": p["name"], "best": float(p["best"]), "runs": int(p["runs"])})
	rows.sort_custom(func(a, b):
		if float(a["best"]) <= 0.0: return false
		if float(b["best"]) <= 0.0: return true
		return float(a["best"]) < float(b["best"]))
	return rows

func _push_scoreboard() -> void:
	var rows = scoreboard_rows()
	_scoreboard.rpc(rows)
	scoreboard_changed.emit(rows)

# ------------------------------------------------------- local rider glue
func _process(delta: float) -> void:
	if not round_active: return
	round_left = maxf(0.0, round_left - delta)
	if is_host() and round_left <= 0.0:
		end_round(); return
	if not drive_scene or not online(): return
	var current = Main.instance.current_world() if Main.instance else null
	if current != _scene and current is CourseScene: _adopt(current)
	if _scene == null or not is_instance_valid(_scene): return
	_send_accum += delta
	if _send_accum >= 1.0 / STATE_HZ:
		_send_accum = 0.0
		var s = _scene.slider
		send_state(s.global_position, s.state.facing_yaw, s.state.speed)
		if is_host(): _clock.rpc(round_left)

func send_state(pos: Vector3, yaw: float, speed: float) -> void:
	if is_host():
		for pid in players.keys():
			if pid != 1: _peer_state.rpc_id(pid, 1, pos, yaw, speed)
	else:
		_rider_state.rpc_id(1, pos, yaw, speed)

func submit_finish(time: float, replay_code: String) -> void:
	if is_host(): _accept_finish(1, time, replay_code)
	else: _finish_claim.rpc_id(1, time, replay_code)

func _adopt(s: CourseScene) -> void:
	_scene = s
	s.show_results = false
	var overlay = NetOverlay.new(); overlay.setup(self); s._ui.add_child(overlay)
	s.run.retry_countdown = 0.35
	s.run.run_finished.connect(_on_local_finish)
	_clear_remotes()

func _on_local_finish(result: Dictionary) -> void:
	if not round_active: return
	var rep: Replay = result.get("replay")
	if bool(result.get("finished", false)) and rep:
		submit_finish(float(result["time"]), rep.to_code())
	await get_tree().create_timer(1.2).timeout
	if _scene and is_instance_valid(_scene) and round_active: _scene.run.retry()

func _apply_state(id: int, pos: Vector3, yaw: float, speed: float) -> void:
	if not drive_scene or _scene == null or not is_instance_valid(_scene): return
	if not _remotes.has(id):
		var r = RemoteRider.new()
		r.peer_id = id
		var p: Dictionary = players.get(id, {})
		r.display_name = str(p.get("name", "RIDER"))
		r.color = COLORS[int(p.get("color", 0)) % COLORS.size()]
		_scene.add_child(r)
		_remotes[id] = r
	_remotes[id].push_state(pos, yaw, speed)

func remote_count() -> int:
	return _remotes.size()

func _clear_remotes() -> void:
	for r in _remotes.values():
		if is_instance_valid(r): r.queue_free()
	_remotes.clear()
