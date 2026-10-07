// v77 material: a port of three.js r128 MeshStandardMaterial / MeshPhysicalMaterial / MeshBasicMaterial as v77 renders
// them (no tone mapping, LinearEncoding output, non-physical lights), plus v77's onBeforeCompile patches:
// lobby clip volumes, the warm desaturation tint and premultiplied output - plus Neon Core's look v2 pass.
// Uniform values are three's raw (linear) numbers. The final image is decoded back by shaders/v77_output.gdshader so
// what reaches the screen is exactly three's output value.
// Variant files define V77_UNSHADED / V77_SPRITE and the render_mode, then include this file.

uniform vec4 v_color = vec4(1.0);            // rgb = color, a = opacity
uniform bool v_vertex_colors = false;
uniform bool v_use_map = false;
uniform bool v_map_srgb = false;
uniform sampler2D v_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform mat3 v_map_uv = mat3(1.0);
uniform bool v_use_alpha_map = false;
uniform sampler2D v_alpha_map : filter_linear_mipmap, repeat_enable;
uniform mat3 v_alpha_uv = mat3(1.0);
uniform float v_alpha_test = 0.0;
uniform vec3 v_emissive = vec3(0.0);       // emissive * emissiveIntensity
uniform bool v_use_emissive_map = false;
uniform bool v_emissive_map_srgb = false;
uniform sampler2D v_emissive_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform mat3 v_emissive_uv = mat3(1.0);
uniform float v_roughness = 1.0;
uniform float v_metalness = 0.0;
uniform bool v_use_rough_map = false;
uniform sampler2D v_rough_map : filter_linear_mipmap, repeat_enable;   // three reads G
uniform bool v_use_metal_map = false;
uniform sampler2D v_metal_map : filter_linear_mipmap, repeat_enable;   // three reads B
uniform mat3 v_rough_uv = mat3(1.0);
uniform bool v_use_normal_map = false;
uniform sampler2D v_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 v_normal_scale = vec2(1.0);
uniform mat3 v_normal_uv = mat3(1.0);
uniform bool v_use_light_map = false;
uniform sampler2D v_light_map : filter_linear_mipmap, repeat_enable;
uniform float v_light_map_intensity = 1.0;
uniform float v_clearcoat = 0.0;
uniform float v_clearcoat_roughness = 0.0;
uniform bool v_fog = true;
// patches
uniform bool v_premultiply = false;         // gl_FragColor = vec4(rgb * a, a)
uniform float v_neutral = 0.0;              // mix(c, luma(c) * (1.07, .97, .85), k)
uniform int v_clip_count = 0;               // lobby clip volumes: discard city geometry inside the sky-bridge rooms
uniform vec4 v_clip_a[48];                  // (centre x, centre z, dir x, dir z)
uniform vec4 v_clip_b[48];                  // (half length, across min, across max, y min)
uniform float v_clip_y[48];                 // y max
// sprites (three.js Sprite): centre and rotation
uniform vec2 v_sprite_center = vec2(0.5);
uniform float v_sprite_rotation = 0.0;
uniform bool v_size_attenuation = true;

// scene globals, set once by the world (shared by every v77 material)
global uniform vec3 v77_hemi_sky;           // HemisphereLight color * intensity
global uniform vec3 v77_hemi_ground;        // HemisphereLight groundColor * intensity
global uniform vec3 v77_fog_color;
global uniform float v77_fog_density;
global uniform int v77_debug;

