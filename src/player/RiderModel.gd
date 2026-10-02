class_name RiderModel
extends Node3D

## Ed. If `res://art/ed/ed.glb` exists (the Meshy export), it is loaded,
## normalised to 1.2 m, feet on the board, facing travel. Otherwise a stand-in
## Ed is assembled from primitives in his exact palette: grey beanie, black
## spiky hair, grey track hoodie and pants with white stripes, white-and-blue
## shoes, and the yellow chick on his chest.
##
## Either way the rider is posed procedurally from the motor's state: crouch
## and arm balance on the ground, a tighter shape when tucking, arms up in the
## air, a squash on landing. Lean into turns comes from SlideBody's roll. A
## rigged model rides side-on in a board stance (see EdRig); a static one is
## shown as authored.

const GLB_PATH = "res://art/ed/ed.glb"
## Where the rider model comes from. A res:// path is imported by Godot; any
## other path (e.g. user://) is read at runtime with GLTFDocument.
static var glb_path = GLB_PATH
const HEIGHT = 1.2
const FEET_Y = -0.31                 ## top of the board
const RIDE_SCALE = 0.62

const SKIN = Color("f2c7a5")
const HAIR = Color("1b1c22")
const BEANIE = Color("8a8d93")
const HOODIE = Color("6e7178")
const PANTS = Color("74777e")
const STRIPE = Color("eef0f4")
const SHOE = Color("f4f5f7")
const SHOE_BLUE = Color("3a5f8f")
const CHICK = Color("ffd93a")
## Hair spikes as directions from the head centre: a forward fringe, swept
## sides and a messy crown behind, matching the reference sheet.
const SPIKES = [
	Vector3(-0.35, 0.25, -0.9), Vector3(0.0, 0.35, -0.95), Vector3(0.35, 0.22, -0.9),
	Vector3(-0.95, 0.05, -0.2), Vector3(0.95, 0.05, -0.2), Vector3(-0.9, -0.2, 0.3), Vector3(0.9, -0.2, 0.3),
	Vector3(-0.5, 0.1, 0.85), Vector3(0.5, 0.1, 0.85), Vector3(0.0, -0.25, 0.95), Vector3(-0.75, 0.45, 0.45), Vector3(0.75, 0.45, 0.45),
]

var is_imported = false
var glow_color = CHICK
var _parts = {}                      ## name -> MeshInstance3D (stand-in limbs)
var _mats: Array[StandardMaterial3D] = []
var _glow: Array[StandardMaterial3D] = []
var _squash = 0.0
var _pose_tuck = 0.0
var _pose_air = 0.0
var _clock = 0.0
var _rig: EdRig = null                ## set when the model has Ed's skeleton

func _ready() -> void:
	# Chibi proportions at 0.62 keep the horizon clear for the tuned chase cam.
	scale = Vector3.ONE * RIDE_SCALE
	position.y = FEET_Y * (1.0 - RIDE_SCALE)
	if _load_glb():
		is_imported = true
	else:
		_build_standin()
		pose(0.0, 0.0, 1.0)

# ------------------------------------------------------------ imported model
func _load_glb() -> bool:
	var inst: Node3D = null
	if glb_path.begins_with("res://"):
		if not ResourceLoader.exists(glb_path): return false
		var scene = load(glb_path)
		if scene is PackedScene: inst = scene.instantiate()
	elif FileAccess.file_exists(glb_path):
		var doc = GLTFDocument.new(); var st = GLTFState.new()
		if doc.append_from_file(glb_path, st) == OK: inst = doc.generate_scene(st) as Node3D
	if inst == null:
		return false
	add_child(inst)
	var box = _aabb(inst, Transform3D.IDENTITY)
	if box.size.y <= 0.001:
		inst.queue_free(); return false
	var s = HEIGHT / box.size.y
	inst.scale = Vector3.ONE * s
	inst.rotation.y = PI                     # glTF faces +Z; our rider faces -Z
	inst.position = Vector3(-box.get_center().x * s, FEET_Y - box.position.y * s, box.get_center().z * s)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_unbake_light(mi)
	var skels = inst.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		_rig = EdRig.create(skels[0])
	if _rig:
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			(ap as AnimationPlayer).stop()
		pose(0.0, 0.0, 0.6)
	return true

## Meshy exports bake the lit colour into an emissive copy of the albedo, which
## would make Ed glow flat under the course lighting. The game lights him.
static func _unbake_light(mi: MeshInstance3D) -> void:
	if mi.mesh == null: return
	for i in mi.mesh.get_surface_count():
		var m = mi.mesh.surface_get_material(i) as BaseMaterial3D
		if m and m.emission_enabled:
			var own = m.duplicate() as BaseMaterial3D
			own.emission_enabled = false
			own.rim_enabled = true; own.rim = 0.3; own.rim_tint = 0.5
			mi.set_surface_override_material(i, own)

