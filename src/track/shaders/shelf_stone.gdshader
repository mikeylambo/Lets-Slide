shader_type spatial;

// Masonry of the Shelf. Instance colour (MultiMesh) is the block's tone.
// World-space strata on the faces and flagstones on the tops read as built
// stone at any block size, with no textures or UVs.

uniform float strata_metres = 3.2;
uniform float flag_metres = 6.0;

varying vec3 world_pos;
varying vec3 world_nrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453); }
float line_aa(float x, float width) {
	float d = abs(fract(x - 0.5) - 0.5);
	float w = fwidth(x) * 1.2 + 1e-5;
	return 1.0 - smoothstep(width, width + w, d);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 tone = COLOR.rgb;
	float top = smoothstep(0.6, 0.9, world_nrm.y);
	// Faces: courses of stone, each a slightly different shade, with a joint.
	float course_i = floor(world_pos.y / strata_metres);
	float course_tone = 0.92 + 0.12 * hash(vec2(course_i, 7.0));
	float joint = line_aa(world_pos.y / strata_metres, 0.03);
	// Tops: flagstones.
	vec2 cell = floor(world_pos.xz / flag_metres);
	float flag_tone = 0.94 + 0.1 * hash(cell);
	float flag_joint = max(line_aa(world_pos.x / flag_metres, 0.02), line_aa(world_pos.z / flag_metres, 0.02));
	float shade = mix(course_tone * (1.0 - 0.28 * joint), flag_tone * (1.0 - 0.22 * flag_joint), top);
	ALBEDO = tone * shade;
	ROUGHNESS = 0.86;
	SPECULAR = 0.3;
}
