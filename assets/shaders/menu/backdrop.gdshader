shader_type canvas_item;
// The menu's painted city, brought to life: slow parallax drift with the mouse, drifting fog banks,
// flickering red windows, sweeping searchlights, the blood moon's pulse, rain and the odd lightning flash.

uniform vec2 parallax = vec2(0.0);       // set from the mouse (-1..1)
uniform float zoom = 1.08;
uniform vec2 moon_uv = vec2(0.693, 0.2); // moon centre in the painting
uniform float lightning = 0.0;           // 0..1, pulsed from script
uniform vec3 fog_color : source_color = vec3(0.32, 0.31, 0.34);

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { v += noise(p) * a; p *= 2.03; a *= 0.5; } return v; }

void fragment() {
	vec2 uv = (UV - 0.5) / zoom + 0.5 + parallax * vec2(0.025, 0.012);
	vec3 c = texture(TEXTURE, uv).rgb;
	float t = TIME;
	// red window lights: twinkle each lit cell independently (not the moon)
	vec2 md = (uv - moon_uv) * vec2(2.4, 1.0);
	float mr = length(md);
	float red = clamp((c.r - max(c.g, c.b)) * 3.0, 0.0, 1.0) * smoothstep(0.17, 0.22, mr);
	vec2 cell = floor(uv * vec2(260.0, 110.0));
	float flick = 0.75 + 0.25 * sin(t * (1.0 + h21(cell) * 3.0) + h21(cell + 7.0) * 6.28);
	flick *= step(0.04, fract(h21(cell + 3.0) + t * 0.05)) ;                    // some go dark for a moment
	c += vec3(1.0, 0.05, 0.02) * red * (flick - 0.7) * 0.9;
	// moon pulse + corona
	c += vec3(0.9, 0.05, 0.03) * exp(-mr * 9.0) * (0.25 + 0.08 * sin(t * 0.7));
	// searchlights sweeping up from the skyline
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 o = vec2(0.18 + fi * 0.33, 0.78);
		float ang = sin(t * (0.13 + fi * 0.05) + fi * 2.1) * 0.55 + (fi - 1.0) * 0.25;
		vec2 d = uv - o;
		vec2 dir = vec2(sin(ang), -cos(ang));
		float along = dot(d, dir);
		float across = abs(dot(d, vec2(-dir.y, dir.x)));
		float beam = smoothstep(0.012 + along * 0.09, 0.0, across) * step(0.0, along) * exp(-along * 2.2);
		c += vec3(0.75, 0.78, 0.85) * beam * 0.16 * (1.0 - red);
	}
	// fog banks drifting through the lower towers
	float fog = fbm(vec2(uv.x * 3.0 + t * 0.018, uv.y * 7.0 - t * 0.01));
	float band = smoothstep(0.42, 0.95, uv.y) * smoothstep(0.35, 0.75, fog);
	c = mix(c, fog_color, band * 0.38);
	// rain: two layers of slanted streaks
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		vec2 r = uv * vec2(140.0 + fk * 90.0, 6.0 + fk * 3.0) + vec2(uv.y * (14.0 + fk * 8.0), t * (5.0 + fk * 3.0));
		float drop = step(0.965, h21(floor(r))) * smoothstep(0.0, 0.5, fract(r.y)) * (1.0 - fract(r.y));
		c += vec3(0.55, 0.57, 0.62) * drop * (0.10 + fk * 0.06);
	}
	// lightning: the whole sky lifts and the cloud layer goes hot white for a frame or two
	c += vec3(0.6, 0.6, 0.68) * lightning * (1.0 - smoothstep(0.1, 0.65, uv.y)) * (0.6 + 0.4 * fbm(uv * 6.0));
	c *= 1.0 + lightning * 0.35;
	COLOR = vec4(c, 1.0);
}
