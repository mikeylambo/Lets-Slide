class_name FlowSystem
extends Node

signal tier_changed(tier: int)
signal flow_changed(value: float, tier: int, multiplier: int)
signal flow_broken(reason: String)

enum Tier { NONE, WARM, LIT, BURN, INVERT }
const NAMES = ["", "WARM", "LIT", "BURN", "INVERT"]
const MULTIPLIERS = [1, 1, 2, 3, 5]
const TIER_SECONDS = [0.0, 1.6, 4.2, 8.5, 14.0]
const GRAZE_DISTANCE = 1.35

var slider: SlideBody
var active_seconds = 0.0
var rolling_peak = 1.0
var current_tier = Tier.NONE
var max_tier = Tier.NONE
var max_seconds = 0.0
var total_flow_seconds = 0.0
var _grace = 0.0
var _segment_target_speed = 0.0
var _grazing = false

func setup(player: SlideBody) -> void:
	slider = player
	if not slider.bonked.is_connected(_on_bonk):
		slider.bonked.connect(_on_bonk)
	if not slider.landed.is_connected(_on_landed):
		slider.landed.connect(_on_landed)

func reset() -> void:
	active_seconds = 0.0
	rolling_peak = 1.0
	current_tier = Tier.NONE
	max_tier = Tier.NONE
	max_seconds = 0.0
	total_flow_seconds = 0.0
	_grace = 0.0
	_grazing = false
	tier_changed.emit(current_tier)
	flow_changed.emit(active_seconds, current_tier, multiplier())

func set_segment_target(speed: float) -> void:
	_segment_target_speed = maxf(speed, 0.0)

func _process(delta: float) -> void:
	if slider == null or not slider.control_enabled:
		return
	var s = slider.state
	rolling_peak = maxf(s.speed, lerpf(rolling_peak, s.speed, clampf(delta * 0.18, 0.0, 1.0)))
	var floor_speed = maxf(_segment_target_speed, rolling_peak * 0.55)
	_grazing = _near_geometry() and s.speed >= rolling_peak * 0.62

	var qualifying = false
	if s.grounded:
		var high_bank = s.floor_normal.y < 0.78 and s.speed >= rolling_peak * 0.62
		qualifying = s.speed >= rolling_peak * 0.80 or high_bank or _grazing
	else:
		qualifying = s.flat_speed() >= rolling_peak * 0.62 and _air_tracks_landable_surface()

	if s.speed < floor_speed:
		_grace += delta
		if _grace > 0.42:
			break_flow("SPEED")
	elif qualifying:
		_grace = 0.0
		active_seconds += delta
		total_flow_seconds += delta
		max_seconds = maxf(max_seconds, active_seconds)
		_update_tier()
	else:
		# Set-up beats are permitted briefly; Flow is about sustained clean motion,
		# not demanding that every frame be at the rolling peak.
		_grace += delta * 0.45
		if _grace > 0.7:
			active_seconds = maxf(0.0, active_seconds - delta * 0.5)
	flow_changed.emit(active_seconds, current_tier, multiplier())

func multiplier() -> int:
	return MULTIPLIERS[current_tier]

func tier_name() -> String:
	return NAMES[current_tier]

func break_flow(reason: String) -> void:
	if active_seconds <= 0.0 and current_tier == Tier.NONE:
		return
	active_seconds = 0.0
	_grace = 0.0
	if current_tier != Tier.NONE:
		current_tier = Tier.NONE
		tier_changed.emit(current_tier)
	flow_broken.emit(reason)
	flow_changed.emit(active_seconds, current_tier, multiplier())

func _update_tier() -> void:
	var next = Tier.NONE
	if active_seconds >= TIER_SECONDS[Tier.INVERT]:
		next = Tier.INVERT
	elif active_seconds >= TIER_SECONDS[Tier.BURN]:
		next = Tier.BURN
	elif active_seconds >= TIER_SECONDS[Tier.LIT]:
		next = Tier.LIT
	elif active_seconds >= TIER_SECONDS[Tier.WARM]:
		next = Tier.WARM
	if next != current_tier:
		current_tier = next
		max_tier = maxi(max_tier, current_tier)
		tier_changed.emit(current_tier)

func _near_geometry() -> bool:
	if slider == null or not slider.is_inside_tree():
		return false
	var velocity = slider.state.flat_velocity()
	if velocity.length() < 1.0:
		return false
	var forward = velocity.normalized()
	var side = forward.cross(Vector3.UP).normalized()
	var origin = slider.global_position + Vector3.UP * 0.45
	var space = slider.get_world_3d().direct_space_state
	for direction in [side, -side]:
		var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * GRAZE_DISTANCE)
		query.exclude = [slider.get_rid()]
		if not space.intersect_ray(query).is_empty():
			return true
	return false

func _air_tracks_landable_surface() -> bool:
	if slider == null or not slider.is_inside_tree():
		return false
	var space = slider.get_world_3d().direct_space_state
	var p = slider.global_position
	var v = slider.state.velocity
	var step = 0.10
	for _i in 18:
		var next = p + v * step
		v.y -= slider.params.gravity * step
		var query = PhysicsRayQueryParameters3D.create(p, next)
		query.exclude = [slider.get_rid()]
		if not space.intersect_ray(query).is_empty():
			return true
		p = next
	return false

func _on_bonk(_speed: float) -> void:
	break_flow("BONK")

func _on_landed(quality: float, _speed: float) -> void:
	if quality < 0.40:
		break_flow("LANDING")
