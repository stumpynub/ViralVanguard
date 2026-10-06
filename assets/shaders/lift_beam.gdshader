shader_type spatial;
// Gravity-lift beam: additive cyan cylinder with scan bands scrolling upward.
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
uniform vec3 color : source_color = vec3(0.13, 0.9, 1.0);
uniform float height = 20.0;
void fragment() {
	float y = UV.y * height;
	float band = 0.5 + 0.5 * sin((y / 6.0 * 16.0 - TIME * 3.0) * 6.2832 / 16.0 * 16.0 / 6.0);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = color * (0.06 + 0.18 * band) * (0.3 + rim) * smoothstep(0.0, 1.5, y) * (1.0 - smoothstep(height - 1.0, height, y));
}
