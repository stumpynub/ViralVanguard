shader_type spatial;
// v77 planet cloud shell (port): drifting fbm clouds lit from uL.
render_mode unshaded, fog_disabled, depth_draw_never, blend_mix;
uniform vec3 uL = vec3(0.755, 0.352, 0.553);
varying vec3 vP;
float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float vn(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){float s=0.,a=.5;for(int i=0;i<5;i++){s+=a*vn(p);p*=2.03;a*=.5;}return s;}
void vertex(){vP=VERTEX;}
void fragment(){float uT=TIME;vec3 n=normalize(vP);float a=uT*.012;mat2 r=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)));vec3 q=n;q.xz=r*q.xz;
 float w=fbm(q*4.+vec3(0,uT*.004,0)+fbm(q*2.5)*1.4);float bands=.5+.5*sin(n.y*9.+fbm(q*3.)*4.);float d=smoothstep(.44,.70,w*(.75+.4*bands));
 float term=smoothstep(-.15,.3,dot(n,uL));float l=.08+1.05*max(dot(n,uL),0.)*term;ALBEDO=vec3(.95,.97,1.)*l;ALPHA=d*.92;}
