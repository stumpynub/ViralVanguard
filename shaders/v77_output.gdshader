shader_type canvas_item;
// v77 renders with LinearEncoding output and no tone mapping: whatever its shaders compute goes straight to the
// screen. Godot encodes the 3D result to sRGB; this pass (under the HUD) decodes it again, so the value on screen is
// exactly the shader value, as in v77.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThanEqual(c, vec3(0.04045)))), 1.0);
}
