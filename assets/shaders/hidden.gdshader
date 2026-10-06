shader_type spatial;
render_mode unshaded, shadows_disabled;
// Kit surfaces replaced by scene nodes (the sky-bridge glass is GlassPanel nodes): collapsed out of view.
void vertex() { POSITION = vec4(2.0, 2.0, 2.0, 1.0); }
void fragment() { ALBEDO = vec3(0.0); }
