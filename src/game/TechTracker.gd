class_name TechTracker
extends Node

## Watches the real motion state and names the movement tech a player has just
## performed. Discovery is the reward: the codex starts as a list of hints and
## fills in as the player finds each technique on their own.
##
## Detection mirrors the motor's own conditions, so a technique only counts
## when it actually did something.

signal discovered(id: String, info: Dictionary)

const TECHS = [
	{"id": "crest_release", "name": "CREST RELEASE", "hint": "Something happens if you lean back as the ground falls away.",
		"desc": "Lean back (S / stick down) over a crest. The motor keeps more of your speed as you leave the ground."},
	{"id": "compression_load", "name": "COMPRESSION LOAD", "hint": "Dips want weight.",
		"desc": "Lean forward through a compression. Loading the dip carries extra speed out of it."},
	{"id": "flush_landing", "name": "FLUSH LANDING", "hint": "Not every landing costs the same.",
		"desc": "Touch down with your board parallel to the slope at speed. Flush landings keep almost all momentum."},
	{"id": "tuck_dive", "name": "TUCK DIVE", "hint": "Hold your shape in the air.",
		"desc": "Hold tuck through a long airtime and land clean. Tuck cuts drag and drops you onto the line faster."},
	{"id": "bank_carve", "name": "BANK CARVE", "hint": "Banks are not walls.",
		"desc": "Steer into a banked surface. Banks give extra rotation for the same speed cost."},
	{"id": "wall_ride", "name": "WALL RIDE", "hint": "How steep can you stay on?",
		"desc": "Hold a line on terrain steeper than 60°. The rider adheres as long as the surface turns smoothly."},
	{"id": "big_air", "name": "BIG AIR", "hint": "Two seconds is a long time.",
		"desc": "Stay airborne for two full seconds."},
]

var slider: SlideBody
var run: RunController
var _hold = {}                       ## id -> seconds the condition has held
var _air_tuck = 0.0

static func info(id: String) -> Dictionary:
	for t in TECHS:
		if t["id"] == id: return t
	return {}

func setup(player: SlideBody, controller: RunController) -> void:
	slider = player
	run = controller
	slider.took_off.connect(_on_takeoff)
	slider.landed.connect(_on_landed)

func _active() -> bool:
	return run != null and run.state == RunController.State.RUNNING and not run.watching

func _physics_process(dt: float) -> void:
	if slider == null or not _active():
		return
	var s = slider.state
	var inp = slider.input
	if s.grounded:
		_air_tuck = 0.0
		var curvature = s.floor_normal.angle_to(s.previous_floor_normal) / maxf(dt, 0.001)
		var vertical = s.floor_normal.y - s.previous_floor_normal.y
		_held("compression_load", inp.lean > 0.3 and vertical < -0.0005 and curvature > 0.05 and s.speed > 15.0, dt, 0.15)
		var side = s.velocity.normalized().cross(Vector3.UP)
		var bank = s.floor_normal.dot(side.normalized()) if side.length() > 0.01 else 0.0
		_held("bank_carve", absf(inp.steer) > 0.5 and absf(bank) > 0.3 and -bank * signf(inp.steer) > 0.0 and s.speed > 15.0, dt, 0.5)
		_held("wall_ride", s.slope_deg > 60.0 and s.speed > 10.0, dt, 0.4)
	else:
		if inp.tuck: _air_tuck += dt
		if s.air_time >= 2.0: _found("big_air")

func _held(id: String, cond: bool, dt: float, need: float) -> void:
	_hold[id] = (float(_hold.get(id, 0.0)) + dt) if cond else 0.0
	if float(_hold[id]) >= need: _found(id)

func _on_takeoff(speed: float) -> void:
	if _active() and slider.input.lean < -0.3 and speed > 20.0:
		_found("crest_release")

func _on_landed(quality: float, speed: float) -> void:
	if not _active(): return
	if quality >= 0.97 and speed >= 25.0: _found("flush_landing")
	if _air_tuck >= 0.6 and quality >= 0.85: _found("tuck_dive")
	_air_tuck = 0.0

func _found(id: String) -> void:
	if Game.discover_tech(id):
		discovered.emit(id, info(id))
