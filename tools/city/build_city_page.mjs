// Builds the Neon Core city page that the bake runs on: the v77 game page with Neon Core's city changes applied.
// v77 itself is never edited; every change here is an exact-text patch that must match once, so a v77 update that moves
// the patched code fails loudly instead of baking a half-patched city.
//   node tools/city/build_city_page.mjs [path to v77 index.html]   -> bake/neoncore_city.html
// Changes:
//   roadway  - the three elevated highways become one ring road that follows the street grid: west and east viaducts down
//              the middle of Road_3 and Road_5, a south viaduct over the Road_0 avenue, square junction decks over the two
//              street corners, piers placed mid-block in the median (never in an intersection or under another deck),
//              and crash-barrier ends with an end pier where the north ends stop short of the gateway towers
//   bridges  - the 72 m pedestrian bridges that ran along and under the highways become short square-on street crossings
//              (road width + 7 m), clear of every other deck, with a lift and landing at each end and closed end rails
//   balcony  - sky-bridge exit balconies need clear space below them (none hangs low over a deck)
//   pads     - only the street pads that reach high places stay (sky-bridge roofs, Spire podium, transit canopy); the
//              pads on the sky-bridge exit platforms are removed and the platforms stay as railed balconies
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const src = process.argv[2] || path.resolve(root, "../viral-vanguard/index.html");
let html = fs.readFileSync(src, "utf8");

const once = (find, repl, what) => {
	const n = html.split(find).length - 1;
	if (n !== 1) throw new Error(`${what}: expected 1 match, found ${n}`);
	html = html.replace(find, () => repl);
};

// ---------------------------------------------------------------- layout: the ring road
{
	const key = "const NCC_LAYOUT=";
	const a = html.indexOf(key), b = html.indexOf(";\n", a);
	if (a < 0 || b < 0) throw new Error("NCC_LAYOUT not found");
	const L = JSON.parse(html.slice(a + key.length, b));
	const WX = -62.2, EX = 69.9, SZ = 80.325, JH = 5.5;          // viaduct centre lines; junction half size
	const WN = -6, EN = -56;                                      // north ends: west stops short of the sky-bridge cluster at Road_2, east short of the tower
	const seg = (name, x0, z0, x1, z1, ends, road) => {
		const L_ = Math.hypot(x1 - x0, z1 - z0);
		return { name, c: [+((x0 + x1) / 2).toFixed(3), +((z0 + z1) / 2).toFixed(3)], L: +L_.toFixed(3), W: 10, d: [+((x1 - x0) / L_).toFixed(5), +((z1 - z0) / L_).toFixed(5)], top: 19, bot: 15, supports: [], ends, road };
	};
	L.highways = [
		seg("West Viaduct", WX, WN, WX, SZ - JH, ["end", "junction"], "Road_3"),
		seg("East Viaduct", EX, EN, EX, SZ - JH, ["end", "junction"], "Road_5"),
		seg("South Viaduct", WX + JH, SZ, EX - JH, SZ, ["junction", "junction"], "Road_0"),
	];
	L.junctions = [{ c: [WX, SZ], outer: [[-1, 0], [0, 1]] }, { c: [EX, SZ], outer: [[1, 0], [0, 1]] }];
	L.bridges = [];                                               // placed by the generator (street crossings)
	html = html.slice(0, a + key.length) + JSON.stringify(L) + html.slice(b);
}

// ---------------------------------------------------------------- generator: viaducts, junctions, crossings
const oldRoad = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), "v77_roadway_block.js"), "utf8").replace(/\r\n/g, "\n").replace(/\n$/, "");
const newRoad = fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), "roadway.js"), "utf8").replace(/\r\n/g, "\n").replace(/\n$/, "");
once(oldRoad, newRoad, "roadway block");

// ---------------------------------------------------------------- sky-bridge exit platforms: no launch pad
{
	const a = html.indexOf("  // the pad\n  const pu=PD*.58");
	const endMark = "tg?tg.slice(0,3).map(v=>+v.toFixed(1)):null])}";
	const b = html.indexOf(endMark, a);
	if (a < 0 || b < 0 || html.indexOf("  // the pad\n  const pu=PD*.58", a + 1) >= 0) throw new Error("platform pad block not found once");
	html = html.slice(0, a) + "  // (Neon Core: no launch pad here - the platform is a railed balcony; pads only stand where they reach high ground)\n }" + html.slice(b + endMark.length);
}

// ---------------------------------------------------------------- sky-bridge exit balconies: real headroom below
// a balcony may not hang low over a walkable deck (it used to sit 3 m over a viaduct with its strut on the road)
once("if(sol(x,top+.9,z)||sol(x,top+2.5,z)){PD=Math.min(PD,u-.3);break}", "if(sol(x,top+.9,z)||sol(x,top+2.5,z)||sol(x,top-1.8,z)||sol(x,top-3.2,z)||sol(x,top-4.6,z)){PD=Math.min(PD,u-.3);break}", "balcony headroom");

const out = path.join(root, "bake", "neoncore_city.html");
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, html);
console.log("wrote", path.relative(root, out), (html.length / 1e6).toFixed(1), "MB");
