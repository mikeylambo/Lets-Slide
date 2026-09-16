class_name VerbLibrary
extends RefCounted

## Machine-readable terrain grammar shared by authored courses, the generator,
## the inspector and validation.  The values are intentionally data-first: the
## level designer and procedural system are making decisions from the same facts.

const META = {
	"straight": {"tier": 1, "intensity": 0.12, "speed_effect": "build", "requires_entry_speed": 0.0, "recovery": true, "pairs_well_with": ["drop", "crest", "split", "tunnel"], "reads_poorly_after": []},
	"drop": {"tier": 1, "intensity": 0.38, "speed_effect": "build", "requires_entry_speed": 0.0, "recovery": false, "pairs_well_with": ["bank", "bowl", "compression"], "reads_poorly_after": []},
	"bank": {"tier": 1, "intensity": 0.42, "speed_effect": "hold", "requires_entry_speed": 6.0, "recovery": false, "pairs_well_with": ["straight", "chicane", "wall", "crest"], "reads_poorly_after": []},
	"bowl": {"tier": 1, "intensity": 0.28, "speed_effect": "hold", "requires_entry_speed": 4.0, "recovery": true, "pairs_well_with": ["ramp", "crest", "bank"], "reads_poorly_after": []},
	"ramp": {"tier": 2, "intensity": 0.58, "speed_effect": "spend", "requires_entry_speed": 14.0, "recovery": false, "pairs_well_with": ["gap", "drop"], "reads_poorly_after": ["funnel"]},
	"gap": {"tier": 2, "intensity": 0.66, "speed_effect": "spend", "requires_entry_speed": 16.0, "recovery": false, "pairs_well_with": ["drop", "bowl"], "reads_poorly_after": ["gap"]},
	"wall": {"tier": 2, "intensity": 0.58, "speed_effect": "hold", "requires_entry_speed": 12.0, "recovery": false, "pairs_well_with": ["transfer", "bank_to_wall", "bowl"], "reads_poorly_after": []},
	"funnel": {"tier": 2, "intensity": 0.52, "speed_effect": "spend", "requires_entry_speed": 8.0, "recovery": false, "pairs_well_with": ["straight", "tunnel"], "reads_poorly_after": ["gap"]},
	"crest": {"tier": 1, "intensity": 0.40, "speed_effect": "spend", "requires_entry_speed": 10.0, "recovery": false, "pairs_well_with": ["drop", "bowl", "straight"], "reads_poorly_after": []},
	"compression": {"tier": 2, "intensity": 0.46, "speed_effect": "build", "requires_entry_speed": 9.0, "recovery": false, "pairs_well_with": ["crest", "bank", "chicane"], "reads_poorly_after": []},
	"patch": {"tier": 1, "intensity": 0.24, "speed_effect": "hold", "requires_entry_speed": 0.0, "recovery": true, "pairs_well_with": ["straight", "bank", "funnel"], "reads_poorly_after": []},
	"chicane": {"tier": 2, "intensity": 0.62, "speed_effect": "spend", "requires_entry_speed": 12.0, "recovery": false, "pairs_well_with": ["compression", "bowl", "straight"], "reads_poorly_after": ["chicane"]},
	"ridge": {"tier": 3, "intensity": 0.76, "speed_effect": "hold", "requires_entry_speed": 15.0, "recovery": false, "pairs_well_with": ["drop", "crest"], "reads_poorly_after": ["fullpipe"]},
	"transfer": {"tier": 3, "intensity": 0.80, "speed_effect": "spend", "requires_entry_speed": 20.0, "recovery": false, "pairs_well_with": ["wall", "bank_to_wall", "bowl"], "reads_poorly_after": ["funnel"]},
	"bank_to_wall": {"tier": 3, "intensity": 0.82, "speed_effect": "hold", "requires_entry_speed": 20.0, "recovery": false, "pairs_well_with": ["transfer", "corkscrew"], "reads_poorly_after": ["gap"]},
	"corkscrew": {"tier": 4, "intensity": 0.94, "speed_effect": "spend", "requires_entry_speed": 24.0, "recovery": false, "pairs_well_with": ["bowl", "straight"], "reads_poorly_after": ["corkscrew", "fullpipe"]},
	"fullpipe": {"tier": 4, "intensity": 0.90, "speed_effect": "hold", "requires_entry_speed": 22.0, "recovery": false, "pairs_well_with": ["straight", "drop"], "reads_poorly_after": ["fullpipe"]},
	"shaft": {"tier": 3, "intensity": 0.84, "speed_effect": "build", "requires_entry_speed": 10.0, "recovery": false, "pairs_well_with": ["bowl", "updraft", "drop"], "reads_poorly_after": ["ridge"]},
	"conveyor": {"tier": 2, "intensity": 0.44, "speed_effect": "build", "requires_entry_speed": 0.0, "recovery": true, "pairs_well_with": ["chicane", "ramp"], "reads_poorly_after": []},
	"avalanche": {"tier": 3, "intensity": 0.72, "speed_effect": "build", "requires_entry_speed": 8.0, "recovery": false, "pairs_well_with": ["ridge", "funnel", "drop"], "reads_poorly_after": []},
	"updraft": {"tier": 3, "intensity": 0.68, "speed_effect": "hold", "requires_entry_speed": 14.0, "recovery": false, "pairs_well_with": ["gap", "transfer", "shaft"], "reads_poorly_after": []},
	"hazard": {"tier": 2, "intensity": 0.60, "speed_effect": "spend", "requires_entry_speed": 8.0, "recovery": false, "pairs_well_with": ["split", "bank", "funnel"], "reads_poorly_after": []},
	"split": {"tier": 1, "intensity": 0.34, "speed_effect": "hold", "requires_entry_speed": 6.0, "recovery": true, "pairs_well_with": ["bank", "patch", "straight"], "reads_poorly_after": []},
	"tunnel": {"tier": 1, "intensity": 0.32, "speed_effect": "hold", "requires_entry_speed": 5.0, "recovery": true, "pairs_well_with": ["drop", "funnel", "straight"], "reads_poorly_after": []},
}

