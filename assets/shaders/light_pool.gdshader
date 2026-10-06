shader_type spatial;
// Additive glow pool on wet ground under neon (stand-in for real lights, like the original's light pools).
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;
uniform vec3 color : source_color = vec3(0.13, 0.9, 1.0);
uniform float strength = 0.5;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(0.0, 1.0 - d), 2.2);
	ALBEDO = color * a * strength;
}
