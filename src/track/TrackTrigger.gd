class_name TrackTrigger
extends Area3D

signal triggered(trigger: TrackTrigger)

enum Kind { CHECKPOINT = 0, FINISH = 1, ROUTE = 2, KILL = 3 }

var kind: int = Kind.CHECKPOINT
var index = 0
var route_id = ""
var respawn_position = Vector3.ZERO
var respawn_yaw = 0.0
var once = true

var _fired = false

func _init(k: int = Kind.CHECKPOINT, idx: int = 0) -> void:
	kind = k
	index = idx

func setup(size: Vector3, frame: Dictionary) -> void:
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)

	var f: Vector3 = frame.get("f", Vector3.FORWARD)
	var u: Vector3 = frame.get("u", Vector3.UP)
	var origin: Vector3 = frame.get("pos", Vector3.ZERO) + u * (size.y * 0.35)
	# Built before the course is in the tree, so transform is set directly
	# rather than via look_at (which requires a global transform).
	transform = Transform3D(Basis.looking_at(f, u).orthonormalized(), origin)

	respawn_position = frame.get("pos", Vector3.ZERO) + u * 0.55
	respawn_yaw = atan2(f.x, f.z)

	if kind == Kind.FINISH or kind == Kind.CHECKPOINT:
		_add_gate_visual(size, Pickup.COLORS[Pickup.Kind.CHAIN] if kind == Kind.CHECKPOINT else Color(0.4, 1.0, 0.6))

	monitoring = true
	body_entered.connect(_on_body_entered)

func _add_gate_visual(size: Vector3, c: Color) -> void:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size.x, 0.14, 0.14)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, size.y * 0.5, 0)
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _on_body_entered(body: Node3D) -> void:
	if not (body is SlideBody):
		return
	if once and _fired:
		return
	_fired = true
	triggered.emit(self)

func reset() -> void:
	_fired = false
