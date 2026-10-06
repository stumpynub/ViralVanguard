shader_type spatial;
// Destructible cargo block: ribbed steel, dark frame, hazard chevrons at the base and a glowing outline.
uniform vec3 tint : source_color = vec3(0.6, 0.63, 0.69);
uniform vec3 glow_color : source_color = vec3(1.0, 0.6, 0.24);
uniform float glow_strength = 0.5;
void fragment() {
	vec2 uv = UV * vec2(3.0, 2.0);
	vec2 f = fract(uv);
	float rib = step(0.5, fract(f.x * 16.0));
	vec3 col = mix(vec3(0.17, 0.19, 0.24), vec3(0.23, 0.25, 0.31), rib) * tint * 1.6;
	float frame = step(f.x, 0.04) + step(0.96, f.x) + step(f.y, 0.04) + step(0.96, f.y);
	col = mix(col, vec3(0.08, 0.09, 0.11), clamp(frame, 0.0, 1.0));
	float chev = step(0.84, f.y) * step(f.y, 0.94) * step(0.5, fract((f.x + f.y) * 8.0));
	col = mix(col, vec3(0.88, 0.63, 0.13), chev);
	float edge = step(f.x, 0.02) + step(0.98, f.x) + step(f.y, 0.02) + step(0.98, f.y) + step(0.38, f.y) * step(f.y, 0.405);
	ALBEDO = col;
	EMISSION = glow_color * clamp(edge, 0.0, 1.0) * glow_strength;
	ROUGHNESS = 0.5;
	METALLIC = 0.45;
}
