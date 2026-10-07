// In-page exporter: runs inside the original v77 game (served by tools/bake/server.mjs) and writes what v77 built at
// runtime (meshes, instanced meshes, sprites, lights, materials and their canvas / image textures) to the bake server:
//   bake/<name>/scene.json   node tree, geometries, materials, textures, lights, and the material shader patches
//   bake/<name>/geometry.bin vertex / index data (little-endian Float32 / Uint32)
//   bake/<name>/tex/<id>.png every texture image, exactly as v77 drew it
// Usage from the page:  await VVBake.exportObject(S, 'city', {exclude: [C]})
window.VVBake = (() => {
	const post = (path, body) => fetch('/save?path=' + encodeURIComponent(path), { method: 'POST', body }).then((r) => { if (!r.ok) throw new Error('save failed ' + path); });
	const arr = (m) => Array.from(m.elements);
	const col = (c) => (c ? [c.r, c.g, c.b] : null);

	async function texPNG(tex) {
		const img = tex.image;
		if (!img) return null;
		let cv = null;
		if (img instanceof HTMLCanvasElement) cv = img;
		else if (img instanceof HTMLImageElement || img instanceof ImageBitmap) {
			const w = img.naturalWidth || img.width, h = img.naturalHeight || img.height;
			if (!w || !h) return null;
			cv = document.createElement('canvas'); cv.width = w; cv.height = h;
			cv.getContext('2d').drawImage(img, 0, 0);
		} else if (img.data && img.width) {               // DataTexture
			cv = document.createElement('canvas'); cv.width = img.width; cv.height = img.height;
			const id = cv.getContext('2d').createImageData(img.width, img.height);
			const d = img.data, n = img.width * img.height, ch = d.length / n;
			for (let i = 0; i < n; i++) { for (let k = 0; k < 3; k++) id.data[i * 4 + k] = d[i * ch + Math.min(k, ch - 1)] * (d instanceof Float32Array ? 255 : 1); id.data[i * 4 + 3] = ch === 4 ? d[i * 4 + 3] * (d instanceof Float32Array ? 255 : 1) : 255; }
			cv.getContext('2d').putImageData(id, 0, 0);
		} else return null;
		return await new Promise((res) => cv.toBlob(res, 'image/png'));
	}

	async function exportObject(root, name, opt = {}) {
		const exclude = new Set(opt.exclude || []);
		root.updateMatrixWorld(true);
		const geoIdx = new Map(), matIdx = new Map(), texIdx = new Map(), patchIdx = new Map();
		const geos = [], mats = [], texs = [], patches = [], nodes = [], lights = [];
		const chunks = []; let off = 0;
		const pushBuf = (typed) => {
			const b = new Uint8Array(typed.buffer.slice(typed.byteOffset, typed.byteOffset + typed.byteLength));
			const at = off; chunks.push(b); off += b.byteLength;
			const pad = (4 - (off % 4)) % 4; if (pad) { chunks.push(new Uint8Array(pad)); off += pad; }
			return at;
		};
		const attr = (a) => {
			if (!a) return null;
			const n = a.count, s = a.itemSize, out = new Float32Array(n * s);
			for (let i = 0; i < n; i++) for (let k = 0; k < s; k++) out[i * s + k] = k === 0 ? a.getX(i) : k === 1 ? a.getY(i) : k === 2 ? a.getZ(i) : a.getW(i);
			return { off: pushBuf(out), n, s, normalized: !!a.normalized };
		};
		const geo = (g) => {
			if (geoIdx.has(g.uuid)) return geoIdx.get(g.uuid);
			const A = g.attributes, e = { type: g.type };
			for (const k of ['position', 'normal', 'uv', 'uv2', 'color', 'tangent']) if (A[k]) e[k] = attr(A[k]);
			const extra = Object.keys(A).filter((k) => !['position', 'normal', 'uv', 'uv2', 'color', 'tangent'].includes(k));
			if (extra.length) e.extra = extra.map((k) => [k, attr(A[k])]);
			if (g.index) { const ix = new Uint32Array(g.index.count); for (let i = 0; i < ix.length; i++) ix[i] = g.index.getX(i); e.index = { off: pushBuf(ix), n: ix.length }; }
			if (g.groups && g.groups.length) e.groups = g.groups.map((q) => [q.start, q.count, q.materialIndex]);
			if (g.drawRange && (g.drawRange.start || g.drawRange.count !== Infinity)) e.drawRange = [g.drawRange.start, g.drawRange.count === Infinity ? -1 : g.drawRange.count];
			geoIdx.set(g.uuid, geos.length); geos.push(e); return geos.length - 1;
		};
		const tex = (t) => {
			if (!t) return null;
			if (texIdx.has(t.uuid)) return texIdx.get(t.uuid);
			t.updateMatrix();
			const e = { id: texs.length, name: t.name, encoding: t.encoding, wrap: [t.wrapS, t.wrapT], repeat: [t.repeat.x, t.repeat.y], offset: [t.offset.x, t.offset.y], center: [t.center.x, t.center.y], rotation: t.rotation, flipY: t.flipY, mag: t.magFilter, min: t.minFilter, aniso: t.anisotropy, mips: t.generateMipmaps, uvMatrix: Array.from(t.matrix.elements), src: t.image && t.image.src && !t.image.src.startsWith('data:') ? t.image.src : null, w: t.image && (t.image.width || t.image.naturalWidth), h: t.image && (t.image.height || t.image.naturalHeight), file: null, _t: t };
			texIdx.set(t.uuid, e.id); texs.push(e); return e.id;
		};
		const patch = (m) => {
			const s = m.onBeforeCompile ? String(m.onBeforeCompile) : '';
			if (s.length <= 40) return null;
			if (!patchIdx.has(s)) { patchIdx.set(s, patches.length); patches.push(s); }
			return patchIdx.get(s);
		};
		const mat = (m) => {
			if (!m) return null;
			if (matIdx.has(m.uuid)) return matIdx.get(m.uuid);
			const e = { type: m.type, name: m.name, color: col(m.color), emissive: col(m.emissive), emissiveIntensity: m.emissiveIntensity, roughness: m.roughness, metalness: m.metalness, opacity: m.opacity, transparent: m.transparent, side: m.side, blending: m.blending, vertexColors: m.vertexColors, toneMapped: m.toneMapped, depthWrite: m.depthWrite, depthTest: m.depthTest, flatShading: m.flatShading, fog: m.fog, alphaTest: m.alphaTest, visible: m.visible, colorWrite: m.colorWrite, polygonOffset: m.polygonOffset ? [m.polygonOffsetFactor, m.polygonOffsetUnits] : null, wireframe: m.wireframe, sizeAttenuation: m.sizeAttenuation, rotation: m.rotation, size: m.size, clearcoat: m.clearcoat, clearcoatRoughness: m.clearcoatRoughness, transmission: m.transmission, reflectivity: m.reflectivity, envMapIntensity: m.envMapIntensity, normalScale: m.normalScale ? [m.normalScale.x, m.normalScale.y] : null, lightMapIntensity: m.lightMapIntensity, aoMapIntensity: m.aoMapIntensity, bumpScale: m.bumpScale, shininess: m.shininess, specular: col(m.specular), patch: patch(m), cacheKey: m.customProgramCacheKey ? String(m.customProgramCacheKey()) : null };
			for (const k of ['map', 'emissiveMap', 'normalMap', 'roughnessMap', 'metalnessMap', 'alphaMap', 'lightMap', 'aoMap', 'bumpMap', 'clearcoatNormalMap', 'specularMap']) if (m[k]) e[k] = tex(m[k]);
			// evaluate the material's onBeforeCompile against a stand-in shader to capture what it injects and the
			// uniform values it binds (clip volumes, desaturation amount, premultiplied output)
			if (e.patch != null) {
				const sh = { uniforms: {}, vertexShader: 'void main() {\n#include <project_vertex>\n}', fragmentShader: 'void main() {\ngl_FragColor = vec4( outgoingLight, diffuseColor.a );\n#include <fog_fragment>\n}' };
				try {
					m.onBeforeCompile(sh, R);
					e.patchOut = { vs: sh.vertexShader, fs: sh.fragmentShader, uniforms: {} };
					for (const [k, u] of Object.entries(sh.uniforms)) {
						const v = u.value;
						e.patchOut.uniforms[k] = Array.isArray(v) ? v.map((x) => (x && x.toArray ? x.toArray() : x)) : v && v.toArray ? v.toArray() : v;
					}
				} catch (err) { e.patchOut = { error: String(err) }; }
			}
			if (m.isShaderMaterial) {
				e.vertexShader = m.vertexShader; e.fragmentShader = m.fragmentShader; e.defines = m.defines; e.extensions = m.extensions;
				e.uniforms = {};
				for (const [k, u] of Object.entries(m.uniforms || {})) {
					const v = u.value;
					e.uniforms[k] = v == null ? null : v.isTexture ? { tex: tex(v) } : v.isColor ? { color: col(v) } : v.isVector2 || v.isVector3 || v.isVector4 ? { vec: v.toArray() } : v.isMatrix4 || v.isMatrix3 ? { mat: Array.from(v.elements) } : Array.isArray(v) ? { array: v.map((x) => (x && x.toArray ? x.toArray() : x)) } : typeof v === 'number' || typeof v === 'boolean' ? { v } : { unknown: String(v).slice(0, 80) };
				}
			}
			matIdx.set(m.uuid, mats.length); mats.push(e); return mats.length - 1;
		};
		const walk = (o, parent) => {
			if (exclude.has(o)) return;
			const n = { name: o.name, type: o.type, parent, matrix: arr(o.matrix), visible: o.visible, castShadow: o.castShadow, receiveShadow: o.receiveShadow, renderOrder: o.renderOrder, frustumCulled: o.frustumCulled, layers: o.layers.mask, userData: Object.keys(o.userData || {}).length ? JSON.parse(JSON.stringify(o.userData, (k, v) => (v && v.isObject3D ? undefined : v))) : undefined };
			const me = nodes.length; nodes.push(n);
			if ((o.isMesh || o.isPoints || o.isLine || o.isSprite) && o.geometry) {
				n.geo = geo(o.geometry);
				n.mat = Array.isArray(o.material) ? o.material.map(mat) : mat(o.material);
				if (o.isInstancedMesh) {
					n.count = o.count;
					n.instances = { off: pushBuf(new Float32Array(o.instanceMatrix.array.slice(0, o.count * 16))), n: o.count };
					if (o.instanceColor) n.instanceColors = { off: pushBuf(new Float32Array(o.instanceColor.array.slice(0, o.count * 3))), n: o.count };
				}
				if (o.isSprite) n.center = [o.center.x, o.center.y];
			}
			if (o.isLight) {
				n.light = { type: o.type, color: col(o.color), groundColor: col(o.groundColor), intensity: o.intensity, distance: o.distance, decay: o.decay, angle: o.angle, penumbra: o.penumbra, castShadow: o.castShadow, target: o.target ? arr(o.target.matrixWorld) : null };
				if (o.castShadow && o.shadow) n.light.shadow = { mapSize: [o.shadow.mapSize.x, o.shadow.mapSize.y], bias: o.shadow.bias, normalBias: o.shadow.normalBias, radius: o.shadow.radius, camera: o.shadow.camera.isOrthographicCamera ? [o.shadow.camera.left, o.shadow.camera.right, o.shadow.camera.top, o.shadow.camera.bottom, o.shadow.camera.near, o.shadow.camera.far] : [o.shadow.camera.near, o.shadow.camera.far] };
			}
			if (o.isCamera) n.camera = { fov: o.fov, near: o.near, far: o.far };
			for (const c of o.children) walk(c, me);
		};
		walk(root, -1);
		// textures to PNG, a few at a time
		for (const e of texs) {
			const blob = await texPNG(e._t);
			if (blob) { e.file = `tex/${e.id}.png`; await post(`${name}/${e.file}`, blob); }
			delete e._t;
		}
		const env = root.isScene ? { background: root.background && root.background.isColor ? col(root.background) : null, fog: root.fog ? { color: col(root.fog.color), density: root.fog.density, near: root.fog.near, far: root.fog.far } : null } : null;
		const manifest = { name, three: THREE.REVISION, env, nodes, geometries: geos, materials: mats, textures: texs, patches, binBytes: off };
		const bin = new Uint8Array(off); let p = 0; for (const c of chunks) { bin.set(c, p); p += c.byteLength; }
		await post(`${name}/geometry.bin`, bin);
		await post(`${name}/scene.json`, JSON.stringify(manifest));
		return { nodes: nodes.length, geometries: geos.length, materials: mats.length, textures: texs.length, patches: patches.length, mb: +(off / 1e6).toFixed(1) };
	}
	return { exportObject, post };
})();
