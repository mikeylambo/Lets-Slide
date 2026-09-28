extends RefCounted

## Builds the paste-back handoff: playtests/<session>/summary.md.
## Written after every run so a crash or hard close never loses a session.

static func build(h) -> String:
	var s: Dictionary = h.session
	var runs: Array = h.runs
	var course: CourseData = h.course
	var L = PackedStringArray()
	var finished = runs.filter(func(r): return bool(r["finished"]))
	var elapsed = int(Time.get_unix_time_from_system() - float(s["started_unix"]))

	L.append("# Let's Slide — Playtest %s" % s["id"])
	L.append("")
	L.append("- **Course:** `%s` %s · %.1f bars @ %d BPM · author %.2f s" % [
		course.id, course.title, h.total_bars(), int(Tempo.BPM), course.author_time])
	L.append("- **Build:** %s · Godot %s" % [s["commit"], s["godot"]])
	L.append("- **Session:** %d runs (%d finished) · %dm %02ds · %d markers" % [
		runs.size(), finished.size(), elapsed / 60, elapsed % 60, h.markers.size()])
	if not h.blind_reveal.is_empty():
		L.append("- **Blind reveal:** " + " · ".join(h.blind_reveal))
	L.append("- Bars are 0-based offsets, the same units as `CourseData.spec` / `segment_ranges`.")
	L.append("")

	# ---------------------------------------------------------- best times
	L.append("## Best times per preset")
	L.append("")
	L.append("| Preset | Runs | Finished | Best | Avg | Top speed | Avg rating | All-time ghost |")
	L.append("|---|---:|---:|---:|---:|---:|---:|---:|")
	var keys = []
	for r in runs:
		if not keys.has(r["key"]): keys.append(r["key"])
	if keys.is_empty():
		L.append("| — | 0 | 0 | — | — | — | — | — |")
	for k in keys:
		var rs = runs.filter(func(r): return r["key"] == k)
		var fin = rs.filter(func(r): return bool(r["finished"]) and not bool(r["mixed"]))
		var best = INF
		var tsum = 0.0
		for r in fin:
			best = minf(best, float(r["time"]))
			tsum += float(r["time"])
		var top = 0.0
		var rated = 0
		var rsum = 0
		for r in rs:
			top = maxf(top, float(r["top_speed"]))
			if int(r["rating"]) > 0:
				rated += 1
				rsum += int(r["rating"])
		var gb = h.ghost_best(str(rs[0]["preset"]))
		L.append("| %s | %d | %d | %s | %s | %.1f m/s | %s | %s |" % [
			k, rs.size(), fin.size(),
			_t(best) if best < INF else "—",
			_t(tsum / fin.size()) if not fin.is_empty() else "—",
			top, ("%.1f ★ (%d)" % [float(rsum) / rated, rated]) if rated > 0 else "—",
			_t(gb) if gb > 0.0 else "—"])
	L.append("")

	# ------------------------------------------------------------- markers
	L.append("## Markers")
	L.append("")
	if h.markers.is_empty():
		L.append("_None dropped (N / controller Select)._")
	else:
		L.append("| # | Run | Preset | Run time | Course bar | Segment | Speed | State |")
		L.append("|---:|---:|---|---:|---:|---|---:|---|")
		for m in h.markers:
			L.append("| %d | %d | %s | %.2f s | **%.2f** | #%d %s | %.1f m/s | %s |" % [
				int(m["n"]), int(m["run"]), m["preset_key"], float(m["t"]), float(m["bar"]),
				int(m["segment"]), m["kind"], float(m["speed"]), "ground" if bool(m["grounded"]) else "air"])
	L.append("")

	# ------------------------------------------------------------- tuning
	var diffs = PackedStringArray()
	for vk in h.variants.keys():
		var v: Dictionary = h.variants[vk]
		if str(v["variant"]) == "":
			continue
		var changes = PackedStringArray()
		var base: Dictionary = v["baseline"]
		var now: Dictionary = v["params"]
		for row in MotorParams.SCHEMA:
			var p: String = row[0]
			if base.has(p) and now.has(p) and not is_equal_approx(float(base[p]), float(now[p])):
				changes.append("  - `%s`: %s → **%s**" % [p, _n(float(base[p])), _n(float(now[p]))])
		if not changes.is_empty():
			diffs.append("- **%s** (vs saved `%s`)" % [vk, v["preset"]])
			diffs.append_array(changes)
	if not diffs.is_empty():
		L.append("## Tuning deltas vs saved presets")
		L.append("")
		L.append_array(diffs)
		L.append("")

	# ----------------------------------------------------------------- runs
	L.append("## Runs")
	L.append("")
	L.append("| Run | Preset | Seen as | Outcome | Time | Top | Avg | Pops | Land Q | Bonks | Markers | Rating | Notes |")
	L.append("|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|")
	for r in runs:
		var notes = PackedStringArray()
		if bool(r["mixed"]): notes.append("A/B swapped mid-run")
		if bool(r["tweaked"]): notes.append("tuned mid-run")
		L.append("| %d | %s | %s | %s | %s | %.1f | %.1f | %d | %s | %d | %d | %s | %s |" % [
			int(r["run"]), r["key"], r["seen_as"], r["outcome"], _t(float(r["time"])),
			float(r["top_speed"]), float(r["avg_speed"]), int(r["pops"]),
			("%.0f%%" % (float(r["landing_quality"]) * 100.0)) if float(r["landing_quality"]) >= 0.0 else "—",
			int(r["bonks"]), int(r["markers"]),
			"★".repeat(int(r["rating"])) + "☆".repeat(5 - int(r["rating"])) if int(r["rating"]) > 0 else "—",
			", ".join(notes)])
	L.append("")
	L.append("Raw data: `%s`" % ProjectSettings.globalize_path(str(s["dir"])))
	L.append("")
	return "\n".join(L)

static func _t(t: float) -> String:
	return "%.3f s" % t if t > 0.0 else "—"

static func _n(v: float) -> String:
	return str(snappedf(v, 0.0001))
