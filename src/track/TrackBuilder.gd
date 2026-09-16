class_name TrackBuilder
extends RefCounted

## Data-driven course geometry. All 24 verbs pass through this builder, which is
## also used by procedural courses and the developer inspector.

const STEP = 2.0
const CROSS = 13
const RAIL_LIFT = 0.06

var samples: Array[Dictionary] = []
var segment_ranges: Array[Dictionary] = []
var parallel_routes: Array[Dictionary] = []
var total_length = 0.0
var beat_map: Array[float] = []
var author_avg_speed: float = 32.0
var root: Node3D
var _tris: Array[Dictionary] = []
var _lines = PackedVector3Array()
var _line_colors = PackedColorArray()

func build(spec: Array, start_pos: Vector3 = Vector3.ZERO, start_yaw: float = 0.0, avg_speed: float = 32.0) -> Node3D:
	author_avg_speed = avg_speed
	root = Node3D.new()
	root.name = "Track"
	samples.clear()
	segment_ranges.clear()
	parallel_routes.clear()
	beat_map.clear()
	_tris.clear()
	_lines = PackedVector3Array()
	_line_colors = PackedColorArray()
	total_length = 0.0

	var first: Dictionary = spec[0] if not spec.is_empty() else {}
	var frame = {
		"pos": start_pos,
		"yaw": start_yaw,
		"pitch": deg_to_rad(float(first.get("slope", 0.0))),
		"bank": 0.0,
		"width": float(first.get("width", 14.0)),
	}
	var bar_cursor = 0.0
	for raw in spec:
		var seg: Dictionary = raw.duplicate(true)
		var seg_bars = float(seg.get("bars", Tempo.meters_to_bars(float(seg.get("length", 80.0)), author_avg_speed)))
		seg_bars = VerbLibrary.quantize_bars_for(str(seg.get("kind", "straight")), seg_bars)
		seg["bars"] = seg_bars
		seg["length"] = Tempo.bars_to_meters(seg_bars, author_avg_speed)
		beat_map.append(bar_cursor)
		var begin = total_length
		frame = _emit_segment(frame, seg)
		segment_ranges.append({"kind": str(seg.get("kind", "straight")), "from": begin, "to": total_length, "bar_from": bar_cursor, "bar_to": bar_cursor + seg_bars, "seg": seg})
		bar_cursor += seg_bars

	_flush_geometry(root, "MainLine")
	_flush_lines(root)
	_decorate_segments()
	return root

func add_parallel_route(from_dist: float, to_dist: float, lateral: float, height: float,
		width: float, surface: int, name_hint: String = "Route") -> void:
	parallel_routes.append({"from": from_dist, "to": to_dist, "lateral": lateral,
		"height": height, "width": width, "name": name_hint})
	var picked: Array[Dictionary] = []
	for s in samples:
		if float(s["dist"]) >= from_dist and float(s["dist"]) <= to_dist:
			picked.append(s)
	if picked.size() < 3:
		return
	_tris.clear()
	var span: float = maxf(to_dist - from_dist, 0.001)
	var prev = PackedVector3Array()
	for i in picked.size():
		var s: Dictionary = picked[i]
		var t: float = (float(s["dist"]) - from_dist) / span
		var blend: float = sin(clampf(t, 0.0, 1.0) * PI)
		var centre: Vector3 = s["pos"] + s["r"] * (lateral * blend) + s["u"] * (height * blend)
		var cross = PackedVector3Array()
		for j in CROSS:
			var u: float = float(j) / float(CROSS - 1) * 2.0 - 1.0
			cross.append(centre + s["r"] * (u * width * 0.5))
		if i > 0:
			_stitch(prev, cross, surface)
			_add_rail(prev, cross, SurfaceKind.color_of(surface))
		prev = cross
	_flush_geometry(root, name_hint)
	_flush_lines(root)

