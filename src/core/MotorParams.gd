class_name MotorParams
extends Resource

## Single source of truth for movement tuning. The Movement Lab builds its
## slider panel from SCHEMA, so adding a tunable here makes it appear in the
## lab automatically — there is no second list to keep in sync.
##
## SCHEMA rows: [property, label, group, min, max, step]

enum Model { PRODUCTION = 0, SM64_REFERENCE = 1 }

@export var model: int = Model.PRODUCTION

# ---------------------------------------------------------------- simulation
@export var simulation_hz: float = 120.0
@export var gravity: float = 26.0              ## m/s², tuned not physical
@export var terminal_velocity: float = 62.0
@export var author_avg_speed: float = 32.0     ## content scale authority; bars -> metres
@export var ground_snap_distance: float = 0.55 ## metres of "stick to terrain"
@export var ground_probe_radius: float = 0.42  ## normal-averaging footprint

# --------------------------------------------------------------------- slide
@export var slope_accel: float = 30.0          ## m/s² at a vertical face
@export var slope_accel_curve: float = 1.0     ## exponent on sin(slope)
@export var flat_friction: float = 1.6         ## m/s² drag on level ground
@export var downhill_friction: float = 0.55
@export var uphill_friction: float = 4.2
@export var drag_quadratic: float = 0.0035     ## speed² term — sets the soft cap
@export var steering_strength: float = 145.0   ## deg/s of velocity bend at rest
@export var steering_speed_falloff: float = 0.62 ## 0 = no falloff, 1 = harsh
@export var countersteer_strength: float = 1.45 ## multiplier when opposing drift
@export var momentum_retention: float = 0.985  ## speed kept per full-lock turn
@export var carve_grip: float = 0.88           ## how much bank resists sideslip
@export var max_speed: float = 62.0
@export var min_slide_speed: float = 0.6
@export var boost_accel: float = 34.0          ## BOOST surface thrust
@export var brake_decel: float = 22.0
@export var conveyor_accel: float = 18.0
@export var avalanche_accel: float = 26.0
@export var avalanche_drift: float = 3.5

# Weight transfer never creates energy on flat ground. It only changes how
# cleanly existing terrain forces are received/released.
@export var weight_transfer_strength: float = 0.22
@export var compression_bonus: float = 0.18
@export var crest_release: float = 0.32
@export var landing_match_bonus: float = 0.12

# ----------------------------------------------------------------------- air
@export var air_steering: float = 82.0         ## deg/s heading change airborne
@export var air_forward_accel: float = 2.4
@export var air_lateral_accel: float = 8.5
@export var air_drag: float = 0.0016
@export var air_max_rotation_rate: float = 240.0 ## deg/s cap on body yaw
@export var tuck_drag_scale: float = 0.35      ## tuck multiplies air_drag by this
@export var tuck_gravity_scale: float = 1.22   ## tuck falls faster (line control)
@export var extend_lift: float = 5.5           ## m/s² upward while extending
@export var landing_retention: float = 0.94    ## flush-landing speed kept
@export var bad_landing_penalty: float = 0.45  ## worst-case speed kept
@export var landing_alignment_power: float = 1.6 ## curve on landing quality

# ----------------------------------------------------------------- collision
@export var bonk_threshold: float = 0.55       ## |dot(vel, -wall_normal)| to bonk
@export var bonk_speed_threshold: float = 9.0  ## m/s below which walls never bonk
@export var bonk_restitution: float = 0.22     ## speed kept through a bonk
@export var bonk_lockout: float = 0.35         ## seconds of no steering after
@export var wall_deflection: float = 0.15      ## push away from wall on graze
@export var glancing_retention: float = 0.93   ## speed kept sliding along a wall
@export var edge_tolerance: float = 0.28       ## metres of forgiveness at lips
@export var ground_reacquire_angle: float = 76.0 ## deg from world-up when reacquiring from air
@export var surface_normal_follow_angle: float = 58.0 ## max normal change while adhered

# ------------------------------------------------- SM64 reference constants
# Editable so you can see what each original constant is doing, but the
# defaults ARE the decomp values. Reset Reference restores them exactly.
@export var sm64_hz: float = 30.0
@export var sm64_accel_very_slippery: float = 10.0
@export var sm64_accel_slippery: float = 8.0
@export var sm64_accel_default: float = 7.0
@export var sm64_accel_not_slippery: float = 5.0
@export var sm64_loss_base_very_slippery: float = 0.98
@export var sm64_loss_base_slippery: float = 0.96
@export var sm64_loss_base_default: float = 0.92
@export var sm64_facing_correction: float = 512.0 ## 0x200 per frame
@export var sm64_speed_cap: float = 100.0      ## units/frame
@export var sm64_stop_speed: float = 1.0
@export var sm64_gravity: float = 4.0          ## units/frame²
@export var sm64_air_steer: float = 0.35