// ---------------------------------------------------------------- look v2: contact AO, surface grain, weathering, wet streets
// (set up by V77World: look_ao is baked by tools/bake_look_ao.gd, look_refl is the street-level planar reflection)
global uniform sampler2D look_ao : filter_linear, repeat_disable;   // r = height-field AO, g = ground height
global uniform vec4 look_ao_rect;                                     // grid origin x, z and size x, z (metres)
global uniform sampler2D look_refl : filter_linear, repeat_disable;  // street-level planar reflection (sRGB)
global uniform vec2 look_refl_size;                                   // size of the reflection viewport (identifies its pass)
global uniform float look_wet;                                        // 0 = dry, 1 = wet streets
#ifndef V77_TRANSPARENT
#ifndef V77_SPRITE
#define LK_ON
#endif
#endif
float lk_hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float lk_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(lk_hash(i), lk_hash(i + vec2(1.0, 0.0)), f.x), mix(lk_hash(i + vec2(0.0, 1.0)), lk_hash(i + vec2(1.0)), f.x), f.y);
}
float lk_fbm(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 4; i++) { s += a * lk_noise(p); p = p * 2.03 + 17.1; a *= 0.5; } return s / 0.9375; }
float lk_tri(vec3 p, vec3 w) { return w.x * lk_fbm(p.zy) + w.y * lk_fbm(p.xz) + w.z * lk_fbm(p.xy); }

//               // 1: paint front faces green, back faces red (debugging)       // FogExp2 density (0 = none)

varying vec3 v_world;
varying vec2 v_uv2;
varying vec3 v_spec;               // specular colour (F0) for light()

vec3 v77_srgb_to_linear(vec3 c) {           // three.js sRGBToLinear
	return mix(pow(c * 0.9478672986 + vec3(0.0521327014), vec3(2.4)), c * 0.0773993808, vec3(lessThanEqual(c, vec3(0.04045))));
}
vec2 v77_uv(mat3 m, vec2 uv) { return (m * vec3(uv, 1.0)).xy; }

void vertex() {
#ifdef V77_SPRITE
	// three.js sprite.vert: the quad faces the camera, scaled by the object's scale, offset by center, rotated
	vec4 mv_position = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vec2 scale = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	if (!v_size_attenuation) {
		bool persp = PROJECTION_MATRIX[2][3] == -1.0;
		if (persp) scale *= -mv_position.z;
	}
	vec2 aligned = (VERTEX.xy - (v_sprite_center - vec2(0.5))) * scale;
	vec2 rotated = vec2(cos(v_sprite_rotation) * aligned.x - sin(v_sprite_rotation) * aligned.y, sin(v_sprite_rotation) * aligned.x + cos(v_sprite_rotation) * aligned.y);
	mv_position.xy += rotated;
	POSITION = PROJECTION_MATRIX * mv_position;
	v_world = (INV_VIEW_MATRIX * mv_position).xyz;
#else
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
#endif
	v_uv2 = UV2;
}