static func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out = AABB()
	var first = true
	var t = xf * (n.transform if n is Node3D else Transform3D.IDENTITY)
	if n is MeshInstance3D and n.mesh:
		var mi := n as MeshInstance3D
		var mt = t
		# A skinned mesh renders in its skeleton's space through the bind
		# poses, not through its own node transform.
		if mi.skin and mi.skin.get_bind_count() > 0 and mi.get_parent() is Skeleton3D:
			var sk := mi.get_parent() as Skeleton3D
			var bone = mi.skin.get_bind_bone(0)
			if bone < 0: bone = sk.find_bone(mi.skin.get_bind_name(0))
			if bone >= 0: mt = xf * sk.get_bone_global_rest(bone) * mi.skin.get_bind_pose(0)
		var b = mt * mi.get_aabb()
		out = b; first = false
	for c in n.get_children():
		var cb = _aabb(c, t)
		if cb.size != Vector3.ZERO:
			out = cb if first else out.merge(cb); first = false
	return out

# ----------------------------------------------------------------- stand-in
func _mat(c: Color, glow: bool = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.75
	m.rim_enabled = true; m.rim = 0.35; m.rim_tint = 0.4
	if glow:
		m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = 0.6
		_glow.append(m)
	_mats.append(m)
	return m

func _sphere(name: String, r: float, c: Color, pos: Vector3, glow: bool = false) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); mi.name = name
	var m = SphereMesh.new(); m.radius = r; m.height = r * 2.0; m.radial_segments = 16; m.rings = 8
	mi.mesh = m; mi.material_override = _mat(c, glow); mi.position = pos
	add_child(mi); _parts[name] = mi
	return mi

func _limb(name: String, r: float, c: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); mi.name = name
	var m = CapsuleMesh.new(); m.radius = r; m.height = 1.0; m.radial_segments = 12; m.rings = 2
	mi.mesh = m; mi.material_override = _mat(c)
	add_child(mi); _parts[name] = mi
	return mi

