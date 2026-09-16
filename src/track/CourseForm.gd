class_name CourseForm
extends RefCounted

const NAMES := ["steady_climb", "double_drop", "late_spike", "sawtooth", "front_loaded"]

# Canonical 32-bar forms. Block durations scale to the requested total and are
# corrected on the final block so every course ends exactly on-grid.
const FORMS := {
	"steady_climb": [[4.0,"intro"],[8.0,"build"],[8.0,"build"],[8.0,"peak"],[4.0,"out"]],
	"double_drop": [[4.0,"intro"],[8.0,"peak"],[4.0,"rest"],[12.0,"peak"],[4.0,"out"]],
	"late_spike": [[8.0,"roller"],[8.0,"roller"],[4.0,"build"],[8.0,"peak"],[4.0,"out"]],
	"sawtooth": [[4.0,"peak"],[4.0,"rest"],[4.0,"peak"],[4.0,"rest"],[4.0,"peak"],[4.0,"rest"],[4.0,"peak"],[4.0,"out"]],
	"front_loaded": [[12.0,"peak"],[4.0,"rest"],[8.0,"build"],[4.0,"peak"],[4.0,"out"]],
}

static func blocks(form: String, total_bars: float) -> Array:
	var src: Array = FORMS.get(form, FORMS["steady_climb"])
	var out: Array = []
	var scale = total_bars / 32.0
	var used = 0.0
	for i in range(src.size()):
		var bars = Tempo.quantize_bars(float(src[i][0]) * scale)
		if i == src.size() - 1:
			bars = maxf(0.5, total_bars - used)
		out.append({"bars": bars, "role": str(src[i][1])})
		used += bars
	return out

static func fill(form: String, total_bars: float, vocab: Array, seed: int, intensity_scale: float = 1.0) -> Array:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	var spec: Array = []
	var previous = ""
	# Give each generated course a small recurring vocabulary. About 70% of
	# eligible draws prefer these motifs, so a course repeats recognizable ideas
	# instead of becoming a uniform random walk through the region vocabulary.
	var motif_verbs: Array[String] = []
	var motif_pool: Array[String] = []
	for raw in vocab:
		var motif_kind = str(raw)
		if motif_kind not in motif_pool:
			motif_pool.append(motif_kind)
	# Seeded Fisher-Yates so generated courses remain deterministic.
	for i in range(motif_pool.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = motif_pool[i]
		motif_pool[i] = motif_pool[j]
		motif_pool[j] = tmp
	var motif_count = clampi(int(ceil(float(motif_pool.size()) / 4.0)), 2, 3)
	for i in range(mini(motif_count, motif_pool.size())):
		motif_verbs.append(motif_pool[i])
	# Guarantee the recurring vocabulary can actually participate in both high
	# pressure and recovery blocks. Otherwise the 70% motif weighting silently
	# disappears for half the form.
	var has_peak = false
	var has_rest = false
	for kind in motif_verbs:
		var meta = VerbLibrary.data(kind)
		has_peak = has_peak or float(meta.get("intensity", 0.0)) >= 0.55
		has_rest = has_rest or bool(meta.get("recovery", false))
	if not has_peak:
		for kind in motif_pool:
			if float(VerbLibrary.data(kind).get("intensity", 0.0)) >= 0.55:
				if motif_verbs.size() >= motif_count: motif_verbs[motif_verbs.size()-1] = kind
				else: motif_verbs.append(kind)
				break
	if not has_rest:
		for kind in motif_pool:
			if bool(VerbLibrary.data(kind).get("recovery", false)):
				if kind not in motif_verbs:
					if motif_verbs.size() >= motif_count: motif_verbs[0] = kind
					else: motif_verbs.append(kind)
				break
	for block in blocks(form, total_bars):
		var remaining = float(block["bars"])
		var role = str(block["role"])
		while remaining > 0.001:
			var candidates: Array[String] = []
			for raw in vocab:
				var kind = str(raw)
				if not VerbLibrary.compatible(previous, kind): continue
				var meta = VerbLibrary.data(kind)
				var intensity = float(meta.get("intensity", 0.2))
				var ok = false
				match role:
					"peak": ok = intensity >= 0.55
					"rest": ok = bool(meta.get("recovery", false))
					"build": ok = str(meta.get("speed_effect", "hold")) == "build"
					"intro", "out": ok = intensity <= 0.45 or bool(meta.get("recovery", false))
					"roller": ok = intensity >= 0.28 and intensity <= 0.68
				if ok: candidates.append(kind)
			if candidates.is_empty(): candidates = ["straight"]
			var motif_candidates: Array[String] = []
			for candidate in candidates:
				# A motif should recur with contrast (A-B-A), not stack like a stuck
				# record (A-A-A).
				if candidate in motif_verbs and candidate != previous:
					motif_candidates.append(candidate)
			var draw_pool: Array[String] = motif_candidates if (not motif_candidates.is_empty() and rng.randf() < 0.70) else candidates
			var kind = draw_pool[rng.randi_range(0, draw_pool.size()-1)]
			var seg = VerbLibrary.default_segment(kind, intensity_scale)
			var seg_bars = minf(float(seg.get("bars", 2.0)), remaining)
			seg["bars"] = VerbLibrary.quantize_bars_for(kind, seg_bars)
			if float(seg["bars"]) > remaining: seg["bars"] = remaining
			if kind == "bank":
				var sign = -1.0 if rng.randf() < 0.5 else 1.0
				seg["turn"] = absf(float(seg.get("turn",45.0))) * sign
				seg["bank"] = -absf(float(seg.get("bank",20.0))) * sign
			if kind == "patch":
				seg["surface"] = [SurfaceKind.SLIPPERY, SurfaceKind.HIGH_FRICTION, SurfaceKind.BOOST][rng.randi_range(0,2)]
			spec.append(seg)
			remaining -= float(seg["bars"])
			previous = kind
	return spec
