class_name CustomCourses
extends RefCounted

## The player's community courses: one JSON file each in user://courses/.

const DIR = "user://courses"
static var root = DIR                # tests point this at a sandbox

static func path_for(id: String) -> String:
	return root.path_join(id + ".json")

static func save(c: CourseData) -> bool:
	DirAccess.make_dir_recursive_absolute(root)
	var f = FileAccess.open(path_for(c.id), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(CourseCodec.from_course(c), "\t"))
	f.close()
	return true

static func load_course(id: String) -> CourseData:
	if not id.begins_with("c_") or not FileAccess.file_exists(path_for(id)):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(path_for(id)))
	if not (d is Dictionary):
		return null
	var c = CourseCodec.to_course(d)
	return c if c.spec.size() >= 3 else null

static func all() -> Array[CourseData]:
	var out: Array[CourseData] = []
	var dir = DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			var c = load_course(f.get_basename())
			if c: out.append(c)
	out.sort_custom(func(a, b): return a.title < b.title)
	return out

static func delete(id: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(id)))

## A starter course for "NEW COURSE": a short, friendly, finishable line.
static func template() -> CourseData:
	return CourseCodec.to_course({"title": "NEW COURSE", "region": 0, "author": "SLIDER", "spec": [
		{"kind": "straight", "bars": 4.0, "slope": 14.0, "width": 20.0},
		{"kind": "crest", "bars": 2.0, "slope": 15.0, "crest": 10.0, "width": 19.0},
		{"kind": "bank", "bars": 4.0, "slope": 16.0, "turn": 35.0, "bank": -18.0, "width": 18.0},
		{"kind": "drop", "bars": 3.0, "slope": 24.0, "width": 18.0},
		{"kind": "straight", "bars": 3.0, "slope": 18.0, "width": 22.0},
	]})
