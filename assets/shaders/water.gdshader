shader_type spatial;
// Harbor water: dark, glossy, with drifting neon reflection streaks.
uniform vec3 base : source_color = vec3(0.024, 0.027, 0.1);
uniform float streak_strength = 1.4;
varying vec3 wpos;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * vec2(0.05, 0.6) + vec2(TIME * 0.12, TIME * 0.05);
	vec2 c = floor(p);
	float r = h21(c);
	float on = step(0.86, r) * smoothstep(0.0, 0.3, fract(p.x)) * (1.0 - smoothstep(0.5, 1.0, fract(p.x)));
	vec3 tint = r > 0.96 ? vec3(1.0, 0.17, 0.84) : (r > 0.92 ? vec3(0.13, 0.9, 1.0) : (r > 0.89 ? vec3(0.54, 0.23, 1.0) : vec3(1.0, 0.6, 0.24)));
	ALBEDO = base;
	METALLIC = 0.85;
	ROUGHNESS = 0.08;
	EMISSION = tint * on * streak_strength * 0.5;
}