static func all_names() -> Array[String]:
	var out: Array[String] = []
	for k in META.keys():
		out.append(str(k))
	out.sort()
	return out

static func data(kind: String) -> Dictionary:
	return META.get(kind, META["straight"]).duplicate(true)

static func tier(kind: String) -> int:
	return int(data(kind).get("tier", 1))

static func intensity(kind: String) -> float:
	return float(data(kind).get("intensity", 0.2))

static func compatible(previous: String, next_kind: String) -> bool:
	if previous == "":
		return true
	var bad: Array = data(next_kind).get("reads_poorly_after", [])
	return previous not in bad


static func quantize_bars_for(kind: String, bars: float) -> float:
	# Gaps are the one deliberate quarter-bar exception. At 174 BPM this keeps
	# launch-or-die distances close to the original physical verb instead of
	# inflating a 14 m gap into ~22 m at the 32 m/s authoring baseline.
	if kind == "gap":
		return Tempo.quantize_bars_step(bars, 0.25, 0.25)
	return Tempo.quantize_bars(bars)

static func default_segment(kind: String, intensity_scale: float = 1.0) -> Dictionary:
	var i = clampf(intensity(kind) * intensity_scale, 0.0, 1.0)
	var bars_by_kind = {
		"gap": 0.25, "ramp": 1.0, "patch": 1.5, "crest": 2.0, "updraft": 2.0,
		"straight": 2.0, "compression": 2.0, "funnel": 2.0,
		"bowl": 2.5, "drop": 2.5, "ridge": 2.5, "hazard": 2.5,
		"tunnel": 3.0, "bank": 3.0, "avalanche": 3.0, "shaft": 3.0,
		"conveyor": 3.0, "wall": 3.0, "split": 3.5, "chicane": 3.5,
		"transfer": 3.5, "bank_to_wall": 3.5, "fullpipe": 4.0, "corkscrew": 4.0,
	}
	var base_bars = float(bars_by_kind.get(kind, 2.0))
	# Intensity changes phrase duration only inside a narrow, musical window.
	var scale = lerpf(0.85, 1.25, clampf((intensity_scale - 0.85) / 0.40, 0.0, 1.0))
	var d = {"kind": kind, "bars": quantize_bars_for(kind, base_bars * scale), "slope": 8.0 + i * 14.0, "width": 18.0 - i * 5.0}
	match kind:
		"straight": d.merge({"slope": 10.0, "width": 18.0}, true)
		"drop": d.merge({"slope": 25.0, "width": 17.0}, true)
		"bank": d.merge({"turn": 48.0, "bank": -20.0, "width": 16.0}, true)
		"bowl": d.merge({"bowl": 5.0, "width": 22.0}, true)
		"ramp": d.merge({"launch": 9.0, "width": 15.0}, true)
		"gap": d.merge({"slope": 18.0}, true)
		"wall": d.merge({"wall": 5.5, "width": 18.0}, true)
		"funnel": d.merge({"width": 7.5}, true)
		"crest": d.merge({"crest": 12.0, "width": 16.0}, true)
		"compression": d.merge({"compression": 10.0, "width": 17.0}, true)
		"patch": d.merge({"surface": SurfaceKind.SLIPPERY, "width": 17.0}, true)
		"chicane": d.merge({"turn": 58.0, "bank": 18.0, "width": 15.0}, true)
		"ridge": d.merge({"ridge": 3.8, "width": 9.0}, true)
		"transfer": d.merge({"transfer": 6.0, "wall": 7.0, "width": 18.0}, true)
		"bank_to_wall": d.merge({"turn": 45.0, "bank": 72.0, "wall": 4.5, "width": 17.0}, true)
		"corkscrew": d.merge({"turn": 70.0, "bank": 170.0, "width": 16.0}, true)
		"fullpipe": d.merge({"bowl": 10.0, "wall": 9.0, "width": 19.0, "pipe": 1.0}, true)
		"shaft": d.merge({"slope": 68.0, "width": 16.0}, true)
		"conveyor": d.merge({"surface": SurfaceKind.CONVEYOR, "width": 16.0}, true)
		"avalanche": d.merge({"surface": SurfaceKind.AVALANCHE, "width": 18.0}, true)
		"updraft": d.merge({"updraft": 10.0, "width": 17.0}, true)
		"hazard": d.merge({"hazards": 3, "width": 16.0}, true)
		"split": d.merge({"split": 1.0, "width": 18.0}, true)
		"tunnel": d.merge({"tunnel": 1.0, "width": 15.0}, true)
	return d
