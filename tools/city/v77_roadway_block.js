 for(const h of LAY.highways){const[dx,dz]=h.d,sx=-dz,sz=dx;runSeg(h.c,h.d,h.L,20,HWY,'highway_seg');
  deck3(h.c[0],h.c[1],h.L,11,dx,dz,HWY-1.2,HWY);
  for(const s of[-1,1])obbCells(h.c[0]+sx*s*5.25,h.c[1]+sz*s*5.25,h.L,.6,dx,dz,(x,z)=>slab3(x,z,HWY-1.2,HWY+1.1));
  const ons=h.supports.map(q=>{const t=(q[0]-h.c[0])*dx+(q[1]-h.c[1])*dz;return[h.c[0]+dx*t,h.c[1]+dz*t,t]});
  for(const[x,z]of ons){kitAt('highway_pylon',x,0,z,RYd(h.d)+Math.PI/2,1,(HWY-2.4)/16.6,1);solidBox(x-1.3,x+1.3,z-1.3,z+1.3,HWY-2.4);pool(x,z,4,HEX.cya,.35)}
  ons.sort((a,b)=>a[2]-b[2]);
  for(const q of[ons[1],ons[ons.length-2]])liftBeside(h.c,h.d,q[2]+5,5.5,HWY+.6,HWY);
  for(let t=-h.L/2+10;t<h.L/2;t+=20)pool(h.c[0]+dx*t,h.c[1]+dz*t,6,HEX.cya,.22,2.2,RYd(h.d))}

 // ---------- pedestrian bridges (10 m) and enclosed sky-bridges, with lifts at the ends ----------
 for(const b of LAY.bridges){const[dx,dz]=b.d,sx=-dz,sz=dx,top=b.top;runSeg(b.c,b.d,b.L,10,top,'ped_bridge');
  deck3(b.c[0],b.c[1],b.L,7,dx,dz,top-.5,top);
  for(const s of[-1,1])obbCells(b.c[0]+sx*s*3.3,b.c[1]+sz*s*3.3,b.L-1,.4,dx,dz,(x,z)=>slab3(x,z,top-.5,top+.9));
  for(const e of[-1,1])liftBeside(b.c,b.d,e*(b.L/2-3),3.5,top+.6,top);}
