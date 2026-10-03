class_name WorldKit
extends RefCounted

## The Shelf: a continent-scale descending structure of stone and glass
## terraces, above a sea of cloud. Every course is dressed by the same kit;
## each region's palette and light come from RegionTheme.
##
## What the kit builds, from the track outward:
##   sky, sun and fog       the region's light and air (RegionTheme)
##   gates                  a stone gate over the start and the finish line
##   terraces               stepped slabs beside and below the line, built
##                          down and away from it so they frame, never block
##   piers                  columns carrying the deck down into the cloud
##   far shelf              cliff-scale silhouettes dissolving into the fog
##   cloud sea              the floor of the world, far below everything
## All placement is seeded from the course, so a course always looks the same.

const CLOUD_SHADER = preload("res://src/track/shaders/cloud_sea.gdshader")
const STONE_SHADER = preload("res://src/track/shaders/shelf_stone.gdshader")
const TRACK_CLEARANCE = 9.0       ## metres kept free around any part of the line

static func add_environment(parent: Node3D, region_index: int = 0) -> WorldEnvironment:
	var th = RegionTheme.of(region_index)
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var mat = ProceduralSkyMaterial.new()
	mat.sky_top_color = th["sky_top"]
	mat.sky_horizon_color = th["sky_horizon"]
	mat.sky_curve = 0.12
	mat.ground_horizon_color = (th["clouds"] as Color).lerp(th["sky_horizon"], 0.5)
	mat.ground_bottom_color = th["cloud_shadow"]
	mat.ground_curve = 0.06
	mat.sun_angle_max = 24.0
	mat.sun_curve = 0.12
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(th["ambient"])
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = th["fog"]
	env.fog_density = float(th["fog_density"])
	env.fog_sky_affect = 0.22
	env.fog_aerial_perspective = 0.4
	env.fog_sun_scatter = 0.25
	env.glow_enabled = true
	env.glow_intensity = float(th["glow"])
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_meta("glow_base", float(th["glow"]))
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	var we = WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	return we

static func add_sun(parent: Node3D, region_index: int = 0) -> DirectionalLight3D:
	var th = RegionTheme.of(region_index)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(float(th["sun_pitch"]), float(th["sun_yaw"]), 0)
	sun.light_energy = float(th["sun_energy"])
	sun.light_color = th["sun_color"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.shadow_blur = 1.5
	parent.add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, float(th["sun_yaw"]) + 180.0, 0)
	fill.light_energy = float(th["fill_energy"])
	fill.light_color = th["fill_color"]
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY   # no second sun disc
	parent.add_child(fill)
	return sun

static func add_shelf_architecture(parent: Node3D, builder: TrackBuilder, region_index: int) -> Node3D:
	var root = Node3D.new()
	root.name = "ShelfArchitecture"
	parent.add_child(root)
	if builder == null or builder.samples.is_empty(): return root
	var th = RegionTheme.of(region_index)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(builder.total_length) + str(region_index) + str(builder.samples.size()))
	var lo = Vector3(INF, INF, INF); var hi = -lo
	for s in builder.samples:
		lo = lo.min(s["pos"]); hi = hi.max(s["pos"])
	var kit = _Kit.new(builder, th)
	_terraces(kit, builder, th, rng)
	_piers(kit, builder, lo.y - 150.0, rng)
	_far_shelf(kit, lo, hi, th, rng)
	_gate(kit, builder.sample_at(14.0), th, 1.0)
	_gate(kit, builder.finish_frame(), th, 1.6)
	_landmark(kit, builder, th)
	kit.flush(root)
	_cloud_sea(root, lo, hi, th)
	return root

# ------------------------------------------------------------------- pieces
static func _terraces(kit: _Kit, builder: TrackBuilder, th: Dictionary, rng: RandomNumberGenerator) -> void:
	var every = float(th["terrace_every"])
	var d = 30.0
	while d < builder.total_length - 10.0:
		var s = builder.sample_at(d)
		var fr = _flat(s)
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.18: continue          # leave gaps so the void shows
			var lateral = 16.0 + rng.randf_range(2.0, 22.0)
			var drop = rng.randf_range(6.0, 16.0)
			for k in rng.randi_range(2, 4):
				var w = rng.randf_range(24.0, 64.0)
				var depth = every * rng.randf_range(0.8, 1.5)
				var h = rng.randf_range(8.0, 22.0)
				var top: Vector3 = s["pos"] + fr["r"] * side * lateral + Vector3.UP * -drop
				var centre = top + fr["r"] * side * (w * 0.5) + Vector3.UP * (-h * 0.5)
				if kit.clear(centre, Vector2(w, depth).length() * 0.5, centre.y - h * 0.5, centre.y + h * 0.5):
					var shade = rng.randf_range(0.82, 1.06)
					kit.stone(centre, fr, Vector3(w, h, depth), (th["stone"] as Color) * shade)
					# Frosted glass lip on the edge that faces the line.
					kit.glass(top + fr["r"] * side * 0.6 + Vector3.UP * 0.2, fr, Vector3(1.0, 0.4, depth * 0.96))
				lateral += w * rng.randf_range(0.5, 0.85)
				drop += rng.randf_range(9.0, 22.0)
		d += every * rng.randf_range(0.8, 1.25)

