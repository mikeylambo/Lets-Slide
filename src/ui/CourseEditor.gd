class_name CourseEditor
extends Control

## Community course editor. Courses are verb lists in bars, the same grammar
## the campaign is authored in, so anything built here plays exactly like a
## campaign course. Rule borrowed from Trackmania: you must finish your own
## course to verify it before it can be shared; that run sets the author time.

const FEATURE = {
	"crest": ["crest", "CREST"], "compression": ["compression", "DIP"], "ramp": ["launch", "LAUNCH"],
	"bowl": ["bowl", "BOWL"], "fullpipe": ["bowl", "BOWL"], "wall": ["wall", "WALL"],
	"ridge": ["ridge", "RIDGE"], "updraft": ["updraft", "LIFT"], "hazard": ["hazards", "COUNT"],
	"transfer": ["transfer", "REACH"], "split": ["split_offset", "OFFSET"], "patch": ["surface", "SURFACE"],
}

var course: CourseData
var _title: LineEdit
var _region: OptionButton
var _stats: Label
var _rows: VBoxContainer
var _status: Label
var _share: Button
var _previous_id = ""

func _ready() -> void:
	if course == null: course = CustomCourses.template()
	_previous_id = course.id
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.backdrop())
	var margin = MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 50)
	margin.add_theme_constant_override("margin_top", 36); margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 8); margin.add_child(col)
	col.add_child(UiKit.label("COURSE EDITOR", UiKit.H2, UiKit.TEXT))

	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 12); col.add_child(head)
	_title = LineEdit.new(); _title.text = course.title; _title.max_length = 32
	_title.custom_minimum_size = Vector2(360, 40); _title.placeholder_text = "Course title"
	_title.text_changed.connect(func(t): course.title = t.to_upper(); _refresh(false))
	head.add_child(_title)
	_region = OptionButton.new(); _region.custom_minimum_size = Vector2(240, 40)
	for r in CourseCatalog.REGIONS: _region.add_item(str(r["name"]))
	_region.select(course.region_index)
	_region.item_selected.connect(func(i): course.region_index = i; course.region = str(CourseCatalog.REGIONS[i]["name"]); _edited())
	head.add_child(_region)
	_stats = UiKit.mono("", UiKit.BODY, UiKit.LINE); head.add_child(_stats)

	var hdr = HBoxContainer.new(); hdr.add_theme_constant_override("separation", 6); col.add_child(hdr)
	for h in [["#", 34], ["VERB", 170], ["BARS", 100], ["SLOPE°", 100], ["TURN°", 100], ["BANK°", 100], ["WIDTH", 100], ["FEATURE", 200]]:
		var l = UiKit.label(h[0], 13, UiKit.TEXT_DIM); l.custom_minimum_size = Vector2(h[1], 0); hdr.add_child(l)

	var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus = true
	col.add_child(scroll)
	_rows = VBoxContainer.new(); _rows.add_theme_constant_override("separation", 4); scroll.add_child(_rows)

	_status = UiKit.label("", UiKit.BODY, UiKit.TEXT_DIM); _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	var actions = HBoxContainer.new(); actions.add_theme_constant_override("separation", 10); col.add_child(actions)
	var test = _act("TEST RIDE", true, func(): _ride(false)); actions.add_child(test)
	actions.add_child(_act("VERIFY RUN", false, func(): _ride(true)))
	actions.add_child(_act("SAVE", false, func(): _save(); _status.text = "Saved."))
	_share = _act("COPY COURSE CODE", false, _copy_code); actions.add_child(_share)
	actions.add_child(_act("BACK", false, func(): _save(); Game.editor_course = null; Main.instance.show_courses()))
	_build_rows()
	_refresh(false)
	test.grab_focus()

func _act(text: String, accent: bool, f: Callable) -> Button:
	var b = UiKit.button(text, accent); b.custom_minimum_size = Vector2(0, 42); b.pressed.connect(f); return b

# ------------------------------------------------------------------- rows
func _build_rows() -> void:
	for c in _rows.get_children(): c.queue_free()
	for i in course.spec.size():
		_rows.add_child(_row(i))

func _row(i: int) -> HBoxContainer:
	var seg: Dictionary = course.spec[i]
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 6)
	var idx = UiKit.mono("%02d" % (i + 1), 15, UiKit.TEXT_DIM); idx.custom_minimum_size = Vector2(34, 0); row.add_child(idx)
	var kind = OptionButton.new(); kind.custom_minimum_size = Vector2(170, 36)
	var names = VerbLibrary.all_names()
	for n in names: kind.add_item(n)
	kind.select(maxi(0, names.find(str(seg["kind"]))))
	kind.item_selected.connect(func(n): set_kind(i, names[n]))
	row.add_child(kind)
	for key in ["bars", "slope", "turn", "bank", "width"]:
		row.add_child(_spin(seg, key, 0.25 if key == "bars" else (0.5 if key == "width" else 1.0)))
	var feat = FEATURE.get(str(seg["kind"]), [])
	var fbox = HBoxContainer.new(); fbox.custom_minimum_size = Vector2(200, 0); row.add_child(fbox)
	if not feat.is_empty():
		fbox.add_child(UiKit.label(feat[1], 12, UiKit.TEXT_DIM))
		fbox.add_child(_spin(seg, feat[0], 1.0 if feat[0] in CourseCodec.INT_KEYS else 0.5))
	for b in [["▲", func(): move(i, -1)], ["▼", func(): move(i, 1)], ["+", func(): insert_after(i)], ["✕", func(): remove(i)]]:
		var btn = Button.new(); btn.text = b[0]; btn.custom_minimum_size = Vector2(40, 36); btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(b[1]); row.add_child(btn)
	return row

