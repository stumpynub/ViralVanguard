shader_type spatial;
// Neon strips on the city kit meshes: the vertex colour is the light colour (HDR so it blooms).
render_mode unshaded;
uniform float energy = 2.6;
void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
