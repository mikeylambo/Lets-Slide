class_name TrackEffect
extends Area3D

## Lightweight gameplay volumes emitted by terrain verbs. They operate directly
## on SlideBody state, so generated and authored courses share the exact effect.

enum Kind { UPDRAFT, HAZARD }

var kind: int = Kind.UPDRAFT
var strength = 10.0
var active = true

func setup(effect_kind: int, size: Vector3, effect_strength: float = 10.0) -> void:
	kind = effect_kind
	strength = effect_strength
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1
	var cs = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	add_child(cs)
	if kind == Kind.HAZARD:
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not active or kind != Kind.UPDRAFT:
		return
	for body in get_overlapping_bodies():
		if body is SlideBody:
			var slider = body as SlideBody
			slider.state.velocity.y += strength * delta
			slider.state.velocity.y = minf(slider.state.velocity.y, strength * 1.7)

func _on_body_entered(body: Node3D) -> void:
	if not active or not (body is SlideBody):
		return
	var slider = body as SlideBody
	var speed = slider.state.velocity.length()
	slider.state.velocity *= 0.25
	slider.bonked.emit(maxf(speed, 12.0))
