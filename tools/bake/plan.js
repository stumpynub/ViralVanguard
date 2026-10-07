// In-page plan view of the city layout for checking the roadway: streets, buildings, gateway towers, viaducts, junctions,
// pedestrian bridges, sky-bridges, piers (white), lifts (cyan), pads (blue), and any blocked deck cells (red).
//   await VVPlan.draw('plan.png')          -> bake/analysis/plan.png
//   VVPlan.blocked()                        -> {counts, cells}: deck cells with something solid standing on them
window.VVPlan = (() => {
	const decks = () => {
		const L = NCC_LAYOUT, out = [];
		for (const h of L.highways) out.push({ n: h.name, c: h.c, d: h.d, L: h.L - 1.6, W: 10, top: 19 });
		for (const J of L.junctions || []) out.push({ n: 'junction', c: J.c, d: [1, 0], L: 10, W: 10, top: 19 });
		for (const b of L.bridges) out.push({ n: 'ped ' + (b.road || ''), c: b.c, d: b.d, L: b.L - 1.4, W: 6.2, top: b.top });
		return out;
	};
	function blocked() {
		const sol = CITY.sol, counts = {}, cells = [];
		for (const k of decks()) for (let a = -k.L / 2 + .6; a <= k.L / 2 - .6; a += .5) for (let b = -k.W / 2 + .6; b <= k.W / 2 - .6; b += .5) {
			const x = k.c[0] + k.d[0] * a - k.d[1] * b, z = k.c[1] + k.d[1] * a + k.d[0] * b;
			if (sol(x, k.top + 1.0, z) || sol(x, k.top + 1.7, z)) { counts[k.n] = (counts[k.n] || 0) + 1; cells.push([x, z]); }
			if (!sol(x, k.top - .2, z)) counts[k.n + ' HOLE'] = (counts[k.n + ' HOLE'] || 0) + 1;
		}
		return { counts, cells };
	}
	async function draw(file, marks) {
		const L = NCC_LAYOUT, K = 6, B = L.bounds, W = (B[1] - B[0] + 20) * K, H = (B[3] - B[2] + 20) * K, cv = document.createElement('canvas');
		cv.width = W; cv.height = H; const g = cv.getContext('2d');
		const X = (x) => (x - B[0] + 10) * K, Z = (z) => (z - B[2] + 10) * K;
		g.fillStyle = '#0b0b12'; g.fillRect(0, 0, W, H);
		const obb = (c, d, Lg, Wd, fill, stroke) => { const sx = -d[1], sz = d[0], p = [[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([a, b]) => [c[0] + d[0] * a * Lg / 2 + sx * b * Wd / 2, c[1] + d[1] * a * Lg / 2 + sz * b * Wd / 2]); g.beginPath(); p.forEach((q, i) => i ? g.lineTo(X(q[0]), Z(q[1])) : g.moveTo(X(q[0]), Z(q[1]))); g.closePath(); if (fill) { g.fillStyle = fill; g.fill(); } if (stroke) { g.strokeStyle = stroke; g.lineWidth = 2; g.stroke(); } };
		const rect = (b, f, s) => { g.fillStyle = f; g.fillRect(X(b[0]), Z(b[2]), (b[1] - b[0]) * K, (b[3] - b[2]) * K); if (s) { g.strokeStyle = s; g.strokeRect(X(b[0]), Z(b[2]), (b[1] - b[0]) * K, (b[3] - b[2]) * K); } };
		for (const r of L.roads) obb(r.c, r.d, r.L, r.W, '#2a2a33');
		for (const b of L.buildings) rect(b.box, '#3b3550');
		for (const b of L.towers) rect(b.box, '#4b3a70');
		for (const a of L.anchors) rect(a.box, a.gate ? 'rgba(255,60,200,.35)' : '#5a3a60', a.gate ? '#ff3cc8' : null);
		rect(L.skyport.box, 'rgba(120,80,255,.3)', '#8a5cff'); rect(L.transit_canopy, 'rgba(80,160,255,.25)', '#50a0ff');
		for (const h of L.highways) obb(h.c, h.d, h.L, 11, 'rgba(255,170,40,.35)', '#ffaa28');
		for (const J of L.junctions || []) obb(J.c, [1, 0], 11, 11, 'rgba(255,200,60,.5)', '#ffc83c');
		for (const b of L.bridges) obb(b.c, b.d, b.L, 7, 'rgba(60,255,140,.45)', '#3cff8c');
		for (const s of L.skybridges) obb(s.c, s.d, s.L, 7.4, 'rgba(33,230,255,.3)', '#21e6ff');
		g.fillStyle = '#fff';
		for (const h of L.highways) for (const [x, z] of h.supports) g.fillRect(X(x) - 8, Z(z) - 8, 16, 16);
		for (const J of L.junctions || []) g.fillRect(X(J.c[0]) - 8, Z(J.c[1]) - 8, 16, 16);
		for (const q of CITY.LIFTS) { g.fillStyle = '#00ffff'; g.beginPath(); g.arc(X(q[0]), Z(q[1]), 7, 0, 7); g.fill(); }
		for (const p of CITY.PADS) { g.fillStyle = '#4060ff'; g.beginPath(); g.arc(X(p[0]), Z(p[1]), 10, 0, 7); g.fill(); }
		for (const [x, z] of marks || blocked().cells) { g.fillStyle = '#ff2030'; g.fillRect(X(x) - 3, Z(z) - 3, 6, 6); }
		g.font = 'bold 22px sans-serif'; g.fillStyle = '#fff';
		L.skybridges.forEach((s) => g.fillText(s.name + ' ' + s.top + 'm', X(s.c[0]) - 40, Z(s.c[1]) - 30));
		L.highways.forEach((h) => g.fillText((h.name || 'highway') + ' ' + (h.top || 19) + 'm', X(h.c[0]) + 12, Z(h.c[1]) + 40));
		L.bridges.forEach((b) => g.fillText('PED ' + b.top + 'm', X(b.c[0]) + 14, Z(b.c[1])));
		g.fillStyle = '#888';
		for (let x = -120; x <= 120; x += 20) g.fillText(x, X(x), 18);
		for (let z = -100; z <= 100; z += 20) g.fillText(z, 4, Z(z));
		const blob = await new Promise((r) => cv.toBlob(r, 'image/png'));
		await VVBake.post('analysis/' + file, blob);
		return file;
	}
	return { draw, blocked };
})();
