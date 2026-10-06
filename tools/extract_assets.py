#!/usr/bin/env python3
"""Pull the embedded assets out of the original Viral Vanguard HTML build.

Writes into the Godot project:
  assets/ui/hangar_bg.jpg           hangar backdrop (CSS --hangar data URI)
  assets/audio/music_menu.mp3       MUSIC_SRC (hangar loop)
  assets/audio/music_game.mp3       GAME_SRC (match loop)
  assets/models/spider.glb          SPIDER_LODS[0]  (body, glow, 4 legs on their hip pivots)
  assets/models/spider_lod1.glb     SPIDER_LODS[1]
  assets/models/operative_mk1..4.glb  hangar operative, one per armour suit tier

Usage: python3 tools/extract_assets.py "/path/to/viral-vanguard.html"
"""
import base64, json, math, os, re, struct, sys

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/viral-vanguard(1).html")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
html = open(SRC, encoding="utf-8").read()


def out(rel):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def js_string(name):
    m = re.search(r"const %s='([^']*)'" % name, html)
    return m.group(1)


# ---------------------------------------------------------------- images / audio
m = re.search(r"--hangar:url\(data:image/jpeg;base64,([A-Za-z0-9+/=]+)\)", html)
open(out("assets/ui/hangar_bg.jpg"), "wb").write(base64.b64decode(m.group(1)))
for js, f in (("MUSIC_SRC", "music_menu.mp3"), ("GAME_SRC", "music_game.mp3")):
    data = js_string(js).split(",", 1)[1]
    open(out("assets/audio/" + f), "wb").write(base64.b64decode(data))


from glb_writer import GLB


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def flat(pos, tri, col=None):
    """De-index into flat-shaded triangles (the original used flatShading)."""
    P, N, C = [], [], []
    for a, b, c in tri:
        pa, pb, pc = pos[a], pos[b], pos[c]
        u = [pb[i] - pa[i] for i in range(3)]
        v = [pc[i] - pa[i] for i in range(3)]
        n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        l = math.sqrt(sum(x * x for x in n)) or 1.0
        n = [x / l for x in n]
        for k in (a, b, c):
            P += pos[k]; N += n
            if col: C += col[k]
    return P, N, C


# ---------------------------------------------------------------- spider robot
line = next(l for l in html.split("\n") if l.startswith("const SPIDER_LODS="))
PAL = [[.028, .028, .032], [.20, .21, .23], [.05, .05, .06], [.30, .31, .34]]
PAL = [[srgb_to_lin(c) for c in p] for p in PAL]
lods = re.findall(r'\{p:(\{[^}]*\}),piv:(\[\[.*?\]\]),lo:(\[[^\]]*\]),sc:(\[[^\]]*\]),b:"([A-Za-z0-9+/=]+)"', line)
for li, (P_, piv, lo, sc, b) in enumerate(lods):
    parts, piv, lo, sc = json.loads(P_), json.loads(piv), json.loads(lo), json.loads(sc)
    buf = base64.b64decode(b)
    g = GLB()
    m_body = g.material("SpiderHull", [1, 1, 1], 0.6, 0.34)
    m_glow = g.material("SpiderGlow", [0.02, 0.2, 1.0], 0.0, 1.0, emissive=[0.18, 1.6, 3.2])

    def part(k, pv=None):
        o, nv, nt = parts[k]
        q = struct.unpack_from("<%dH" % (nv * 3), buf, o); o += nv * 6
        ix = struct.unpack_from("<%dH" % (nt * 3), buf, o); o += nt * 6
        ci = buf[o:o + nv]
        pos = [[lo[a] + q[i * 3 + a] * sc[a] - (pv[a] if pv else 0) for a in range(3)] for i in range(nv)]
        col = [PAL[ci[i]] for i in range(nv)]
        tri = [ix[i * 3:i * 3 + 3] for i in range(nt)]
        return flat(pos, tri, col)

    P, N, C = part("body")
    body = g.node("Body", g.mesh("Body", [{"pos": P, "nrm": N, "col": C, "mat": m_body}]))
    P, N, C = part("glow")
    glow = g.node("Glow", g.mesh("Glow", [{"pos": P, "nrm": N, "mat": m_glow}]))
    hull = g.node("Hull", children=[body, glow])
    legs = []
    for i in range(4):
        P, N, C = part("leg%d" % i, piv[i])
        legs.append(g.node("Leg%d" % i, g.mesh("Leg%d" % i, [{"pos": P, "nrm": N, "col": C, "mat": m_body}]), t=piv[i]))
    g.node("Spider", children=[hull] + legs, root=True)
    g.save(out("assets/models/spider%s.glb" % ("" if li == 0 else "_lod1")))