func sample_at(dist: float) -> Dictionary:
	if samples.is_empty():
		return {}
	var best: Dictionary = samples[0]
	var best_d = absf(float(best["dist"]) - dist)
	for s in samples:
		var dd = absf(float(s["dist"]) - dist)
		if dd < best_d:
			best = s
			best_d = dd
		if float(s["dist"]) > dist and dd > best_d:
			break
	return best

func finish_frame() -> Dictionary:
	return samples[samples.size() - 1] if not samples.is_empty() else {}

# ------------------------------------------------------------ segment verbs
func _emit_segment(frame: Dictionary, seg: Dictionary) -> Dictionary:
	var kind: String = str(seg.get("kind", "straight"))
	var length: float = float(seg.get("length", 40.0))
	var steps: int = maxi(2, int(round(length / STEP)))
	var surface: int = int(seg.get("surface", SurfaceKind.VERY_SLIPPERY))
	var turn: float = deg_to_rad(float(seg.get("turn", 0.0)))
	var target_pitch: float = deg_to_rad(float(seg.get("slope", 0.0)))
	var target_bank: float = deg_to_rad(float(seg.get("bank", 0.0)))
	var target_width: float = float(seg.get("width", frame["width"]))
	var bowl: float = float(seg.get("bowl", 0.0))
	var wall: float = float(seg.get("wall", 0.0))
	var ridge: float = float(seg.get("ridge", 0.0))
	var launch: float = deg_to_rad(float(seg.get("launch", 0.0)))
	var crest: float = deg_to_rad(float(seg.get("crest", 0.0)))
	var compression: float = deg_to_rad(float(seg.get("compression", 0.0)))
	var is_gap = kind == "gap"
	var is_pipe = kind == "fullpipe" or float(seg.get("pipe", 0.0)) > 0.0
	var start_pitch: float = frame["pitch"]
	var start_bank: float = frame["bank"]
	var start_width: float = frame["width"]
	var start_yaw: float = frame["yaw"]
	var prev_cross = PackedVector3Array()

	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var ease: float = smoothstep(0.0, 1.0, t)
		if kind == "chicane":
			frame["yaw"] = start_yaw + turn * sin(t * TAU)
		elif i > 0:
			frame["yaw"] = float(frame["yaw"]) + turn / float(steps)

		var pitch: float = lerpf(start_pitch, target_pitch, ease)
		if kind == "ramp":
			pitch = lerpf(start_pitch, -launch, smoothstep(0.35, 1.0, t))
		elif kind == "crest":
			pitch -= crest * sin(t * PI)
		elif kind == "compression":
			pitch += compression * sin(t * PI)
		elif kind == "shaft":
			pitch = lerpf(start_pitch, target_pitch, smoothstep(0.08, 0.55, t))
		frame["pitch"] = pitch

		var bank_now = lerpf(start_bank, target_bank, ease)
		if kind == "transfer":
			bank_now += deg_to_rad(36.0) * sin(t * TAU)
		elif kind == "corkscrew":
			bank_now = start_bank + target_bank * t
		frame["bank"] = bank_now
		frame["width"] = lerpf(start_width, target_width, ease)

		var basis_data = _frame_basis(frame)
		var f: Vector3 = basis_data["f"]
		var r: Vector3 = basis_data["r"]
		var u: Vector3 = basis_data["u"]
		if i > 0:
			frame["pos"] = frame["pos"] + f * STEP
			total_length += STEP
		var pos: Vector3 = frame["pos"]
		samples.append({"pos": pos, "f": f, "r": r, "u": u, "dist": total_length, "surface": surface, "gap": is_gap, "kind": kind})
		if is_gap:
			prev_cross = PackedVector3Array()
			continue

		var cross = PackedVector3Array()
		if is_pipe:
			var radius: float = float(frame["width"]) * 0.5
			for j in CROSS:
				var a = -PI + (TAU * float(j) / float(CROSS - 1))
				cross.append(pos + r * sin(a) * radius + u * (radius + cos(a) * radius))
		else:
			for j in CROSS:
				var uu: float = float(j) / float(CROSS - 1) * 2.0 - 1.0
				var lateral: float = uu * float(frame["width"]) * 0.5
				var lift = 0.0
				if bowl != 0.0:
					lift += bowl * uu * uu
				if ridge != 0.0:
					lift -= ridge * pow(absf(uu), 1.35)
				if wall != 0.0:
					var ws = 0.55
					var aa: float = absf(uu)
					if aa > ws:
						var kk: float = (aa - ws) / (1.0 - ws)
						lift += wall * kk * kk
				cross.append(pos + r * lateral + u * lift)
		if not prev_cross.is_empty():
			_stitch(prev_cross, cross, surface)
			_add_rail(prev_cross, cross, SurfaceKind.color_of(surface))
		prev_cross = cross

	if kind == "ramp":
		frame["pitch"] = start_pitch
	if kind == "chicane":
		frame["yaw"] = start_yaw
	return frame