void fragment() {
	// the street reflection pass: the camera is mirrored under the street, so cut away everything at or below it
	bool lk_refl_pass = abs(VIEWPORT_SIZE.x - look_refl_size.x) < 0.5 && abs(VIEWPORT_SIZE.y - look_refl_size.y) < 0.5;
	if (lk_refl_pass && v_world.y < 0.08) discard;
	// lobby clip volumes (v77 CLIPV): discard city fragments inside a sky-bridge room
	for (int i = 0; i < v_clip_count; i++) {
		vec4 a = v_clip_a[i];
		vec4 b = v_clip_b[i];
		vec2 d = v_world.xz - a.xy;
		float t = dot(d, a.zw);
		float o = dot(d, vec2(-a.w, a.z));
		if (abs(t) < b.x && o > b.y && o < b.z && v_world.y > b.w && v_world.y < v_clip_y[i]) discard;
	}
	vec4 diffuse = v_color;
	if (v_vertex_colors) diffuse.rgb *= COLOR.rgb;
	if (v_use_map) {
		vec4 t = texture(v_map, v77_uv(v_map_uv, UV));
		if (v_map_srgb) t.rgb = v77_srgb_to_linear(t.rgb);
		diffuse *= t;
	}
	if (v_use_alpha_map) diffuse.a *= texture(v_alpha_map, v77_uv(v_alpha_uv, UV)).g;
	if (diffuse.a < v_alpha_test) discard;

	float lk_ao = 1.0, lk_wet = 0.0, lk_rough_add = 0.0;
	vec3 lk_bump = vec3(0.0), lk_refl = vec3(0.0);
#ifdef LK_ON
	{
		float lk_k = 1.0;                       // how much of the pass applies: all of it on lit surfaces,
#ifdef V77_UNSHADED
		lk_k = 1.0 - smoothstep(0.08, 0.3, max(diffuse.r, max(diffuse.g, diffuse.b)));   // only dark unlit ones
#endif
		if (v_use_emissive_map) {                 // lit windows stay clean glass
			float el = dot(texture(v_emissive_map, v77_uv(v_emissive_uv, UV)).rgb, vec3(0.333));
			lk_k *= 1.0 - smoothstep(0.05, 0.3, el);
		}
		vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 pw = v_world;
		vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		float near_k = 1.0 - smoothstep(18.0, 70.0, -VERTEX.z);       // fine detail fades out with distance
		bool vertical = abs(nw.y) < 0.35;
		bool street = nw.y > 0.85 && pw.y < 0.6;
		// contact AO: ground and roofs from the height-field AO, walls darken toward the ground in front of them
		vec2 here = texture(look_ao, (pw.xz - look_ao_rect.xy) / look_ao_rect.zw).rg;
		float wall_h = 99.0;
		if (nw.y > 0.6 && abs(pw.y - here.g) < 0.4) lk_ao = here.r;
		else if (vertical) {
			vec2 front = texture(look_ao, (pw.xz + normalize(nw.xz + vec2(1e-4)) * 0.75 - look_ao_rect.xy) / look_ao_rect.zw).rg;
			wall_h = pw.y - front.g;
			if (wall_h > -0.3 && wall_h < 8.0) lk_ao = mix(0.42, 1.0, smoothstep(0.0, 2.6, wall_h)) * mix(1.0, front.r, 0.6);
		}
		lk_ao = mix(1.0, lk_ao, lk_k);
		// triplanar grain: large blotches (colour variation) and fine grain (albedo + bump), world space so nothing tiles
		vec3 tw = pow(abs(nw), vec3(4.0)); tw /= (tw.x + tw.y + tw.z);
		float macro = lk_tri(pw * 0.22, tw);
		vec2 q; vec3 ta, tb;
		if (tw.y >= tw.x && tw.y >= tw.z) { q = pw.xz; ta = vec3(1.0, 0.0, 0.0); tb = vec3(0.0, 0.0, 1.0); }
		else if (tw.x >= tw.z) { q = pw.zy; ta = vec3(0.0, 0.0, 1.0); tb = vec3(0.0, 1.0, 0.0); }
		else { q = pw.xy; ta = vec3(1.0, 0.0, 0.0); tb = vec3(0.0, 1.0, 0.0); }
		float e = 0.04, h0 = lk_fbm(q * 5.5), hx = lk_fbm((q + vec2(e, 0.0)) * 5.5), hy = lk_fbm((q + vec2(0.0, e)) * 5.5);
		float matte_k = smoothstep(0.3, 0.7, v_roughness) * (1.0 - 0.7 * v_metalness);   // bump only reads on matte surfaces
		lk_bump = -(ta * (hx - h0) + tb * (hy - h0)) / e * 0.01 * near_k * lk_k * matte_k;
		float metal_k = 1.0 - 0.6 * v_metalness;                           // bare metal takes less grime
		vec3 c = diffuse.rgb;
		c *= mix(1.0, 0.8 + 0.4 * macro, 0.8);
		c *= mix(1.0, 0.9 + 0.2 * h0, near_k);
		lk_rough_add += (h0 - 0.5) * 0.12;
		if (vertical) {
			// rain streaks: thin vertical runs of darker, rougher staining
			float along = abs(nw.x) > abs(nw.z) ? pw.z : pw.x;
			float col_id = floor(along * 1.3);
			float st = smoothstep(0.58, 0.9, lk_noise(vec2(along * 1.3, pw.y * 0.07 + lk_hash(vec2(col_id, 3.0)) * 9.0)));
			c *= 1.0 - 0.3 * st * metal_k;
			lk_rough_add += 0.15 * st;
			// grime band where the wall meets the ground
			float grime = 1.0 - smoothstep(0.0, 1.6, wall_h);
			c = mix(c, c * vec3(0.6, 0.56, 0.52), grime * 0.75 * metal_k);
		} else if (nw.y > 0.6 && !street) {
			c = mix(c, vec3(0.13, 0.12, 0.14), 0.25 * macro * metal_k);           // dust on roofs, decks, ledges
			lk_rough_add += 0.1;
		}
		if (street) {
			// wet streets: everything damp, puddles in the low blotches mirror the city
			float puddle = smoothstep(0.55, 0.63, lk_fbm(pw.xz * 0.16 + 3.1)) * look_wet * (1.0 - smoothstep(0.05, 0.12, pw.y));
			float damp = 0.3 * look_wet;
			lk_wet = max(puddle, damp);
			c *= mix(1.0, 0.5, puddle) * mix(1.0, 0.85, damp);
			if (!lk_refl_pass) {
				vec3 rr = texture(look_refl, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y) + lk_bump.xz * 0.5).rgb;
				rr = v77_srgb_to_linear(rr);
				float nv = clamp(dot(nw, vw), 0.0, 1.0);
				float fres = 0.04 + 0.96 * pow(1.0 - nv, 5.0);
				lk_refl = rr * mix(0.1, 0.85, puddle) * mix(0.35, 1.0, fres) * look_wet * lk_k;
			}
		}
		diffuse.rgb = mix(diffuse.rgb, c, lk_k);
		lk_rough_add *= lk_k;
		lk_wet *= lk_k;
	}