# ---------------------------------------------------------------- hangar operative (four suit tiers)
MT = {1: [.085, .088, .096, 1, .22], 11: [.032, .033, .038, 1, .30], 8: [.62, .64, .68, 1, .20], 4: [.030, .032, .036, 0, .52],
      13: [.030, .028, .026, 0, .48], 15: [.028, .027, .026, 0, .46], 14: [.05, .05, .055, 0, .8], 9: [.018, .018, .018, 0, .85],
      2: [.0, .03, .05, 0, .05], 5: [.085, .088, .096, 1, .22], 12: [.02, .06, .08, 0, .3]}
SUITS = [{"glo": [.04, .30, 1.], "mt": {}},
         {"glo": [.04, .36, 1.], "mt": {1: [.105, .112, .13, 1, .24], 11: [.04, .043, .052, 1, .30], 5: [.105, .112, .13, 1, .24], 6: [.50, .53, .58, 1, .26]}},
         {"glo": [.08, .62, 1.], "mt": {1: [.06, .062, .068, 1, .16], 11: [.024, .025, .03, 1, .26], 5: [.06, .062, .068, 1, .16], 6: [.74, .76, .80, 1, .15]}},
         {"glo": [.26, .55, 1.], "mt": {1: [.034, .034, .04, 1, .12], 11: [.016, .016, .02, 1, .2], 5: [.034, .034, .04, 1, .12], 6: [.95, .68, .28, 1, .2]}}]
SUIT_N = [[35166, 209928], [35064, 209910], [35024, 209832], [34997, 209790]]
LO, HI = [-3.1, -0.2, -2.0], [3.1, 12.6, 3.4]
NAMES = {1: "ArmorPlate", 11: "ArmorDark", 8: "Steel", 4: "Fabric", 13: "Leather", 15: "Webbing", 14: "Rubber", 9: "Black",
         2: "Visor", 5: "ArmorPlateB", 12: "GlowSoft", 7: "GlowCore", 6: "Trim"}
for tier, src in enumerate(["OPM_SRC", "OPM_T1", "OPM_T2", "OPM_T3"]):
    NV, NI = SUIT_N[tier]
    buf = base64.b64decode(js_string(src))
    su = SUITS[tier]
    pos, nrm, mid = [], [], []
    for i in range(NV):
        o = i * 12
        q = struct.unpack_from("<3H", buf, o)
        pos.append([LO[k] + (HI[k] - LO[k]) * q[k] / 65535 for k in range(3)])
        n = struct.unpack_from("<3b", buf, o + 8)
        nrm.append([c / 127 for c in n])
        mid.append(buf[o + 6])
    idx = struct.unpack_from("<%dH" % NI, buf, NV * 12)
    groups = {}
    for t in range(NI // 3):
        a, b, c = idx[t * 3:t * 3 + 3]
        groups.setdefault(mid[a], []).append((a, b, c))
    g = GLB()
    prims = []
    for id_, tris in sorted(groups.items()):
        t = su["mt"].get(id_) or MT.get(id_) or MT[1]
        emi = None
        if id_ == 12: emi = [c * 1.8 for c in su["glo"]]
        if id_ == 7: emi = [c * 2.8 for c in su["glo"]]
        mat = g.material(NAMES.get(id_, "Mat%d" % id_), t[:3], float(t[3]), float(t[4]), emi)
        remap, P, N, I = {}, [], [], []
        for tri in tris:
            for v in tri:
                if v not in remap:
                    remap[v] = len(remap); P += pos[v]; N += nrm[v]
                I.append(remap[v])
        prims.append({"pos": P, "nrm": N, "idx": I, "mat": mat})
    s = 1.92 / 11.9
    g.node("Operative", g.mesh("Operative", prims), s=[s, s, s], root=True)
    g.save(out("assets/models/operative_mk%d.glb" % (tier + 1)))

print("assets extracted to", ROOT)