# ------------------------------------------------------------- dev overrides
@export var enable_jump: bool = false          ## design hypothesis is NO jump
@export var jump_impulse: float = 9.5

const SCHEMA = [
	["simulation_hz", "Simulation Hz", "Simulation", 30.0, 240.0, 1.0],
	["gravity", "Gravity", "Simulation", 5.0, 80.0, 0.1],
	["terminal_velocity", "Terminal Velocity", "Simulation", 20.0, 160.0, 0.5],
	["author_avg_speed", "Author Avg Speed", "Simulation", 20.0, 70.0, 0.5],
	["ground_snap_distance", "Ground Snap", "Simulation", 0.0, 2.0, 0.01],
	["ground_probe_radius", "Probe Radius", "Simulation", 0.05, 1.5, 0.01],

	["slope_accel", "Slope Accel", "Slide", 0.0, 90.0, 0.1],
	["slope_accel_curve", "Slope Curve Exp", "Slide", 0.25, 3.0, 0.01],
	["flat_friction", "Flat Friction", "Slide", 0.0, 12.0, 0.01],
	["downhill_friction", "Downhill Friction", "Slide", 0.0, 12.0, 0.01],
	["uphill_friction", "Uphill Friction", "Slide", 0.0, 20.0, 0.01],
	["drag_quadratic", "Quadratic Drag", "Slide", 0.0, 0.02, 0.0001],
	["steering_strength", "Steering Strength", "Slide", 0.0, 400.0, 1.0],
	["steering_speed_falloff", "Steer Falloff vs Speed", "Slide", 0.0, 1.0, 0.01],
	["countersteer_strength", "Countersteer", "Slide", 0.5, 3.0, 0.01],
	["momentum_retention", "Momentum Retention", "Slide", 0.85, 1.0, 0.001],
	["carve_grip", "Carve Grip", "Slide", 0.0, 1.0, 0.01],
	["max_speed", "Max Speed", "Slide", 10.0, 140.0, 0.5],
	["min_slide_speed", "Min Slide Speed", "Slide", 0.0, 6.0, 0.05],
	["boost_accel", "Boost Surface Accel", "Slide", 0.0, 90.0, 0.5],
	["brake_decel", "Brake Decel", "Slide", 0.0, 60.0, 0.5],
	["conveyor_accel", "Conveyor Accel", "Slide", 0.0, 60.0, 0.5],
	["avalanche_accel", "Avalanche Accel", "Slide", 0.0, 80.0, 0.5],
	["avalanche_drift", "Avalanche Drift", "Slide", 0.0, 15.0, 0.1],
	["weight_transfer_strength", "Weight Transfer", "Slide", 0.0, 0.8, 0.01],
	["compression_bonus", "Compression Timing", "Slide", 0.0, 0.6, 0.01],
	["crest_release", "Crest Release", "Slide", 0.0, 0.8, 0.01],
	["landing_match_bonus", "Landing Match", "Slide", 0.0, 0.5, 0.01],

	["air_steering", "Air Steering", "Air", 0.0, 260.0, 1.0],
	["air_forward_accel", "Air Forward Accel", "Air", 0.0, 20.0, 0.1],
	["air_lateral_accel", "Air Lateral Accel", "Air", 0.0, 30.0, 0.1],
	["air_drag", "Air Drag", "Air", 0.0, 0.02, 0.0001],
	["air_max_rotation_rate", "Max Rotation Rate", "Air", 30.0, 720.0, 5.0],
	["tuck_drag_scale", "Tuck Drag Scale", "Air", 0.0, 2.0, 0.01],
	["tuck_gravity_scale", "Tuck Gravity Scale", "Air", 0.5, 2.5, 0.01],
	["extend_lift", "Extend Lift", "Air", 0.0, 20.0, 0.1],
	["landing_retention", "Landing Retention", "Air", 0.3, 1.0, 0.005],
	["bad_landing_penalty", "Bad Landing Retention", "Air", 0.0, 1.0, 0.01],
	["landing_alignment_power", "Landing Curve Exp", "Air", 0.5, 4.0, 0.05],

	["bonk_threshold", "Bonk Threshold", "Collision", 0.0, 1.0, 0.01],
	["bonk_speed_threshold", "Bonk Min Speed", "Collision", 0.0, 40.0, 0.5],
	["bonk_restitution", "Bonk Restitution", "Collision", 0.0, 1.0, 0.01],
	["bonk_lockout", "Bonk Lockout", "Collision", 0.0, 2.0, 0.01],
	["wall_deflection", "Wall Deflection", "Collision", 0.0, 1.0, 0.01],
	["glancing_retention", "Glancing Retention", "Collision", 0.5, 1.0, 0.005],
	["edge_tolerance", "Edge Tolerance", "Collision", 0.0, 1.5, 0.01],
	["ground_reacquire_angle", "Air Reacquire Angle", "Collision", 30.0, 89.0, 0.5],
	["surface_normal_follow_angle", "Adhesion Normal Change", "Collision", 10.0, 89.0, 0.5],

	["sm64_hz", "Reference Hz", "SM64 Reference", 10.0, 120.0, 1.0],
	["sm64_accel_very_slippery", "Accel VERY_SLIPPERY", "SM64 Reference", 0.0, 30.0, 0.1],
	["sm64_accel_slippery", "Accel SLIPPERY", "SM64 Reference", 0.0, 30.0, 0.1],
	["sm64_accel_default", "Accel DEFAULT", "SM64 Reference", 0.0, 30.0, 0.1],
	["sm64_accel_not_slippery", "Accel NOT_SLIPPERY", "SM64 Reference", 0.0, 30.0, 0.1],
	["sm64_loss_base_very_slippery", "Loss Base V.SLIP", "SM64 Reference", 0.85, 1.0, 0.001],
	["sm64_loss_base_slippery", "Loss Base SLIP", "SM64 Reference", 0.85, 1.0, 0.001],
	["sm64_loss_base_default", "Loss Base DEFAULT", "SM64 Reference", 0.85, 1.0, 0.001],
	["sm64_facing_correction", "Facing Correction (0x200)", "SM64 Reference", 0.0, 4096.0, 16.0],
	["sm64_speed_cap", "Speed Cap (units/frame)", "SM64 Reference", 10.0, 300.0, 1.0],
	["sm64_stop_speed", "Stop Speed", "SM64 Reference", 0.0, 20.0, 0.1],
	["sm64_gravity", "Gravity (units/frame²)", "SM64 Reference", 0.5, 20.0, 0.1],
	["sm64_air_steer", "Air Drag (0.35)", "SM64 Reference", 0.0, 2.0, 0.01],

	["jump_impulse", "Dev Jump Impulse", "Dev", 0.0, 25.0, 0.1],
]

