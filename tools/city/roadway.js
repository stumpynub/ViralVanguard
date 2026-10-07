 // ---------- Neon Core ring road: viaducts down the middle of the streets, square junction decks over the corners ----------
 // hammerhead piers stand mid-block in the median about every 24 m, nudged along the street until the column is clear:
 // never inside an intersection, never through another deck, never on a lift; dead ends get a crash barrier and an end pier
 const roadOf=n=>LAY.roads.find(r=>r.name===n);
 const inRoadX=(x,z,r,pad)=>{const px=x-r.c[0],pz=z-r.c[1];return Math.abs(px*r.d[0]+pz*r.d[1])<=r.L/2+pad&&Math.abs(-px*r.d[1]+pz*r.d[0])<=r.W/2+pad};
 const pierOK=(x,z,own,pad=2)=>{if(inPlaza(x,z,2)||LAY.roads.some(r=>r!==own&&inRoadX(x,z,r,pad)))return false;
  for(let y=.5;y<HWY-2.6;y+=1.5)for(const[a,b]of[[0,0],[1.4,1.4],[-1.4,1.4],[1.4,-1.4],[-1.4,-1.4]])if(sol(x+a,y,z+b))return false;
  return!LIFTS.some(q=>Math.hypot(q[0]-x,q[1]-z)<4)};
 const pier=(x,z,ry)=>{kitAt('highway_pylon',x,0,z,ry,1,(HWY-2.4)/16.6,1);solidBox(x-1.3,x+1.3,z-1.3,z+1.3,HWY-2.4);pool(x,z,4,HEX.cya,.35)};
 const rail3=(cx,cz,L,dx,dz)=>obbCells(cx,cz,L,.6,dx,dz,(x,z)=>slab3(x,z,HWY-1.2,HWY+1.1));
 for(const J of LAY.junctions||[]){const[jx,jz]=J.c;
  box('roof',jx,HWY-.6,jz,11,1.2,11,0x1b1b22);box('metal',jx,HWY-1.75,jz,9.4,1.1,9.4,0x15151b);box('glow',jx,HWY-1.22,jz,9,.03,9,HEX.cya.clone().multiplyScalar(.5));
  deck3(jx,jz,11,11,0,1,HWY-1.2,HWY);
  for(const[ox,oz]of J.outer){const bx=jx+ox*5.33,bz=jz+oz*5.33,ry=ox?0:Math.PI/2;   // barrier along each outer edge; the inner sides stay open
   box('metal',bx,HWY+.53,bz,.36,1.06,11,0x3a3a46,ry);box('glow',bx,HWY+1.08,bz,.4,.05,11,HEX.cya,ry);rail3(jx+ox*5.25,jz+oz*5.25,11,oz?1:0,ox?1:0)}
  pier(jx,jz,Math.PI/4);pool(jx,jz,8,HEX.cya,.3)}
 for(const h of LAY.highways){const[dx,dz]=h.d,sx=-dz,sz=dx,own=roadOf(h.road),ry=RYd(h.d);runSeg(h.c,h.d,h.L,20,HWY,'highway_seg');
  deck3(h.c[0],h.c[1],h.L,11,dx,dz,HWY-1.2,HWY);
  for(const s of[-1,1])rail3(h.c[0]+sx*s*5.25,h.c[1]+sz*s*5.25,h.L,dx,dz);
  // ends: a junction deck carries on; a dead end gets a crash barrier across the deck with hazard stripes facing the traffic
  h.ends.forEach((k,i)=>{if(k!=='end')return;const e=i?1:-1,t=e*(h.L/2-.25),x=h.c[0]+dx*t,z=h.c[1]+dz*t;
   box('metal',x,HWY+.53,z,11,1.06,.4,0x3a3a46,ry);box('glow',x,HWY+1.08,z,11,.05,.44,HEX.mag,ry);for(let k2=-4;k2<=4;k2+=2)box('glow',x+sx*k2-dx*e*.21,HWY+.53,z+sz*k2-dz*e*.21,.9,.18,.02,HEX.ora,ry);
   obbCells(x,z,.8,11,dx,dz,(a,b)=>slab3(a,b,HWY-1.2,HWY+1.1))});
  // piers: ~24 m spans end to end, each nudged along the median to the nearest clear spot (an end pier may stand at the edge of a crossing)
  const n=Math.max(2,Math.round(h.L/24)),ons=[];
  for(let k=0;k<=n;k++){let t=-h.L/2+h.L*k/n;if(k===0){if(h.ends[0]!=='end')continue;t+=3}if(k===n){if(h.ends[1]!=='end')continue;t-=3}
   for(const o of[0,1.5,-1.5,3,-3,4.5,-4.5,6,-6,8,-8]){const tt=t+o;if(tt<-h.L/2+2.5||tt>h.L/2-2.5)continue;const x=h.c[0]+dx*tt,z=h.c[1]+dz*tt;
    if(!pierOK(x,z,own,k===0||k===n?.5:2))continue;pier(x,z,ry+Math.PI/2);ons.push(tt);break}}
  // no span over 32 m: where crossings pushed piers apart, add one in the gap (wider search, the edge of a crossing allowed)
  for(let pass=0;pass<4;pass++){const st=ons.slice().sort((p,q)=>p-q),ends=[h.ends[0]==="end"?-h.L/2:-h.L/2-5.5].concat(st,[h.ends[1]==="end"?h.L/2:h.L/2+5.5]);let added=false;
   for(let i=0;i+1<ends.length;i++){if(ends[i+1]-ends[i]<=32)continue;const m=(ends[i]+ends[i+1])/2;
    for(const o of[0,2,-2,4,-4,6,-6,8,-8,10,-10,12,-12]){const tt=m+o;if(tt-ends[i]<8||ends[i+1]-tt<8||tt<-h.L/2+2.5||tt>h.L/2-2.5)continue;const x=h.c[0]+dx*tt,z=h.c[1]+dz*tt;
     if(!pierOK(x,z,own,.5))continue;pier(x,z,ry+Math.PI/2);ons.push(tt);added=true;break}}
   if(!added)break}
  h.supports=ons.map(t=>[+(h.c[0]+dx*t).toFixed(2),+(h.c[1]+dz*t).toFixed(2)]);
  ons.sort((a,b)=>a-b);
  for(const q of[ons[1],ons[ons.length-2]])if(q!=null)liftBeside(h.c,h.d,q+5,5.5,HWY+.6,HWY);
  for(let t=-h.L/2+10;t<h.L/2;t+=20)pool(h.c[0]+dx*t,h.c[1]+dz*t,6,HEX.cya,.22,2.2,ry)}

 // ---------- pedestrian bridges (10 m): short square-on street crossings landing on the sidewalk, a lift at each end ----------
 // (kept out from under the sky-bridges, and off the transit canopy, skyport and rooftop arena, which are generated later)
 {const top=10,PB=[],later=[LAY.transit_canopy,LAY.skyport.box,LAY.zones.Rooftop],nearDeck=(x,z)=>later.some(b=>x>b[0]-2&&x<b[1]+2&&z>b[2]-2&&z<b[3]+2)||LAY.skybridges.some(q=>{const px=x-q.c[0],pz=z-q.c[1];return Math.abs(px*q.d[0]+pz*q.d[1])<=q.L/2+3&&Math.abs(-px*q.d[1]+pz*q.d[0])<=(q.W||7)/2+3})||LAY.highways.some(h=>{const px=x-h.c[0],pz=z-h.c[1];return Math.abs(px*h.d[0]+pz*h.d[1])<=h.L/2+12&&Math.abs(-px*h.d[1]+pz*h.d[0])<=10})||(LAY.junctions||[]).some(J=>Math.abs(x-J.c[0])<12&&Math.abs(z-J.c[1])<12),
   clearAt=(x,z)=>{if(hAt(x,z)>top-2.2)return false;for(const y of[top-1.4,top-.7,top+.4,top+1.4,top+2.6,top+3.6])if(sol(x,y,z))return false;return true},
   canLift=(c,d,t0)=>{const[dx,dz]=d,sx=-dz,sz=dx;for(const o of[6.5,9,12])for(const ts of[0,4,-4])for(const s of[1,-1]){const t=t0+ts,x=c[0]+dx*t+sx*s*o,z=c[1]+dz*t+sz*s*o;if(colClear(x,z,top+.6)&&!inPlaza(x,z)&&!inRoad(x,z,.5))return true}return false},
   cand=[];
  for(const r of LAY.roads){if(r.W>12)continue;const[dx,dz]=r.d,nx=-dz,nz=dx,L=+(r.W+7).toFixed(2);
   for(let t=-r.L/2+14;t<=r.L/2-14;t+=2){const cx=r.c[0]+dx*t,cz=r.c[1]+dz*t;if(inPlaza(cx,cz,8))continue;let ok=true;
    for(let a=-L/2;ok&&a<=L/2+.01;a+=1)for(let b=-3.5;ok&&b<=3.51;b+=1){const x=cx+nx*a+dx*b,z=cz+nz*a+dz*b;
     if(!clearAt(x,z)||nearDeck(x,z)||LIFTS.some(q=>Math.hypot(q[0]-x,q[1]-z)<3)||LAY.roads.some(q=>q!==r&&inRoadX(x,z,q,3)))ok=false}
    for(const e of[-1,1]){const x=cx+nx*e*(L/2-.5),z=cz+nz*e*(L/2-.5);if(ok&&(inRoad(x,z,-.3)||!canLift([cx,cz],[nx,nz],e*(L/2-2))))ok=false}
    if(ok)cand.push({c:[+cx.toFixed(3),+cz.toFixed(3)],d:[nx,nz],L,W:7,top,road:r.name})}}
  // spread them through the districts: inner streets first, at least 55 m apart
  cand.sort((p,q)=>Math.hypot(p.c[0],p.c[1])-Math.hypot(q.c[0],q.c[1]));
  for(const c of cand)if(PB.length<4&&PB.every(p=>Math.hypot(p.c[0]-c.c[0],p.c[1]-c.c[1])>55))PB.push(c);
  LAY.bridges=PB;window.NCC_BRIDGES={placed:PB,candidates:cand.length}}
 for(const b of LAY.bridges){const[dx,dz]=b.d,sx=-dz,sz=dx,top=b.top,ry=RYd(b.d);runSeg(b.c,b.d,b.L,10,top,'ped_bridge');
  deck3(b.c[0],b.c[1],b.L,7,dx,dz,top-.5,top);
  const LS=[-1,1].map(e=>liftBeside(b.c,b.d,e*(b.L/2-2),3.5,top+.6,top));
  // side rails, open only where a lift landing meets the deck; both ends closed with a rail
  for(const s of[-1,1])for(let t=-b.L/2+.5;t<b.L/2-.4;t+=1){if(LS.some(q=>q&&q[0]===s&&Math.abs(t-q[1])<1.8))continue;obbCells(b.c[0]+sx*s*3.3+dx*t,b.c[1]+sz*s*3.3+dz*t,1,.4,dx,dz,(x,z)=>slab3(x,z,top-.5,top+.9))}
  for(const e of[-1,1]){const x=b.c[0]+dx*e*(b.L/2-.12),z=b.c[1]+dz*e*(b.L/2-.12);box('metal',x,top+.5,z,6.8,1,.1,0x2a2d36,ry);box('glow',x,top+1.02,z,6.8,.04,.14,HEX.cya,ry);obbCells(x,z,.5,7,dx,dz,(a,c)=>slab3(a,c,top-.5,top+.9))}}
