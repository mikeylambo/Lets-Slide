class_name SpeedTrail
extends MeshInstance3D

## A cheap additive ribbon. No particles, no shader compile stalls — this has to
## be free on the Intel Mac and on phone hardware, because the trail is doing
## real work: it is the clearest read the player has on whether their last turn
## kept speed or spent it.

const MAX_POINTS = 42
const MIN_STEP = 0.22
const LIFETIME = 0.55

var base_width = 0.34
var color_slow = Color(0.20, 0.55, 0.95)
var color_fast = Color(1.0, 0.42, 0.92)
var flow_tier = 0
var intensity_scale = 1.0

var _points: Array[Dictionary] = []
var _im = ImmediateMesh.new()

func _ready() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = true
	material_override = m

func clear_trail() -> void:
	_points.clear()
	_im.clear_surfaces()

func push_point(pos: Vector3, intensity: float) -> void:
	if not _points.is_empty():
		var last: Vector3 = _points[_points.size() - 1]["pos"]
		if last.distance_to(pos) < MIN_STEP:
			return
	_points.append({"pos": pos, "age": 0.0, "i": clampf(intensity, 0.0, 1.0)})
	while _points.size() > MAX_POINTS:
		_points.pop_front()

func _process(delta: float) -> void:
	var i = 0
	while i < _points.size():
		_points[i]["age"] += delta
		if _points[i]["age"] > LIFETIME:
			_points.remove_at(i)
		else:
			i += 1
	_rebuild()

func _rebuild() -> void:
	_im.clear_surfaces()
	if _points.size() < 2:
		return
	var cam = get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam else global_position + Vector3.UP * 8.0

	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _points.size():
		var p: Dictionary = _points[i]
		var pos: Vector3 = p["pos"]
		var nxt: Vector3 = _points[mini(i + 1, _points.size() - 1)]["pos"]
		var prv: Vector3 = _points[maxi(i - 1, 0)]["pos"]
		var dir = (nxt - prv)
		if dir.length() < 0.0001:
			dir = Vector3.FORWARD
		dir = dir.normalized()
		var side = dir.cross((pos - eye).normalized())
		if side.length() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()

		var life: float = 1.0 - (p["age"] / LIFETIME)
		var tier_scale = 1.0 + float(flow_tier) * 0.22
		var w: float = base_width * tier_scale * life * (0.45 + 0.85 * float(p["i"])) * intensity_scale
		var c: Color = color_slow.lerp(color_fast, float(p["i"]))
		if flow_tier >= 2: c = c.lerp(Color(0.98, 0.82, 0.25), 0.18 * float(flow_tier - 1))
		if flow_tier >= 4: c = Color(0.96, 0.96, 1.0).lerp(c, 0.30)
		c.a = life * life * 0.85 * intensity_scale

		_im.surface_set_color(c)
		_im.surface_add_vertex(pos - side * w)
		_im.surface_set_color(c)
		_im.surface_add_vertex(pos + side * w)
	_im.surface_end()