static func _piers(kit: _Kit, builder: TrackBuilder, floor_y: float, rng: RandomNumberGenerator) -> void:
	var d = 60.0
	while d < builder.total_length - 30.0:
		var s = builder.sample_at(d)
		if not s.get("gap", false) and absf((s["u"] as Vector3).dot(Vector3.UP)) > 0.85:
			var top_y = (s["pos"] as Vector3).y - TrackBuilder.DECK_DEPTH - 0.5
			var h = top_y - floor_y
			var c = Vector3(s["pos"].x, floor_y + h * 0.5, s["pos"].z)
			if h > 20.0 and kit.clear(c, 3.0, floor_y, top_y - 1.0, d):
				kit.stone(c, _flat(s), Vector3(4.0, h, 4.0), kit.th["stone_dark"])
		d += rng.randf_range(90.0, 150.0)

## The rest of the Shelf on the horizon: stepped massifs, each a stack of
## receding strata, standing in the cloud far enough out for the fog to melt
## them into the sky. They give the course its scale.
static func _far_shelf(kit: _Kit, lo: Vector3, hi: Vector3, th: Dictionary, rng: RandomNumberGenerator) -> void:
	var centre = (lo + hi) * 0.5
	var span = maxf(hi.x - lo.x, hi.z - lo.z)
	var floor_y = lo.y - 200.0
	for i in 14:
		var a = TAU * float(i) / 14.0 + rng.randf_range(-0.18, 0.18)
		var dist = span * 0.5 + rng.randf_range(1100.0, 2200.0)
		var p = Vector3(centre.x + cos(a) * dist, 0.0, centre.z + sin(a) * dist)
		var face = Vector3(-cos(a), 0, -sin(a))
		var fr = {"r": Vector3.UP.cross(face).normalized() * -1.0, "f": face}
		var w = rng.randf_range(380.0, 820.0)
		var deep = w * rng.randf_range(0.5, 0.9)
		var y = floor_y
		var top_y = hi.y + rng.randf_range(-120.0, 220.0)
		var tiers = rng.randi_range(3, 6)
		var tone = (th["stone"] as Color).darkened(rng.randf_range(0.05, 0.3))
		for k in tiers:
			var h = (top_y - floor_y) / float(tiers) * rng.randf_range(0.8, 1.2)
			# Each stratum steps back from the face below it.
			var c = p - face * (float(k) * deep * 0.12) + Vector3.UP * (y + h * 0.5)
			kit.stone(c, fr, Vector3(w * (1.0 - 0.1 * float(k)), h, deep * (1.0 - 0.12 * float(k))), tone.lightened(0.04 * float(k)))
			y += h
		if th["spires"]:
			kit.stone(p + fr["r"] * w * 0.55 + Vector3.UP * (y + 150.0) * 0.5, fr, Vector3(40.0, y + 150.0 - floor_y, 40.0), th["stone_dark"])

## A stone gate over the line: two piers, a lintel and a glass band. Scale
## grows for the finish so the end of a course reads from far up the hill.
static func _gate(kit: _Kit, s: Dictionary, th: Dictionary, scale: float) -> void:
	if s.is_empty(): return
	var fr = _flat(s)
	var half = 15.0 * scale
	var h = 26.0 * scale
	var base: Vector3 = s["pos"] - Vector3.UP * (TrackBuilder.DECK_DEPTH + 2.0)
	for side in [-1.0, 1.0]:
		kit.stone(base + fr["r"] * side * half + Vector3.UP * h * 0.5, fr, Vector3(4.5, h, 6.0) * Vector3(scale, 1.0, scale), th["stone"])
		kit.glass(base + fr["r"] * side * (half - 2.4 * scale) + Vector3.UP * h * 0.5, fr, Vector3(0.4, h * 0.85, 2.0 * scale), true)
	kit.stone(base + Vector3.UP * (h + 2.0 * scale), fr, Vector3(half * 2.0 + 8.0 * scale, 4.0 * scale, 7.0 * scale), th["stone"])
	kit.glass(base + Vector3.UP * (h - 0.6 * scale), fr, Vector3(half * 2.0 - 3.0, 0.7, 1.4 * scale), true)

