extends RefCounted

## Maps a world position onto the authored course: distance along the main
## line, the 0-based bar offset (same units as CourseData spec / segment_ranges)
## and the segment underneath. Windowed search keeps it cheap at 120 Hz.

var builder: TrackBuilder
var _idx = 0

func _init(b: TrackBuilder) -> void:
	builder = b

func reset() -> void:
	_idx = 0

func locate(pos: Vector3) -> Dictionary:
	var samples = builder.samples
	var n = samples.size()
	if n == 0:
		return {"dist": 0.0, "bar": 0.0, "segment": -1, "kind": ""}
	var best = _scan(pos, maxi(0, _idx - 40), mini(n - 1, _idx + 80))
	if pos.distance_squared_to(samples[best]["pos"]) > 900.0:
		best = _scan(pos, 0, n - 1)   # respawn / teleport / parallel route
	_idx = best
	var dist = float(samples[best]["dist"])
	var seg = segment_at(dist)
	return {"dist": dist, "bar": bar_at(dist), "segment": seg,
		"kind": str(builder.segment_ranges[seg]["kind"]) if seg >= 0 else ""}

func _scan(pos: Vector3, lo: int, hi: int) -> int:
	var best = lo
	var best_d = INF
	for i in range(lo, hi + 1):
		var d = pos.distance_squared_to(builder.samples[i]["pos"])
		if d < best_d:
			best_d = d
			best = i
	return best

func segment_at(dist: float) -> int:
	var ranges = builder.segment_ranges
	for i in ranges.size():
		if dist <= float(ranges[i]["to"]):
			return i
	return ranges.size() - 1

func bar_at(dist: float) -> float:
	var seg = segment_at(dist)
	if seg < 0:
		return 0.0
	var r: Dictionary = builder.segment_ranges[seg]
	var span = maxf(float(r["to"]) - float(r["from"]), 0.001)
	var t = clampf((dist - float(r["from"])) / span, 0.0, 1.0)
	return lerpf(float(r["bar_from"]), float(r["bar_to"]), t)

func total_bars() -> float:
	var ranges = builder.segment_ranges
	return float(ranges[ranges.size() - 1]["bar_to"]) if not ranges.is_empty() else 0.0