func _spin(seg: Dictionary, key: String, step: float) -> SpinBox:
	var lim: Array = CourseCodec.LIMITS[key]
	var s = SpinBox.new(); s.min_value = lim[0]; s.max_value = lim[1]; s.step = step
	s.value = float(seg.get(key, 0.0)); s.custom_minimum_size = Vector2(100, 36)
	s.value_changed.connect(func(v):
		seg[key] = VerbLibrary.quantize_bars_for(str(seg["kind"]), v) if key == "bars" else v
		_edited())
	return s

# ------------------------------------------------------------- operations
func set_kind(i: int, kind: String) -> void:
	var old: Dictionary = course.spec[i]
	var fresh = VerbLibrary.default_segment(kind)
	fresh["bars"] = VerbLibrary.quantize_bars_for(kind, float(old.get("bars", fresh["bars"])))
	fresh["width"] = float(old.get("width", fresh.get("width", 16.0)))
	course.spec[i] = CourseCodec.sanitize_segment(fresh)
	_build_rows(); _edited()

func insert_after(i: int) -> void:
	if course.spec.size() >= CourseCodec.MAX_SEGMENTS: return
	course.spec.insert(i + 1, CourseCodec.sanitize_segment(VerbLibrary.default_segment("straight")))
	_build_rows(); _edited()

func remove(i: int) -> void:
	if course.spec.size() <= 3:
		_status.text = "A course needs at least three segments."; return
	course.spec.remove_at(i)
	_build_rows(); _edited()

func move(i: int, d: int) -> void:
	var j = i + d
	if j < 0 or j >= course.spec.size(): return
	var t = course.spec[i]; course.spec[i] = course.spec[j]; course.spec[j] = t
	_build_rows(); _edited()

## Any geometry edit invalidates the verification: the author must ride the
## new version.
func _edited() -> void:
	course.spec = CourseCodec.sanitize_spec(course.spec)
	course.total_bars = CourseCatalog.spec_bars(course.spec)
	course.id = CourseCodec.course_id(course.spec, course.region_index)
	if CourseCodec.is_verified(course):
		course.medal_source = "provisional"; course.set_meta("author_run", "")
	_refresh(true)

func _refresh(changed: bool) -> void:
	var secs = Tempo.course_seconds(course.total_bars)
	var v = GenerationValidator.validate(course.spec)
	_stats.text = "%d segments · %.1f bars · ~%ds" % [course.spec.size(), course.total_bars, int(secs)]
	var verified = CourseCodec.is_verified(course)
	_share.disabled = not verified
	if not v.get("ok", false):
		_status.text = _explain(v)
		_status.add_theme_color_override("font_color", UiKit.WARN)
	elif verified:
		_status.text = "Verified · author time %s. Ready to share." % RunController.format_time(course.author_time)
		_status.add_theme_color_override("font_color", UiKit.GOOD)
	else:
		_status.text = "Finish a VERIFY RUN to set the author time and unlock sharing." if not changed else "Edited. Verify again to share this version."
		_status.add_theme_color_override("font_color", UiKit.TEXT_DIM)

static func _explain(v: Dictionary) -> String:
	match str(v.get("reason", "")):
		"too_short": return "Add at least five segments for a full run (three is the minimum to play)."
		"no_rest_beat": return "Three intense verbs in a row with no recovery. Riders need a rest beat; add a straight, bowl, patch, split or tunnel."
		"speed_gate": return "%s needs about %d m/s on entry, but the line before it only builds about %d. Add a drop or straight before it." % [str(v.get("kind", "")).to_upper(), int(v.get("need", 0)), int(v.get("estimate", 0))]
	return "Structure check failed."

# ------------------------------------------------------------- persistence
func _save() -> void:
	course.title = _title.text.strip_edges().to_upper() if _title.text.strip_edges() != "" else "UNTITLED"
	if not course.has_meta("author_name"): course.set_meta("author_name", str(Game.profile.get("name", "SLIDER")))
	if _previous_id != "" and _previous_id != course.id: CustomCourses.delete(_previous_id)
	CustomCourses.save(course)
	_previous_id = course.id

func _copy_code() -> void:
	_save()
	DisplayServer.clipboard_set(CourseCodec.to_code(course))
	_status.text = "Course code copied. Anyone can paste it into COURSES → IMPORT."

func _ride(verify: bool) -> void:
	_save()
	Game.editor_course = course
	Game.verifying_course = verify
	Game.set_mode(Game.Mode.TIME_TRIAL)
	Main.instance.play_course(course)
