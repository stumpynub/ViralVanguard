shader_type canvas_item;
// v77 renders with LinearEncoding output and no tone mapping: whatever its shaders compute goes straight to the
// screen. Godot encodes the 3D result to sRGB; this pass (under the HUD) decodes it again, so the value on screen is
// exactly the shader value, as in v77 - then Neon Core's look v2 grade: 14% less saturation so the neon stops
// shouting everywhere, and crushed blacks lifted toward a cool blue-grey so shapes in the dark still read.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	c = mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThanEqual(c, vec3(0.04045))));
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, 0.86);
	c += vec3(0.028, 0.03, 0.048) * (1.0 - smoothstep(0.0, 0.14, l));
	COLOR = vec4(c, 1.0);
}
