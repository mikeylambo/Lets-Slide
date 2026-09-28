// Readability Kit greybox surface: world-space triplanar grid.
// Minor cells give continuous motion parallax; major lines glow faintly so
// speed reads even in shadow; the surface-class vertex colour tints through
// so friction classes stay distinguishable.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.44, 0.46, 0.50);
uniform vec3 line_color : source_color = vec3(0.09, 0.10, 0.12);
uniform vec3 major_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float cell = 2.0;
uniform float major_every = 5.0;
uniform float surface_tint = 0.30;
uniform float checker_contrast = 0.07;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p, float spacing, float width) {
	vec2 g = p / spacing;
	vec2 fw = max(fwidth(g), vec2(1e-5));
	vec2 d = abs(fract(g - 0.5) - 0.5) / fw;
	float line = 1.0 - min(min(d.x, d.y) / width, 1.0);
	// Fade lines once cells shrink to a few pixels: no distant moire.
	return line * (1.0 - smoothstep(0.2, 0.55, max(fw.x, fw.y)));
}

float checker(vec2 p, float spacing) {
	vec2 c = floor(p / spacing);
	return mod(c.x + c.y, 2.0);
}

void fragment() {
	vec3 w = pow(abs(world_normal), vec3(4.0));
	w /= (w.x + w.y + w.z + 1e-5);
	vec2 px = world_pos.zy;
	vec2 py = world_pos.xz;
	vec2 pz = world_pos.xy;
	float minor = grid_line(px, cell, 1.0) * w.x + grid_line(py, cell, 1.0) * w.y + grid_line(pz, cell, 1.0) * w.z;
	float big = cell * major_every;
	float major = grid_line(px, big, 1.6) * w.x + grid_line(py, big, 1.6) * w.y + grid_line(pz, big, 1.6) * w.z;
	float chk = checker(px, cell) * w.x + checker(py, cell) * w.y + checker(pz, cell) * w.z;
	vec3 base = mix(base_color, COLOR.rgb, surface_tint);
	base *= 1.0 - checker_contrast + 2.0 * checker_contrast * chk;
	vec3 col = mix(base, line_color, minor * 0.6);
	col = mix(col, major_color, major * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.88;
	EMISSION = major_color * major * 0.35;
}