func _decorate_segments() -> void:
	for info in segment_ranges:
		var kind = str(info["kind"])
		var from_d = float(info["from"])
		var to_d = float(info["to"])
		var seg: Dictionary = info["seg"]
		match kind:
			"split":
				add_parallel_route(from_d + 8.0, to_d - 8.0, float(seg.get("split_offset", 7.0)), float(seg.get("split_height", 1.1)), maxf(5.5, float(seg.get("width", 18.0)) * 0.42), int(seg.get("surface", SurfaceKind.VERY_SLIPPERY)), "SplitRoute")
			"tunnel":
				_add_tunnel_rings(from_d, to_d, float(seg.get("width", 15.0)))
			"fullpipe":
				_add_tunnel_rings(from_d, to_d, float(seg.get("width", 19.0)))
			"updraft":
				_add_effect(from_d, to_d, TrackEffect.Kind.UPDRAFT, float(seg.get("updraft", 10.0)))
			"hazard":
				_add_hazards(from_d, to_d, int(seg.get("hazards", 3)))
			"transfer":
				add_parallel_route(from_d + 12.0, to_d - 12.0, 6.5, 4.0, 5.5, SurfaceKind.SLIPPERY, "TransferHighLine")

func _add_tunnel_rings(from_d: float, to_d: float, width: float) -> void:
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var d = from_d
	while d <= to_d:
		var s = sample_at(d)
		if not s.is_empty():
			var radius = width * 0.58
			for j in 16:
				var a0 = TAU * float(j) / 16.0
				var a1 = TAU * float(j + 1) / 16.0
				var p0: Vector3 = s["pos"] + s["r"] * cos(a0) * radius + s["u"] * (sin(a0) * radius + radius * 0.4)
				var p1: Vector3 = s["pos"] + s["r"] * cos(a1) * radius + s["u"] * (sin(a1) * radius + radius * 0.4)
				im.surface_set_color(Color(0.24, 0.75, 1.0, 0.42))
				im.surface_add_vertex(p0)
				im.surface_set_color(Color(0.24, 0.75, 1.0, 0.42))
				im.surface_add_vertex(p1)
		d += 16.0
	im.surface_end()
	var mi = MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _line_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

func _add_effect(from_d: float, to_d: float, kind: int, strength: float) -> void:
	var mid = sample_at((from_d + to_d) * 0.5)
	if mid.is_empty():
		return
	var fx = TrackEffect.new()
	fx.setup(kind, Vector3(16.0, 16.0, maxf(18.0, to_d - from_d)), strength)
	# TrackBuilder also runs outside the SceneTree in unit tests. Samples are
	# authored in Track-local coordinates, so set the local transform directly;
	# querying/setting global_transform before the node enters the tree is invalid.
	fx.position = mid["pos"] + mid["u"] * 4.0
	fx.basis = Basis.looking_at(mid["f"], mid["u"])
	root.add_child(fx)

