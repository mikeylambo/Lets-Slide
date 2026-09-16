class_name Sm64Math
extends RefCounted

## Faithful-in-structure port of the SM64 angle domain.
##
## SM64 stores angles as s16 in the range [-32768, 32767] where 0x10000 == 360°.
## Yaw 0 points along +Z; sins(yaw) yields the X component, coss(yaw) the Z
## component. Every angle constant in the decomp (0x200 per-frame facing
## correction, the 0x4000 quadrant clamps, the 0x8000 wrap) is preserved here so
## the reference model can be compared against footage without reinterpretation.
##
## This is not a bit-exact N64 emulation: we use IEEE doubles instead of the
## ROM's 4096-entry sine table and its f32 rounding. It reproduces the equations
## and constants, not the hardware.

const S16_MIN = -32768
const S16_MAX = 32767
const ANGLE_FULL = 65536.0

## World scale contract: 1 SM64 unit == 0.01 Godot metres.
## Mario is 160 units tall -> 1.6 m. The 100 units/frame slide cap at 30 Hz
## therefore lands at 30 m/s.
const UNITS_TO_M = 0.01
const M_TO_UNITS = 100.0

static func wrap_s16(a: int) -> int:
	a = int(a) & 0xFFFF
	if a >= 32768:
		a -= 65536
	return a

static func sins(angle: int) -> float:
	return sin(float(wrap_s16(angle)) * TAU / ANGLE_FULL)

static func coss(angle: int) -> float:
	return cos(float(wrap_s16(angle)) * TAU / ANGLE_FULL)

## SM64 calls atan2s(z, x) to get a world yaw. In its convention that is
## atan2(x, z) in standard maths, which keeps sins/coss consistent above.
static func atan2s(z: float, x: float) -> int:
	return wrap_s16(int(round(atan2(x, z) * ANGLE_FULL / TAU)))

static func rad_to_s16(r: float) -> int:
	return wrap_s16(int(round(r * ANGLE_FULL / TAU)))

static func s16_to_rad(a: int) -> float:
	return float(wrap_s16(a)) * TAU / ANGLE_FULL

## approach_s16 with the decomp's saturating behaviour.
static func approach_s16(current: int, target: int, step: int) -> int:
	var d = wrap_s16(target - current)
	if absi(d) <= step:
		return wrap_s16(target)
	return wrap_s16(current + (step if d > 0 else -step))
