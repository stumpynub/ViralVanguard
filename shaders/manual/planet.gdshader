shader_type spatial;
// v77 floating planet surface (port of its ShaderMaterial): craters, continents, ice caps, lit from uL, blue rim.
render_mode unshaded, fog_disabled;
uniform vec3 uL = vec3(0.755, 0.352, 0.553);
varying vec3 vP;
varying vec3 vW;
float h3(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float vn(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){float s=0.,a=.5;for(int i=0;i<5;i++){s+=a*vn(p);p*=2.03;a*=.5;}return s;}
vec2 cell(vec3 p){vec3 i=floor(p),f=fract(p);float d1=8.,r=0.;for(int x=-1;x<=1;x++)for(int y=-1;y<=1;y++)for(int z=-1;z<=1;z++){vec3 g=vec3(float(x),float(y),float(z)),o=vec3(h3(i+g),h3(i+g+11.3),h3(i+g+27.1));vec3 q=g+o-f;float d=dot(q,q);if(d<d1){d1=d;r=h3(i+g+5.7);}}return vec2(sqrt(d1),r);}
float crater(vec3 p,float sc){vec2 c=cell(p*sc);float r=.18+.25*c.y;float d=c.x/r;return (d<1.?-(1.-d*d)*.9:0.)+smoothstep(1.25,1.,d)*smoothstep(.8,1.,d)*.6;}
void vertex(){vP=VERTEX;vW=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){vec3 n=normalize(vP);float h=fbm(n*3.2)+.5*fbm(n*9.);float cr=crater(n,4.)*.6+crater(n+3.1,9.)*.35+crater(n+7.7,20.)*.18;
 vec3 lowc=vec3(.20,.24,.36),mid=vec3(.46,.38,.33),hi=vec3(.66,.60,.55);vec3 col=mix(lowc,mid,smoothstep(.55,.75,h));col=mix(col,hi,smoothstep(.85,1.05,h));
 col*=.85+.35*cr;col=mix(col,vec3(.9,.93,1.),smoothstep(.72,.86,abs(n.y))*.9);
 float e=.02;vec3 b=vec3(fbm((n+vec3(e,0,0))*3.2)-fbm((n-vec3(e,0,0))*3.2),fbm((n+vec3(0,e,0))*3.2)-fbm((n-vec3(0,e,0))*3.2),fbm((n+vec3(0,0,e))*3.2)-fbm((n-vec3(0,0,e))*3.2));
 vec3 bc=vec3(crater(n+vec3(e,0,0),4.)-crater(n-vec3(e,0,0),4.),crater(n+vec3(0,e,0),4.)-crater(n-vec3(0,e,0),4.),crater(n+vec3(0,0,e),4.)-crater(n-vec3(0,0,e),4.));
 vec3 nn=normalize(n-b*1.6-bc*.9);float dif=max(dot(nn,uL),0.);float term=smoothstep(-.12,.25,dot(n,uL));
 vec3 c=col*(dif*1.25*term+.035)+vec3(.02,.03,.08);vec3 vd=normalize(CAMERA_POSITION_WORLD-vW);vec3 wn=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.)).xyz);float rim=pow(1.-max(dot(wn,vd),0.),3.);
 c+=vec3(.25,.45,1.)*rim*(.25+.9*term);ALBEDO=pow(c,vec3(.95));}
