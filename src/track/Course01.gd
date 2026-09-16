class_name Course01
extends RefCounted

## Compatibility wrapper retained for tests/tools that still refer to the
## original vertical-slice class. Runtime campaign content lives in CourseData.
static func data() -> CourseData:
	return CourseCatalog.all_courses()[0]

static func build() -> Dictionary:
	return CourseFactory.build(data(), MotorParams.new().author_avg_speed)
