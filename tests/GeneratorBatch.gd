extends Node

## Generates fifty deterministic candidates for a region and writes the full
## verb lists plus structural validation to user://generated_candidates.json.
## Physical and human-tolerance probes can then be run against chosen seeds.

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	var region = 0
	var count = 50
	for a in args:
		if a.begins_with("--region="):
			region = clampi(int(a.trim_prefix("--region=")), 0, 4)
		elif a.begins_with("--count="):
			count = maxi(1, int(a.trim_prefix("--count=")))
	var rows: Array = []
	var accepted = 0
	for i in range(count):
		var seed = 100003 + region * 10000 + i * 7919
		var c = CourseGenerator.generate(seed, region, 32.0, "candidate_%d" % seed, "CANDIDATE", "")
		var v = GenerationValidator.validate(c.spec)
		if bool(v.get("ok", false)):
			accepted += 1
		rows.append({"seed":seed,"region":region,"validation":v,"spec":c.spec,"author_time":c.author_time,"form":c.form,"total_bars":c.total_bars,"signature_moment":c.signature_moment})
	var path = "user://generated_candidates.json"
	Game._write_json(path, {"region":region,"count":count,"accepted":accepted,"candidates":rows})
	print("── generator batch ──")
	print("  region    : %s" % CourseCatalog.REGIONS[region]["name"])
	print("  generated : %d" % count)
	print("  accepted  : %d" % accepted)
	print("  output    : %s" % ProjectSettings.globalize_path(path))
	get_tree().quit(0)
