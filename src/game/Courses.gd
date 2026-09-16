class_name Courses
extends RefCounted

const COURSE_DIR := "res://content/courses"
static var _cache: Array[CourseData] = []

static func all() -> Array[CourseData]:
	if _cache.is_empty():
		_cache = _load_saved_courses()
		if _cache.is_empty(): _cache = CourseCatalog.all_courses()
	return _cache

static func reload() -> void:
	_cache.clear()

static func _load_saved_courses() -> Array[CourseData]:
	var out: Array[CourseData] = []
	var dir = DirAccess.open(COURSE_DIR)
	if dir == null: return out
	var files: Array[String] = []
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"): files.append(name)
		name = dir.get_next()
	dir.list_dir_end(); files.sort()
	for filename in files:
		var resource = load("%s/%s" % [COURSE_DIR, filename])
		if resource is CourseData: out.append(resource)
	out.sort_custom(func(a: CourseData, b: CourseData): return a.id < b.id)
	return out

static func by_id(id: String) -> CourseData:
	for c in all():
		if c.id == id: return c
	return null

static func region_courses(region_index: int) -> Array[CourseData]:
	var out: Array[CourseData] = []
	for c in all():
		if c.region_index == region_index: out.append(c)
	return out

static func build(id: String, author_avg_speed: float = 32.0) -> Dictionary:
	var c = by_id(id)
	if c == null:
		push_error("Unknown course id: %s" % id)
		return {}
	return CourseFactory.build(c, author_avg_speed)
