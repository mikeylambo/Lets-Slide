class_name CourseCodec
extends RefCounted

## Community course format. A course is its verb list in bars (the same spec
## authored courses use) plus a title, a visual region and, once its author
## has finished it, the author time and the author's run.
##
## Everything coming in is treated as untrusted: unknown keys are dropped,
## every number is clamped to what the track builder can safely build, and
## the embedded author run must belong to this exact geometry.
##
## Share code: "SLCS1:" + base64(zstd(JSON)).

const FORMAT = "lets-slide-course"
const VERSION = 1
const CODE_PREFIX = "SLCS1:"
const MAX_SEGMENTS = 64
const MAX_BARS = 160.0
const MAX_CODE_BYTES = 256 * 1024

## [min, max] for every numeric segment key the builder understands.
const LIMITS = {
	"bars": [0.25, 16.0], "slope": [-20.0, 80.0], "width": [6.0, 30.0],
	"turn": [-180.0, 180.0], "bank": [-180.0, 180.0], "bowl": [0.0, 12.0],
	"wall": [0.0, 12.0], "ridge": [0.0, 8.0], "launch": [0.0, 30.0],
	"crest": [0.0, 30.0], "compression": [0.0, 30.0], "updraft": [0.0, 30.0],
	"hazards": [0.0, 6.0], "split_offset": [3.0, 12.0], "split_height": [0.0, 3.0],
	"transfer": [0.0, 12.0], "pipe": [0.0, 1.0], "split": [0.0, 1.0], "tunnel": [0.0, 1.0],
	"surface": [0.0, 7.0],
}
const INT_KEYS = ["hazards", "surface"]

## Stable identity of the geometry: same spec + region = same id, so run
## codes and records follow the course, and any edit makes a new course.
static func course_id(spec: Array, region: int) -> String:
	return "c_%08x" % (hash(JSON.stringify({"r": region, "s": spec}, "", true)) & 0xffffffff)

static func sanitize_segment(raw) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var kind = str(raw.get("kind", ""))
	if not VerbLibrary.META.has(kind):
		return {}
	var out = {"kind": kind}
	for key in LIMITS.keys():
		if not raw.has(key):
			continue
		var v = raw[key]
		if not (v is float or v is int):
			continue
		var lim: Array = LIMITS[key]
		var x = clampf(float(v), lim[0], lim[1])
		if not is_finite(x):
			continue
		out[key] = int(round(x)) if key in INT_KEYS else snappedf(x, 0.01)
	out["bars"] = VerbLibrary.quantize_bars_for(kind, float(out.get("bars", 2.0)))
	return out

static func sanitize_spec(raw) -> Array:
	var out = []
	if not (raw is Array):
		return out
	var bars = 0.0
	for seg in raw:
		if out.size() >= MAX_SEGMENTS:
			break
		var s = sanitize_segment(seg)
		if s.is_empty():
			continue
		if bars + float(s["bars"]) > MAX_BARS:
			break
		bars += float(s["bars"])
		out.append(s)
	return out

## Builds a playable CourseData. Medals scale from the author time exactly
## like the campaign's ratios; unverified courses have provisional targets.
static func to_course(d: Dictionary) -> CourseData:
	var c = CourseData.new()
	c.spec = sanitize_spec(d.get("spec", []))
	c.region_index = clampi(int(d.get("region", 0)), 0, 4)
	c.region = str(CourseCatalog.REGIONS[c.region_index]["name"])
	c.id = course_id(c.spec, c.region_index)
	c.title = str(d.get("title", "UNTITLED")).strip_edges().substr(0, 32).to_upper()
	if c.title == "": c.title = "UNTITLED"
	c.subtitle = "by " + str(d.get("author", "SLIDER")).strip_edges().substr(0, 24)
	c.generated = true
	c.total_bars = CourseCatalog.spec_bars(c.spec)
	c.form = "community"
	c.unlock_medals = 0
	c.par_score = int(c.total_bars * 135.0)
	c.mastery_count = 1
	var at = float(d.get("author_time", 0.0))
	c.medal_source = "author" if at > 0.0 else "provisional"
	if at <= 0.0:
		at = Tempo.course_seconds(c.total_bars) * 0.84
	c.author_time = at
	c.gold_time = at * 1.08; c.silver_time = at * 1.22; c.bronze_time = at * 1.45
	c.set_meta("author_name", str(d.get("author", "SLIDER")).substr(0, 24))
	c.set_meta("author_run", str(d.get("author_run", "")))
	return c

static func from_course(c: CourseData) -> Dictionary:
	var verified = c.medal_source == "author"
	return {
		"format": FORMAT, "v": VERSION, "title": c.title, "region": c.region_index,
		"author": str(c.get_meta("author_name", "SLIDER")), "spec": c.spec.duplicate(true),
		"author_time": c.author_time if verified else 0.0,
		"author_run": str(c.get_meta("author_run", "")) if verified else "",
	}

static func is_verified(c: CourseData) -> bool:
	return c.medal_source == "author"

static func author_replay(c: CourseData) -> Replay:
	var r = Replay.from_code(str(c.get_meta("author_run", "")))
	return r if r != null and r.course_id == c.id and r.valid() else null

# ------------------------------------------------------------------ codes
static func to_code(c: CourseData) -> String:
	var raw = JSON.stringify(from_course(c)).to_utf8_buffer()
	var packed = raw.compress(FileAccess.COMPRESSION_ZSTD)
	var size = PackedByteArray(); size.resize(4); size.encode_u32(0, raw.size())
	size.append_array(packed)
	return CODE_PREFIX + Marshalls.raw_to_base64(size)

## Returns {"course": CourseData} or {"error": "why"}.
static func from_code(code: String) -> Dictionary:
	var t = code.strip_edges()
	if not t.begins_with(CODE_PREFIX):
		return {"error": "Course codes start with SLCS1:"}
	var data = Replay.decode_b64(t.trim_prefix(CODE_PREFIX))
	if data.size() < 5:
		return {"error": "That code is incomplete."}
	var raw_size = data.decode_u32(0)
	if raw_size <= 0 or raw_size > MAX_CODE_BYTES:
		return {"error": "That code is too large to be a course."}
	var raw = data.slice(4).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return {"error": "That code is damaged."}
	var d = JSON.parse_string(raw.get_string_from_utf8())
	if not (d is Dictionary) or str(d.get("format", "")) != FORMAT:
		return {"error": "That code isn't a Let's Slide course."}
	if int(d.get("v", 0)) > VERSION:
		return {"error": "This course needs a newer version of the game."}
	var c = to_course(d)
	if c.spec.size() < 3:
		return {"error": "That course has fewer than three valid segments."}
	# A claimed author time must come with the author's run on this geometry.
	if is_verified(c) and author_replay(c) == null:
		c.medal_source = "provisional"
		c.set_meta("author_run", "")
	return {"course": c}
