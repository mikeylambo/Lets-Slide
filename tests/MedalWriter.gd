extends Node

func _ready() -> void:
	var csv_path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--medal-file="):
			csv_path = arg.trim_prefix("--medal-file=")
	if csv_path == "":
		push_error("Missing --medal-file=<path>")
		get_tree().quit(2)
		return
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("Could not open medal file: %s" % csv_path)
		get_tree().quit(2)
		return
	var updated = 0
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts = line.split(",")
		if parts.size() < 2:
			continue
		var id = str(parts[0]).strip_edges()
		var physical_time = float(parts[1])
		var measured_score = int(parts[2]) if parts.size() >= 3 else 0
		var path = "res://content/courses/%s.tres" % id
		var course = load(path) as CourseData
		if course == null or physical_time <= 0.0:
			push_error("Invalid medal row for %s" % id)
			get_tree().quit(3)
			return
		course.author_time = physical_time
		course.gold_time = physical_time * 1.08
		course.silver_time = physical_time * 1.22
		course.bronze_time = physical_time * 1.45
		course.medal_source = "probe"
		if measured_score > 0:
			course.par_score = measured_score
		var err = ResourceSaver.save(course, path)
		if err != OK:
			push_error("Failed saving medals for %s" % id)
			get_tree().quit(4)
			return
		updated += 1
	print("── medal calibration ──")
	print("  updated : %d" % updated)
	get_tree().quit(0)
