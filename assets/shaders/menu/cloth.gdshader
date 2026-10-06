shader_type spatial;
// Hanging banner: wind ripples in the vertex shader, cel-lit crimson cloth with the sigil printed on it.
render_mode diffuse_toon, cull_disabled;

uniform sampler2D sigil : source_color, hint_default_black;
uniform vec3 cloth : source_color = vec3(0.42, 0.015, 0.02);
uniform vec3 ink : source_color = vec3(0.01, 0.01, 0.012);
uniform float wind = 0.06;

void vertex() {
	float hang = 1.0 - UV.y;      // pinned at the top
	VERTEX.z += sin(TIME * 2.2 + VERTEX.y * 3.0 + VERTEX.x * 2.0) * wind * (1.0 - hang) + sin(TIME * 5.1 + VERTEX.x * 7.0) * wind * 0.25 * (1.0 - hang);
}

void fragment() {
	vec4 s = texture(sigil, UV);
	float mark = clamp((s.r - max(s.g, s.b)) * 2.0, 0.0, 1.0);
	ALBEDO = mix(cloth, ink, mark);
	EMISSION = mix(cloth, ink, mark) * 0.35;      // reads even in the dark
	ROUGHNESS = 0.9;
}

void light() {
	float q = step(0.25, dot(NORMAL, LIGHT) * ATTENUATION);
	DIFFUSE_LIGHT += mix(ALBEDO * 0.25, ALBEDO, q) * LIGHT_COLOR / PI;
}
