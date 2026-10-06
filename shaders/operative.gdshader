shader_type spatial;
// v77 operative shader (hangar avatar and first-person forearms), ported from the original GLSL: its own three-light
// GGX shading, studio environment, neon line work, vents, insignia, ACES and gamma. Output is display colour,
// converted back to linear so Godot shows exactly that value.
render_mode unshaded, cull_back, depth_draw_opaque;
varying vec3 vP;
varying vec3 vN;
varying vec3 vNv;
varying vec3 vV;
varying vec3 vCol;
varying vec3 vEmi;
varying vec4 vMR;
varying vec2 vX;
void vertex(){vP=VERTEX;vN=NORMAL;vNv=normalize((MODELVIEW_MATRIX*vec4(NORMAL,0.)).xyz);vV=(MODELVIEW_MATRIX*vec4(VERTEX,1.)).xyz;vCol=COLOR.rgb;vEmi=CUSTOM0.rgb;vMR=CUSTOM1;vX=UV2;}
uniform vec3 uGlo = vec3(0.04, 0.3, 1.0);
#define GLO uGlo
uniform float uOp = 1.0;
uniform float uDetK = 1.0;
uniform float uTime = 0.0;
uniform sampler2D uDet : filter_linear_mipmap, repeat_enable;
const vec3 E2L=vec3(1.46896,7.95698,0.42479),W2L=vec3(0.61085,7.08597,1.19440),nEL=vec3(-0.36276,-0.83452,0.41471),nWL=vec3(-0.60970,-0.35504,0.70867),HCL=vec3(0.29792,7.04509,1.64485);
const mat3 MUL=mat3(vec3(0.52234,0.25109,-0.81493),vec3(-0.08322,0.96611,0.24433),vec3(0.84867,-0.05981,0.52554)),MFL=mat3(vec3(0.49429,0.61966,-0.60967),vec3(0.07184,0.66982,0.73904),vec3(0.86632,-0.40910,0.28657)),MHL=mat3(vec3(-0.39912,0.59966,0.69362),vec3(-0.86807,-0.00356,-0.49642),vec3(-0.29522,-0.80025,0.52197));
const vec3 E2R=vec3(2.00809,7.95763,-0.23409),W2R=vec3(1.21410,8.17416,0.95334),nER=vec3(-0.29127,-0.73184,0.61610),nWR=vec3(-0.60763,-0.30676,0.73259),HCR=vec3(0.92145,7.79139,1.21856);
const mat3 MUR=mat3(vec3(0.86068,0.00236,-0.50914),vec3(-0.12135,0.97212,-0.20063),vec3(0.49447,0.23446,0.83697)),MFR=mat3(vec3(0.76041,0.64705,-0.05570),vec3(0.12867,-0.06603,0.98949),vec3(0.63657,-0.75958,-0.13346)),MHR=mat3(vec3(0.64418,0.52750,-0.55387),vec3(-0.03467,0.74353,0.66780),vec3(0.76409,-0.41098,0.49725));

const vec3 SR_=vec3(1.62,9.62,0.),ER_=vec3(2.04,7.95,-.06),WR_=vec3(2.22,6.52,.04);
float hash(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
            mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){float a=.5,s=0.;for(int i=0;i<4;i++){s+=a*noise(p);p*=2.03;a*=.5;}return s;}
float D_GGX(float nh,float a){float a2=a*a;float d=nh*nh*(a2-1.)+1.;return a2/(PI*d*d);}
vec3 F_s(vec3 f0,float vh){return f0+(1.-f0)*pow(1.-vh,5.);}
float scratches(vec3 p){float s=0.;
 for(int i=0;i<3;i++){vec3 dir=normalize(vec3(hash(vec3(float(i),1,2))-.5,hash(vec3(2,float(i),5))-.5,hash(vec3(4,7,float(i)))-.5));
  float f=dot(p,dir)*(60.+40.*float(i))+fbm(p*8.+float(i))*6.;float l=smoothstep(.06,0.,abs(fract(f)-.5));
  s=max(s,l*smoothstep(.62,.8,fbm(p*vec3(3.,9.,5.)+float(i)*3.1)));}
 return s;}float seg2(vec2 p,vec2 a,vec2 b){vec2 pa=p-a,ba=b-a;float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);return length(pa-ba*h);}
