shader_type canvas_item;
// In-match film / ink pass for the dark arenas: thin ink edges from luminance, a cold grade that keeps crimson,
// crushed blacks, grain, a faint projector flicker and a vignette. Sits under the HUD (CanvasLayer -1).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float ink = 0.45;
uniform float ink_threshold = 0.16;
uniform float grain = 0.05;
uniform float vignette = 0.55;
uniform float desat = 0.7;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * 0.75;
	vec3 c = texture(screen_tex, uv).rgb;
	float tl = lum(texture(screen_tex, uv + px * vec2(-1, -1)).rgb), tr = lum(texture(screen_tex, uv + px * vec2(1, -1)).rgb);
	float bl = lum(texture(screen_tex, uv + px * vec2(-1, 1)).rgb), br = lum(texture(screen_tex, uv + px * vec2(1, 1)).rgb);
	float e = abs(tl - br) + abs(tr - bl);
	float edge = smoothstep(ink_threshold, ink_threshold * 2.0, e);
	float L = lum(c);
	float red = clamp((c.r - max(c.g, c.b)) * 2.5, 0.0, 1.0);
	vec3 g = mix(c, vec3(L) * vec3(0.92, 0.95, 1.03), desat * (1.0 - red));
	g = pow(max(g, vec3(0.0)), vec3(1.12)) * 1.04;
	g = mix(g, vec3(0.0), edge * ink);
	g += (h21(FRAGCOORD.xy + fract(TIME) * 77.0) - 0.5) * grain;
	g *= 1.0 - 0.035 * step(0.95, h21(vec2(floor(TIME * 14.0), 3.0)));
	vec2 cd = uv - 0.5;
	g *= 1.0 - vignette * pow(length(cd * vec2(1.1, 1.35)), 2.4);
	COLOR = vec4(g, 1.0);
}
