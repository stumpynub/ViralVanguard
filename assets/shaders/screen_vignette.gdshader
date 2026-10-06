shader_type canvas_item;
// Radial screen tint used for the damage / shield / chrono / heal overlays.
uniform vec4 color : source_color = vec4(1.0, 0.16, 0.24, 0.8);
uniform float inner = 0.4;
uniform float ring = 0.0;     // >0 adds an inner border (shield)
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p * vec2(1.0, 0.85));
	float a = smoothstep(inner, 1.25, d);
	float b = ring * (step(0.995, max(abs(p.x), abs(p.y))));
	COLOR = vec4(color.rgb, clamp(a * color.a + b, 0.0, 1.0));
}
