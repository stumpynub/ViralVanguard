shader_type spatial;
// Holographic billboard: soft colour blobs, scanlines and a slow scrolling sheen.
render_mode unshaded, cull_disabled;
uniform vec3 color_a : source_color = vec3(0.13, 0.9, 1.0);
uniform vec3 color_b : source_color = vec3(0.54, 0.23, 1.0);
uniform float brightness = 1.6;
float blob(vec2 uv, vec2 c, float r) { return exp(-dot(uv - c, uv - c) / (r * r)); }
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.04, 0.016, 0.125), vec3(0.08, 0.03, 0.22), uv.x * uv.y);
	col += color_a * blob(uv, vec2(0.3 + 0.05 * sin(TIME * 0.3), 0.35), 0.25) * 0.8;
	col += color_b * blob(uv, vec2(0.72, 0.3 + 0.05 * cos(TIME * 0.4)), 0.3) * 0.8;
	col += color_a * blob(uv, vec2(0.6, 0.62), 0.18) * 0.5;
	col *= 0.8 + 0.2 * step(0.5, fract(uv.y * 128.0));
	col += vec3(0.2) * smoothstep(0.02, 0.0, abs(fract(uv.y - TIME * 0.18) - 0.5));
	float frame = step(uv.x, 0.012) + step(0.988, uv.x) + step(uv.y, 0.012) + step(0.988, uv.y);
	col = mix(col, color_a * 1.5, clamp(frame, 0.0, 1.0));
	ALBEDO = col * brightness;
}
