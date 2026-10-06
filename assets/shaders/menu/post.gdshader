shader_type canvas_item;
// Film pass over the whole menu frame (the cel / ink pass lives on the 3D layer, ink3d.gdshader):
// cold desaturated grade that keeps the crimson, grain, flicker, scratches, scanlines, vignette and a
// little chromatic split toward the edges. Dark, gritty, a bit haunted.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.09;
uniform float vignette = 0.75;
uniform float aberration = 0.0007;
uniform float red_keep = 1.0;
uniform float flicker = 0.08;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cd = (uv - 0.5);
	vec3 c;
	c.r = texture(screen_tex, uv + cd * aberration * 8.0).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - cd * aberration * 8.0).b;
	// grade: keep reds, everything else toward cold grey
	float L = lum(c);
	float red = clamp((c.r - max(c.g, c.b)) * 2.5, 0.0, 1.0) * red_keep;
	vec3 g = mix(vec3(L) * vec3(0.93, 0.95, 1.0), c, red);
	// grain, scanlines, vignette
	g *= 0.92;                                                              // crush toward black
	g += (h21(FRAGCOORD.xy + fract(TIME) * 91.0) - 0.5) * grain;
	// film scratches and the odd dust fleck, a projector flicker
	g += step(0.9985, h21(vec2(floor(uv.x * 900.0), floor(TIME * 12.0)))) * 0.07 * smoothstep(0.2, 0.8, h21(vec2(floor(TIME * 12.0), 3.0)));
	g *= 1.0 - flicker * step(0.93, h21(vec2(floor(TIME * 14.0), 7.0)));
	g *= 0.94 + 0.06 * sin(FRAGCOORD.y * 3.14159);
	g *= 1.0 - vignette * pow(length(cd * vec2(1.1, 1.3)), 2.4);
	COLOR = vec4(max(g, vec3(0.0)), 1.0);
}
