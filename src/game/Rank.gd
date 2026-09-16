class_name Rank
extends RefCounted

const ORDER = ["D", "C", "B", "A", "S", "SS"]
const W_TIME = 0.42
const W_SCORE = 0.22
const W_MOMENTUM = 0.26
const W_MASTERY = 0.10

static func evaluate(course: CourseData, result: Dictionary) -> Dictionary:
	var time = float(result.get("time", 0.0))
	var score = int(result.get("score", 0))
	var momentum = clampf(float(result.get("avg_momentum", 0.0)), 0.0, 1.0)
	var mastery = int(result.get("mastery", 0))
	var time_score = 0.0
	if time > 0.0:
		var worst = course.bronze_time * 1.5
		time_score = clampf((worst - time) / maxf(worst - course.author_time, 0.001), 0.0, 1.0)
	var score_score = 0.0
	if course.par_score > 0:
		score_score = clampf(float(score) / float(course.par_score), 0.0, 1.0)
	var mastery_score = 0.0
	if course.mastery_count > 0:
		mastery_score = clampf(float(mastery) / float(course.mastery_count), 0.0, 1.0)

	# Tutorial courses may intentionally omit score/mastery. Missing axes are
	# removed from the denominator rather than making SS mathematically impossible.
	var weight_sum = W_TIME + W_MOMENTUM
	var total = time_score * W_TIME + momentum * W_MOMENTUM
	if course.par_score > 0:
		weight_sum += W_SCORE
		total += score_score * W_SCORE
	if course.mastery_count > 0:
		weight_sum += W_MASTERY
		total += mastery_score * W_MASTERY
	total /= maxf(weight_sum, 0.001)

	var letter = "D"
	if total >= 0.94: letter = "SS"
	elif total >= 0.85: letter = "S"
	elif total >= 0.74: letter = "A"
	elif total >= 0.60: letter = "B"
	elif total >= 0.42: letter = "C"
	return {"rank": letter, "total": total, "time_score": time_score, "score_score": score_score,
		"momentum_score": momentum, "mastery_score": mastery_score}

static func is_better(a: String, b: String) -> bool:
	return ORDER.find(a) > ORDER.find(b)

static func color_for(letter: String) -> Color:
	match letter:
		"SS": return Color(1.0, 0.42, 0.92)
		"S": return Color(0.55, 0.85, 1.0)
		"A": return Color(0.45, 1.0, 0.62)
		"B": return Color(0.95, 0.88, 0.4)
		"C": return Color(0.95, 0.62, 0.35)
		_: return Color(0.7, 0.72, 0.78)
