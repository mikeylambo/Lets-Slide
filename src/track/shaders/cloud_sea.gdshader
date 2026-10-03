shader_type spatial;
render_mode cull_disabled, specular_disabled;

// The sea of cloud the Shelf descends into. A slow-drifting two-tone fbm
// layer far below the course; the environment fog dissolves it into the
// horizon, which is what sells the altitude.

uniform vec3 light_col : source_color = vec3(1.0, 0.93, 0.88);
uniform vec3 shade_col : source_color = vec3(0.62, 0.66, 0.82);
uniform float scale = 0.0016;
uniform vec2 drift = vec2(0.004, 0.0015);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), w.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), w.x), w.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale + drift * TIME;
	float c = fbm(p + fbm(p * 0.5) * 0.8);
	float billow = smoothstep(0.30, 0.78, c);
	ALBEDO = mix(shade_col, light_col, billow);
	ROUGHNESS = 1.0;
	// Clouds are bright and soft; a little self-light keeps the tops from
	// going grey in the shadowed half of the sky.
	EMISSION = light_col * billow * 0.18;
}