## Groups render in this order in the lab.
const GROUP_ORDER = ["Simulation", "Slide", "Air", "Collision", "SM64 Reference", "Dev"]

func duplicate_params() -> MotorParams:
	var p = MotorParams.new()
	for row in SCHEMA:
		p.set(row[0], get(row[0]))
	p.model = model
	p.enable_jump = enable_jump
	return p

func to_dict() -> Dictionary:
	var d = {"model": model, "enable_jump": enable_jump}
	for row in SCHEMA:
		d[row[0]] = get(row[0])
	return d

func from_dict(d: Dictionary) -> void:
	for row in SCHEMA:
		if d.has(row[0]):
			set(row[0], float(d[row[0]]))
	if d.has("model"):
		model = int(d["model"])
	if d.has("enable_jump"):
		enable_jump = bool(d["enable_jump"])

## Restores only the SM64 group to the decomp's actual values.
func reset_reference_constants() -> void:
	sm64_hz = 30.0
	sm64_accel_very_slippery = 10.0
	sm64_accel_slippery = 8.0
	sm64_accel_default = 7.0
	sm64_accel_not_slippery = 5.0
	sm64_loss_base_very_slippery = 0.98
	sm64_loss_base_slippery = 0.96
	sm64_loss_base_default = 0.92
	sm64_facing_correction = 512.0
	sm64_speed_cap = 100.0
	sm64_stop_speed = 1.0
	sm64_gravity = 4.0
	sm64_air_steer = 0.35

func sm64_accel_for(kind: int) -> float:
	match kind:
		SurfaceKind.VERY_SLIPPERY, SurfaceKind.BOOST, SurfaceKind.CONVEYOR, SurfaceKind.AVALANCHE: return sm64_accel_very_slippery
		SurfaceKind.SLIPPERY: return sm64_accel_slippery
		SurfaceKind.NOT_SLIPPERY, SurfaceKind.HIGH_FRICTION: return sm64_accel_not_slippery
		_: return sm64_accel_default

func sm64_loss_base_for(kind: int) -> float:
	match kind:
		SurfaceKind.VERY_SLIPPERY, SurfaceKind.BOOST, SurfaceKind.CONVEYOR, SurfaceKind.AVALANCHE: return sm64_loss_base_very_slippery
		SurfaceKind.SLIPPERY: return sm64_loss_base_slippery
		_: return sm64_loss_base_default
