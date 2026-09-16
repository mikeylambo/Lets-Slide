extends Node

const OUT_DIR := "res://content/courses"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var args = OS.get_cmdline_user_args()
	var force = "--force-export-courses" in args
	var failures = 0
	var written = 0
	var skipped = 0
	for course in CourseCatalog.all_courses():
		var path = "%s/%s.tres" % [OUT_DIR, course.id]
		if FileAccess.file_exists(path) and not force:
			skipped += 1
			continue
		var err = ResourceSaver.save(course, path)
		if err != OK:
			push_error("Failed saving %s: %s" % [path, error_string(err)])
			failures += 1
		else:
			written += 1
	print("── course export ──")
	print("  catalog : %d" % CourseCatalog.all_courses().size())
	print("  written : %d" % written)
	print("  skipped : %d" % skipped)
	print("  force   : %s" % str(force))
	print("  output  : %s" % ProjectSettings.globalize_path(OUT_DIR))
	print("  failures: %d" % failures)
	Courses.reload()
	get_tree().quit(0 if failures == 0 else 2)
