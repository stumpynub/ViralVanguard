shader_type canvas_item;
// Cel / comic pass for the 3D stage only (its SubViewport renders on a transparent background):
// ink lines from colour AND alpha edges (so every silhouette gets a clean outline against the painted city),
// posterised tones, black-grey-crimson grade and halftone in the shadows. Alpha is preserved.

uniform float ink_strength = 0.55;
uniform float ink_threshold = 0.22;
uniform float silhouette = 0.55;
uniform float levels = 4.0;
uniform float halftone = 0.4;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 0.5;      // hairline ink
	vec4 c = texture(TEXTURE, UV);
	float tl = lum(texture(TEXTURE, UV + px * vec2(-1, -1)).rgb), t = lum(texture(TEXTURE, UV + px * vec2(0, -1)).rgb), tr = lum(texture(TEXTURE, UV + px * vec2(1, -1)).rgb);
	float l = lum(texture(TEXTURE, UV + px * vec2(-1, 0)).rgb), r = lum(texture(TEXTURE, UV + px * vec2(1, 0)).rgb);
	float bl = lum(texture(TEXTURE, UV + px * vec2(-1, 1)).rgb), b = lum(texture(TEXTURE, UV + px * vec2(0, 1)).rgb), br = lum(texture(TEXTURE, UV + px * vec2(1, 1)).rgb);
	float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	float edge = smoothstep(ink_threshold, ink_threshold * 2.0, length(vec2(gx, gy)));
	// silhouette: alpha gradient
	float a0 = texture(TEXTURE, UV + vec2(px.x, 0)).a, a1 = texture(TEXTURE, UV - vec2(px.x, 0)).a;
	float a2 = texture(TEXTURE, UV + vec2(0, px.y)).a, a3 = texture(TEXTURE, UV - vec2(0, px.y)).a;
	float sil = clamp((abs(a0 - a1) + abs(a2 - a3)) * 1.0, 0.0, 1.0) * silhouette;
	vec3 col = c.rgb / max(c.a, 0.001);
	float L = lum(col);
	float red = clamp((col.r - max(col.g, col.b)) * 2.5, 0.0, 1.0);
	vec3 g = mix(vec3(L) * vec3(0.92, 0.94, 1.0), col, red);
	float pl = floor(L * levels + 0.5) / levels;
	g *= mix(1.0, pl / max(L, 0.001), 0.6);
	vec2 hp = FRAGCOORD.xy / 4.0;
	float shade = 1.0 - smoothstep(0.04, 0.3, L);
	g *= 1.0 - halftone * shade * step(length(fract(hp) - 0.5), 0.3 * shade + 0.04);
	float ink = max(edge * ink_strength * c.a, sil);
	g = mix(g, vec3(0.0), ink);
	COLOR = vec4(g, max(c.a, sil));
}
