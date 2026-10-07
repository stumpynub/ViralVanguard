// Off-screen shots of the running v77 game with its own renderer (works even while the page isn't being painted).
//   await VVShot.shot('name', [x,y,z], [tx,ty,tz], fov)   -> bake/shots/name.png
window.VVShot = (() => {
	async function shot(name, pos, target, fov = 70, w = 1280, h = 720) {
		const cam = new THREE.PerspectiveCamera(fov, w / h, 0.05, 1400);
		cam.position.set(...pos); cam.lookAt(new THREE.Vector3(...target)); cam.updateMatrixWorld(true);
		const rt = new THREE.WebGLRenderTarget(w, h);
		const prevT = R.getRenderTarget();
		R.setRenderTarget(rt); R.clear(); R.render(S, cam); R.setRenderTarget(prevT);
		const px = new Uint8Array(w * h * 4); R.readRenderTargetPixels(rt, 0, 0, w, h, px); rt.dispose();
		const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
		const g = cv.getContext('2d'), id = g.createImageData(w, h);
		for (let y = 0; y < h; y++) id.data.set(px.subarray((h - 1 - y) * w * 4, (h - y) * w * 4), y * w * 4);
		g.putImageData(id, 0, 0);
		const blob = await new Promise((r) => cv.toBlob(r, 'image/png'));
		await VVBake.post(`shots/${name}.png`, blob);
		return name;
	}
	return { shot };
})();
