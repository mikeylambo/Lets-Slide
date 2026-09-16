class_name FlowVisualDirector
extends Node

var environment_node: WorldEnvironment
var rider: SlideBody
var _tier = 0
var _invert_target = 0.0
var _invert_mix = 0.0
var _chroma_target = 0.0
var _chroma_mix = 0.0
var _overlay: ColorRect
var _shader: ShaderMaterial

func setup(env_node: WorldEnvironment, slider: SlideBody, flow: FlowSystem) -> void:
	environment_node = env_node
	rider = slider
	flow.tier_changed.connect(_on_tier)
	_build_overlay()

func _build_overlay() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float invert_amount : hint_range(0.0, 1.0) = 0.0;
uniform float chroma_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
    vec2 px = SCREEN_PIXEL_SIZE * (1.0 + chroma_amount * 5.0);
    vec4 base = texture(screen_texture, SCREEN_UV);
    float r = texture(screen_texture, SCREEN_UV + vec2(px.x * chroma_amount, 0.0)).r;
    float b = texture(screen_texture, SCREEN_UV - vec2(px.x * chroma_amount, 0.0)).b;
    vec3 shifted = vec3(r, base.g, b);
    vec3 inverted = vec3(1.0) - shifted;
    COLOR = vec4(mix(shifted, inverted, invert_amount), 1.0);
}
"""
	_shader = ShaderMaterial.new()
	_shader.shader = shader
	_overlay.material = _shader
	layer.add_child(_overlay)

func _on_tier(tier: int) -> void:
	_tier = tier
	_invert_target = 1.0 if tier == FlowSystem.Tier.INVERT else 0.0
	_chroma_target = 0.32 if tier == FlowSystem.Tier.BURN else (0.18 if tier == FlowSystem.Tier.INVERT else 0.0)
	if rider != null and rider.has_method("set_flow_tier"):
		rider.set_flow_tier(tier)

func _process(delta: float) -> void:
	_invert_mix = lerpf(_invert_mix, _invert_target, clampf(delta * 3.0, 0.0, 1.0))
	_chroma_mix = lerpf(_chroma_mix, _chroma_target, clampf(delta * 4.0, 0.0, 1.0))
	var fx = float(Game.settings.get("flow_effects", 1.0))
	if _shader != null:
		_shader.set_shader_parameter("invert_amount", _invert_mix * fx)
		_shader.set_shader_parameter("chroma_amount", _chroma_mix * fx)
	if environment_node == null or environment_node.environment == null:
		return
	var env = environment_node.environment
	env.glow_intensity = 0.55 + float(_tier) * 0.14 * float(Game.settings.get("flow_effects", 1.0))
