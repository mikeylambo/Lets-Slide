class_name RemoteRider
extends Node3D

## Another player's rider: visual only (no physics, no collision), placed by
## interpolating their broadcast states ~100 ms in the past so motion stays
## smooth through jitter and packet loss.

const BUFFER_DELAY = 0.10
const MAX_STATES = 32

var peer_id = 0
var display_name = "RIDER"
var color = Color(1.0, 0.55, 0.2)
var _states: Array = []              ## [local_time, pos, yaw, speed]
var _clock = 0.0
var _label: Label3D

func _ready() -> void:
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	var board = MeshInstance3D.new()
	var bm = BoxMesh.new(); bm.size = Vector3(0.72, 0.09, 1.7)
	board.mesh = bm; board.material_override = mat; board.position.y = -0.36
	add_child(board)
	var body = MeshInstance3D.new()
	var cm = CapsuleMesh.new(); cm.radius = 0.26; cm.height = 1.0
	body.mesh = cm; body.material_override = mat; body.position.y = 0.12
	add_child(body)
	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = color
	_label.font_size = 40; _label.pixel_size = 0.01; _label.position.y = 1.3
	add_child(_label)
	visible = false

func push_state(pos: Vector3, yaw: float, speed: float) -> void:
	_states.append([_clock, pos, yaw, speed])
	if _states.size() > MAX_STATES: _states.pop_front()
	visible = true

func clear() -> void:
	_states.clear(); visible = false

func _process(delta: float) -> void:
	_clock += delta
	if _states.size() < 2:
		if _states.size() == 1: position = _states[0][1]
		return
	var t = _clock - BUFFER_DELAY
	while _states.size() > 2 and float(_states[1][0]) <= t: _states.pop_front()
	var a: Array = _states[0]; var b: Array = _states[1]
	var span = maxf(float(b[0]) - float(a[0]), 0.0001)
	var k = clampf((t - float(a[0])) / span, 0.0, 1.0)
	position = (a[1] as Vector3).lerp(b[1], k)
	rotation.y = lerp_angle(float(a[2]), float(b[2]), k)