#endif
	vec3 emissive = v_emissive;
	if (v_use_emissive_map) {
		vec3 e = texture(v_emissive_map, v77_uv(v_emissive_uv, UV)).rgb;
		if (v_emissive_map_srgb) e = v77_srgb_to_linear(e);
		emissive *= e;
	}
#ifdef V77_UNSHADED
	// MeshBasicMaterial / SpriteMaterial: color straight out (a light map still adds, as in three)
	vec3 outgoing = diffuse.rgb;
	if (v_use_light_map) outgoing += texture(v_light_map, v_uv2).rgb * v_light_map_intensity * diffuse.rgb;
	ALBEDO = outgoing * lk_ao + lk_refl;
#else
	float rough = v_roughness;
	float metal = v_metalness;
	if (v_use_rough_map) rough *= texture(v_rough_map, v77_uv(v_rough_uv, UV)).g;
	if (v_use_metal_map) metal *= texture(v_metal_map, v77_uv(v_rough_uv, UV)).b;
#ifdef LK_ON
	rough = mix(clamp(rough + lk_rough_add, 0.04, 1.0), 0.07, lk_wet);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(lk_bump, 0.0)).xyz);
#endif

	if (v_use_normal_map) {
		vec3 n = texture(v_normal_map, v77_uv(v_normal_uv, UV)).xyz * 2.0 - 1.0;
		n.xy *= v_normal_scale;
		NORMAL_MAP = n * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 1.0;
	}
	// three: roughness = max(r, 0.0525) + geometry roughness from the normal's screen derivatives
	vec3 dxy = max(abs(dFdx(NORMAL)), abs(dFdy(NORMAL)));
	rough = min(max(rough, 0.0525) + max(max(dxy.x, dxy.y), dxy.z), 1.0);
	vec3 diffuse_color = diffuse.rgb * (1.0 - metal);
	ALBEDO = diffuse_color;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	v_spec = mix(vec3(0.04), diffuse.rgb, metal);
	// indirect: hemisphere light (three: irradiance * PI * Lambert(1/PI)) and the light map
	float hw = 0.5 * dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz) + 0.5;
	vec3 irr = mix(v77_hemi_ground, v77_hemi_sky, hw);
	if (v_use_light_map) irr += texture(v_light_map, v_uv2).rgb * v_light_map_intensity;
	EMISSION = irr * diffuse_color * lk_ao + emissive + lk_refl;
	ALBEDO *= mix(1.0, lk_ao, 0.6);
