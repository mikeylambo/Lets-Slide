extends Node

const OUT_DIR := "res://content/courses"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failures = 0
	for course in CourseCatalog.all_courses():
		var path = "%s/%s.tres" % [OUT_DIR, course.id]
		var err = ResourceSaver.save(course, path)
		if err != OK:
			push_error("Failed saving %s: %s" % [path, error_string(err)])
			failures += 1
	print("── course export ──")
	print("  courses : %d" % CourseCatalog.all_courses().size())
	print("  output  : %s" % ProjectSettings.globalize_path(OUT_DIR))
	print("  failures: %d" % failures)
	Courses.reload()
	get_tree().quit(0 if failures == 0 else 2)
