class_name GenerationValidator
extends RefCounted

## Fast structural gate used before a generated seed is instantiated. The real
## headless CourseProbe remains the physical gate; this rejects obviously bad
## rhythm/speed sequences first.

static func validate(spec: Array) -> Dictionary:
	if spec.size() < 5: return {"ok": false, "reason": "too_short"}
	var high_run = 0
	var speed_est = 10.0
	var max_high = 0
	for seg in spec:
		var kind = str(seg.get("kind", "straight"))
		var meta = VerbLibrary.data(kind)
		var intensity = float(meta.get("intensity", 0.2))
		high_run = high_run + 1 if intensity > 0.7 else 0
		max_high = maxi(max_high, high_run)
		if high_run > 2 and not bool(meta.get("recovery", false)):
			return {"ok": false, "reason": "no_rest_beat"}
		var need = float(meta.get("requires_entry_speed", 0.0))
		if need > speed_est + 8.0:
			return {"ok": false, "reason": "speed_gate", "kind": kind, "need": need, "estimate": speed_est}
		match str(meta.get("speed_effect", "hold")):
			"build": speed_est = minf(58.0, speed_est + 6.0)
			"spend": speed_est = maxf(8.0, speed_est - 4.0)
			_: speed_est = maxf(10.0, speed_est - 0.5)
	return {"ok": true, "max_high_run": max_high, "speed_estimate": speed_est}
