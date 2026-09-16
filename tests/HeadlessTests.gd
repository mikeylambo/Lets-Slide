extends Node

## Headless gate. Run with:
##   godot --headless -- --unit
##
## These are the things that must not silently break: the SM64 reference must
## stay deterministic and must still accelerate down a slope the way the decomp
## says it does; the production motor must lose speed when it turns; the track
## builder must produce collidable geometry with surface metadata; and the rank
## and record layers must not throw.

var failures = 0
var checks = 0

func _ready() -> void:
	print("── SLIDE headless tests ──")
	_test_sm64_math()
	_test_reference_determinism()
	_test_reference_accelerates_downhill()
	_test_production_turn_costs_speed()
	_test_production_landing_quality()
	_test_wall_response()
	_test_track_build()
	_test_course_build()
	_test_rank_and_records()
	_test_track_collides_from_above()
	_test_ramp_does_not_lift_the_landing()
	_test_full_verb_library()
	_test_campaign_catalog()
	_test_generator_contract()
	_test_weight_transfer_no_flat_pump()

	print("── %d checks, %d failures ──" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _test_track_collides_from_above() -> void:
	## Ribbon winding is frame-dependent, so a one-sided concave shape silently
	## loses collision from above and the slider falls through the world.
	var b = TrackBuilder.new()
	var root = b.build([{"kind": "straight", "length": 40.0, "slope": 10.0, "width": 14.0}],
		Vector3(0, 100, 0), 0.0)
	var two_sided = true
	for child in root.get_children():
		if child is StaticBody3D:
			for gc in child.get_children():
				if gc is CollisionShape3D and gc.shape is ConcavePolygonShape3D:
					two_sided = two_sided and gc.shape.backface_collision
	check("track collision is two-sided", two_sided)
	root.free()

func _test_ramp_does_not_lift_the_landing() -> void:
	## A kicker must not carry its launch angle into the following segment —
	## that raises the landing above the launch and the player flies under it.
	var b = TrackBuilder.new()
	var spec = [
		{"kind": "straight", "length": 60.0, "slope": 14.0, "width": 14.0},
		{"kind": "ramp", "length": 40.0, "slope": 14.0, "launch": 12.0},
		{"kind": "gap", "length": 14.0, "slope": 20.0},
		{"kind": "drop", "length": 80.0, "slope": 20.0},
	]
	var root = b.build(spec, Vector3(0, 300, 0), 0.0)
	var lip = b.sample_at(96.0)
	var landing = b.sample_at(130.0)
	check("landing sits below the launch lip", float(landing["pos"].y) < float(lip["pos"].y),
		"lip %.2f vs landing %.2f" % [lip["pos"].y, landing["pos"].y])
	root.free()

# ------------------------------------------------------------------ helpers
func check(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s %s" % [label, detail])

func _slope_state(deg: float, speed: float = 0.0) -> MotionState:
	var s = MotionState.new()
	var r = deg_to_rad(deg)
	s.floor_normal = Vector3(0.0, cos(r), sin(r)).normalized()
	s.grounded = true
	s.surface_class = SurfaceKind.VERY_SLIPPERY
	s.velocity = Vector3(0, 0, speed)
	s.sm64_face_yaw = 0
	s.sm64_slide_yaw = 0
	return s

# -------------------------------------------------------------------- tests
func _test_sm64_math() -> void:
	check("s16 wrap", Sm64Math.wrap_s16(0x8000) == -32768, str(Sm64Math.wrap_s16(0x8000)))
	check("sins(0x4000) ~ 1", absf(Sm64Math.sins(0x4000) - 1.0) < 0.0001)
	check("coss(0) == 1", absf(Sm64Math.coss(0) - 1.0) < 0.0001)
	var a = Sm64Math.atan2s(1.0, 0.0)
	check("atan2s(z=1,x=0) == 0", absf(float(a)) < 2.0, str(a))
	var b = Sm64Math.atan2s(0.0, 1.0)
	check("atan2s(z=0,x=1) == 0x4000", absf(float(b) - 16384.0) < 2.0, str(b))

func _test_reference_determinism() -> void:
	var motor = Sm64Motor.new()
	var p = MotorParams.new()
	p.model = MotorParams.Model.SM64_REFERENCE
	var inp = MotorInput.new()
	var results = []
	for run in 2:
		var s = _slope_state(30.0)
		for i in 240:
			motor.step(s, p, inp, 1.0 / p.sm64_hz)
		results.append(s.velocity)
	check("reference is deterministic", results[0].distance_to(results[1]) < 1e-9,
		"%s vs %s" % [results[0], results[1]])

func _test_reference_accelerates_downhill() -> void:
	var motor = Sm64Motor.new()
	var p = MotorParams.new()
	p.model = MotorParams.Model.SM64_REFERENCE
	var inp = MotorInput.new()
	var s = _slope_state(30.0)
	var speeds = []
	for i in 300:
		motor.step(s, p, inp, 1.0 / p.sm64_hz)
		speeds.append(s.flat_speed())
	check("reference accelerates on a 30° slope", speeds[60] > speeds[5], "%f -> %f" % [speeds[5], speeds[60]])
	check("reference reaches terminal slide speed", speeds[299] > 5.0, str(speeds[299]))
	# 100 units/frame at 30 Hz with 1 unit == 0.01 m is 30 m/s.
	var cap: float = p.sm64_speed_cap * Sm64Math.UNITS_TO_M * p.sm64_hz
	check("reference respects the unit-scale cap", speeds[299] <= cap + 0.01,
		"%f > %f" % [speeds[299], cap])

func _test_production_turn_costs_speed() -> void:
	var motor = SlideMotor.new()
	var p = MotorParams.new()
	var inp = MotorInput.new()

	var straight = _slope_state(20.0, 20.0)
	var turning = _slope_state(20.0, 20.0)
	inp.steer = 0.0
	for i in 120:
		motor.step(straight, p, inp, 1.0 / 120.0)
	inp.steer = 1.0
	for i in 120:
		motor.step(turning, p, inp, 1.0 / 120.0)

	check("steering bends the velocity vector", turning.velocity.normalized().dot(straight.velocity.normalized()) < 0.999)
	check("steering costs momentum", turning.speed < straight.speed,
		"turn %f vs straight %f" % [turning.speed, straight.speed])

func _test_production_landing_quality() -> void:
	var motor = SlideMotor.new()
	var p = MotorParams.new()

	var flush = MotionState.new()
	flush.floor_normal = Vector3.UP
	flush.velocity = Vector3(0, -0.2, 30.0)
	motor.on_landing(flush, p)

	var flat = MotionState.new()
	flat.floor_normal = Vector3.UP
	flat.velocity = Vector3(0, -30.0, 2.0)
	motor.on_landing(flat, p)

	check("flush landing keeps most speed", flush.last_landing_quality > 0.9, str(flush.last_landing_quality))
	check("faceplant landing is punished", flat.last_landing_quality < 0.2, str(flat.last_landing_quality))
	check("landing never produces NaN", not is_nan(flat.velocity.length()))

func _test_wall_response() -> void:
	var motor = SlideMotor.new()
	var p = MotorParams.new()

	var head_on = MotionState.new()
	head_on.velocity = Vector3(0, 0, 30.0)
	var was_bonk: bool = motor.on_wall(head_on, p, Vector3(0, 0, -1))
	check("head-on impact bonks", was_bonk)
	check("bonk sheds speed", head_on.velocity.length() < 30.0 * 0.5, str(head_on.velocity.length()))

	var graze = MotionState.new()
	graze.velocity = Vector3(30.0, 0, 2.0)
	var grazed: bool = motor.on_wall(graze, p, Vector3(0, 0, -1))
	check("glancing impact does not bonk", not grazed)
	check("glancing keeps most speed", graze.velocity.length() > 26.0, str(graze.velocity.length()))

func _test_track_build() -> void:
	var b = TrackBuilder.new()
	var spec = [
		{"kind": "straight", "length": 40.0, "slope": 10.0, "width": 14.0},
		{"kind": "bank", "length": 60.0, "slope": 14.0, "turn": -45.0, "bank": 22.0},
		{"kind": "ramp", "length": 30.0, "launch": 16.0},
		{"kind": "gap", "length": 20.0},
		{"kind": "drop", "length": 40.0, "slope": 24.0},
	]
	var root = b.build(spec, Vector3.ZERO, 0.0)
	check("builder produced samples", b.samples.size() > 40, str(b.samples.size()))
	check("builder measured length", b.total_length > 150.0, str(b.total_length))

	var bodies = 0
	var shapes = 0
	for child in root.get_children():
		if child is StaticBody3D:
			bodies += 1
			check("body carries surface metadata", child.has_meta("surface_class"), child.name)
			for gc in child.get_children():
				if gc is CollisionShape3D and gc.shape is ConcavePolygonShape3D:
					shapes += 1
					check("collision has faces", gc.shape.get_faces().size() > 0, child.name)
	check("builder emitted collidable bodies", bodies > 0, str(bodies))
	check("builder emitted collision shapes", shapes > 0, str(shapes))

	# The track must descend — a course that climbs is a broken verb list.
	var first: Vector3 = b.samples[0]["pos"]
	var last: Vector3 = b.samples[b.samples.size() - 1]["pos"]
	check("track descends", last.y < first.y - 20.0, "%f -> %f" % [first.y, last.y])
	root.free()

func _test_course_build() -> void:
	var built = Course01.build()
	check("course built", built.has("root"))
	check("course has pickups", built["pickups"].size() > 10, str(built["pickups"].size()))
	check("course has a mastery collectible", built["mastery"] != null)
	check("course has checkpoints", built["checkpoints"].size() >= 4, str(built["checkpoints"].size()))
	check("course has a finish", built["finish"] != null)
	check("course length matches 20-bar teaching target", built["length"] > 820.0 and built["length"] < 950.0, str(built["length"]))
	var start: Vector3 = built["start_position"]
	check("start above kill plane", start.y > float(built["kill_y"]), "%f vs %f" % [start.y, built["kill_y"]])
	built["root"].free()

func _test_rank_and_records() -> void:
	var course = Course01.data()
	var perfect = Rank.evaluate(course, {
		"time": course.author_time, "score": course.par_score,
		"avg_momentum": 1.0, "mastery": 1,
	})
	var poor = Rank.evaluate(course, {
		"time": course.bronze_time * 1.4, "score": 0,
		"avg_momentum": 0.1, "mastery": 0,
	})
	check("perfect run ranks SS or S", perfect["rank"] in ["SS", "S"], str(perfect["rank"]))
	check("poor run ranks D", poor["rank"] == "D", str(poor["rank"]))
	check("rank ordering works", Rank.is_better("S", "A") and not Rank.is_better("C", "B"))

	check("medal thresholds ordered",
		course.medal_for(course.author_time) == "AUTHOR"
		and course.medal_for(course.gold_time) == "GOLD"
		and course.medal_for(course.bronze_time + 1.0) == "")


func _test_full_verb_library() -> void:
	var names = VerbLibrary.all_names()
	check("verb library has 24 verbs", names.size() == 24, str(names.size()))
	for name in names:
		var meta = VerbLibrary.data(name)
		check("verb %s has tier" % name, int(meta.get("tier", 0)) in [1, 2, 3, 4])
		check("verb %s has intensity" % name, float(meta.get("intensity", -1.0)) >= 0.0 and float(meta.get("intensity", 2.0)) <= 1.0)
		check("verb %s has speed effect" % name, str(meta.get("speed_effect", "")) in ["build", "hold", "spend"])
		var b = TrackBuilder.new()
		var seg = VerbLibrary.default_segment(name)
		var root = b.build([seg], Vector3(0.0, 120.0, 0.0), 0.0)
		check("verb %s builds samples" % name, b.samples.size() > 2, str(b.samples.size()))
		root.free()

func _test_campaign_catalog() -> void:
	var courses = Courses.all()
	check("campaign has 25 authored courses", courses.size() == 25, str(courses.size()))
	var descents = 0
	var ids = {}
	for course in courses:
		ids[course.id] = true
		if course.is_descent:
			descents += 1
		check("course %s has verb spec" % course.id, not course.spec.is_empty())
		check("course %s bar budget matches spec" % course.id, absf(CourseCatalog.spec_bars(course.spec) - course.total_bars) < 0.01, "%f vs %f" % [CourseCatalog.spec_bars(course.spec), course.total_bars])
		check("course %s medal order" % course.id,
			course.author_time < course.gold_time and course.gold_time < course.silver_time and course.silver_time < course.bronze_time)
	check("campaign has five region Descents", descents == 5, str(descents))
	check("campaign ids unique", ids.size() == 25, str(ids.size()))
	check("region gates match design", CourseCatalog.REGIONS[0]["gate"] == 0 and CourseCatalog.REGIONS[4]["gate"] == 18)
	check("tempo is 174 BPM", is_equal_approx(Tempo.BPM, 174.0))
	check("beat grid quantizes half bars", is_equal_approx(Tempo.quantize_bars(2.26), 2.5))
	check("gap keeps quarter-bar exception", is_equal_approx(float(VerbLibrary.default_segment("gap").get("bars", 0.0)), 0.25))
	var threshold := CourseCatalog.all_courses()[0]
	check("course specs are authored in bars", threshold.spec.all(func(seg): return seg.has("bars")))
	check("Threshold 1 is 20 bars", is_equal_approx(CourseCatalog.spec_bars(threshold.spec), 20.0), str(CourseCatalog.spec_bars(threshold.spec)))
	check("campaign has five named forms", CourseForm.NAMES.size() == 5)
	var forms_seen := {}
	for c in CourseCatalog.all_courses(): forms_seen[c.form] = true
	check("campaign uses all five forms", forms_seen.size() == 5, str(forms_seen.keys()))
	check("serialized course directory exists", DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(Courses.COURSE_DIR)))
	check("serialized course 01 exists", ResourceLoader.exists("res://content/courses/course_01.tres"))
	var b32 := CourseFactory.build(threshold, 32.0)
	var b40 := CourseFactory.build(threshold, 40.0)
	var ratio := float(b40["length"]) / maxf(float(b32["length"]), 0.001)
	check("author speed rescales mountain", absf(ratio - 1.25) < 0.035, str(ratio))
	check("rescale preserves beat map", b32["beat_map"] == b40["beat_map"])
	b32["root"].free(); b40["root"].free()

func _test_generator_contract() -> void:
	for region in range(5):
		var generated = CourseGenerator.generate(12345 + region * 991, region, 32.0, "test_gen_%d" % region)
		var validation = GenerationValidator.validate(generated.spec)
		check("generator region %d returns a course" % region, generated.generated and not generated.spec.is_empty())
		check("generator region %d is structurally valid" % region, bool(validation.get("ok", false)), str(validation))
		check("generator region %d stays in vocabulary" % region, _spec_in_vocab(generated.spec, CourseCatalog.REGIONS[region]["vocab"]))
	var a = CourseGenerator.generate(777, 2, 32.0, "a")
	var b = CourseGenerator.generate(777, 2, 32.0, "b")
	check("seeded generator is deterministic", JSON.stringify(a.spec) == JSON.stringify(b.spec))

func _spec_in_vocab(spec: Array, vocab: Array) -> bool:
	for seg in spec:
		if str(seg.get("kind", "")) not in vocab:
			return false
	return true

func _test_weight_transfer_no_flat_pump() -> void:
	var motor = SlideMotor.new()
	var p = MotorParams.new()
	p.gravity = 0.0
	p.flat_friction = 0.0
	p.downhill_friction = 0.0
	p.uphill_friction = 0.0
	p.drag_quadratic = 0.0
	var neutral = MotionState.new()
	neutral.grounded = true
	neutral.floor_normal = Vector3.UP
	neutral.previous_floor_normal = Vector3.UP
	neutral.velocity = Vector3(0.0, 0.0, 20.0)
	var pumping = MotionState.new()
	pumping.grounded = true
	pumping.floor_normal = Vector3.UP
	pumping.previous_floor_normal = Vector3.UP
	pumping.velocity = Vector3(0.0, 0.0, 20.0)
	var input_neutral = MotorInput.new()
	var input_pump = MotorInput.new()
	input_pump.lean = 1.0
	for i in 240:
		motor.step(neutral, p, input_neutral, 1.0 / 120.0)
		motor.step(pumping, p, input_pump, 1.0 / 120.0)
	check("weight transfer cannot pump flat terrain", absf(neutral.speed - pumping.speed) < 0.001, "%f vs %f" % [neutral.speed, pumping.speed])
