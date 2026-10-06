shader_type spatial;
// v77 oil-slick puddle (port): fbm-edged disc with iridescence and a sky reflection by view angle.
render_mode unshaded, depth_draw_never, blend_mix;
uniform float uT = 0.0;
varying vec3 vW;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5);}float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+1.),f.x),f.y);}
float fb(vec2 p){return .5*n(p)+.25*n(p*2.1)+.125*n(p*4.3);}
void vertex(){vW=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){float t=TIME;float vS=UV2.x;vec2 q=vec2(UV.x,1.-UV.y)*2.-1.;float d=length(q)+ .35*(fb(q*2.2+vS)-.5);float m=smoothstep(.95,.7,d);if(m<.01)discard;
 vec3 v=normalize(CAMERA_POSITION_WORLD-vW);float fr=pow(1.-max(v.y,0.),3.);
 float th=fb(vW.xz*.9+vS)*2.+fb(vW.xz*3.1-t*.02)*.6;vec3 iri=.5+.5*cos(6.2831*(th+vec3(0.,.33,.67)));
 vec3 refl=mix(vec3(.03,.02,.07),vec3(.35,.12,.55),fr)+vec3(.1,.5,.7)*pow(fb(vW.xz*.15+vec2(t*.01,0.)),3.)*fr*1.6;
 vec3 c=refl+iri*.10*smoothstep(.2,.8,fb(vW.xz*1.7+vS))*(.4+fr);ALBEDO=c;ALPHA=m*(.55+.4*fr);}
