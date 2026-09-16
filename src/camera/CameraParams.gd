class_name CameraParams
extends Resource

## Rider-anchored momentum camera. Lookahead changes what the camera aims toward;
## it never drags the pivot away from the player. This guarantees the rider stays
## in frame even at max speed.

@export var follow_distance: float = 6.8
@export var follow_height: float = 0.82       ## aim anchor above rider, not camera altitude
@export var distance_speed_gain: float = 0.055
@export var height_speed_gain: float = 0.004
@export var position_damping: float = 11.0
@export var air_distance_bonus: float = 2.6
@export var air_height_bonus: float = 0.35

@export var yaw_damping: float = 6.4
@export var yaw_max_rate: float = 220.0
@export var yaw_speed_tighten: float = 0.62
@export var pitch_base: float = 7.0
@export var pitch_slope_follow: float = 0.52
@export var pitch_damping: float = 5.2
@export var pitch_min: float = -24.0
@export var pitch_max: float = 38.0

@export var roll_from_bank: float = 0.36
@export var roll_max: float = 22.0
@export var roll_damping: float = 6.0

@export var lookahead_time: float = 0.32
@export var lookahead_max: float = 9.0
@export var terrain_anticipation: float = 16.0
@export var vertical_lookahead: float = 0.48
@export var landing_aim_weight: float = 0.62

@export var intro_swivel_enabled: bool = true
@export var intro_hold: float = 0.24
@export var intro_swivel_duration: float = 1.35

@export var fov_base: float = 70.0
@export var fov_speed_gain: float = 0.30
@export var fov_max: float = 96.0
@export var fov_attack: float = 3.0
@export var fov_release: float = 6.5

@export var shake_landing: float = 0.35
@export var shake_bonk: float = 1.0
@export var shake_decay: float = 4.5

const SCHEMA = [
	["follow_distance", "Distance", "Camera Rig", 2.0, 18.0, 0.1],
	["follow_height", "Rider Screen Anchor", "Camera Rig", 0.15, 2.2, 0.05],
	["distance_speed_gain", "Distance / Speed", "Camera Rig", 0.0, 0.25, 0.005],
	["height_speed_gain", "Anchor / Speed", "Camera Rig", 0.0, 0.08, 0.002],
	["position_damping", "Position Damping", "Camera Rig", 0.5, 30.0, 0.1],
	["air_distance_bonus", "Air Distance Bonus", "Camera Rig", 0.0, 10.0, 0.1],
	["air_height_bonus", "Air Anchor Bonus", "Camera Rig", 0.0, 4.0, 0.05],
	["yaw_damping", "Yaw Damping", "Camera Aim", 0.5, 25.0, 0.1],
	["yaw_max_rate", "Yaw Max Rate", "Camera Aim", 30.0, 720.0, 5.0],
	["yaw_speed_tighten", "Yaw Tighten / Speed", "Camera Aim", 0.0, 2.0, 0.01],
	["pitch_base", "Pitch Base", "Camera Aim", -20.0, 45.0, 0.5],
	["pitch_slope_follow", "Pitch Follows Slope", "Camera Aim", 0.0, 1.0, 0.01],
	["pitch_damping", "Pitch Damping", "Camera Aim", 0.5, 25.0, 0.1],
	["pitch_min", "Pitch Min", "Camera Aim", -70.0, 0.0, 1.0],
	["pitch_max", "Pitch Max", "Camera Aim", 0.0, 70.0, 1.0],
	["roll_from_bank", "Roll From Bank", "Camera Bank", 0.0, 1.0, 0.01],
	["roll_max", "Roll Max", "Camera Bank", 0.0, 60.0, 0.5],
	["roll_damping", "Roll Damping", "Camera Bank", 0.5, 25.0, 0.1],
	["lookahead_time", "Lookahead Time", "Camera Read", 0.0, 1.2, 0.01],
	["lookahead_max", "Lookahead Max", "Camera Read", 0.0, 30.0, 0.5],
	["terrain_anticipation", "Terrain Anticipation", "Camera Read", 0.0, 50.0, 0.5],
	["vertical_lookahead", "Vertical Lookahead", "Camera Read", 0.0, 2.0, 0.01],
	["landing_aim_weight", "Landing Aim Weight", "Camera Read", 0.0, 1.0, 0.01],
	["fov_base", "FOV Base", "Camera FOV", 40.0, 100.0, 0.5],
	["fov_speed_gain", "FOV / Speed", "Camera FOV", 0.0, 1.0, 0.01],
	["fov_max", "FOV Max", "Camera FOV", 55.0, 115.0, 0.5],
	["fov_attack", "FOV Attack", "Camera FOV", 0.2, 20.0, 0.1],
	["fov_release", "FOV Release", "Camera FOV", 0.2, 20.0, 0.1],
	["shake_landing", "Shake: Landing", "Camera Feel", 0.0, 3.0, 0.01],
	["shake_bonk", "Shake: Bonk", "Camera Feel", 0.0, 3.0, 0.01],
	["shake_decay", "Shake Decay", "Camera Feel", 0.5, 20.0, 0.1],
]
const GROUP_ORDER = ["Camera Rig", "Camera Aim", "Camera Bank", "Camera Read", "Camera FOV", "Camera Feel"]

func to_dict() -> Dictionary:
	var d = {}
	for row in SCHEMA: d[row[0]] = get(row[0])
	return d
func from_dict(d: Dictionary) -> void:
	for row in SCHEMA:
		if d.has(row[0]):
			# Presets survive project updates. Clamp old values into the new framing
			# contract so a stale preset cannot push the rider out of frame again.
			set(row[0], clampf(float(d[row[0]]), float(row[3]), float(row[4])))
