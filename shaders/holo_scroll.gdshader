shader_type spatial;
// v77 hangar hologram scroll (port): the NEON CORE title projected on a curved sheet with RGB split, scanlines,
// a rolling bar, edge fade, flicker and the occasional glitch band. Additive.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform sampler2D uMap : source_color, filter_linear;
uniform float uT = 0.0;
float h(float x){return fract(sin(x*91.7)*43758.5);}
void fragment(){vec2 uv=vec2(UV.x,UV.y);
 float band=step(.985,h(floor(uT*3.)))*step(abs((1.-uv.y)-fract(uT*.37)),.03);uv.x+=band*.012*sin(uT*80.);
 vec3 c=vec3(texture(uMap,uv+vec2(.0018,0.)).r,texture(uMap,uv).g,texture(uMap,uv-vec2(.0018,0.)).b);
 float vy=1.-uv.y;
 float scan=.78+.22*sin(vy*620.+uT*9.);float roll=.88+.12*smoothstep(.0,.08,abs(fract(vy-uT*.11)-.5));
 float edge=smoothstep(0.,.05,uv.x)*smoothstep(1.,.95,uv.x)*smoothstep(0.,.04,vy)*smoothstep(1.,.96,vy);
 float flick=.92+.08*h(floor(uT*14.));vec3 tint=vec3(.75,.9,1.15);
 ALBEDO=c*tint*scan*roll*flick*edge*1.15+vec3(.04,.12,.25)*edge*.35;}
