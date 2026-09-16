class_name CourseCatalog
extends RefCounted

const REGIONS = [
	{"name":"THRESHOLD","subtitle":"Learning the mountain","gate":0,"vocab":["straight","drop","bank","bowl","ramp","gap","wall","funnel","crest","patch","split","tunnel"]},
	{"name":"THE COMBS","subtitle":"Rhythm and speed economy","gate":3,"vocab":["straight","drop","bank","bowl","crest","patch","split","tunnel","compression","chicane","conveyor","hazard"]},
	{"name":"SKYFALL","subtitle":"The aerial chapter","gate":7,"vocab":["straight","drop","bank","bowl","ramp","gap","wall","crest","compression","shaft","updraft","transfer","bank_to_wall"]},
	{"name":"NEEDLEWORK","subtitle":"Precision under consequence","gate":12,"vocab":["straight","drop","bank","bowl","funnel","crest","compression","chicane","ridge","avalanche","hazard","split","tunnel"]},
	{"name":"THE THROAT","subtitle":"Orientation and commitment","gate":18,"vocab":["straight","drop","bank","bowl","wall","crest","compression","transfer","bank_to_wall","ridge","shaft","corkscrew","fullpipe"]},
]
const TITLES = [
	["FALL LESSON","TWO WAYS DOWN","SURFACE READ","OPEN THROTTLE","THRESHOLD DESCENT"],
	["LOAD","COUNTER","MOVING GROUND","TEETH","COMBS DESCENT"],
	["DROP THROUGH","BORROWED AIR","CROSSOVER","PAST VERTICAL","SKYFALL DESCENT"],
	["THE SPINE","WHITEOUT","NARROWS","THREAD","NEEDLE DESCENT"],
	["ROLL OVER","PIPE DREAM","NO HORIZON","THE MOUTH","THROAT DESCENT"],
]
const INTRODUCES = [
	["crest","split","patch","tunnel","crest"], ["compression","chicane","conveyor","hazard","compression"],
	["shaft","updraft","transfer","bank_to_wall","shaft"], ["ridge","avalanche","funnel","hazard","ridge"],
	["corkscrew","fullpipe","transfer","bank_to_wall","corkscrew"],
]
const FORMS = ["steady_climb","late_spike","sawtooth","front_loaded","double_drop"]
const SIGNATURES = [
	["The first natural crest teaches that terrain is the jump button.","A high split only opens if speed was protected through the preceding bank.","Three surface bands turn friction into a readable line choice.","A tunnel crest hides the landing until commitment, then opens into the void.","Four parallel lines stay visible together before one enormous final release."],
	["A compression loads the rider and fires directly into a rising bank.","Alternating chicanes resolve like a drum fill into a clean bowl.","A moving surface changes the timing of an otherwise familiar line.","A hazard corridor rewards holding rhythm instead of panic steering.","Two major drops frame a breakdown that lets the player reset their line."],
	["A vertical shaft turns falling itself into the route.","An updraft extends a line that looks impossible from the entry.","Twin walls create the first committed wall-to-wall crossover.","A bank keeps rotating until the floor becomes a wall.","Aerial verbs chain into a long descent with no conventional jump."],
	["A narrow ridge hangs over open space with two recoverable fall lines.","The mountain itself drifts under the rider during an avalanche section.","A narrowing high-speed funnel becomes the region's nerve test.","Hazards force a line decision before the safe route becomes visible.","A long precision run compresses the whole region into one thread."],
	["The first corkscrew rotates the world without changing the control contract.","A fullpipe gives total line freedom while the horizon disappears.","A transfer exits enclosure into a suspended exterior line.","A bank-to-wall sequence asks for commitment before orientation is obvious.","The final corkscrew/fullpipe synthesis turns the entire Shelf inside out."],
]

static func all_courses() -> Array[CourseData]:
	var out: Array[CourseData] = []
	for r in range(5):
		for c in range(5): out.append(_make(r,c))
	return out

static func _make(region_i: int, course_i: int) -> CourseData:
	var d = CourseData.new()
	var num = region_i * 5 + course_i + 1
	d.id = "course_%02d" % num; d.region_index = region_i; d.course_index = course_i
	d.region = str(REGIONS[region_i]["name"]); d.unlock_medals = int(REGIONS[region_i]["gate"])
	d.title = str(TITLES[region_i][course_i]); d.subtitle = "%s · %s" % [REGIONS[region_i]["subtitle"], INTRODUCES[region_i][course_i]]
	d.is_descent = course_i == 4; d.form = FORMS[region_i] if d.is_descent else FORMS[course_i]
	d.total_bars = 64.0 if d.is_descent else (20.0 if region_i == 0 and course_i < 2 else 32.0)
	d.bpm = Tempo.BPM; d.signature_moment = str(SIGNATURES[region_i][course_i]) if region_i == 0 else ""
	d.spec = _spec_for(region_i, course_i, d.form, d.total_bars)
	d.total_bars = spec_bars(d.spec)
	# Bootstrap timings are musical-duration estimates. Phase C replaces Region I
	# with measured physical probe times before release.
	d.medal_source = "provisional"
	d.author_time = Tempo.course_seconds(d.total_bars) * 0.84
	d.gold_time = d.author_time * 1.08; d.silver_time = d.author_time * 1.22; d.bronze_time = d.author_time * 1.45
	d.par_score = 0 if num == 1 else int(d.total_bars * (135.0 + float(region_i)*18.0))
	d.mastery_count = 0 if num == 1 else 1
	return d

