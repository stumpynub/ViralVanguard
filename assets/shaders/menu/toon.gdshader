shader_type spatial;
// Cel shading for the menu: hard light bands, a cold key, blood-red rim, ink-black shadows.
// Albedo comes from a texture (UV or world-space triplanar for tiling surfaces) times vertex colour / tint.
render_mode diffuse_toon, specular_toon;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform bool world_uv = false;           // floors / walls: tile by world position instead of UVs
uniform float world_scale = 0.25;        // texture repeats per metre (world_uv)
uniform float desaturate : hint_range(0.0, 1.0) = 0.65;   // pull the source colours toward the black / grey / red palette
uniform float bands : hint_range(1.0, 6.0) = 3.0;
uniform vec3 shadow_color : source_color = vec3(0.02, 0.02, 0.035);
uniform vec3 rim_color : source_color = vec3(1.0, 0.06, 0.04);
uniform float rim_strength = 1.6;
uniform float rim_width : hint_range(0.0, 1.0) = 0.32;
uniform float spec_size : hint_range(0.0, 1.0) = 0.08;
uniform float wet = 0.0;                 // glossy wet floor: sharper, brighter highlights
uniform vec3 emission_color : source_color = vec3(0.0);
uniform sampler2D emission_tex : source_color, hint_default_black;
uniform float emission_energy = 0.0;      // emission_tex strength (keeps glowing lenses / strips from the source model)
uniform float emission_threshold = 2.0;  // red-dominant texels above this brightness glow (lights in textures)

uniform float fade_near = 0.0;            // first person: dither out pixels closer than this to the camera (0 = off)
uniform float fade_far = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 grade(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float red = clamp((c.r - max(c.g, c.b)) * 2.0, 0.0, 1.0);    // keep reds, drain everything else
	return mix(c, vec3(l), desaturate * (1.0 - red));
}

void fragment() {
	if (fade_far > 0.0) {
		float d = length(VERTEX);
		float k = clamp((d - fade_near) / max(fade_far - fade_near, 0.001), 0.0, 1.0);
		float h = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
		if (k < h) discard;
	}
	vec4 a;
	if (world_uv) {
		vec3 bw = pow(abs(wnrm), vec3(4.0));
		bw /= bw.x + bw.y + bw.z;
		a = texture(albedo_tex, wpos.zy * world_scale) * bw.x + texture(albedo_tex, wpos.xz * world_scale) * bw.y + texture(albedo_tex, wpos.xy * world_scale) * bw.z;
	} else {
		a = texture(albedo_tex, UV);
	}
	vec3 c = a.rgb * tint.rgb;
	if (use_vertex_color) c *= COLOR.rgb;
	ALBEDO = grade(c);
	float glow = smoothstep(emission_threshold, emission_threshold + 0.25, a.r * 3.0 - a.g - a.b);
	vec3 et = texture(emission_tex, UV).rgb * emission_energy;
	EMISSION = emission_color + vec3(1.0, 0.05, 0.03) * glow * 3.0 + vec3(et.r + et.g + et.b) * vec3(1.0, 0.06, 0.03);   // any glow burns red
	ROUGHNESS = mix(0.8, 0.15, wet);
	SPECULAR = 0.5;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	// hard bands with a hair of anti-aliasing so noisy normals don't sparkle
	float x = clamp(ndl, 0.0, 1.0) * bands + 0.35;
	float fw = max(fwidth(x), 0.001) * 1.5;
	float q = (floor(x) + smoothstep(1.0 - fw, 1.0, fract(x))) / bands;
	vec3 lit = mix(shadow_color, ALBEDO, q) * LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += max(lit, vec3(0.0));
	vec3 h = normalize(LIGHT + VIEW);
	float sx = dot(NORMAL, h) - (1.0 - spec_size * 0.5 * (1.0 + wet * 2.0));
	float s = smoothstep(0.0, max(fwidth(sx), 0.002) * 2.0, sx) * step(0.25, ndl);
	SPECULAR_LIGHT += s * LIGHT_COLOR * (0.2 + wet * 1.5) * ATTENUATION;
	// rim: a backlight only (the light is behind the surface as seen from the camera), on silhouette edges
	float edge = step(1.0 - rim_width, 1.0 - max(dot(NORMAL, VIEW), 0.0));
	float back = smoothstep(-0.1, 0.6, -dot(LIGHT, VIEW)) * step(0.0, dot(NORMAL, LIGHT) + 0.3);
	SPECULAR_LIGHT += edge * back * rim_color * rim_strength * LIGHT_COLOR * 0.25 * ATTENUATION;
}
