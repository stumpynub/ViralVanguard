shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;
// The painted city wrapped around the arena on a huge cylinder (assets/generated/menu/city_02), with window twinkle.
uniform sampler2D city : source_color, filter_linear_mipmap, repeat_enable;
uniform float repeats = 3.0;
uniform float brightness = 0.85;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = vec2(UV.x * repeats, UV.y);
	vec3 c = texture(city, uv).rgb;
	float red = clamp((c.r - max(c.g, c.b)) * 3.0, 0.0, 1.0);
	vec2 cell = floor(uv * vec2(260.0, 110.0));
	c += vec3(1.0, 0.05, 0.02) * red * 0.35 * sin(TIME * (1.0 + h21(cell) * 3.0) + h21(cell + 7.0) * 6.28);
	ALBEDO = c * brightness;
}