static func _spec_for(r: int, c: int, form: String, total_bars: float) -> Array:
	# Region I is authored as five actual courses. The remaining regions are
	# bootstrap content using distinct musical forms until their own authoring pass.
	if r == 0: return _threshold_spec(c)
	return CourseForm.fill(form, total_bars, REGIONS[r]["vocab"], 174000 + r*1000 + c*97, 0.95 + float(r)*0.06)

static func _threshold_spec(c: int) -> Array:
	match c:
		0: return [
			{"kind":"straight","bars":8.0,"slope":13.0,"width":18.0},
			{"kind":"crest","bars":4.0,"slope":13.0,"crest":19.0,"width":18.0},
			{"kind":"straight","bars":8.0,"slope":22.0,"width":20.0},
		]
		1: return [
			{"kind":"straight","bars":3.0,"slope":15.0,"width":20.0},
			{"kind":"split","bars":4.0,"slope":16.0,"width":20.0,"split_offset":6.5,"split_height":0.8},
			{"kind":"straight","bars":2.0,"slope":16.0,"width":20.0},
			{"kind":"bank","bars":4.0,"slope":16.0,"turn":-34.0,"bank":18.0,"width":19.0},
			{"kind":"split","bars":4.0,"slope":17.0,"width":20.0,"split_offset":7.0,"split_height":1.0},
			{"kind":"straight","bars":3.0,"slope":17.0,"width":21.0},
		]
		2: return [
			{"kind":"straight","bars":4.0,"slope":15.0,"width":20.0},
			{"kind":"patch","bars":4.0,"slope":15.0,"width":20.0,"surface":SurfaceKind.SLIPPERY},
			{"kind":"bank","bars":5.0,"slope":16.0,"turn":30.0,"bank":-17.0,"width":19.0},
			{"kind":"patch","bars":4.0,"slope":17.0,"width":19.0,"surface":SurfaceKind.HIGH_FRICTION},
			{"kind":"bowl","bars":5.0,"slope":17.0,"width":21.0,"bowl":2.2},
			{"kind":"patch","bars":4.0,"slope":18.0,"width":20.0,"surface":SurfaceKind.VERY_SLIPPERY},
			{"kind":"crest","bars":2.0,"slope":18.0,"crest":10.0,"width":21.0},
			{"kind":"straight","bars":4.0,"slope":20.0,"width":22.0},
		]
		3: return [
			{"kind":"straight","bars":4.0,"slope":16.0,"width":20.0},
			{"kind":"tunnel","bars":6.0,"slope":17.0,"width":20.0},
			{"kind":"crest","bars":2.0,"slope":17.0,"crest":9.0,"width":20.0},
			{"kind":"straight","bars":4.0,"slope":21.0,"width":21.0},
			{"kind":"split","bars":5.0,"slope":18.0,"width":20.0,"split_offset":6.0,"split_height":0.7},
			{"kind":"tunnel","bars":7.0,"slope":19.0,"width":19.0},
			{"kind":"straight","bars":4.0,"slope":20.0,"width":22.0},
		]
		_: return [
			{"kind":"straight","bars":6.0,"slope":14.0,"width":22.0}, {"kind":"crest","bars":4.0,"slope":15.0,"crest":10.0,"width":20.0},
			{"kind":"drop","bars":6.0,"slope":27.0,"width":20.0}, {"kind":"split","bars":7.0,"slope":17.0,"width":20.0,"split_offset":7.5,"split_height":1.4},
			{"kind":"bank","bars":7.0,"slope":17.0,"turn":-42.0,"bank":20.0,"width":19.0}, {"kind":"patch","bars":5.0,"slope":18.0,"width":19.0,"surface":SurfaceKind.SLIPPERY},
			{"kind":"tunnel","bars":8.0,"slope":19.0,"width":18.0}, {"kind":"bank","bars":7.0,"slope":18.0,"turn":46.0,"bank":-22.0,"width":18.0},
			{"kind":"bowl","bars":6.0,"slope":16.0,"width":23.0,"bowl":4.0}, {"kind":"crest","bars":4.0,"slope":20.0,"crest":13.0,"width":21.0},
			{"kind":"straight","bars":4.0,"slope":24.0,"width":24.0},
		]

static func spec_bars(spec: Array) -> float:
	var total = 0.0
	for seg in spec: total += float(seg.get("bars", 0.0))
	return total
