shader_type sky;
// Night sky from the original painted dome: violet horizon band, stars, a hazy moon and a ridge of distant mountains.

uniform vec3 zenith : source_color = vec3(0.012, 0.012, 0.047);
uniform vec3 upper : source_color = vec3(0.043, 0.039, 0.149);
uniform vec3 horizon : source_color = vec3(0.165, 0.078, 0.314);
uniform vec3 ground : source_color = vec3(0.02, 0.016, 0.055);
uniform vec3 mountain : source_color = vec3(0.04, 0.035, 0.1);
uniform vec3 moon_dir = vec3(0.35, 0.55, -0.75);
uniform float star_density = 0.0025;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n1(float x) { float i = floor(x), f = fract(x); return mix(h21(vec2(i, 0.0)), h21(vec2(i + 1.0, 0.0)), f * f * (3.0 - 2.0 * f)); }

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = y > 0.0 ? mix(horizon, mix(upper, zenith, smoothstep(0.2, 0.9, y)), smoothstep(0.0, 0.18, y)) : mix(horizon, ground, smoothstep(0.0, -0.08, y));
	float az = atan(d.x, d.z);
	float ridge = 0.03 + 0.05 * n1(az * 6.0) + 0.025 * n1(az * 19.0);
	col = mix(col, mountain, step(y, ridge) * step(-0.02, y));
	if (y > ridge) {
		vec2 sp = floor(vec2(az * 400.0, y * 400.0));
		float s = step(1.0 - star_density, h21(sp)) * h21(sp + 1.3) * smoothstep(0.05, 0.4, y);
		col += vec3(s);
	}
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	col += vec3(0.85, 0.88, 1.0) * smoothstep(0.9993, 0.9996, m) * 1.5;
	col += vec3(0.5, 0.52, 0.8) * pow(max(m, 0.0), 300.0) * 0.6;
	COLOR = col;
}
