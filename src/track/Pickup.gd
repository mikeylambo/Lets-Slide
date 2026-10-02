class_name Pickup
extends Area3D

signal collected(pickup: Pickup)

enum Kind { SCORE = 0, CHAIN = 1, MASTERY = 2, BADGE = 3 }

const COLORS = {
	Kind.SCORE: Color(0.35, 0.95, 1.0),
	Kind.CHAIN: Color(1.0, 0.78, 0.25),
	Kind.MASTERY: Color(1.0, 0.35, 0.95),
	Kind.BADGE: Color(1.0, 0.86, 0.22),
}

@export var kind: int = Kind.SCORE
@export var value: int = 100

var _taken = false
var _mesh: MeshInstance3D
var _phase = 0.0

func _init(k: int = Kind.SCORE, v: int = 100) -> void:
	kind = k
	value = v

func _ready() -> void:
	_phase = randf() * TAU
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.6 if kind == Kind.MASTERY else 1.25
	shape.shape = sphere
	add_child(shape)

	if kind == Kind.BADGE:
		_mesh = _build_chick()
		add_child(_mesh)
		monitoring = true
		collision_mask = SlideBody.RIDER_LAYER
		body_entered.connect(_on_body_entered)
		return
	_mesh = MeshInstance3D.new()
	var m: Mesh
	if kind == Kind.MASTERY:
		var pm = PrismMesh.new()
		pm.size = Vector3(1.5, 2.2, 1.5)
		m = pm
	else:
		var sm = SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		sm.radial_segments = 10
		sm.rings = 6
		m = sm
	_mesh.mesh = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var c: Color = COLORS[kind]
	var mat = StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 2.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)

	monitoring = true
	collision_mask = SlideBody.RIDER_LAYER
	body_entered.connect(_on_body_entered)

## A little yellow chick: Ed's hoodie emblem, hidden once per course.
func _build_chick() -> MeshInstance3D:
	var root = MeshInstance3D.new()
	var yellow = _unshaded(COLORS[Kind.BADGE], 1.8)
	var body = SphereMesh.new(); body.radius = 0.42; body.height = 0.78
	root.mesh = body
	root.material_override = yellow
	var head = MeshInstance3D.new()
	var hm = SphereMesh.new(); hm.radius = 0.28; hm.height = 0.56
	head.mesh = hm; head.material_override = yellow; head.position = Vector3(0, 0.5, 0.08)
	root.add_child(head)
	var beak = MeshInstance3D.new()
	var bm = CylinderMesh.new(); bm.top_radius = 0.0; bm.bottom_radius = 0.08; bm.height = 0.16
	beak.mesh = bm; beak.material_override = _unshaded(Color(1.0, 0.55, 0.15), 1.6)
	beak.rotation_degrees = Vector3(90, 0, 0); beak.position = Vector3(0, 0.48, 0.38)
	root.add_child(beak)
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root

static func _unshaded(c: Color, energy: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _process(delta: float) -> void:
	if _taken:
		return
	_phase += delta
	_mesh.rotate_y(delta * 2.2)
	_mesh.position.y = sin(_phase * 2.4) * 0.22

func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is SlideBody) or not (body as SlideBody).is_player:
		return
	_taken = true
	collected.emit(self)
	# Instant feedback, no wait — retry loops must never queue on an animation.
	visible = false
	set_deferred("monitoring", false)
	set_process(false)

func is_taken() -> bool:
	return _taken

func restore() -> void:
	_taken = false
	visible = true
	set_deferred("monitoring", true)
	set_process(true)
