shader_type canvas_item;
// Menu title: white ink type with a crimson split shadow, horizontal glitch slices and a power flicker.

uniform float glitch = 0.0;     // pulsed from script, 0..1

float h11(float x) { return fract(sin(x * 91.3458) * 47453.5453); }

void fragment() {
	float t = floor(TIME * 18.0);
	float slice = floor(UV.y * 9.0);
	float off = (h11(slice + t) - 0.5) * 0.06 * glitch * step(0.6, h11(slice * 3.1 + t));
	vec2 uv = UV + vec2(off, 0.0);
	vec4 base = texture(TEXTURE, uv);
	float sr = texture(TEXTURE, uv + vec2(0.006 + glitch * 0.02, 0.0)).a;
	vec3 c = base.rgb * COLOR.rgb;
	float a = base.a * COLOR.a;
	vec4 red = vec4(0.9, 0.03, 0.02, sr * COLOR.a * 0.9);
	vec4 o = mix(red, vec4(c, a), a);
	float flick = 1.0 - 0.18 * step(0.97, h11(floor(TIME * 12.0)));
	COLOR = vec4(o.rgb * flick, max(a, red.a));
}
