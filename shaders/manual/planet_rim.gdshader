shader_type spatial;
// v77 planet atmosphere rim (port): additive back-face glow.
render_mode unshaded, fog_disabled, blend_add, cull_front, depth_draw_never;
uniform vec3 uL = vec3(0.755, 0.352, 0.553);
varying vec3 vP;
varying vec3 vW;
void vertex(){vP=VERTEX;vW=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){vec3 n=normalize(vP),vd=normalize(CAMERA_POSITION_WORLD-vW);vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);float f=pow(max(0.,1.-abs(dot(wn,vd))),2.);float g=smoothstep(.0,1.,f)*(1.-smoothstep(.55,1.,f));
 float term=smoothstep(-.4,.4,dot(n,uL));ALBEDO=vec3(.3,.55,1.)*g*(.25+1.1*term);}
