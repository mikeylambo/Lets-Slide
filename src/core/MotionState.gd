class_name MotionState
extends RefCounted

## Everything the movement model owns. The driver (SlideBody) owns collision and
## position; the motors own this. Keeping it in one object is what lets us swap
## SM64 Reference and Production mid-run without touching the driver.

# --- kinematics (metres, seconds) ---
var velocity = Vector3.ZERO
var position = Vector3.ZERO
var facing_yaw = 0.0          ## radians, 0 == +Z

# --- contact ---
var grounded = false
var was_grounded = false
var floor_normal = Vector3.UP
var previous_floor_normal = Vector3.UP
var surface_class = SurfaceKind.VERY_SLIPPERY
var slope_deg = 0.0           ## angle between floor normal and up
var downhill = Vector3.ZERO   ## unit vector, steepest descent on current floor

# --- derived / telemetry ---
var speed = 0.0
var ground_speed = 0.0
var air_time = 0.0
var ground_time = 0.0
var steer_delta_deg = 0.0     ## how far this tick bent the velocity vector
var momentum_retention = 1.0  ## exit_speed / entry_speed across the last tick
var entry_speed = 0.0
var last_launch_speed = 0.0
var last_landing_speed = 0.0
var last_landing_quality = 1.0 ## 1.0 = flush landing, 0.0 = full faceplant
var last_bonk_speed = 0.0
var bonk_timer = 0.0          ## >0 means steering is locked out
var tuck = 0.0                ## 0..1 blended tuck/extend input
var airborne_launch_pos = Vector3.ZERO

# --- SM64 reference scratch (units/frame domain, only touched by Sm64Motor) ---
var sm64_slide_vel_x = 0.0
var sm64_slide_vel_z = 0.0
var sm64_slide_yaw = 0
var sm64_face_yaw = 0
var sm64_forward_vel = 0.0

func reset(at: Vector3, yaw: float = 0.0) -> void:
	velocity = Vector3.ZERO
	position = at
	facing_yaw = yaw
	grounded = false
	was_grounded = false
	floor_normal = Vector3.UP
	previous_floor_normal = Vector3.UP
	surface_class = SurfaceKind.VERY_SLIPPERY
	slope_deg = 0.0
	downhill = Vector3.ZERO
	speed = 0.0
	ground_speed = 0.0
	air_time = 0.0
	ground_time = 0.0
	steer_delta_deg = 0.0
	momentum_retention = 1.0
	entry_speed = 0.0
	last_launch_speed = 0.0
	last_landing_speed = 0.0
	last_landing_quality = 1.0
	last_bonk_speed = 0.0
	bonk_timer = 0.0
	tuck = 0.0
	sm64_slide_vel_x = 0.0
	sm64_slide_vel_z = 0.0
	sm64_slide_yaw = Sm64Math.rad_to_s16(yaw)
	sm64_face_yaw = Sm64Math.rad_to_s16(yaw)
	sm64_forward_vel = 0.0

## Horizontal-only velocity helper used all over both motors.
func flat_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)

func flat_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func snapshot() -> Dictionary:
	return {
		"speed": speed,
		"ground_speed": ground_speed,
		"slope_deg": slope_deg,
		"steer_delta_deg": steer_delta_deg,
		"momentum": momentum_retention,
		"surface": SurfaceKind.name_of(surface_class),
		"grounded": grounded,
		"air_time": air_time,
		"landing_quality": last_landing_quality,
		"position": position,
	}
