class_name SurfaceKind
extends RefCounted

enum {
	NOT_SLIPPERY = 0,
	DEFAULT = 1,
	SLIPPERY = 2,
	VERY_SLIPPERY = 3,
	BOOST = 4,
	HIGH_FRICTION = 5,
	CONVEYOR = 6,
	AVALANCHE = 7,
}

const NAMES = {
	NOT_SLIPPERY: "NOT_SLIPPERY", DEFAULT: "DEFAULT", SLIPPERY: "SLIPPERY",
	VERY_SLIPPERY: "VERY_SLIPPERY", BOOST: "BOOST", HIGH_FRICTION: "HIGH_FRICTION",
	CONVEYOR: "CONVEYOR", AVALANCHE: "AVALANCHE",
}

const COLORS = {
	NOT_SLIPPERY: Color(0.55, 0.38, 0.30), DEFAULT: Color(0.30, 0.34, 0.42),
	SLIPPERY: Color(0.28, 0.52, 0.68), VERY_SLIPPERY: Color(0.35, 0.80, 0.95),
	BOOST: Color(0.95, 0.45, 0.85), HIGH_FRICTION: Color(0.62, 0.55, 0.25),
	CONVEYOR: Color(0.35, 1.0, 0.62), AVALANCHE: Color(0.85, 0.72, 1.0),
}

static func name_of(kind: int) -> String:
	return NAMES.get(kind, "UNKNOWN")

static func color_of(kind: int) -> Color:
	return COLORS.get(kind, Color.WHITE)

static func sm64_accel(kind: int) -> float:
	match kind:
		VERY_SLIPPERY, BOOST, CONVEYOR, AVALANCHE: return 10.0
		SLIPPERY: return 8.0
		NOT_SLIPPERY, HIGH_FRICTION: return 5.0
		_: return 7.0

static func friction_scale(kind: int) -> float:
	match kind:
		VERY_SLIPPERY: return 0.35
		SLIPPERY: return 0.65
		DEFAULT: return 1.0
		NOT_SLIPPERY: return 1.6
		BOOST: return 0.2
		HIGH_FRICTION: return 3.4
		CONVEYOR: return 0.35
		AVALANCHE: return 0.28
		_: return 1.0
