class_name RegionTheme
extends RefCounted

## The look of each region of the Shelf, as data. WorldKit and TrackBuilder
## read these; nothing else hard-codes a region's colours. To restyle a region
## (or prototype a new one), edit its entry here and run
## `Tools/world-shots.sh <course_id>` to see it.
##
## Rules that keep the game readable whatever the palette:
## - The deck keeps its surface-class hue (SurfaceKind.COLORS) blended into
##   the region's stone, so friction still reads from 200 m.
## - Edges glow in the surface hue; the region's accent is for architecture.
## - Terraces always sit below the riding line: the world frames the track,
##   it never competes with it.
## - "landmark" names a one-off silhouette (WorldKit._landmark) placed on the
##   horizon past the finish, so every course in the region rides toward it.

const THEMES = [
	{   # I. THRESHOLD: dawn at the top edge of the Shelf. Warm limestone and
		# frosted glass above a sea of cloud; the first view of how far down goes.
		"name": "THRESHOLD",
		"sky_top": Color(0.20, 0.36, 0.66), "sky_horizon": Color(0.98, 0.72, 0.52),
		"sun_color": Color(1.0, 0.82, 0.60), "sun_energy": 1.5, "sun_pitch": -16.0, "sun_yaw": 30.0,
		"fill_color": Color(0.50, 0.64, 1.0), "fill_energy": 0.22,
		"ambient": 0.42, "fog": Color(0.80, 0.70, 0.66), "fog_density": 0.00055,
		"stone": Color(0.80, 0.72, 0.62), "stone_dark": Color(0.40, 0.38, 0.44),
		"glass": Color(0.62, 0.90, 1.0), "accent": Color(1.0, 0.74, 0.40),
		"clouds": Color(1.0, 0.88, 0.78), "cloud_shadow": Color(0.46, 0.50, 0.70),
		"deck_mix": 0.5, "glow": 0.32, "terrace_every": 70.0, "spires": false,
		"landmark": "great_arch",
	},
	{   # II. THE COMBS: late sun through honeycomb terraces. Amber stone, rhythm.
		"name": "THE COMBS",
		"sky_top": Color(0.36, 0.22, 0.46), "sky_horizon": Color(1.0, 0.58, 0.36),
		"sun_color": Color(1.0, 0.68, 0.42), "sun_energy": 1.45, "sun_pitch": -14.0, "sun_yaw": 200.0,
		"fill_color": Color(0.62, 0.48, 1.0), "fill_energy": 0.35,
		"ambient": 0.65, "fog": Color(0.86, 0.60, 0.50), "fog_density": 0.0013,
		"stone": Color(0.86, 0.66, 0.46), "stone_dark": Color(0.45, 0.30, 0.28),
		"glass": Color(1.0, 0.80, 0.50), "accent": Color(1.0, 0.55, 0.30),
		"clouds": Color(1.0, 0.76, 0.62), "cloud_shadow": Color(0.62, 0.42, 0.60),
		"deck_mix": 0.40, "glow": 0.34, "terrace_every": 55.0, "spires": false,
	},
	{   # III. SKYFALL: high noon in open air. Pale stone, thin spires, long drops.
		"name": "SKYFALL",
		"sky_top": Color(0.08, 0.30, 0.78), "sky_horizon": Color(0.62, 0.80, 0.98),
		"sun_color": Color(1.0, 0.97, 0.90), "sun_energy": 1.45, "sun_pitch": -58.0, "sun_yaw": 120.0,
		"fill_color": Color(0.55, 0.75, 1.0), "fill_energy": 0.25,
		"ambient": 0.5, "fog": Color(0.70, 0.82, 0.98), "fog_density": 0.0005,
		"stone": Color(0.78, 0.80, 0.86), "stone_dark": Color(0.40, 0.46, 0.58),
		"glass": Color(0.55, 0.92, 1.0), "accent": Color(0.40, 0.85, 1.0),
		"clouds": Color(0.98, 0.99, 1.0), "cloud_shadow": Color(0.50, 0.62, 0.84),
		"deck_mix": 0.45, "glow": 0.30, "terrace_every": 95.0, "spires": true,
	},
	{   # IV. NEEDLEWORK: overcast, steel and slate. Precision, tight framing.
		"name": "NEEDLEWORK",
		"sky_top": Color(0.30, 0.34, 0.42), "sky_horizon": Color(0.66, 0.68, 0.74),
		"sun_color": Color(0.86, 0.90, 1.0), "sun_energy": 1.1, "sun_pitch": -40.0, "sun_yaw": 70.0,
		"fill_color": Color(0.60, 0.66, 0.85), "fill_energy": 0.45,
		"ambient": 0.7, "fog": Color(0.58, 0.60, 0.66), "fog_density": 0.0019,
		"stone": Color(0.52, 0.55, 0.62), "stone_dark": Color(0.26, 0.28, 0.34),
		"glass": Color(0.80, 0.86, 1.0), "accent": Color(0.70, 0.62, 1.0),
		"clouds": Color(0.70, 0.72, 0.78), "cloud_shadow": Color(0.40, 0.42, 0.50),
		"deck_mix": 0.36, "glow": 0.38, "terrace_every": 45.0, "spires": true,
	},
	{   # V. THE THROAT: the bottom nobody confirmed. Night, basalt, ember light.
		"name": "THE THROAT",
		"sky_top": Color(0.03, 0.02, 0.06), "sky_horizon": Color(0.30, 0.08, 0.14),
		"sun_color": Color(1.0, 0.42, 0.36), "sun_energy": 0.9, "sun_pitch": -10.0, "sun_yaw": 230.0,
		"fill_color": Color(0.45, 0.30, 0.85), "fill_energy": 0.5,
		"ambient": 0.55, "fog": Color(0.22, 0.07, 0.12), "fog_density": 0.0024,
		"stone": Color(0.30, 0.27, 0.30), "stone_dark": Color(0.10, 0.08, 0.11),
		"glass": Color(1.0, 0.40, 0.30), "accent": Color(1.0, 0.30, 0.42),
		"clouds": Color(0.40, 0.14, 0.18), "cloud_shadow": Color(0.10, 0.04, 0.08),
		"deck_mix": 0.30, "glow": 0.50, "terrace_every": 60.0, "spires": false,
	},
]

static func of(region_index: int) -> Dictionary:
	return THEMES[clampi(region_index, 0, THEMES.size() - 1)]
