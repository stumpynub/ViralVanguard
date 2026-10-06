shader_type spatial;
render_mode unshaded, fog_disabled;
// The gas giant hanging over the bay: banded, lit from the moon side, with a soft terminator.

uniform vec3 band_a : source_color = vec3(0.32, 0.18, 0.55);
uniform vec3 band_b : source_color = vec3(0.12, 0.28, 0.6);
uniform vec3 band_c : source_color = vec3(0.85, 0.45, 0.7);
uniform vec3 light_dir = vec3(-0.6, 0.5, 0.6);

varying vec3 lpos;
varying vec3 wn;

float h(float x) { return fract(sin(x * 91.7) * 43758.5); }
float n1(float x) { float i = floor(x), f = fract(x); return mix(h(i), h(i + 1.0), f * f * (3.0 - 2.0 * f)); }

void vertex() {
	lpos = normalize(VERTEX);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float lat = lpos.y + 0.06 * sin(lpos.x * 9.0 + lpos.z * 5.0) + 0.02 * sin(atan(lpos.z, lpos.x) * 14.0 + lpos.y * 30.0);
	float b = n1(lat * 9.0) * 0.7 + n1(lat * 31.0) * 0.3;
	vec3 col = mix(band_a, band_b, smoothstep(0.25, 0.75, b));
	col = mix(col, band_c, smoothstep(0.78, 0.95, n1(lat * 17.0 + 3.0)) * 0.6);
	float lit = smoothstep(-0.25, 0.6, dot(wn, normalize(light_dir)));
	ALBEDO = col * (0.08 + 0.9 * lit);
}
