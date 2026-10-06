shader_type canvas_item;
// The sigil art is red on black: key the black out, keep the red, and let it pulse like a heartbeat.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float red = clamp((c.r - max(c.g, c.b)) * 2.2, 0.0, 1.0);
	float beat = 0.85 + 0.15 * pow(max(sin(TIME * 2.4), 0.0), 8.0);
	COLOR = vec4(vec3(0.9, 0.04, 0.03) * (0.8 + 0.6 * beat) , red * COLOR.a);
}
