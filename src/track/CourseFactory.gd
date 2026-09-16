class_name CourseFactory
extends RefCounted

## Shared authored/generated course assembly. Route, pickup, checkpoint and finish
## logic is identical no matter where the verb list came from.

static func build(course: CourseData, author_avg_speed: float = 32.0) -> Dictionary:
	var builder = TrackBuilder.new()
	var start_height = 260.0 + float(course.region_index) * 170.0 + (120.0 if course.is_descent else 0.0)
	var root = builder.build(course.spec, Vector3(0.0, start_height, 0.0), 0.0, author_avg_speed)
	root.name = course.id
	var props = Node3D.new()
	props.name = "CourseProps"
	root.add_child(props)
	var length = builder.total_length

	# Four-line doctrine: the main ribbon is safe; a parallel fast line asks for
	# commitment; pickups trace a score line; a high mastery route is only easy
	# to reach with speed protected before it.
	if length > 420.0 and course.id != "course_01":
		var fast_from = length * 0.18
		var fast_to = length * 0.34
		if not _authored_route_overlaps(builder, fast_from, fast_to):
			builder.add_parallel_route(fast_from, fast_to, -6.0, 0.7, 6.0, SurfaceKind.VERY_SLIPPERY, "FastLine")
			_add_route_beacons(builder, props, fast_from, fast_to, -6.0, Color(0.30,0.95,1.0,0.78), 3)
		var mastery_from = length * 0.62
		var mastery_to = length * 0.78
		if not _authored_route_overlaps(builder, mastery_from, mastery_to):
			builder.add_parallel_route(mastery_from, mastery_to, 8.0, 5.4, 6.2, SurfaceKind.SLIPPERY, "MasteryRoute")
			_add_route_beacons(builder, props, mastery_from, mastery_to, 8.0, Color(1.0,0.34,0.88,0.90), 5)

	var pickups: Array[Pickup] = []
	if course.par_score > 0:
		var pickup_spacing = Tempo.bar_meters(author_avg_speed) * (0.75 if course.is_descent else 1.0)
		var d = Tempo.bar_meters(author_avg_speed) * 1.5
		var index = 0
		while d < length - Tempo.bar_meters(author_avg_speed):
			var kind = Pickup.Kind.SCORE
			if index % 4 != 0:
				kind = Pickup.Kind.CHAIN
			var lateral = sin(float(index) * 1.7) * 4.3
			_place(builder, props, pickups, d, lateral, 1.6, kind, 90 + course.region_index * 20)
			d += pickup_spacing
			index += 1

	var mastery: Pickup = null
	if course.mastery_count > 0:
		mastery = _place(builder, props, pickups, length * 0.70, 7.5, 6.8, Pickup.Kind.MASTERY, 1800 + course.region_index * 350)

	var checkpoints: Array[TrackTrigger] = []
	var cp_count = 7 if course.is_descent else 4
	for i in range(cp_count):
		var cd = length * (float(i + 1) / float(cp_count + 1))
		var frame = builder.sample_at(cd)
		if frame.is_empty(): continue
		var t = TrackTrigger.new(TrackTrigger.Kind.CHECKPOINT, i)
		props.add_child(t)
		t.setup(Vector3(24.0, 12.0, 3.0), frame)
		checkpoints.append(t)

	var finish = TrackTrigger.new(TrackTrigger.Kind.FINISH, 0)
	props.add_child(finish)
	finish.setup(Vector3(32.0, 14.0, 4.0), builder.finish_frame())

	var start_frame = builder.sample_at(5.0)
	var start_pos: Vector3 = start_frame["pos"] + start_frame["u"] * 0.65
	var start_yaw: float = atan2(start_frame["f"].x, start_frame["f"].z)
	return {
		"root": root, "builder": builder, "pickups": pickups, "mastery": mastery,
		"checkpoints": checkpoints, "finish": finish, "start_position": start_pos,
		"start_yaw": start_yaw, "length": length, "beat_map": builder.beat_map.duplicate(), "kill_y": _lowest_y(builder) - 90.0,
	}

static func _place(b: TrackBuilder, parent: Node3D, out: Array[Pickup], dist: float,
		lateral: float, height: float, kind: int, value: int) -> Pickup:
	var f = b.sample_at(dist)
	if f.is_empty(): return null
	var p = Pickup.new(kind, value)
	parent.add_child(p)
	p.position = f["pos"] + f["r"] * lateral + f["u"] * height
	out.append(p)
	return p

static func _add_route_beacons(b: TrackBuilder, parent: Node3D, from_d: float, to_d: float, lateral: float, color: Color, count: int) -> void:
	for i in range(count):
		var t = float(i + 1) / float(count + 1)
		var f = b.sample_at(lerpf(from_d, to_d, t))
		if f.is_empty(): continue
		var mi = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.07; mesh.bottom_radius = 0.07; mesh.height = 2.4
		mi.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		mat.emission_enabled = true; mat.emission = Color(color.r,color.g,color.b); mat.emission_energy_multiplier = 1.8
		mi.material_override = mat
		mi.position = f["pos"] + f["r"] * lateral + f["u"] * 1.2
		parent.add_child(mi)

static func _lowest_y(b: TrackBuilder) -> float:
	var lowest = INF
	for s in b.samples: lowest = minf(lowest, float(s["pos"].y))
	return lowest if lowest != INF else 0.0

static func _authored_route_overlaps(b: TrackBuilder, from_d: float, to_d: float) -> bool:
	for info in b.segment_ranges:
		if str(info["kind"]) in ["split", "transfer"] and float(info["from"]) < to_d and float(info["to"]) > from_d:
			return true
	return false