func _add_hazards(from_d: float, to_d: float, count: int) -> void:
	for i in range(count):
		var t = float(i + 1) / float(count + 1)
		var s = sample_at(lerpf(from_d, to_d, t))
		if s.is_empty():
			continue
		var body = StaticBody3D.new()
		body.name = "Hazard_%d" % i
		body.set_meta("surface_class", SurfaceKind.NOT_SLIPPERY)
		var cs = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1.6, 2.7, 1.6)
		cs.shape = shape
		body.add_child(cs)
		var mi = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = shape.size
		mi.mesh = mesh
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.03, 0.08)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.12, 0.28)
		mat.emission_energy_multiplier = 2.2
		mi.material_override = mat
		body.add_child(mi)
		var lateral = (-1.0 if i % 2 == 0 else 1.0) * float(s.get("width", 12.0)) * 0.18
		body.position = s["pos"] + s["r"] * lateral + s["u"] * 1.35
		root.add_child(body)

func _frame_basis(frame: Dictionary) -> Dictionary:
	var yaw: float = frame["yaw"]
	var pitch: float = frame["pitch"]
	var bank: float = frame["bank"]
	var f = Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var r = Vector3.UP.cross(f)
	if r.length() < 0.001:
		r = Vector3.RIGHT
	r = r.normalized()
	var u = f.cross(r).normalized()
	if bank != 0.0:
		r = r.rotated(f, bank).normalized()
		u = f.cross(r).normalized()
	return {"f": f, "r": r, "u": u}

func _stitch(a: PackedVector3Array, b: PackedVector3Array, surface: int) -> void:
	if a.size() != b.size():
		return
	for i in range(a.size() - 1):
		_tris.append({"v": [a[i], b[i], a[i + 1]], "s": surface})
		_tris.append({"v": [a[i + 1], b[i], b[i + 1]], "s": surface})

func _add_rail(a: PackedVector3Array, b: PackedVector3Array, c: Color) -> void:
	var lift = Vector3.UP * RAIL_LIFT
	for idx in [0, a.size() - 1]:
		_lines.append(a[idx] + lift)
		_lines.append(b[idx] + lift)
		_line_colors.append(c)
		_line_colors.append(c)
	var mid = int(a.size() / 2)
	_lines.append(a[mid] + lift)
	_lines.append(b[mid] + lift)
	var faint = Color(c.r, c.g, c.b, 0.22)
	_line_colors.append(faint)
	_line_colors.append(faint)

func _flush_geometry(parent: Node3D, node_name: String) -> void:
	if _tris.is_empty():
		return
	var by_surface = {}
	for tri in _tris:
		var s: int = tri["s"]
		if not by_surface.has(s):
			by_surface[s] = []
		by_surface[s].append(tri["v"])
	_tris.clear()
	for s in by_surface.keys():
		var tris: Array = by_surface[s]
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var col: Color = SurfaceKind.color_of(s)
		var faces = PackedVector3Array()
		for v in tris:
			var n: Vector3 = (v[1] - v[0]).cross(v[2] - v[0]).normalized()
			for k in 3:
				st.set_color(col)
				st.set_normal(n)
				st.add_vertex(v[k])
				faces.append(v[k])
		st.index()
		var body = StaticBody3D.new()
		body.name = "%s_%s" % [node_name, SurfaceKind.name_of(s)]
		body.set_meta("surface_class", s)
		var mi = MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _track_material()
		body.add_child(mi)
		var shape = ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var cs = CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)

func _flush_lines(parent: Node3D) -> void:
	if _lines.is_empty():
		return
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _lines
	arr[Mesh.ARRAY_COLOR] = _line_colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var mi = MeshInstance3D.new()
	mi.name = "Rails"
	mi.mesh = mesh
	mi.material_override = _line_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_lines = PackedVector3Array()
	_line_colors = PackedColorArray()

static func _track_material() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.66
	m.metallic = 0.08
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _line_material() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
