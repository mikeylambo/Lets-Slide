shader_type spatial;
render_mode cull_disabled;

// The riding surface. Vertex colour is the surface class (SurfaceKind), which
// stays dominant so friction reads at a glance; the region's stone gives it
// material. UV.x runs across the deck (0..1), UV.y is metres down the course.

uniform vec3 stone : source_color = vec3(0.86, 0.83, 0.78);
uniform float stone_mix : hint_range(0.0, 1.0) = 0.42;
uniform float bar_metres = 44.0;      // one 174 BPM bar at author speed
uniform float panel_metres = 4.0;     // joints between deck panels
uniform float edge_glow = 2.4;        // glass strip along both edges
uniform float band_glow = 0.9;        // beat-grid band on every bar line

float line_aa(float x, float width) {
	// Distance to the nearest integer, antialiased to ~1 px.
	float d = abs(fract(x - 0.5) - 0.5);
	float w = fwidth(x) * 1.2 + 1e-5;
	return 1.0 - smoothstep(width, width + w, d);
}

void fragment() {
	vec3 surf = COLOR.rgb;
	float u = UV.x;
	float d = UV.y;
	vec3 base = mix(surf, stone * mix(vec3(1.0), surf, 0.25), stone_mix);

	// Panel joints and lane seams: fine darker lines, the texture of speed.
	float joints = line_aa(d / panel_metres, 0.015);
	float lanes = line_aa(u * 4.0, 0.012);
	base *= 1.0 - 0.18 * max(joints, lanes * 0.7);

	// Beat grid: a lit band at each bar line, the course's tempo made visible.
	float band = line_aa(d / bar_metres, 0.006);

	// Glass edges: a bright strip just inside each lip.
	float edge = smoothstep(0.045, 0.012, min(u, 1.0 - u));

	ALBEDO = base;
	ROUGHNESS = mix(0.78, 0.18, edge);
	SPECULAR = mix(0.22, 0.6, edge);
	// A faint self-lit floor keeps a shadowed deck its readable hue instead
	// of sinking into the sky's blue.
	EMISSION = surf * (edge * edge_glow + band * band_glow) + base * 0.1;
}