#endif
#ifdef V77_UNSHADED
	ALBEDO += emissive;
#endif
	// ALPHA is only referenced by transparent variants: Godot treats any shader that touches ALPHA as transparent
	// (no depth writes, whole meshes sorted back to front), which let far merged city meshes draw over near walls
#ifdef V77_TRANSPARENT
	ALPHA = diffuse.a;
#ifdef V77_UNSHADED
	if (v_premultiply) ALBEDO *= ALPHA;
#else
	if (v_premultiply) { EMISSION *= ALPHA; ALBEDO *= ALPHA; }
#endif
#endif
	if (v77_debug == 1) { EMISSION = FRONT_FACING ? vec3(0.0, 0.6, 0.0) : vec3(0.7, 0.0, 0.0); ALBEDO = vec3(0.0); }
	// FogExp2, as three: factor = 1 - exp(-density^2 * depth^2)
	if (v_fog && v77_fog_density > 0.0) {
		float depth = -VERTEX.z;
		float f = 1.0 - exp(-v77_fog_density * v77_fog_density * depth * depth);
		FOG = vec4(v77_fog_color, clamp(f, 0.0, 1.0));
	}
}

#ifndef V77_UNSHADED

float v77_g_smith(float alpha, float nl, float nv) {      // G_GGX_SmithCorrelated (includes 1 / (4 nl nv))
	float a2 = alpha * alpha;
	float gv = nl * sqrt(a2 + (1.0 - a2) * nv * nv);
	float gl = nv * sqrt(a2 + (1.0 - a2) * nl * nl);
	return 0.5 / max(gv + gl, 1e-6);
}
float v77_d_ggx(float alpha, float nh) {
	float a2 = alpha * alpha;
	float d = nh * nh * (a2 - 1.0) + 1.0;
	return 0.3183098862 * a2 / (d * d);
}
vec3 v77_ggx(vec3 l, vec3 v, vec3 n, vec3 f0, float rough) {
	float alpha = rough * rough;
	vec3 h = normalize(l + v);
	float nl = clamp(dot(n, l), 0.0, 1.0);
	float nv = clamp(dot(n, v), 0.0, 1.0);
	float nh = clamp(dot(n, h), 0.0, 1.0);
	float lh = clamp(dot(l, h), 0.0, 1.0);
	float fres = exp2((-5.55473 * lh - 6.98316) * lh);
	vec3 F = (1.0 - f0) * fres + f0;
	return F * (v77_g_smith(alpha, nl, nv) * v77_d_ggx(alpha, nh));
}

void light() {
	// three non-physical punctual light: irradiance = dot(n,l) * color * PI; diffuse = irradiance * albedo / PI.
	// Point lights: Godot's ATTENUATION (omni_attenuation = 0) is the window (1 - x^4)^2, x = d / range; recover x and
	// apply three's pow(1 - x, decay) with decay 1.
	float att = ATTENUATION;
	if (!LIGHT_IS_DIRECTIONAL) {
		float x = pow(max(1.0 - sqrt(clamp(att, 0.0, 1.0)), 0.0), 0.25);
		att = att > 0.0 ? 1.0 - x : 0.0;
	}
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	vec3 irradiance = nl * LIGHT_COLOR * att;      // Godot passes LIGHT_COLOR = color * energy * PI, which is three's non-physical irradiance scale
	DIFFUSE_LIGHT += irradiance / PI;
	vec3 spec = irradiance * v77_ggx(LIGHT, VIEW, NORMAL, v_spec, ROUGHNESS);
	if (v_clearcoat > 0.0) {
		float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float cc_f = 0.04 + 0.96 * exp2((-5.55473 * nv - 6.98316) * nv);
		spec = spec * (1.0 - v_clearcoat * cc_f) + v_clearcoat * irradiance * v77_ggx(LIGHT, VIEW, NORMAL, vec3(0.04), max(v_clearcoat_roughness, 0.0525));
		DIFFUSE_LIGHT *= 1.0;
	}
	SPECULAR_LIGHT += spec;
}
#endif
