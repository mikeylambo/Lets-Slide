extends RefCounted

## Named feel presets as one JSON file each: <root>/<slug>.json
##   {"name": "...", "motor": {...MotorParams...}, "camera": {...}, "saved_at": "..."}
## First launch seeds the folder from the game's built-in presets so the
## harness always has something to A/B against.

var root = "user://presets"

func _init(root_dir: String = "user://presets") -> void:
	root = root_dir
	DirAccess.make_dir_recursive_absolute(root)
	DirAccess.make_dir_recursive_absolute(ghost_dir())

func ghost_dir() -> String:
	return root.path_join("ghosts")

func ensure_seeded(seed_presets: Dictionary) -> void:
	if not names().is_empty():
		return
	for n in seed_presets.keys():
		var p: Dictionary = seed_presets[n]
		save(str(n), p.get("motor", {}), p.get("camera", {}))

func names() -> Array:
	var out = []
	var dir = DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.get_extension() != "json":
			continue
		var d = _read(root.path_join(f))
		if d.has("motor"):
			out.append(str(d.get("name", f.get_basename())))
	out.sort()
	return out

func exists(preset_name: String) -> bool:
	return FileAccess.file_exists(path_for(preset_name))

func load_preset(preset_name: String) -> Dictionary:
	var d = _read(path_for(preset_name))
	if not d.has("motor"):
		return {}
	d["name"] = str(d.get("name", preset_name))
	if not d.has("camera"):
		d["camera"] = {}
	return d

func save(preset_name: String, motor: Dictionary, camera: Dictionary) -> String:
	var path = path_for(preset_name)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Harness: could not write preset %s" % path)
		return ""
	f.store_string(JSON.stringify({
		"name": preset_name, "motor": motor, "camera": camera,
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}, "\t", true))
	f.close()
	return path

func path_for(preset_name: String) -> String:
	return root.path_join(slug(preset_name) + ".json")

func ghost_path(course_id: String, preset_name: String) -> String:
	return ghost_dir().path_join("%s__%s.dat" % [course_id, slug(preset_name)])

static func slug(text: String) -> String:
	var out = ""
	for ch in text.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("-") and out != "":
			out += "-"
	out = out.trim_suffix("-")
	return out if out != "" else "preset"

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}
