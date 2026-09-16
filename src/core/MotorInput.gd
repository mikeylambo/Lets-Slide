class_name MotorInput
extends RefCounted

## Both motors read this and nothing else. The driver resolves raw device input
## into camera-relative world space once, so swapping models never changes how
## the stick maps to the world.

var steer = 0.0            ## -1 (left) .. 1 (right), already deadzoned
var lean = 0.0             ## -1 (back/extend) .. 1 (forward/tuck-in)
var move_dir = Vector3.ZERO ## camera-relative world XZ, length 0..1
var tuck = false
var brake = false
var jump_pressed = false

func stick_magnitude() -> float:
	return clampf(Vector2(move_dir.x, move_dir.z).length(), 0.0, 1.0)

func intended_yaw_s16(fallback: int) -> int:
	if stick_magnitude() < 0.02:
		return fallback
	return Sm64Math.atan2s(move_dir.z, move_dir.x)

func clear() -> void:
	steer = 0.0
	lean = 0.0
	move_dir = Vector3.ZERO
	tuck = false
	brake = false
	jump_pressed = false