func _box(name: String, size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi = MeshInstance3D.new(); mi.name = name
	var m = BoxMesh.new(); m.size = size
	mi.mesh = m; mi.material_override = _mat(c); mi.position = pos
	add_child(mi); _parts[name] = mi
	return mi

func _build_standin() -> void:
	for side in ["l", "r"]:
		_limb("thigh_" + side, 0.085, PANTS)
		_limb("shin_" + side, 0.075, PANTS)
		_box("shoe_" + side, Vector3(0.15, 0.11, 0.30), SHOE, Vector3.ZERO)
		_box("heel_" + side, Vector3(0.152, 0.06, 0.10), SHOE_BLUE, Vector3.ZERO)
		_limb("arm_" + side, 0.07, HOODIE)
		_limb("forearm_" + side, 0.065, HOODIE)
		_sphere("hand_" + side, 0.065, SKIN, Vector3.ZERO)
	_limb("torso", 0.165, HOODIE)
	_sphere("hood", 0.15, HOODIE, Vector3.ZERO)
	_sphere("chick", 0.045, CHICK, Vector3.ZERO, true)
	_sphere("head", 0.22, SKIN, Vector3.ZERO)
	_sphere("hair", 0.235, HAIR, Vector3.ZERO)
	for i in SPIKES.size():
		var spike = MeshInstance3D.new(); spike.name = "spike_%d" % i
		var cm = CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.075; cm.height = 0.24
		spike.mesh = cm; spike.material_override = _mat(HAIR)
		add_child(spike); _parts[spike.name] = spike
	_sphere("beanie", 0.235, BEANIE, Vector3.ZERO)
	var band = MeshInstance3D.new(); band.name = "band"
	var bm = CylinderMesh.new(); bm.top_radius = 0.245; bm.bottom_radius = 0.245; bm.height = 0.09
	band.mesh = bm; band.material_override = _mat(BEANIE.darkened(0.12)); add_child(band); _parts["band"] = band
	for side in [-1.0, 1.0]:
		var eye = _sphere("eye_%d" % int(side), 0.045, Color("2a2c34"), Vector3.ZERO)
		eye.scale = Vector3(0.85, 1.3, 0.45)
		var shine = _sphere("shine_%d" % int(side), 0.014, Color.WHITE, Vector3.ZERO)

## Places a capsule between two points.
func _span(name: String, a: Vector3, b: Vector3) -> void:
	var mi: MeshInstance3D = _parts[name]
	var d = b - a
	var len = maxf(d.length(), 0.001)
	var cap: CapsuleMesh = mi.mesh
	mi.position = (a + b) * 0.5
	var y = d / len
	var x = y.cross(Vector3.FORWARD) if absf(y.dot(Vector3.FORWARD)) < 0.95 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	mi.basis = Basis(x, y, x.cross(y).normalized()).orthonormalized()
	# Unit-height capsule stretched along the limb; radius stays as authored.
	mi.scale = Vector3(1.0, len + cap.radius * 2.0, 1.0)

## tuck 0..1, air 0..1, ground speed fraction 0..1. Positions are in the
## board's frame: -Z is the direction of travel.
func pose(tuck: float, air: float, speed_t: float) -> void:
	if _rig:
		_rig.pose(tuck, air, speed_t, _squash, _clock); return
	if is_imported or _parts.is_empty(): return
	var crouch = lerpf(0.0, 0.16, tuck) + 0.06 * speed_t
	var squash = _squash
	var hip = Vector3(0, 0.16 - crouch - squash * 0.08, 0.04)
	var chest = hip + Vector3(0, 0.40 - crouch * 0.4, -0.10 - tuck * 0.12)
	var neck = chest + Vector3(0, 0.10, -0.02)
	var head = neck + Vector3(0, 0.22, -0.03 - tuck * 0.05)
	for i in 2:
		var s = -1.0 if i == 0 else 1.0
		var side = "l" if i == 0 else "r"
		var foot = Vector3(0.17 * s, FEET_Y + 0.07, 0.10 * s)
		var knee = Vector3(0.24 * s, lerpf(-0.06, -0.12, tuck) - squash * 0.05, -0.08 + 0.05 * s)
		var hip_j = hip + Vector3(0.11 * s, 0, 0)
		_span("thigh_" + side, hip_j, knee)
		_span("shin_" + side, knee, foot + Vector3(0, 0.05, 0))
		_parts["shoe_" + side].position = foot + Vector3(0, -0.02, -0.04)
		_parts["heel_" + side].position = foot + Vector3(0, 0.0, 0.08)
		var shoulder = chest + Vector3(0.21 * s, 0.02, 0.02)
		# Arms out for balance (the Boy Pose silhouette), in when tucked, up in the air.
		var reach = lerpf(0.55, 0.22, tuck)
		var lift = lerpf(-0.10, 0.30, air) * (1.0 - tuck)
		var hand = shoulder + Vector3(reach * s, lift - 0.04, -0.12 - tuck * 0.18)
		var elbow = shoulder.lerp(hand, 0.5) + Vector3(0, -0.04, 0.05)
		_span("arm_" + side, shoulder, elbow)
		_span("forearm_" + side, elbow, hand)
		_parts["hand_" + side].position = hand
	_span("torso", hip + Vector3(0, 0.08, 0), chest)
	_parts["hood"].position = neck + Vector3(0, 0.02, 0.15)
	_parts["chick"].position = chest + Vector3(0.09, -0.06, -0.19)
	_parts["head"].position = head
	_parts["hair"].position = head + Vector3(0, 0.04, 0.03)
	for i in SPIKES.size():
		var dir: Vector3 = (SPIKES[i] as Vector3).normalized()
		var spike: MeshInstance3D = _parts["spike_%d" % i]
		if i < 3:
			# Fringe: hangs down over the forehead from under the beanie.
			spike.position = head + Vector3(dir.x * 0.13, 0.06, -0.17)
			spike.basis = Basis(Quaternion(Vector3.UP, Vector3(dir.x * 0.4, -1.0, -0.35).normalized()))
		else:
			spike.position = head + dir * 0.2
			spike.basis = Basis(Quaternion(Vector3.UP, (dir + Vector3(0, -0.35, 0)).normalized()))
	# Beanie worn back on the head so the fringe shows, as in the reference.
	_parts["beanie"].position = head + Vector3(0, 0.13, 0.05)
	_parts["beanie"].scale = Vector3(1.04, 0.78, 1.04)
	_parts["beanie"].rotation = Vector3(0.3, 0, 0)
	_parts["band"].position = head + Vector3(0, 0.085, 0.035)
	_parts["band"].rotation = Vector3(0.3, 0, 0)
	for s in [-1, 1]:
		_parts["eye_%d" % s].position = head + Vector3(0.085 * s, -0.02, -0.195)
		_parts["shine_%d" % s].position = head + Vector3(0.075 * s, 0.01, -0.215)

func land(quality: float, speed: float) -> void:
	_squash = clampf(speed / 40.0, 0.2, 1.0) * (1.2 - clampf(quality, 0.0, 1.0))

func animate(delta: float, tuck: float, grounded: bool, speed_t: float) -> void:
	_clock += delta
	_squash = move_toward(_squash, 0.0, delta * 3.0)
	_pose_tuck = lerpf(_pose_tuck, tuck, clampf(delta * 10.0, 0.0, 1.0))
	_pose_air = lerpf(_pose_air, 0.0 if grounded else 1.0, clampf(delta * 6.0, 0.0, 1.0))
	pose(_pose_tuck, _pose_air, speed_t)

func set_glow(energy: float) -> void:
	for m in _glow: m.emission_energy_multiplier = energy

## Ghost riders (replay rivals) render the whole figure translucent.
func set_ghost(tint: Color) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m = StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = tint
		(mi as MeshInstance3D).material_override = m
