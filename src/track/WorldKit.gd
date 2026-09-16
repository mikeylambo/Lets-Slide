class_name WorldKit
extends RefCounted

## The Shelf: one material/lighting pipeline, five silhouette languages. Region
## identity comes from shape and void composition rather than five asset sets.

const REGION_SKY = [
	[Color(0.025,0.045,0.09), Color(0.10,0.16,0.29)],
	[Color(0.055,0.025,0.075), Color(0.18,0.07,0.22)],
	[Color(0.018,0.055,0.08), Color(0.05,0.20,0.26)],
	[Color(0.045,0.04,0.065), Color(0.14,0.12,0.21)],
	[Color(0.015,0.016,0.026), Color(0.09,0.035,0.07)],
]

static func add_environment(parent: Node3D, region_index: int = 0) -> WorldEnvironment:
	region_index = clampi(region_index, 0, REGION_SKY.size() - 1)
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var mat = ProceduralSkyMaterial.new()
	mat.sky_top_color = REGION_SKY[region_index][0]
	mat.sky_horizon_color = REGION_SKY[region_index][1]
	mat.ground_bottom_color = Color(0.008, 0.01, 0.018)
	mat.ground_horizon_color = REGION_SKY[region_index][1].darkened(0.45)
	mat.sun_angle_max = 9.0
	mat.sun_curve = 0.10
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.48
	env.fog_enabled = true
	env.fog_light_color = REGION_SKY[region_index][1].darkened(0.15)
	env.fog_density = 0.0020 + float(region_index) * 0.00028
	env.fog_sky_affect = 0.30
	env.fog_aerial_perspective = 0.42
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 0.82
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	var we = WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	return we

static func add_sun(parent: Node3D, region_index: int = 0) -> DirectionalLight3D:
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 0.82
	sun.light_color = Color(0.86, 0.94, 1.0).lerp(Color(1.0,0.72,0.88), float(region_index) / 8.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 210.0
	parent.add_child(sun)
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -140, 0)
	fill.light_energy = 0.24
	fill.light_color = Color(0.42, 0.62, 1.0)
	parent.add_child(fill)
	return sun

static func add_shelf_architecture(parent: Node3D, builder: TrackBuilder, region_index: int) -> Node3D:
	var root = Node3D.new()
	root.name = "ShelfArchitecture"
	parent.add_child(root)
	if builder == null or builder.samples.is_empty(): return root
	var spacing = [150.0, 110.0, 190.0, 95.0, 120.0][clampi(region_index,0,4)]
	var d = 80.0
	var n = 0
	while d < builder.total_length:
		var s = builder.sample_at(d)
		if not s.is_empty():
			match region_index:
				0: _arch(root, s, 28.0 + float(n % 3) * 8.0, 1.0)
				1: _rib(root, s, 24.0 + float(n % 4) * 5.0)
				2: _spire(root, s, 46.0 + float(n % 3) * 18.0)
				3: _needle(root, s, 32.0 + float(n % 5) * 9.0)
				4: _arch(root, s, 18.0 + float(n % 2) * 5.0, 2.2)
		d += spacing
		n += 1
	return root

static func _emissive(c: Color, energy: float = 1.4) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.72)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.62
	return m

static func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> void:
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new(); mesh.size = size; mi.mesh = mesh
	mi.material_override = _emissive(c, 0.75)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

static func _arch(parent: Node3D, s: Dictionary, h: float, thickness: float) -> void:
	var c = Color(0.16,0.48,0.66,1)
	_box(parent, s["pos"] + s["r"] * 20.0 + Vector3.UP * h * 0.5, Vector3(thickness,h,thickness), c)
	_box(parent, s["pos"] - s["r"] * 20.0 + Vector3.UP * h * 0.5, Vector3(thickness,h,thickness), c)
	_box(parent, s["pos"] + Vector3.UP * h, Vector3(40.0,thickness,thickness), c)

static func _rib(parent: Node3D, s: Dictionary, h: float) -> void:
	for side in [-1.0,1.0]:
		for k in range(3):
			_box(parent, s["pos"] + s["r"] * side * (18.0 + k*5.0) + Vector3.UP*(h*0.5+k*3.0), Vector3(1.2,h+k*6.0,2.0), Color(0.45,0.18,0.62))

static func _spire(parent: Node3D, s: Dictionary, h: float) -> void:
	_box(parent, s["pos"] + s["r"] * (30.0 if int(h)%2==0 else -30.0) + Vector3.UP*h*0.5, Vector3(2.0,h,2.0), Color(0.12,0.64,0.78))

static func _needle(parent: Node3D, s: Dictionary, h: float) -> void:
	for side in [-1.0,1.0]:
		_box(parent, s["pos"] + s["r"]*side*13.0 + Vector3.UP*h*0.5, Vector3(0.55,h,0.55), Color(0.46,0.42,0.74))

static func add_flow_palette(_parent: Node3D) -> void:
	pass
