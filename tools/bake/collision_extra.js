// In-page export of the collision data that is not in the grid: ray proxies, glass panes, lifts, pads, bounds, solid
// boxes, destructible crate blocks (bake/collision/proxies.json), and the doors with their panel nodes indexed in the
// same order export.js walks the scene (bake/collision/doors.json). Needs export.js loaded first (VVBake.post).
// Usage from the page:  await VVCollision.run()
window.VVCollision = (() => {
	async function run() {
		const px = CITY.proxies.map((p) => { p.updateMatrixWorld(true); return { t: p.geometry.type === 'BoxGeometry' ? 'b' : 'c', m: Array.from(p.matrixWorld.elements).map((v) => +v.toFixed(5)), glass: !!(p.userData && p.userData.glass) }; });
		const gl = CITY.GLASS.map((g) => ({ m: Array.from(g.matrixWorld.elements).map((v) => +v.toFixed(5)), cells: g.userData.glass.cells, n: g.userData.glass.n, top: g.userData.glass.top }));
		await VVBake.post('collision/proxies.json', JSON.stringify({ proxies: px, glass: gl, lifts: CITY.LIFTS, pads: CITY.PADS, bounds: CITY.bounds, boxes: CITY.boxes, blocks: [...B.values()].map((m) => [m.userData.i, m.userData.j, m.userData.k, m.userData.col]) }));
		const idx = new Map(); let k = 0;
		const walk = (o) => { if (o === C) return; idx.set(o, k++); for (const c of o.children) walk(c); };
		walk(S);
		const D = window.NCC_DOORS.map((d) => ({ g: idx.get(d.g), pan: d.pan.map(([pn, sg]) => [idx.get(pn), sg]), OW: d.OW, top: d.top, cells: d.cells, pos: d.pos.toArray() }));
		await VVBake.post('collision/doors.json', JSON.stringify({ total: k, doors: D, glassNodes: CITY.GLASS.map((g) => idx.get(g)) }));
		return { proxies: px.length, glass: gl.length, blocks: B.size, doors: D.length, nodes: k };
	}
	return { run };
})();