// neon line work painted onto the armour (projected decals), returns distance to the nearest line
float glowD(vec3 p,vec3 n,bool isA){float ax=abs(p.x),d=1e3;vec2 f=vec2(ax,p.y);
 if(n.z>.3&&p.z>0.){
  d=min(d,seg2(f,vec2(1.02,9.78),vec2(.36,9.32)));d=min(d,seg2(f,vec2(1.10,9.10),vec2(.28,8.40)));     // chest V
  d=min(d,seg2(f,vec2(.66,8.15),vec2(.60,7.45)));                                                      // abdomen sides
  d=min(d,seg2(f,vec2(.80,5.70),vec2(.95,4.30)));d=min(d,seg2(f,vec2(1.05,3.05),vec2(1.14,1.55)));    // thigh, shin
  if(p.z>.60)d=min(d,abs(length(vec2(ax-.92,p.y-3.60))-.16));
  if(isA&&ax>1.7&&p.y<8.2&&p.y>6.6)d=min(d,seg2(f,vec2(2.10,7.85),vec2(2.25,6.75)));
  if(p.y<.95&&p.z>.1)d=min(d,seg2(f,vec2(1.16,.84),vec2(1.17,.42)));                       // forearm
 }
 if(n.z<-.3&&p.z<0.){
  d=min(d,abs(length(vec2(p.x,p.y-9.10))-.52));
  d=min(d,seg2(f,vec2(.20,8.55),vec2(.20,7.25)));d=min(d,seg2(f,vec2(.95,9.85),vec2(.55,9.55)));
  d=min(d,seg2(f,vec2(.90,5.60),vec2(.95,4.40)));d=min(d,seg2(f,vec2(1.10,3.0),vec2(1.15,1.6)));
 }
 if(abs(n.x)>.4&&p.x*n.x>0.){vec2 g=vec2(p.z,p.y);
  if(ax>1.95&&p.y>9.2&&(isA||p.x<0.))d=min(d,abs(length(g-vec2(-.02,9.66))-.24));                                    // shoulder emblem
  if(isA&&ax>2.15&&p.y<7.9&&p.y>6.6)d=min(d,abs(length(g-vec2(0.,7.20))-.17));                             // forearm emblem
  if(ax>1.1&&p.y>4.1&&p.y<5.8)d=min(d,abs(length(g-vec2(0.,4.95))-.26));                              // thigh emblem
  if(ax>1.2&&p.y<3.3&&p.y>1.3)d=min(d,seg2(g,vec2(.10,3.0),vec2(.10,1.7)));
  if(ax>1.3&&p.y<1.05)d=min(d,abs(length(g-vec2(-.03,.80))-.10));                            // calf line
  if(ax>.95&&p.y>8.0&&p.y<9.9)d=min(d,seg2(g,vec2(.30,9.6),vec2(.05,8.3)));                            // ribcage side
 }
 return d;}


float visY(float ax){return .03+.16*ax*ax;}
float smin(float a,float b,float k){float h=clamp(.5+.5*(b-a)/k,0.,1.);return mix(b,a,h)-k*h*(1.-h);}
mat2 rot(float a){float c=cos(a),s=sin(a);return mat2(vec2(c,-s),vec2(s,c));}


// vent grille: dark slots with a lit upper lip; u runs across the slots, m is the soft panel mask
void slots(float u,float m,inout float vent,inout float lip){float t=fract(u);
 vent=max(vent,m*smoothstep(.16,.24,t)*smoothstep(.80,.72,t));lip=max(lip,m*smoothstep(.74,.80,t)*smoothstep(.94,.86,t));}
