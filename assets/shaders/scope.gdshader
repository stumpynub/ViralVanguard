shader_type canvas_item;
// 4x combat scope: black outside the lens, a soft vignette, a lit chevron reticle and bullet-drop stadia.
uniform vec4 reticle : source_color = vec4(1.0, 0.25, 0.3, 1.0);
uniform float radius = 0.41;
void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (FRAGCOORD.xy - res * 0.5) / min(res.x, res.y);
	float d = length(p);
	float outside = smoothstep(radius, radius + 0.003, d);
	float vig = smoothstep(radius * 0.62, radius, d) * 0.55;
	vec3 col = vec3(0.0, 0.03, 0.08);
	float a = max(outside, vig);
	float lines = (1.0 - step(0.0012, abs(p.x))) * step(0.02, abs(p.y)) + (1.0 - step(0.0012, abs(p.y))) * step(0.02, abs(p.x));
	lines *= 1.0 - outside;
	float chev = (1.0 - step(0.0016, abs(abs(p.x) - (-p.y - 0.004)))) * step(p.y, -0.004) * step(-0.024, p.y);
	float stadia = 0.0;
	for (int i = 1; i <= 3; i++) {
		float y = -0.04 * float(i);
		stadia += (1.0 - step(0.0012, abs(p.y + 0.04 * float(i)))) * step(abs(p.x), 0.012 - 0.002 * float(i));
	}
	vec3 rc = reticle.rgb;
	COLOR = vec4(mix(col, rc, clamp(chev + stadia, 0.0, 1.0)), clamp(a + lines * 0.9 + chev + stadia, 0.0, 1.0));
	if (lines > 0.5 && chev + stadia < 0.5) { COLOR.rgb = vec3(0.02); }
}
