shader_type spatial;
// A straight road segment (UV.x across, UV.y along): cyan / magenta edge inlays, violet kerb glow,
// dashed white lane lines, an orange double centre line and optional crosswalks at either end.
uniform float length = 40.0;
uniform float width = 13.77;
uniform int lanes = 4;
uniform bool crosswalk_start = false;
uniform bool crosswalk_end = false;
uniform vec3 asphalt : source_color = vec3(0.05, 0.047, 0.086);
uniform float glow = 2.0;
varying vec3 wpos;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float line(float d, float w) { return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.02, abs(d)); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float x = (UV.x - 0.5) * width;      // metres from the centre line
	float y = UV.y * length;             // metres along
	float hw = width * 0.5;
	float n = h21(floor(wpos.xz * 4.0)) * 0.4 + h21(floor(wpos.xz * 0.7)) * 0.6;
	vec3 col = asphalt * (0.8 + 0.4 * n);
	vec3 emi = vec3(0.13, 0.9, 1.0) * line(x + hw - 0.5, 0.14) * 0.9 + vec3(1.0, 0.17, 0.84) * line(x - hw + 0.5, 0.14) * 0.9;
	float lw = width / float(lanes);
	for (int k = 1; k < 8; k++) {
		if (k >= lanes || k * 2 == lanes) continue;
		emi += vec3(0.75) * line(x + hw - float(k) * lw, 0.12) * step(mod(y, 8.0), 2.6) * 0.6;
	}
	emi += vec3(1.0, 0.6, 0.24) * (line(x - 0.18, 0.1) + line(x + 0.18, 0.1)) * 0.8;
	float cw = step(0.5, fract((x + hw) / 1.4)) * step(abs(x), hw - 1.0);
	if (crosswalk_start) emi += vec3(0.78, 0.82, 1.0) * cw * step(0.5, y) * step(y, 3.5) * 0.35;
	if (crosswalk_end) emi += vec3(0.78, 0.82, 1.0) * cw * step(length - 3.5, y) * step(y, length - 0.5) * 0.35;
	ALBEDO = col;
	EMISSION = emi * glow;
	ROUGHNESS = 0.3;
	METALLIC = 0.5;
}