## The region's signature silhouette, on the horizon beyond the finish.
static func _landmark(kit: _Kit, builder: TrackBuilder, th: Dictionary) -> void:
	match str(th.get("landmark", "")):
		"great_arch":
			# Threshold: the arch the whole Shelf is entered through. Every
			# course in the region descends toward it.
			var end = builder.finish_frame()
			var fr = _flat(end)
			var c: Vector3 = end["pos"] + fr["f"] * 1100.0
			var floor_y = c.y - 420.0
			var span = 380.0; var h = 560.0; var leg = 70.0
			for side in [-1.0, 1.0]:
				kit.stone(Vector3(c.x, floor_y + h * 0.5, c.z) + fr["r"] * side * span * 0.5, fr, Vector3(leg, h, leg * 1.2), th["stone"])
				kit.glass(Vector3(c.x, floor_y + h * 0.5, c.z) + fr["r"] * side * (span * 0.5 - leg * 0.5 - 2.0) - fr["f"] * 10.0, fr, Vector3(4.0, h * 0.9, 6.0), true)
			for k in 3:
				var w = span + leg * (1.6 - 0.25 * float(k))
				kit.stone(Vector3(c.x, floor_y + h + 25.0 + float(k) * 42.0, c.z), fr, Vector3(w, 42.0, leg * (1.4 - 0.15 * float(k))), (th["stone"] as Color).lightened(0.04 * float(k)))
			kit.glass(Vector3(c.x, floor_y + h - 6.0, c.z) - fr["f"] * 10.0, fr, Vector3(span - leg, 6.0, 6.0), true)

static func _cloud_sea(root: Node3D, lo: Vector3, hi: Vector3, th: Dictionary) -> void:
	var mi = MeshInstance3D.new()
	mi.name = "CloudSea"
	var plane = PlaneMesh.new()
	plane.size = Vector2(12000, 12000)
	mi.mesh = plane
	var m = ShaderMaterial.new()
	m.shader = CLOUD_SHADER
	m.set_shader_parameter("light_col", th["clouds"])
	m.set_shader_parameter("shade_col", th["cloud_shadow"])
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3((lo.x + hi.x) * 0.5, lo.y - 150.0, (lo.z + hi.z) * 0.5)
	root.add_child(mi)

## Horizontal frame of a track sample (yaw only): terraces stand level.
static func _flat(s: Dictionary) -> Dictionary:
	var f = Vector3(s["f"].x, 0.0, s["f"].z)
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	return {"f": f, "r": Vector3.UP.cross(f).normalized() * -1.0}

static func add_flow_palette(_parent: Node3D) -> void:
	pass

## Batches every block into two MultiMeshes (stone, glass) so a whole course
## of architecture costs two draw calls.
class _Kit:
	var builder: TrackBuilder
	var th: Dictionary
	var _stone: Array = []    ## [Transform3D, Color]
	var _glass: Array = []    ## [Transform3D, bool bright]
	var _probe: Array[Vector3] = []

	func _init(b: TrackBuilder, theme: Dictionary) -> void:
		builder = b; th = theme
		for i in range(0, b.samples.size(), 3):
			_probe.append(b.samples[i]["pos"])

	## True when a block of horizontal radius `r` spanning y0..y1 keeps
	## TRACK_CLEARANCE from every part of the line (ignoring `skip_d` +- 12 m,
	## for piers that deliberately touch the deck above them).
	func clear(c: Vector3, r: float, y0: float, y1: float, skip_d: float = -1000.0) -> bool:
		var reach = r + WorldKit.TRACK_CLEARANCE
		for i in _probe.size():
			if skip_d > -999.0 and absf(float(i * 3) * TrackBuilder.STEP - skip_d) < 12.0: continue
			var p: Vector3 = _probe[i]
			if Vector2(p.x - c.x, p.z - c.z).length() < reach and p.y > y0 - WorldKit.TRACK_CLEARANCE and p.y < y1 + WorldKit.TRACK_CLEARANCE:
				return false
		return true

	func stone(c: Vector3, fr: Dictionary, size: Vector3, col: Color) -> void:
		_stone.append([_xf(c, fr, size), col])

	func glass(c: Vector3, fr: Dictionary, size: Vector3, bright: bool = false) -> void:
		_glass.append([_xf(c, fr, size), bright])

	func _xf(c: Vector3, fr: Dictionary, size: Vector3) -> Transform3D:
		var r: Vector3 = fr["r"]; var f: Vector3 = fr["f"]
		return Transform3D(Basis(r * size.x, Vector3.UP * size.y, f * size.z), c)

	func flush(root: Node3D) -> void:
		var sm = ShaderMaterial.new()
		sm.shader = WorldKit.STONE_SHADER
		root.add_child(_multimesh("Terraces", _stone, sm, func(e): return e[1]))
		var gm = StandardMaterial3D.new()
		gm.vertex_color_use_as_albedo = true
		gm.albedo_color = Color(1, 1, 1)
		gm.emission_enabled = true
		gm.emission = th["glass"]
		gm.emission_energy_multiplier = 1.2
		gm.roughness = 0.1
		var mm = _multimesh("Glass", _glass, gm, func(e): return (th["accent"] as Color) if e[1] else (th["glass"] as Color))
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mm)

	func _multimesh(name: String, items: Array, mat: Material, color_of: Callable) -> MultiMeshInstance3D:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = BoxMesh.new()
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, color_of.call(items[i]))
		var mi = MultiMeshInstance3D.new()
		mi.name = name
		mi.multimesh = mm
		mi.material_override = mat
		return mi
