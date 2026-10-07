// In-page collision export: rebuilds v77's per-cell collision exactly by probing its own CITY.sol / CITY.hAt.
// Each 1 m cell (x0..x1, z0..z1 integer range) gets its ground height SG and the solid spans above it ([bottom, top)
// pairs, edges refined by bisection to float precision). Output: bake/collision/grid.bin + grid.json
// Layout of grid.bin: for each cell (row-major, z outer, x inner): float32 SG, uint8 spanCount, pad[3], then
// spanCount * (float32 bottom, float32 top). Cells outside the city (CITY's ci < 0) have SG = NaN.
window.VVGrid = (() => {
	async function run(opt = {}) {
		const X0 = opt.x0 ?? -130, X1 = opt.x1 ?? 130, Z0 = opt.z0 ?? -107, Z1 = opt.z1 ?? 107, TOP = opt.top ?? 260, STEP = opt.step ?? 0.04;
		const sol = CITY.sol, hAt = CITY.hAt;
		const out = []; let maxSpans = 0, cells = 0, spansTotal = 0;
		const edge = (x, z, lo, hi, solidAtHi) => {          // boundary between lo (state !solidAtHi) and hi (state solidAtHi)
			for (let i = 0; i < 40; i++) { const m = (lo + hi) / 2; if (sol(x, m, z) === solidAtHi) hi = m; else lo = m; }
			return Math.fround(hi);
		};
		for (let z = Z0; z < Z1; z++) {
			for (let x = X0; x < X1; x++) {
				const cx = x + 0.5, cz = z + 0.5;
				// outside the grid: sol is false everywhere, including below 0
				const inside = sol(cx, -1e6, cz);
				if (!inside) { out.push([NaN, []]); continue; }
				const sg = hAt(cx, cz);
				const spans = [];
				let y = sg + 1e-4, state = false, start = 0;
				while (y < TOP) {
					const s = sol(cx, y, cz);
					if (s !== state) {
						const e = edge(cx, cz, y - STEP, y, s);
						if (s) start = e; else spans.push([start, e]);
						state = s;
					}
					y += STEP;
				}
				if (state) spans.push([start, TOP]);
				maxSpans = Math.max(maxSpans, spans.length); spansTotal += spans.length; cells++;
				out.push([sg, spans]);
			}
			if ((z - Z0) % 20 === 0) await new Promise((r) => setTimeout(r, 0));
		}
		let bytes = 0; for (const [, sp] of out) bytes += 8 + sp.length * 8;
		const buf = new ArrayBuffer(bytes), dv = new DataView(buf); let p = 0;
		for (const [sg, sp] of out) { dv.setFloat32(p, sg, true); dv.setUint8(p + 4, sp.length); p += 8; for (const [a, b] of sp) { dv.setFloat32(p, a, true); dv.setFloat32(p + 4, b, true); p += 8; } }
		await VVBake.post('collision/grid.bin', new Uint8Array(buf));
		const meta = { x0: X0, x1: X1, z0: Z0, z1: Z1, cell: 1, step: STEP, top: TOP, cells, maxSpans, spansTotal, bounds: CITY.bounds,
			lifts: CITY.LIFTS, pads: CITY.PADS, blocks: [...B], glassCount: CITY.GLASS.length };
		await VVBake.post('collision/grid.json', JSON.stringify(meta));
		return { cells, maxSpans, spansTotal, kb: Math.round(bytes / 1024) };
	}
	return { run };
})();
