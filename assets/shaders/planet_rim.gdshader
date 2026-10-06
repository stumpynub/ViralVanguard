shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled;
// Atmosphere halo: brightest at the limb.

uniform vec3 color : source_color = vec3(0.45, 0.35, 1.0);
uniform float strength = 1.4;

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = color * pow(rim, 3.0) * strength;
}
