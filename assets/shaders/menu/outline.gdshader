shader_type spatial;
// Ink outline (inverted hull): pushes back faces out along the normal by a roughly constant on-screen width.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec4 ink : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width = 0.012;            // metres at 1 m from the camera
uniform float max_width = 0.05;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float w = min(width * max(1.0, -view.z), max_width);
	VERTEX += normalize(NORMAL) * w;
}

void fragment() {
	ALBEDO = ink.rgb;
}
