shader_type spatial;
// Wet asphalt with the boulevard / avenue markings of the original: cyan and magenta edge inlays,
// violet curbs, dashed white lanes, an orange double centre line and crosswalks at the plaza.

uniform vec3 asphalt : source_color = vec3(0.05, 0.047, 0.086);
uniform float road_half_width = 10.0;
uniform float plaza_radius = 26.0;
uniform float edge = 96.0;
uniform float glow = 2.0;
/// Off for maps whose roads are separate RoadSegment nodes.
uniform bool markings = true;
uniform vec3 inlay_ns : source_color = vec3(0.13, 0.9, 1.0);
uniform vec3 inlay_ew : source_color = vec3(1.0, 0.17, 0.84);
uniform vec3 curb : source_color = vec3(0.54, 0.23, 1.0);
uniform vec3 center : source_color = vec3(1.0, 0.6, 0.24);

varying vec3 wpos;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float line(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.02, abs(d)); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz;
	float n = noise(p * 0.7) * 0.6 + noise(p * 4.0) * 0.4;
	vec3 col = asphalt * (0.8 + 0.4 * n);
	float puddle = smoothstep(0.62, 0.7, noise(p * 0.08 + 3.0));
	vec3 emi = vec3(0.0);
	float ax = abs(p.x), az = abs(p.y);
	bool ns = markings && ax < road_half_width + 0.5 && az > plaza_radius && az < edge;   // north-south boulevard
	bool ew = markings && az < road_half_width + 0.5 && ax > plaza_radius && ax < edge;   // east-west avenue
	if (ns) {
		emi += inlay_ns * line(ax - (road_half_width - 0.5), 0.14) * 0.9;
		emi += curb * line(ax - road_half_width, 0.07);
		emi += vec3(0.75) * line(ax - 5.0, 0.12) * step(0.5, fract(p.y / 5.0)) * 0.6;
		emi += center * (line(p.x - 0.18, 0.1) + line(p.x + 0.18, 0.1)) * 0.8;
		float cw = step(az, plaza_radius + 3.6) * step(0.5, fract(p.x / 1.4)) * step(ax, road_half_width - 1.0);
		emi += vec3(0.78, 0.82, 1.0) * cw * 0.35;
	}
	if (ew) {
		emi += inlay_ew * line(az - (road_half_width - 0.5), 0.14) * 0.9;
		emi += curb * line(az - road_half_width, 0.07);
		emi += vec3(0.75) * line(az - 5.0, 0.12) * step(0.5, fract(p.x / 5.0)) * 0.6;
		emi += center * (line(p.y - 0.18, 0.1) + line(p.y + 0.18, 0.1)) * 0.8;
		float cw = step(ax, plaza_radius + 3.6) * step(0.5, fract(p.y / 1.4)) * step(az, road_half_width - 1.0);
		emi += vec3(0.78, 0.82, 1.0) * cw * 0.35;
	}
	ALBEDO = col;
	EMISSION = emi * glow;
	ROUGHNESS = mix(0.38, 0.06, puddle);
	METALLIC = mix(0.45, 0.8, puddle);
}
