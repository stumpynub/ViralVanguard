#!/usr/bin/env python3
"""Pull the v74 ("Neon Core City" co-op build) assets out of Viral_Vanguard_v74_coop.html.

Writes:
  data/ncc_layout.json                  the city plan (roads, buildings, towers, highways, bridges, skyport...)
  assets/models/kit/<piece>.glb         17 quantised kit meshes (spire, highway, bridges, lamps, trees, rocks...)
  assets/models/kit/wpn_grip.glb, wpn_stock.glb
  assets/models/vehicles/ship.glb       civilian spacecraft (PBR textures embedded)
  assets/models/vehicles/moto.glb       motorcycle (vertex colours; paint as a separate mesh)
  assets/models/drone.glb               hunter drone
  assets/ui/boot_art.png                boot / loading screen art

Usage: python3 tools/extract_v74.py ~/Downloads/Viral_Vanguard_v74_coop.html
"""
import base64, json, os, re, struct, sys
sys.path.insert(0, os.path.dirname(__file__))
from glb_writer import GLB

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/Viral_Vanguard_v74_coop.html")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
html = open(SRC, encoding="utf-8").read()
lines = html.split("\n")


def out(rel):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def js_obj(prefix):
    line = next(l for l in lines if l.startswith(prefix))
    return json.loads(line[len(prefix):].rstrip().rstrip(";"))


# ---------------------------------------------------------------- layout + boot art
json.dump(js_obj("const NCC_LAYOUT="), open(out("data/ncc_layout.json"), "w"), indent=1)
m = re.search(r"#boot \.art\{position:absolute;inset:0;background:url\(data:image/jpeg;base64,([A-Za-z0-9+/=]+)\)", html)
import io
from PIL import Image   # Godot boot splashes must be PNG
Image.open(io.BytesIO(base64.b64decode(m.group(1)))).save(out("assets/ui/boot_art.png"))


def unpack(data, nv, ni, big, with_col):
    """Kit / vehicle buffer: int16 xyz, (align 4) int8 normals, (align 4) [uint8 rgb], (align 4) indices."""
    o = 0
    al = lambda o: o + (4 - o % 4) % 4
    q = struct.unpack_from("<%dh" % (nv * 3), data, o); o = al(o + nv * 6)
    n = struct.unpack_from("<%db" % (nv * 3), data, o); o = al(o + nv * 3)
    c = None
    if with_col:
        c = data[o:o + nv * 3]; o = al(o + nv * 3)
    ix = struct.unpack_from("<%d%s" % (ni, "I" if big else "H"), data, o)
    return q, n, c, ix, o + ni * (4 if big else 2)


# ---------------------------------------------------------------- kit meshes
KIT_MATS = {  # bucket: (roughness, metallic, glass?, glow?)
    "metal": (0.45, 0.55), "roof": (0.9, 0.2), "chrome": (0.3, 0.85), "glass": (0.06, 0.9), "glow": (1.0, 0.0)}
kit = re.findall(r"\n(\w+):\{s:([0-9.e-]+),o:\[([^\]]*)\],b:\{(.*?)\}\}", html)
for name, s, o, body in kit:
    s = float(s)
    o = [float(x) for x in o.split(",")]
    g = GLB()
    prims = []
    for bk, nv, ni, big, b64 in re.findall(r"(\w+):\[(\d+),(\d+),(\d),'([A-Za-z0-9+/=]+)'\]", body):
        nv, ni, big = int(nv), int(ni), int(big)
        q, n, c, ix, _ = unpack(base64.b64decode(b64), nv, ni, big, True)
        P = [q[i] * s + o[i % 3] for i in range(nv * 3)]
        N = [x / 127 for x in n]
        C = [min(1.0, b / 255 * 1.25) for b in c]
        rough, metal = KIT_MATS.get(bk, (0.5, 0.5))
        if bk == "glow":
            mat = g.material("glow", [1, 1, 1], 0.0, 1.0, emissive=[2.2, 2.2, 2.2])
        else:
            mat = g.material(bk, [1, 1, 1], metal, rough)
        if bk == "glass":
            g.j["materials"][mat]["alphaMode"] = "BLEND"
            g.j["materials"][mat]["pbrMetallicRoughness"]["baseColorFactor"] = [1, 1, 1, 0.32]
        prims.append({"pos": P, "nrm": N, "col": C, "idx": list(ix), "mat": mat})
    g.node(name, g.mesh(name, prims), root=True)
    g.save(out("assets/models/kit/%s.glb" % name))
print("kit:", [k[0] for k in kit])


# ---------------------------------------------------------------- vehicles
V = js_obj("const VEH_DATA=")


