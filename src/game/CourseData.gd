class_name CourseData
extends Resource

@export var id = "course_01"
@export var title = "FIRST DESCENT"
@export var subtitle = "Learn the mountain"
@export var region = "THRESHOLD"
@export var region_index = 0
@export var course_index = 0
@export var unlock_medals = 0
@export var is_descent = false
@export var generated = false
@export var seed = 0
@export var primary_metric = "time"

@export var author_time = 50.0
@export var gold_time = 57.0
@export var silver_time = 65.0
@export var bronze_time = 78.0
@export var par_score = 4200
@export var pickup_count = 0
@export var mastery_count = 1

@export var spec: Array = []
@export var tension_curve: Array[float] = []
@export var total_bars: float = 32.0
@export var form: String = "steady_climb"
@export var signature_moment: String = ""
@export var bpm: float = 174.0
@export var medal_source: String = "provisional"

func medal_for(time: float) -> String:
	if time <= 0.0: return ""
	if time <= author_time: return "AUTHOR"
	if time <= gold_time: return "GOLD"
	if time <= silver_time: return "SILVER"
	if time <= bronze_time: return "BRONZE"
	return ""

func medal_color(medal: String) -> Color:
	match medal:
		"AUTHOR": return Color(0.65, 0.45, 1.0)
		"GOLD": return Color(1.0, 0.82, 0.3)
		"SILVER": return Color(0.78, 0.84, 0.9)
		"BRONZE": return Color(0.85, 0.55, 0.32)
		_: return Color(0.5, 0.55, 0.6)

func next_medal(time: float) -> Dictionary:
	if time <= 0.0 or time > bronze_time: return {"name": "BRONZE", "time": bronze_time}
	if time > silver_time: return {"name": "SILVER", "time": silver_time}
	if time > gold_time: return {"name": "GOLD", "time": gold_time}
	if time > author_time: return {"name": "AUTHOR", "time": author_time}
	return {}
