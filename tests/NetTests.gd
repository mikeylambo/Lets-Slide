extends Node

## T4 multiplayer gate:  godot --headless --fixed-fps 60 -- --net-test
##
## Real ENet sockets over localhost. The game's own NetSession hosts and
## drives the course scene; a second, protocol-only client session lives in
## its own multiplayer root inside the same process, so the gate is a single
## command on every OS. Covers join, version rejection, round start, relayed
## rider states, finish claims (valid and forged) and the final standings.

const PORT = 24711

var failures = 0
var checks = 0
var host: NetSession
var client: NetSession
var _client_rows: Array = []
var _client_final: Array = []

func check(label: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok: print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _ready() -> void:
	print("── SLIDE multiplayer ──")
	Game.use_sandbox_profile()
	await get_tree().process_frame
	host = Main.instance.net
	client = _spawn_client("ClientRoot")
	await _run()
	client.leave(); host.leave()
	print("── %d checks, %d failures ──" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

## A NetSession at the same relative path ("Main/NetSession") under its own
## SceneMultiplayer root, so RPC paths line up with the host's.
func _spawn_client(root_name: String) -> NetSession:
	var root = Node.new(); root.name = root_name; add_child(root)
	var fake_main = Node.new(); fake_main.name = "Main"; root.add_child(fake_main)
	var s = NetSession.new(); s.name = "NetSession"; s.drive_scene = false
	fake_main.add_child(s)
	get_tree().set_multiplayer(SceneMultiplayer.new(), root.get_path())
	return s

func _wait(cond: Callable, seconds: float = 5.0) -> bool:
	var end = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > end: return false
		await get_tree().process_frame
	return true

func _run() -> void:
	check("host opens a lobby", host.host(PORT, "Host") == OK and host.is_host())
	check("client dials the host", client.join("127.0.0.1", PORT, "Rider<script>Two") == OK)
	check("client joins the lobby", await _wait(func(): return host.players.size() == 2 and client.players.size() == 2))
	var cid = client.multiplayer.get_unique_id()
	check("names are sanitised", str(host.players.get(cid, {}).get("name", "")) == "RIDERSCRIPTTWO", str(host.players.get(cid)))

	# A client on the wrong protocol is turned away with a reason.
	var stale = _spawn_client("StaleRoot")
	var reasons = []
	stale.status.connect(func(t): reasons.append(t))
	stale.join("127.0.0.1", PORT, "Old")
	await _wait(func(): return stale.online())
	stale._hello.rpc_id(1, NetSession.PROTOCOL + 99, "Old")
	check("version mismatch is rejected", await _wait(func(): return reasons.any(func(r): return str(r).begins_with("Version"))), str(reasons))
	await _wait(func(): return host.players.size() == 2)
	check("rejected client never enters the lobby", host.players.size() == 2)

	client.scoreboard_changed.connect(func(rows): _client_rows = rows)
	client.round_ended.connect(func(rows): _client_final = rows)
	var course = Courses.all()[0]
	host.start_round(course, 60.0)
	check("round starts on the client with the same course", await _wait(func(): return client.round_active and client.course != null and client.course.id == course.id))
	check("host plays the round's course", Main.instance.current_world() is CourseScene and Main.instance.current_world().course.id == course.id)

	var scene: CourseScene = Main.instance.current_world()
	var target = scene._built["start_position"] + Vector3(0, 0, 25)
	for i in 30:
		client.send_state(target + Vector3(0, 0, i * 0.5), 0.0, 20.0)
		await get_tree().process_frame
	check("client rider appears in the host's world", await _wait(func(): return host.remote_count() == 1))
	await _wait(func(): return false, 0.3)
	var rr: RemoteRider = host._remotes.values()[0]
	check("remote rider is interpolated near its latest state", rr.position.distance_to(target + Vector3(0, 0, 14.5)) < 3.0, str(rr.position))
	client.send_state(Vector3(NAN, 0, 0), 0.0, 20.0)
	await _wait(func(): return false, 0.2)
	check("non-finite states are ignored", rr.position.is_finite())

	# Finish claims: a forged time is refused, a replay-backed time counts.
	var good = _replay_for(course.id, 1500)          # 12.5 s
	client.submit_finish(9.0, good.to_code())
	await _wait(func(): return false, 0.3)
	check("forged time (replay disagrees) is refused", float(host.players[cid]["best"]) == 0.0)
	client.submit_finish(good.time_seconds(), good.to_code())
	check("replay-backed finish is accepted", await _wait(func(): return float(host.players[cid]["best"]) > 0.0))
	check("client sees the live scoreboard", await _wait(func(): return _client_rows.size() == 2 and int(_client_rows[0]["id"]) == cid))

	# The host's own run finishes through the real run controller.
	scene.run.retry()
	await _wait(func(): return scene.run.state == RunController.State.RUNNING)
	for i in 120: await get_tree().physics_frame
	scene.run.finish_run(true)
	check("host's local finish is scored", await _wait(func(): return float(host.players[1]["best"]) > 0.0))
	check("faster rider leads", int(host.scoreboard_rows()[0]["id"]) == 1, str(host.scoreboard_rows()))

	host.round_left = 0.01
	check("round ends on schedule for everyone", await _wait(func(): return not client.round_active and _client_final.size() == 2))
	check("final standings are sorted by best time", float(_client_final[0]["best"]) <= float(_client_final[1]["best"]))

	# A community course travels as its code so the client builds it too.
	var custom = CustomCourses.template()
	host.start_round(custom, 60.0)
	check("community courses play online", await _wait(func(): return client.round_active and client.course != null and client.course.id == custom.id))

	client.leave()
	check("leaving updates the host's lobby", await _wait(func(): return host.players.size() == 1))

func _replay_for(course_id: String, ticks: int) -> Replay:
	var r = Replay.begin_for(course_id, MotorParams.new())
	var inp = MotorInput.new()
	for i in ticks: r.push(inp)
	r.finish(ticks, true, 120)
	return r