float box2(vec2 q,vec2 c,vec2 h,float r){vec2 d=abs(q-c)-h+r;return length(max(d,0.))+min(max(d.x,d.y),0.)-r;}
// circuit trace: run, 45-degree jog, run, end pad (all in a 2D surface chart)
float trace(vec2 q,vec2 a,float l1,float j,float l2){vec2 b=a+vec2(l1,0.),c=b+vec2(sign(l1)*abs(j),j),e=c+vec2(l2,0.);
 float d=min(min(seg2(q,a,b),seg2(q,b,c)),seg2(q,c,e));return min(d,abs(length(q-e)-.018));}
float chev(vec2 q,float y0){return max(abs(q.y-y0+.62*abs(q.x))-.024,abs(q.x)-.19);}
float ySlit(float ax,float y){float yc=.11-.065*(1.-smoothstep(0.,.42,ax));float hw=.024-.011*smoothstep(.15,.44,ax);float bar=max(abs(y-yc)-hw,ax-.44);bar=max(bar,dot(vec2(ax,-(y-yc)),normalize(vec2(1.,1.6)))-.43);float sw=.016+.009*smoothstep(-.1,-.44,y);float stem=max(ax-sw,max(y-yc,-y-.46));return smin(bar,stem,.014);}
void fragment(){vec3 p=vP,nO=normalize(vN);vec3 n=normalize(vNv);vec3 rd=normalize(vV),v=-rd;
 float wearW=vMR.z,fab=vMR.w,metal=vMR.x;
 
#ifdef LITE
float sc=0.,gr=.5+.2*noise(p*9.),gr2=.5;
#else
float sc=scratches(p*.8),gr=fbm(p*14.),gr2=fbm(p*vec3(60.,4.,60.));
#endif

 float curv=clamp(length(fwidth(nO))*2.5,0.,1.);
 vec3 f0=vCol;float rough=vMR.y;vec3 alb=vCol*(1.-metal);
 // armour plates: grain, wear on edges and scratches, dirt
 vec3 fp=vCol*(.88+.2*gr);float rp=vMR.y+.12*gr2-.10*sc;
 
#ifdef LITE
float wear=clamp(curv*.35,0.,1.);
#else
float wear=clamp(sc*.8+curv*.5*smoothstep(.45,.75,fbm(p*10.)),0.,1.);
#endif
fp=mix(fp,vec3(.68,.69,.71),wear*.6*step(.2,vCol.b));rp=mix(rp,.18,wear);
 f0=mix(mix(vec3(.04),vCol,metal),fp,wearW);rough=mix(rough,rp,wearW);
 // Godot-baked tier detail (triplanar in body space): plate seams, weave / brushing / filigree, edge wear and lit inlays
 float emiD=0.;if(uDetK>0.&&wearW>.05){vec3 bw=pow(abs(nO),vec3(4.));bw/=bw.x+bw.y+bw.z;vec3 q=p*.12;
  vec4 d=texture(uDet,q.zy)*bw.x+texture(uDet,q.xz)*bw.y+texture(uDet,q.xy)*bw.z;float hb=(texture(uDet,q.zy,1.5)*bw.x+texture(uDet,q.xz,1.5)*bw.y+texture(uDet,q.xy,1.5)*bw.z).r;
  float fk=clamp(1.-length(fwidth(q.xy+q.yz))*28.,0.,1.);float h=d.r,seam=smoothstep(.5,.22,h)*mix(.35,1.,fk);
  f0*=1.-.55*seam*uDetK;alb*=1.-.55*seam*uDetK;rough=clamp(mix(rough,d.g,.4*uDetK*fk)+.15*seam,.04,1.);f0=mix(f0,vec3(.62,.64,.68),d.a*.3*uDetK*wearW);
  vec3 dpx=dFdx(vV),dpy=dFdy(vV);float hx=dFdx(hb),hy=dFdy(hb);vec3 r1=cross(dpy,n),r2=cross(n,dpx);float det=dot(dpx,r1);
  n=normalize(abs(det)*n-sign(det)*(hx*r1+hy*r2)*.45*fk*uDetK);emiD=d.b*mix(.4,1.,fk);}
 if(fab>.01){
#ifdef LITE
float qd=.5,rib=.5+.5*sin(p.y*120.);
#else
float qd=fbm(p*50.),rib=.5+.5*sin(p.y*120.+fbm(p*6.)*3.);
#endif
alb*=mix(1.,(.85+.3*qd)*(.92+.16*rib),fab);rough+=.1*qd*fab;}
 vec3 emi=vEmi+GLO*emiD*(1.5+.8*sin(uTime*2.4+p.y*2.6))*uDetK;float vent=0.,lip=0.,vglow=0.;
 // painted neon lines (arm points mapped back to the rest pose by segment)
 if(wearW>.05){vec3 gp=p,gn=nO;bool isA=false;float sg=floor(vX.y+.5);
#ifdef ARMREST
isA=true;
#endif

  if(sg>.5){isA=true;vec3 q=sg>3.5?vec3(-p.x,p.y,p.z):p,qn=sg>3.5?vec3(-nO.x,nO.y,nO.z):nO;float k=sg>3.5?sg-3.:sg;
   mat3 M=k<1.5?(sg>3.5?MUR:MUL):k<2.5?(sg>3.5?MFR:MFL):(sg>3.5?MHR:MHL);
   vec3 o=k<1.5?SR_:k<2.5?ER_:WR_,c=k<1.5?SR_:k<2.5?(sg>3.5?E2R:E2L):(sg>3.5?W2R:W2L);gp=o+M*(q-c);gn=M*qn;}
  float gd=glowD(gp,gn,isA);
  if(isA&&gp.y<7.75&&gp.y>6.7){float fd=1e3;
   if(gn.x>.45){vec2 c=vec2(gp.z,gp.y);float m=smoothstep(.01,0.,box2(c,vec2(.0,7.38),vec2(.10,.17),.03));slots((gp.y-7.18)/.055,m,vent,lip);fd=min(fd,trace(c,vec2(.16,7.62),0.,0.,0.)+1e3);}
   if(gn.z>.35){vec2 c=vec2(gp.x,gp.y);fd=min(fd,trace(vec2(-c.y,c.x),vec2(-7.62,2.34),.30,-.08,.28));}
   emi+=GLO*(1.9*smoothstep(.016,.008,fd)+.25*exp(-fd*45.));}emi+=wearW*GLO*(3.2*smoothstep(.034,.018,gd)+.5*exp(-gd*30.));}
 // ---- refined detail: vents, circuit traces, data stripes, rank insignia (body and helmet only)

#ifndef ARMREST
 if(floor(vX.y+.5)<.5&&wearW>.05){float ax=abs(p.x);vec2 f=vec2(ax,p.y);
  vec3 hq=(p-vec3(0,11.38,0))/vec3(1.08,1.28,1.03);float hx=abs(hq.x);float tg=1e3,tp=0.;
  // helmet: rear exhaust grille, cheek intakes
  if(nO.z<-.25&&hq.z<-.30){float m=smoothstep(.012,0.,box2(vec2(hx,hq.y),vec2(0.,-.30),vec2(.24,.15),.04));slots((hq.y+.45)/.062,m,vent,lip);vglow=max(vglow,m);}
  if(abs(nO.x)>.35&&hq.z>-.05&&hq.y<-.25){vec2 c=vec2(hq.z,hq.y);float m=smoothstep(.01,0.,box2(c,vec2(.12,-.43),vec2(.10,.09),.03));slots((c.x+.6*c.y)/.05,m,vent,lip);}
  // helmet: circuit traces sweeping back above the ear line, data dashes along the crown channels
  if(abs(nO.x)>.30&&hx>.30&&hq.y>.05&&hq.y<.40){vec2 c=vec2(-hq.z,hq.y);
   tg=min(tg,trace(c,vec2(-.02,.30),.22,-.06,.18));tg=min(tg,trace(c,vec2(.02,.24),.16,-.07,.20));tg=min(tg,trace(c,vec2(.06,.18),.10,-.06,.10));}
  if(hq.y>.30&&nO.y>.3&&hq.z<.15){float t=fract(hq.z*13.);if(abs(hx-.215)<.012&&t<.55)tp=max(tp,1.);}
  // chest: angled vent between the V lines; rank bars on the left breast
  if(nO.z>.3&&p.z>0.&&p.y>8.2){vec2 dvn=vec2(-.57,.82),dvl=vec2(.82,.57),c=f-vec2(.80,9.20);float m=smoothstep(.012,0.,box2(vec2(dot(c,dvl),dot(c,dvn)),vec2(0.),vec2(.17,.10),.03));slots(dot(c,dvn)/.05+.5,m,vent,lip);
   if(p.x>0.){float b=min(box2(f,vec2(.66,9.80),vec2(.13,.022),.006),box2(f,vec2(.66,9.72),vec2(.13,.022),.006));float bo=box2(f,vec2(.66,9.76),vec2(.17,.075),.015);
    float a=smoothstep(.006,0.,b);f0=mix(f0,vec3(.80,.82,.86),a);rough=mix(rough,.22,a);tg=min(tg,abs(bo));}
   else{tg=min(tg,trace(f,vec2(.30,9.70),.30,-.08,.16));}}
  // thighs and back plate: circuit traces
  if(nO.z>.3&&p.z>0.&&p.y<5.8&&p.y>4.2){tg=min(tg,trace(vec2(-f.y,f.x),vec2(-5.55,.66),.35,-.08,.30));}
  if(nO.z<-.3&&p.z<0.&&p.y>7.6&&p.y<9.0){tg=min(tg,trace(vec2(-f.y,f.x),vec2(-8.92,.62),.30,.12,.32));
   float m=smoothstep(.01,0.,box2(f,vec2(.46,8.30),vec2(.13,.15),.03));slots((p.y-8.12)/.06,m,vent,lip);}
  // rank insignia: three silver chevrons edged in blue on the left pauldron
  if(p.x>0.&&nO.x>.4&&ax>1.90&&p.y>9.25){vec2 g=vec2(p.z+.02,p.y-9.66);
   float cv=min(chev(g,.14),min(chev(g,.02),chev(g,-.10)));float a=smoothstep(.006,0.,cv);
   f0=mix(f0,vec3(.82,.84,.88),a);rough=mix(rough,.2,a);tg=min(tg,abs(length(g)-.27));
   float st=length(g-vec2(0.,.22));if(st<.045){float an=atan(g.y-.22,g.x),r=.045*(.55+.45*cos(5.*an));f0=mix(f0,vec3(.82,.84,.88),smoothstep(.004,0.,st-r));}}
  emi+=GLO*(1.9*smoothstep(.016,.008,tg)+.25*exp(-tg*45.))+GLO*1.4*tp;
  f0=mix(f0,vec3(.012),vent);alb=mix(alb,vec3(.004),vent);rough=mix(rough,.6,vent);
  f0=mix(f0,vec3(.55,.57,.60),lip*.7);rough=mix(rough,.2,lip);emi+=GLO*.35*vent*vglow;}
#endif
 // helmet: aggressive T slit (scowling brow bar + narrow stem), side ring light, earpiece ring, left mouth vents
 vec3 hp=(p-vec3(0,11.38,0))/vec3(1.08,1.28,1.03);
 if(hp.y>-.75&&hp.y<.6&&hp.z>-.6){float ax=abs(hp.x);float band=ySlit(ax,hp.y);
  if(hp.z>.12&&band<.012){float core=smoothstep(.012,-.012,band);float a=smoothstep(.012,.0,band);emi=mix(emi,GLO*(2.4+1.0*core)*(1.-.25*smoothstep(.30,.45,ax)),a);f0=mix(f0,vec3(.05),a);alb=mix(alb,vec3(0.,.03,.05),a);metal*=1.-a;}
  vec3 e=vec3(ax,hp.y,hp.z)-vec3(.53,-.08,-.12);e.xz=rot(.25)*e.xz;
  if(hp.x<0.&&abs(e.x)<.09)emi+=GLO*3.*smoothstep(.016,.008,abs(length(e.yz)-.10));
  if(hp.x>.17&&hp.x<.58&&hp.y>-.68&&hp.y<-.28&&hp.z>-.05){float hv=0.,hl=0.;float m=smoothstep(0.,.04,hp.x-.17)*smoothstep(0.,.04,.58-hp.x)*smoothstep(0.,.03,hp.y+.68)*smoothstep(0.,.03,-.28-hp.y);slots((hp.y+.68)/.065-(hp.x-.17)*1.4,m,hv,hl);f0=mix(f0,vec3(.012),hv);alb=mix(alb,vec3(.004),hv);rough=mix(rough,.6,hv);f0=mix(f0,vec3(.55,.57,.60),hl*.7);rough=mix(rough,.2,hl);emi+=GLO*.3*hv;vent=max(vent,hv*.6);}
  vec3 ep=hp-vec3(.535,-.10,-.06);if(ep.x>.07)emi+=GLO*3.*smoothstep(.016,.008,abs(length(ep.yz)-.075));}
 float occ=vX.x*(1.-.8*vent);
 vec3 L0=normalize(vec3(.8,.6,1.)),L1=normalize(vec3(-.9,.2,1.)),L2=normalize(vec3(.3,.5,-.9));
 float a=max(rough*rough,.03);vec3 col=vec3(0.);
 for(int i=0;i<3;i++){vec3 l=i==0?L0:i==1?L1:L2;vec3 lc=i==0?vec3(1.,.98,.95)*1.5:i==1?vec3(.55,.65,.8)*.6:vec3(.3,.8,1.)*1.1;float nl=max(dot(n,l),0.);
  vec3 hh=normalize(l+v);float nh=max(dot(n,hh),0.),nv=max(dot(n,v),.001);vec3 Fh=F_s(f0,max(dot(v,hh),0.));
  float spec=min(D_GGX(nh,a)*.25/max(nl*nv,.05)*nl,8.);col+=lc*(Fh*spec*.6+(1.-metal)*alb*nl*1.4+metal*f0*nl*.12);}
 vec3 r=reflect(rd,n);float up=r.y,sd=r.x;
 vec3 envc=vec3(.05,.07,.10)+vec3(.9,.95,1.)*.9*smoothstep(.55,.85,up)*smoothstep(.9,.3,abs(sd))+vec3(.2,.7,.9)*.35*smoothstep(.5,.9,-sd)+vec3(.6)*.25*smoothstep(-.2,.4,up);

#ifdef LITE
envc*=.35;
#endif
 col+=envc*F_s(f0,max(dot(n,v),0.))*occ*.8;
 if(fab>.01){float fr=pow(1.-max(dot(n,v),0.),2.5);col+=(vec3(.75,.8,.9)*.10*max(dot(n,L0),0.)+vec3(.3,.8,1.)*.18*max(dot(n,L2),0.)+vec3(.15))*fr*fab
#ifdef LITE
*.18
#endif
;}
 col*=mix(1.,occ,.8);
#ifdef LITE
col*=.62;
#endif
col+=emi;
 col=col*(2.51*col+.03)/(col*(2.43*col+.59)+.14);col=pow(col,vec3(1./2.2));
 ALBEDO=mix(pow((col+vec3(.055))/1.055,vec3(2.4)),col/12.92,vec3(lessThanEqual(col,vec3(.04045))));ALPHA=uOp;}
