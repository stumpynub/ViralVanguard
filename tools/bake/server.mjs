// Bake server: serves the original v77 page (unchanged) and the bake scripts, and saves what the page posts back.
//   node tools/bake/server.mjs <path to v77 index.html>
//   GET  /            the v77 game
//   GET  /bake/*.js   bake scripts (loaded into the running game from the browser)
//   POST /save?path=  writes the request body to bake/<path>
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const game = process.argv[2];
const out = path.join(root, "bake");
http.createServer((req, res) => {
	const u = new URL(req.url, "http://localhost");
	if (req.method === "POST" && u.pathname === "/save") {
		const rel = u.searchParams.get("path") || "";
		if (!/^[\w./-]+$/.test(rel) || rel.includes("..")) { res.writeHead(400); return res.end("bad path"); }
		const file = path.join(out, rel);
		fs.mkdirSync(path.dirname(file), { recursive: true });
		const chunks = [];
		req.on("data", (c) => chunks.push(c));
		req.on("end", () => { fs.writeFileSync(file, Buffer.concat(chunks)); res.writeHead(200); res.end("ok " + rel); console.log("saved", rel, Buffer.concat(chunks).length); });
		return;
	}
	if (u.pathname === "/" || u.pathname === "/index.html") {
		res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
		return fs.createReadStream(game).pipe(res);
	}
	if (u.pathname.startsWith("/bake/") && u.pathname.endsWith(".js")) {
		const f = path.join(root, "tools", "bake", path.basename(u.pathname));
		if (fs.existsSync(f)) { res.writeHead(200, { "Content-Type": "application/javascript" }); return fs.createReadStream(f).pipe(res); }
	}
	res.writeHead(404); res.end();
}).listen(8777, () => console.log("bake server on http://localhost:8777"));
