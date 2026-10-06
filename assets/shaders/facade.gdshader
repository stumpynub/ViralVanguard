shader_type spatial;
// Procedural night-city facade (replaces the original canvas atlases): window bays on a world-space grid,
// randomly lit per cell, with ledges, mullions and grime. Per building variation comes from the instance seed.

uniform int style : hint_range(0, 2) = 0;   // 0 residential, 1 commercial, 2 industrial
uniform vec3 wall_color : source_color = vec3(0.15, 0.14, 0.2);
uniform vec3 dark_glass : source_color = vec3(0.067, 0.09, 0.15);
uniform vec3 lit_a : source_color = vec3(1.0, 0.71, 0.29);
uniform vec3 lit_b : source_color = vec3(1.0, 0.81, 0.48);
uniform vec3 neon_a : source_color = vec3(1.0, 0.17, 0.84);
uniform vec3 neon_b : source_color = vec3(0.13, 0.9, 1.0);
uniform float bay_width = 2.0;
uniform float floor_height = 3.2;
uniform float lit_chance : hint_range(0.0, 1.0) = 0.42;
uniform float neon_chance : hint_range(0.0, 1.0) = 0.1;
uniform float emission_strength = 2.4;

varying vec3 wpos;
varying vec3 wnrm;
varying float seed;   // per building, from its position (no instance uniforms: WebGL has very few)

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	seed = fract(sin(dot(MODEL_MATRIX[3].xz + MODEL_MATRIX[3].y * 0.37, vec2(12.9898, 78.233))) * 43758.5453) * 100.0;
}

void fragment() {
	vec3 col = wall_color;
	vec3 emi = vec3(0.0);
	float rough = 0.85;
	float metal = 0.1;
	if (abs(wnrm.y) > 0.5) {
		col = wall_color * 0.45;
	} else {
		bool xside = abs(wnrm.x) > abs(wnrm.z);
		float u = xside ? wpos.z : wpos.x;
		float y = wpos.y;
		vec2 cell = vec2(u / bay_width, y / floor_height);
		vec2 id = floor(cell) + vec2(seed * 31.7, seed * 7.3) + (xside ? vec2(91.0, 0.0) : vec2(0.0));
		vec2 f = fract(cell);
		float r = h21(id);
		float r2 = h21(id + 0.37);
		float band = h21(vec2(id.y, seed));
		vec2 lo = style == 1 ? vec2(0.03, 0.06) : vec2(0.16, 0.18);
		float top = style == 1 ? 0.9 : 0.78;
		float win = step(lo.x, f.x) * step(f.x, 1.0 - lo.x) * step(lo.y, f.y) * step(f.y, top);
		if (style == 2) {   // industrial: sparse windows on every other floor
			win *= step(0.45, h21(id + 3.1)) * step(0.5, mod(floor(cell.y), 2.0));
		}
		float ledge = step(0.94, f.y);
		float mull = style == 0 ? (1.0 - step(0.012, abs(f.x - 0.5))) : 0.0;
		float lit = 0.0;
		vec3 lc = lit_a;
		float chance = lit_chance;
		if (style == 1) { chance = band < 0.25 ? 0.85 : (band < 0.35 ? 0.8 : lit_chance); }
		if (r < chance) { lit = 1.0; lc = mix(lit_a, lit_b, r2); }
		else if (r < chance + neon_chance) { lit = 1.0; lc = r2 < 0.5 ? neon_a : neon_b; }
		float blinds = (r2 > 0.5 && style == 0) ? 0.55 + 0.45 * step(0.5, fract(f.y * 9.0)) : 1.0;
		vec3 glass = lit > 0.5 ? lc * 0.6 : dark_glass;
		col = mix(wall_color, glass, win);
		col = mix(col, wall_color * 0.55, ledge);
		col = mix(col, wall_color * 1.3, mull * win);
		emi = lc * lit * win * (1.0 - mull) * blinds * emission_strength * (0.75 + 0.25 * r2);
		// weathering: darker base and vertical grime streaks under the sills
		float grime = smoothstep(6.0, 0.0, y) * 0.35 + step(0.8, h21(vec2(floor(u * 3.0), seed))) * 0.18 * (1.0 - f.y);
		col *= 1.0 - grime;
		rough = mix(0.85, 0.15, win);
		metal = mix(0.1, 0.6, win);
	}
	ALBEDO = col;
	EMISSION = emi;
	ROUGHNESS = rough;
	METALLIC = metal;
}
