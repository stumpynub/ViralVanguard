// v77 material: a port of three.js r128 MeshStandardMaterial / MeshPhysicalMaterial / MeshBasicMaterial as v77 renders
// them (no tone mapping, LinearEncoding output, non-physical lights), plus v77's onBeforeCompile patches:
// lobby clip volumes, the warm desaturation tint and premultiplied output.
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
global uniform int v77_debug;               // 1: paint front faces green, back faces red (debugging)       // FogExp2 density (0 = none)

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
	ALBEDO = outgoing;
#else
	float rough = v_roughness;
	float metal = v_metalness;
	if (v_use_rough_map) rough *= texture(v_rough_map, v77_uv(v_rough_uv, UV)).g;
	if (v_use_metal_map) metal *= texture(v_metal_map, v77_uv(v_rough_uv, UV)).b;
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
	EMISSION = irr * diffuse_color + emissive;
#endif
#ifdef V77_UNSHADED
	ALBEDO += emissive;
#endif
#ifdef V77_TRANSPARENT
	ALPHA = diffuse.a;
#endif
	if (v77_debug == 1) { EMISSION = FRONT_FACING ? vec3(0.0, 0.6, 0.0) : vec3(0.7, 0.0, 0.0); ALBEDO = vec3(0.0); }
#ifdef V77_UNSHADED
	if (v_premultiply) ALBEDO *= ALPHA;
#else
	if (v_premultiply) { EMISSION *= ALPHA; ALBEDO *= ALPHA; }
#endif
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