def data_uri_image(g, uri):
    mime, b64 = re.match(r"data:(image/\w+);base64,(.*)", uri, re.S).groups()
    raw = base64.b64decode(b64)
    while len(g.bin) % 4:
        g.bin.append(0)
    off = len(g.bin)
    g.bin += raw
    g.j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(raw)})
    g.j.setdefault("images", []).append({"bufferView": len(g.j["bufferViews"]) - 1, "mimeType": mime})
    g.j.setdefault("samplers", [{"wrapS": 10497, "wrapT": 10497}])
    g.j.setdefault("textures", []).append({"source": len(g.j["images"]) - 1, "sampler": 0})
    return len(g.j["textures"]) - 1


def vehicle(key, offset, textured):
    D = V[key]
    g = GLB()
    nodes = []
    for part, spec in D["g"].items():
        nv, ni, big, ub, b64 = spec[:5]
        has_c = len(spec) > 5 and spec[5]
        data = base64.b64decode(b64)
        o = 0
        al = lambda o: o + (4 - o % 4) % 4
        q = struct.unpack_from("<%dh" % (nv * 3), data, 0); o = al(nv * 6)
        n = struct.unpack_from("<%db" % (nv * 3), data, o); o = al(o + nv * 3)
        C = U = None
        if has_c:
            c8 = data[o:o + nv * 3]; o = al(o + nv * 3)
            C = [(v / 255) ** 2 * ((v / 255) * 0.3 + 0.7) for v in c8]
        elif ub is not None:
            u16 = struct.unpack_from("<%dH" % (nv * 2), data, o); o += nv * 4
            U = []
            for i in range(nv):
                U += [u16[i * 2] / 65535 * 8, u16[i * 2 + 1] / 65535 * 8 + ub]
        ix = struct.unpack_from("<%d%s" % (ni, "I" if big else "H"), data, o)
        P = [q[i] * D["s"] + D["o"][i % 3] + offset[i % 3] for i in range(nv * 3)]
        N = [x / 127 for x in n]
        mat = g.material(part, [1, 1, 1], 0.85, 0.5)
        mj = g.j["materials"][mat]
        if textured and part in V.get("shipTex", {}):
            t = V["shipTex"][part]
            if "map" in t: mj["pbrMetallicRoughness"]["baseColorTexture"] = {"index": data_uri_image(g, t["map"])}
            if "mr" in t: mj["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": data_uri_image(g, t["mr"])}
            if "nrm" in t: mj["normalTexture"] = {"index": data_uri_image(g, t["nrm"])}
            if "emi" in t:
                mj["emissiveTexture"] = {"index": data_uri_image(g, t["emi"])}
                mj["emissiveFactor"] = [1, 1, 1]
        if part == "Window":
            mj["pbrMetallicRoughness"].update(baseColorFactor=[0.5, 0.66, 0.85, 1], roughnessFactor=0.08, metallicFactor=0.1)
            mj["pbrMetallicRoughness"].pop("baseColorTexture", None)
        if part in ("HullMain", "Hull"):
            mj["pbrMetallicRoughness"]["baseColorFactor"] = [0.72, 0.74, 0.78, 1]
        prim = {"pos": P, "nrm": N, "idx": list(ix), "mat": mat}
        if C: prim["col"] = C
        mi = g.mesh(part, [prim])
        if U:   # add TEXCOORD_0 to the primitive just written
            g.j["meshes"][mi]["primitives"][0]["attributes"]["TEXCOORD_0"] = g._acc(U, 2)
        nodes.append(g.node(part, mi))
    g.node(key.capitalize(), children=nodes, root=True)
    return g


vehicle("ship", (11.9, 6.3, 0), True).save(out("assets/models/vehicles/ship.glb"))
vehicle("moto", (-0.53, -0.07, 0), False).save(out("assets/models/vehicles/moto.glb"))


# ---------------------------------------------------------------- drone
H = [[2993, 15579], [3700, 19200], [1296, 4497]]
b64 = re.search(r"const DRONE_B='([A-Za-z0-9+/=]+)'", html).group(1)
raw = base64.b64decode(b64)
o = 0
g = GLB()
mats = [g.material("DroneHull", [0.36, 0.45, 0.58], 0.92, 0.24), g.material("DroneDark", [0.106, 0.122, 0.153], 0.85, 0.38),
        g.material("DroneEye", [0.16, 0.55, 1.0], 0.0, 1.0, emissive=[0.25, 0.84, 1.6])]
parts = []
for k, (nv, ni) in enumerate(H):
    P = [v / 32767 * 0.55 for v in struct.unpack_from("<%dh" % (nv * 3), raw, o)]; o += nv * 6
    N = []
    for i in range(nv):
        N += [x / 127 for x in struct.unpack_from("<3b", raw, o + i * 4)]
    o += nv * 4
    ix = struct.unpack_from("<%dH" % ni, raw, o); o += ni * 2
    if (ni * 2) % 4: o += 2
    parts.append(g.node(["Hull", "Frame", "Lights"][k], g.mesh("Drone%d" % k, [{"pos": P, "nrm": N, "idx": list(ix), "mat": mats[k]}])))
g.node("Drone", children=parts, root=True)
g.save(out("assets/models/drone.glb"))
print("v74 assets extracted")
