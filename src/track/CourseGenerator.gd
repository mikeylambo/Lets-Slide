class_name CourseGenerator
extends RefCounted

const CURVES = ["steady_climb", "double_drop", "late_spike", "sawtooth", "front_loaded"]

static func daily() -> CourseData:
	var key = Game.daily_key()
	return generate(key.hash(), 0, 32.0, "daily_%s" % key, "DAILY DESCENT", "Today's blind read")

static func endless(prestige: int) -> CourseData:
	var seed = int(Time.get_ticks_usec()) ^ (prestige * 7919)
	var region = clampi(prestige / 2, 0, 4)
	return generate(seed, region, 32.0 + minf(32.0, float(prestige) * 2.0), "endless_%d_%d" % [prestige, seed], "ENDLESS %02d" % (prestige + 1), "Prestige %d · sight-read only" % (prestige + 1))

static func generate(seed: int, region_index: int, total_bars: float = 32.0, id: String = "generated", title: String = "GENERATED", subtitle: String = "", forced_form: String = "") -> CourseData:
	var region = clampi(region_index,0,4)
	var form = forced_form if forced_form != "" else CURVES[abs(seed) % CURVES.size()]
	var vocab: Array = CourseCatalog.REGIONS[region]["vocab"]
	var spec = CourseForm.fill(form, total_bars, vocab, seed, 0.96 + float(region) * 0.06)
	var validation = GenerationValidator.validate(spec)
	if not bool(validation.get("ok", false)):
		spec = CourseForm.fill("steady_climb", total_bars, vocab, seed + 17, 0.92)

	var d = CourseData.new()
	d.id = id; d.title = title; d.subtitle = subtitle
	d.region_index = region; d.region = str(CourseCatalog.REGIONS[region]["name"])
	d.generated = true; d.seed = seed; d.spec = spec
	d.total_bars = CourseCatalog.spec_bars(spec); d.form = form; d.bpm = Tempo.BPM
	d.medal_source = "provisional"
	d.tension_curve = _tension_for_form(form, spec.size())
	d.signature_moment = "Generated %s form · seed %d" % [form, seed]
	# Generated content uses musical duration as a provisional author target;
	# accepted campaign exports are replaced with physical probe measurements.
	d.author_time = Tempo.course_seconds(total_bars) * 0.84
	d.gold_time = d.author_time * 1.08; d.silver_time = d.author_time * 1.22; d.bronze_time = d.author_time * 1.45
	d.par_score = int(total_bars * 145.0); d.mastery_count = 1
	return d

static func _tension_for_form(form: String, count: int) -> Array[float]:
	var out: Array[float] = []
	for i in range(maxi(count, 1)):
		var t = float(i) / maxf(float(count - 1), 1.0)
		out.append(_curve(form, t))
	return out

static func _curve(name: String, t: float) -> float:
	match name:
		"steady_climb": return lerpf(0.20, 0.84, t)
		"double_drop": return 0.24 + 0.58 * pow(absf(sin(t * TAU)), 1.3)
		"late_spike": return 0.24 + 0.66 * smoothstep(0.55, 0.92, t)
		"sawtooth": return 0.22 + fmod(t * 4.0, 1.0) * 0.62
		"front_loaded": return lerpf(0.84, 0.28, t)
	return 0.4
