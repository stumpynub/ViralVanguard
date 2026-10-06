"""Neon Core City (the v74 map) as an editable Godot scene, built from data/ncc_layout.json.

Port of the v74 CITY builder: Grand Plaza and the 217 m Central Spire, 8 boulevards, ~100 buildings and hero
towers, gateway anchor towers, three elevated highways, pedestrian bridges and glass sky-bridges, the skyport,
the market, parks, the transit canopy, gravity lifts and launch pads, parked spacecraft and motorcycles, and the
bay ringed by mountains. Placement that v74 solved at runtime against its collision grid (lift spots beside
decks, launch-pad arcs, parking) is solved here against a small box model of the same city.
"""
import json, math, random
from godot_writer import *
from build_props import mesh_node, static_box, pool, local_glow
from build_arena import Arena as OldArena, SHOP_SIGNS, BLADE_SIGNS, NEON, ADS

M = lambda n: "assets/materials/%s.tres" % n
P2 = math.pi / 2
MAPK = 0.765
HWY = 19.0
PAD_APEX = 10.0
rng = random.Random(90210)
rr = lambda a, b: a + (b - a) * rng.random()
pick = lambda a: a[int(rng.random() * len(a))]
LAY = json.load(open(ROOT + "/data/ncc_layout.json"))
BND = LAY["bounds"]
PLZ = 36 * MAPK
ryd = lambda d: math.atan2(d[0], d[1])
KIND = {'res': 0, 'com': 1, 'ind': 2}
NEONC = {'Cyan Neon': '#21e6ff', 'Pink Neon': '#ff2bd6', 'Violet Neon': '#8a3bff', 'Green Neon': '#3cff8c'}


# ------------------------------------------------------------------ a coarse solid model of the city (for placement)
class World:
    def __init__(self):
        self.obb = []      # (cx, cz, hl_along, hw_across, dx, dz, y0, y1)
        self.cyl = []      # (cx, cz, r, y0, y1)

    def box(self, x0, x1, z0, z1, y0, y1):
        self.obb.append(((x0 + x1) / 2, (z0 + z1) / 2, (z1 - z0) / 2, (x1 - x0) / 2, 0.0, 1.0, y0, y1))

    def ob(self, cx, cz, L, W, dx, dz, y0, y1):
        self.obb.append((cx, cz, L / 2, W / 2, dx, dz, y0, y1))

    def sol(self, x, y, z):
        for cx, cz, hl, hw, dx, dz, y0, y1 in self.obb:
            if y0 <= y < y1:
                px, pz = x - cx, z - cz
                if abs(px * dx + pz * dz) <= hl and abs(-px * dz + pz * dx) <= hw:
                    return True
        for cx, cz, r, y0, y1 in self.cyl:
            if y0 <= y < y1 and (x - cx) ** 2 + (z - cz) ** 2 <= r * r:
                return True
        return False

    def h_at(self, x, z):
        h = 0.0
        for y in [i * 0.5 for i in range(0, 120)]:
            if self.sol(x, y, z):
                h = y + 0.5
        return h


W = World()


def in_road(x, z, pad=0.0):
    for r in LAY["roads"]:
        px, pz = x - r["c"][0], z - r["c"][1]
        if abs(px * r["d"][0] + pz * r["d"][1]) <= r["L"] / 2 + pad and abs(-px * r["d"][1] + pz * r["d"][0]) <= r["W"] / 2 + pad:
            return True
    return False


in_plaza = lambda x, z, pad=0.0: abs(x) < PLZ + pad and abs(z) < PLZ + pad


def col_clear(x, z, top):
    y = 0.3
    while y < top + 2.4:
        for a, b in ((0, 0), (1.3, 0), (-1.3, 0), (0, 1.3), (0, -1.3), (.9, .9), (-.9, .9), (.9, -.9), (-.9, -.9)):
            if W.sol(x + a, y, z + b):
                return False
        y += 0.5
    return True


# ------------------------------------------------------------------ the scene
class NCC(OldArena):
    """Reuses the old builder's environment, kit helpers, signs and building() (which emits Building nodes)."""

    def __init__(self):
        s = self.s = Scene("Arena", "Node3D")
        r = s.nodes[0][3]
        r["script"] = s.ext_res("scripts/world/arena.gd")
        r["bounds"] = Raw("Rect2(%s, %s, %s, %s)" % (num(BND[0] + 1), num(BND[2] + 1), num(BND[1] - BND[0] - 2), num(BND[3] - BND[2] - 2)))
        self.env()
        s.node("PlayerSpawn", "Marker3D", ".", {"transform": T3(10 * MAPK, 0.1, 92 * MAPK)})
        self.city = s.node("City", "Node3D", ".")
        s.node("Enemies", "Node3D", ".")
        s.node("FX", "Node3D", ".")
        self.d = {k: s.node(k, "Node3D", self.city) for k in
                  ("Ground", "Roads", "Plaza", "Buildings", "Towers", "Highways", "Bridges", "SkyBridges", "Skyport", "Districts",
                   "Parks", "StreetProps", "Traversal", "Vehicles", "Cover", "CargoBlocks", "Bay", "Signs")}
        self.lifts = []

    # environment: v74 lighting (moon from (40,80,-60), district lights scaled into the new map) and thinner fog
    def env(self):
        s = self.s
        sky_mat = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/sky.gdshader"))
        env = s.sub_res("Environment", background_mode=2, sky=s.sub_res("Sky", sky_material=sky_mat), ambient_light_source=2,
                        ambient_light_color=hexcol("#6a6cd8"), ambient_light_energy=0.9, tonemap_mode=3, tonemap_exposure=1.05,
                        glow_enabled=True, glow_intensity=0.55, glow_strength=1.0, glow_bloom=0.05, glow_blend_mode=1, glow_hdr_threshold=1.15,
                        fog_enabled=True, fog_light_color=hexcol("#140f38"), fog_density=0.0052, fog_sky_affect=0.25, fog_aerial_perspective=0.2)
        s.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env})
        s.node("Moon", "DirectionalLight3D", ".", {"transform": Raw(self._look((104, 208, -156), (0, 0, 0))), "light_color": hexcol("#a8b4ff"),
                                                   "light_energy": 0.6, "shadow_enabled": True, "directional_shadow_max_distance": 160.0})
        lights = s.node("DistrictLights", "Node3D", ".")
        for c, x, y, z in (("#ff2bd6", -90, 40, -80), ("#21e6ff", 90, 40, -80), ("#ff9a3c", -90, 30, 80), ("#14b8a6", 90, 30, 80),
                           ("#8a3bff", 0, 60, 0), ("#21e6ff", 53, 20, 27), ("#ff2bd6", -45, 60, -77)):
            s.node("Light", "OmniLight3D", lights, {"transform": T3(x * MAPK, y, z * MAPK), "light_color": hexcol(c), "light_energy": 2.6,
                                                     "omni_range": 150.0, "omni_attenuation": 1.4})
        planet = s.node("Planet", None, ".", {"transform": T3(300, 250, -470)}, instance="scenes/world/props/planet.tscn")
        # house style: the film / ink grade drains the neon to grey and keeps the crimson (same pass as the duel)
        post = s.node("Post", "CanvasLayer", ".", {"layer": -1})
        s.node("Grade", "ColorRect", post, {"anchors_preset": 15, "anchor_right": 1.0, "anchor_bottom": 1.0, "mouse_filter": 2,
                                            "material": s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/game_post.gdshader"),
                                                                  **{"shader_parameter/desat": 0.82, "shader_parameter/ink": 0.35})})

    def kit(self, parent, name, x, y, z, ry=0.0, sx=1.0, sy=1.0, sz=1.0, nm=None):
        return self.s.node(nm or name.title().replace("_", ""), None, parent, {"transform": T3(x, y, z, 0, ry, 0, order="YXZ", s=(sx, sy, sz))},
                           instance="assets/models/kit/%s.glb" % name)

    def solid(self, parent, name, cx, cy, cz, w, h, d, ry=0.0):
        """Invisible collision box (w along local x, d along local z)."""
        b = self.s.node(name, "StaticBody3D", parent, {"transform": T3(cx, cy, cz, 0, ry, 0, order="YXZ"), "collision_mask": 0})
        self.s.node("Shape", "CollisionShape3D", b, {"shape": self.s.sub_res("BoxShape3D", size=V3(w, h, d))})
        return b

    def glow_box(self, parent, name, x, y, z, w, h, d, color, ry=0.0):
        mesh_node(self.s, parent, name, self.s.sub_res("BoxMesh", size=V3(w, h, d)), self.s.ext_res(M("glow_" + color)), T3(x, y, z, 0, ry, 0, order="YXZ"), cast_shadow=0)

    def pool_at(self, parent, x, z, radius, color, strength=0.5, y=0.03):
        pool(self.s, parent, "Pool", color, radius, strength, T3(x, y, z))

    # ------------------------------------------------------------------ ground, bay, walls
    def ground(self):
        s, g = self.s, self.d["Ground"]
        gw, gd, gcx, gcz = BND[1] - BND[0], BND[3] - BND[2], (BND[0] + BND[1]) / 2, (BND[2] + BND[3]) / 2
        body = s.node("Plateau", "StaticBody3D", g, {"collision_mask": 0})
        mat = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/ground.gdshader"), **{"shader_parameter/markings": False})
        mesh_node(s, body, "Asphalt", s.sub_res("PlaneMesh", size=V2(gw, gd), subdivide_width=8, subdivide_depth=8), mat, T3(gcx, 0, gcz))
        s.node("Shape", "CollisionShape3D", body, {"transform": T3(gcx, -0.5, gcz), "shape": s.sub_res("BoxShape3D", size=V3(gw, 1, gd))})
        mesh_node(s, g, "Bay", s.sub_res("PlaneMesh", size=V2(1800, 1800)), s.ext_res(M("water")), T3(0, -3.4, 0), cast_shadow=0)
        for x, z, w, d in ((gcx, BND[2] - .5, gw + 2, 1), (gcx, BND[3] + .5, gw + 2, 1), (BND[0] - .5, gcz, 1, gd + 2), (BND[1] + .5, gcz, 1, gd + 2)):
            mesh_node(s, g, "SeaWall", s.sub_res("BoxMesh", size=V3(w, 4.4, d)), s.ext_res(M("roof")), T3(x, -2.2, z))
            self.glow_box(g, "SeaWallGlow", x, -.35, z, w if w > 2 else 1.06, .08, d if d > 2 else 1.06, "cyan")
            self.solid(g, "EdgeFence", x, 15, z, w, 30, d)        # invisible: keeps everyone on the plateau
        bol = s.sub_res("CylinderMesh", top_radius=.25, bottom_radius=.25, height=.7, radial_segments=10)
        t = BND[0] + 6
        while t < BND[1]:
            for z in (BND[2] + .6, BND[3] - .6):
                mesh_node(s, g, "Bollard", bol, s.ext_res(M("metal_pole")), T3(t, .35, z))
            t += 12

    # ------------------------------------------------------------------ roads (segments between intersections)
    def roads(self):
        s, rd = self.s, self.d["Roads"]
        for ri, r in enumerate(LAY["roads"]):
            dx, dz = r["d"]
            hl, hw = r["L"] / 2, r["W"] / 2

            def other(x, z):
                for q in LAY["roads"]:
                    if q is r:
                        continue
                    px, pz = x - q["c"][0], z - q["c"][1]
                    if abs(px * q["d"][0] + pz * q["d"][1]) <= q["L"] / 2 + .5 and abs(-px * q["d"][1] + pz * q["d"][0]) <= q["W"] / 2 + 3.6:
                        return True
                return False
            # 4 m cells: marked where the road is on its own, plain where it crosses another road or the plaza
            cells = []
            t = -hl
            while t < hl - 0.01:
                m = t + 2
                cx, cz = r["c"][0] + dx * m, r["c"][1] + dz * m
                cells.append((t, not (in_plaza(cx, cz, -1) or other(cx, cz))))
                t += 4
            runs, cur = [], None
            for t, marked in cells:
                if marked and cur is None:
                    cur = [t, t + 4]
                elif marked:
                    cur[1] = t + 4
                elif cur is not None:
                    runs.append(cur); cur = None
            if cur:
                runs.append(cur)
            for k, (a, b) in enumerate(runs):
                mid = (a + b) / 2
                cx, cz = r["c"][0] + dx * mid, r["c"][1] + dz * mid
                self.s.node("Road%d_%d" % (ri, k), None, rd, {"transform": T3(cx, 0.012, cz, 0, ryd(r["d"]), 0, order="YXZ"), "length": b - a, "width": r["W"],
                                                              "crosswalk_start": a > -hl + 1, "crosswalk_end": b < hl - 1}, instance="scenes/world/props/road.tscn")
            # plain asphalt patches under intersections are just the ground plane

    # ------------------------------------------------------------------ plaza, spire, lifts
    def lift(self, parent, x, z, top, y=0.0):
        self.s.node("Lift", None, parent, {"transform": T3(x, y, z), "top": top - y}, instance="scenes/world/props/lift.tscn")
        self.lifts.append((x, z, top))
        W.cyl.append((x, z, 1.0, y + 2.6, y + 2.7))   # nominal, keeps other lifts from stacking

    def landing(self, parent, x, z, w, d, top, ry):
        s = self.s
        mesh_node(s, parent, "Landing", s.sub_res("BoxMesh", size=V3(w, .5, d)), s.ext_res(M("metal_dark")), T3(x, top - .25, z, 0, ry, 0, order="YXZ"))
        self.solid(parent, "LandingBody", x, top - .25, z, w, .5, d, ry)
        self.glow_box(parent, "LandingGlow", x, top + .01, z, w * .9, .02, .06, "cyan", ry)
        W.ob(x, z, d, w, math.sin(ry), math.cos(ry), top - .5, top)

    def plaza(self):
        s, p = self.s, self.d["Plaza"]
        mesh_node(s, p, "Paving", s.sub_res("BoxMesh", size=V3(PLZ * 2, .1, PLZ * 2)), s.ext_res(M("paver")), T3(0, .05, 0))
        for rad, c in ((34.5 * MAPK, "cyan"), (28 * MAPK, "magenta"), (22.5 * MAPK, "violet")):
            mesh_node(s, p, "LightRing", s.sub_res("TorusMesh", inner_radius=rad - .14, outer_radius=rad + .14, rings=160, ring_segments=4), s.ext_res(M("glow_" + c)),
                      T3(0, .11, 0, s=(1, .15, 1)), cast_shadow=0)
        inl = s.sub_res("BoxMesh", size=V3(.08, .02, 5))
        for i in range(32):
            a = i / 32 * math.tau
            mesh_node(s, p, "Inlay", inl, s.ext_res(M("glow_blue")), T3(math.sin(a) * 31.2 * MAPK, .11, math.cos(a) * 31.2 * MAPK, 0, a, 0), cast_shadow=0)
        self.pool_at(p, 0, 0, 40 * MAPK, "#8a3bff", .45, .12)
        # the Central Spire (kit) and its collision: podium, core and the stepped tower body
        self.kit(p, "spire", 0, 0, 0, nm="Spire")
        body = s.node("SpireBody", "StaticBody3D", p, {"collision_mask": 0})
        for i, (rad, y0, y1) in enumerate(((16.5, 0, 12.8), (9, 0, 27), (20, 27, 52), (15, 52, 84), (11, 84, 123), (7, 123, 177), (2.6, 177, 192))):
            s.node("Tier%d" % i, "CollisionShape3D", body, {"transform": T3(0, (y0 + y1) / 2, 0), "shape": s.sub_res("CylinderShape3D", radius=rad, height=y1 - y0)})
            W.cyl.append((0, 0, rad, y0, y1))
        s.node("Beacon", "MeshInstance3D", p, {"transform": T3(0, 219, 0), "mesh": s.sub_res("SphereMesh", radius=1.1, height=2.2), "material_override": s.ext_res(M("glow_red")),
                                              "script": s.ext_res("scripts/world/props/blinker.gd"), "rate": 3.0, "duty": 0.6, "cast_shadow": 0})
        spin = s.ext_res("scripts/world/props/spinner.gd")
        for i, c in enumerate(("cyan", "magenta", "violet")):
            h = s.node("Halo%d" % i, "Node3D", p, {"transform": T3(0, 60 + i * 16, 0, (i - 1) * .16), "script": spin, "speed": -.25 if i % 2 else .35})
            mesh_node(s, h, "Ring", s.sub_res("TorusMesh", inner_radius=26 + i * 3 - .09, outer_radius=26 + i * 3 + .09, rings=160, ring_segments=6), s.ext_res(M("glow_" + c)), cast_shadow=0)
        for sg in (-1, 1):   # elevator shafts up to the first observation deck
            self.lift(p, 0, sg * 21.6, 52.6)
            self.landing(p, 0, sg * 18.4, 3.2, 4.6, 52.4, 0)
        # plaza cover: blockout cover blocks become quarantine barriers, pushed out of the podium
        for cx, cz, w, d in LAY["covers"]:
            ry = P2 if d > w else 0.0
            if in_plaza(cx, cz):
                if math.hypot(cx, cz) < 19:
                    L = math.hypot(cx, cz) or 1
                    cx, cz = cx / L * 24 + cx * .2, cz / L * 24 + cz * .2
                self.barrier(self.d["Cover"], cx, cz, ry)
        for i in range(8):
            a = i / 8 * math.tau + math.pi / 8
            x, z = math.sin(a) * 30 * MAPK, math.cos(a) * 30 * MAPK
            self.tree(p, x, 0, z, 1.0)
        for x, z in ((25, 25), (-25, 25), (25, -25), (-25, -25)):
            x, z = x * MAPK, z * MAPK
            ry = math.atan2(-x, -z)
            self.kit(p, "bench", x, 0, z, ry)
            self.kit(p, "vending", x + 2.6, 0, z, ry)
            self.solid(p, "VendingBody", x + 2.6, 1.05, z, 1, 2.1, 1)
            W.box(x + 2.1, x + 3.1, z - .5, z + .5, 0, 2.1)

    def barrier(self, parent, x, z, ry, y=0.0):
        self.kit(parent, "barrier", x, y, z, ry)
        self.solid(parent, "BarrierBody", x, y + .625, z, 3.2, 1.25, .8, ry)
        c, sn = abs(math.cos(ry)), abs(math.sin(ry))
        hx, hz = 1.6 * c + .4 * sn, 1.6 * sn + .4 * c
        W.box(x - hx, x + hx, z - hz, z + hz, y, y + 1.25)
        self.pool_at(parent, x, z, 2.4, "#ff3355", .25, y + .03)

    def tree(self, parent, x, y, z, sc):
        self.kit(parent, "tree", x, y, z, rng.random() * 6, sc, sc, sc)
        self.solid(parent, "TreeBody", x, y + .45, z, 1.8 * sc, .9, 1.8 * sc)
        W.box(x - .9 * sc, x + .9 * sc, z - .9 * sc, z + .9 * sc, y, y + .9)
        self.pool_at(parent, x, z, 3.5 * sc, "#3cff8c", .4, y + .03)

    # ------------------------------------------------------------------ parks
    def parks(self):
        s, pk = self.s, self.d["Parks"]
        for i, p in enumerate(LAY["parks"]):
            x0, x1, z0, z1 = p["box"]
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            grass = s.sub_res("StandardMaterial3D", albedo_color=hexcol("#0b2414"), roughness=.95)
            mesh_node(s, pk, "Lawn%d" % i, s.sub_res("BoxMesh", size=V3(x1 - x0, .34, z1 - z0)), grass, T3(cx, .17, cz))
            self.solid(pk, "LawnBody%d" % i, cx, .17, cz, x1 - x0, .34, z1 - z0)
            W.box(x0, x1, z0, z1, 0, .34)
            for z in (z0, z1):
                mesh_node(s, pk, "Edge", s.sub_res("BoxMesh", size=V3(x1 - x0 + .4, .5, .4)), s.ext_res(M("planter")), T3(cx, .25, z))
            mesh_node(s, pk, "Path", s.sub_res("BoxMesh", size=V3(x1 - x0 - 2, .04, 2.4)), s.ext_res(M("paver")), T3(cx, .36, cz))
            for o in (1.25, -1.25):
                self.glow_box(pk, "PathGlow", cx, .39, cz + o, x1 - x0 - 2, .02, .08, "green")
            for tx, tz, th in p["trees"]:
                self.tree(pk, tx, .34, tz, min(1.3, max(.8, th / 8)))
            for k in range(3):
                self.kit(pk, "bench", x0 + 4 + (x1 - x0 - 8) * (k + .5) / 3, .34, cz + 2.6, math.pi)

    # ------------------------------------------------------------------ buildings, hero towers, gateway anchors
    def tower_of(self, b, kind, crown, neon, hero, parent):
        x0, x1, z0, z1 = b["box"]
        h = b["h"]
        cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
        sh = b.get("shops")
        sides = {k: v for k, v in (sh or {}).items() if v}
        blade = [x1 + .05, cz, P2] if kind == 'res' and rng.random() < .6 else None
        bill = None
        if kind == 'com' and sides and h > 30 and rng.random() < .45:
            side = 's' if sides.get('s') else 'n' if sides.get('n') else 'e' if sides.get('e') else 'w'
            by = min(h - 9, rr(16, 30))
            bill = {'s': [cx, by, z1 + .15, 0], 'n': [cx, by, z0 - .15, math.pi], 'e': [x1 + .15, by, cz, P2], 'w': [x0 - .15, by, cz, -P2]}[side] + [int(rng.random() * 4)]
            if (w if side in 'sn' else d) < 15:
                bill = None
        if hero or h > 90:
            self.building(x0, x1, z0, z1, h * .6, kind, parent, sides or None, blade, bill)
            self.building(x0 + 1.4, x1 - 1.4, z0 + 1.4, z1 - 1.4, h * .84, kind, parent, clutter=False)
            self.building(x0 + 2.8, x1 - 2.8, z0 + 2.8, z1 - 2.8, h, kind, parent)
            tw, td = w - 5.6, d - 5.6
        else:
            self.building(x0, x1, z0, z1, h, kind, parent, sides or None, blade, bill)
            tw, td = w, d
        W.box(x0, x1, z0, z1, 0, h)
        if crown:
            self.kit(parent, "crown_a" if rng.random() < .5 else "crown_b", cx, h + .3, cz, 0, tw / 10, max(tw, td) / 10, td / 10)
        if neon:
            mesh_node(self.s, parent, "NeonEdge", self.s.sub_res("BoxMesh", size=V3(.22, h * .72, .22)), local_glow(self.s, neon), T3(x1 + .08, h * .48, z1 + .08), cast_shadow=0)
            self.pool_at(parent, x1 + 1, z1 + 1, 4, neon, .5)

    def buildings(self):
        for b in LAY["buildings"]:
            self.tower_of(b, b["kind"], b.get("crown"), NEONC.get(b.get("neon")), False, self.d["Buildings"])
        for t in LAY["towers"]:
            self.tower_of(t, 'com', True, NEONC.get(t.get("neon"), "#21e6ff"), True, self.d["Towers"])
            cx, cz = (t["box"][0] + t["box"][1]) / 2, (t["box"][2] + t["box"][3]) / 2
            mesh_node(self.s, self.d["Towers"], "TowerBeacon", self.s.sub_res("SphereMesh", radius=1.2, height=2.4), self.s.ext_res(M("glow_cyan")), T3(cx, t["beacon"], cz), cast_shadow=0)
        for a in LAY["anchors"]:
            if a.get("gate"):
                self.gate_tower(a)
            else:
                self.tower_of(a, 'com', True, "#ff2bd6", False, self.d["Towers"])

    def gate_tower(self, a):
        """Sky-bridge anchor straddling the street: four legs, the tower body starting at 24 m."""
        s, p = self.s, self.d["Towers"]
        x0, x1, z0, z1 = a["box"]
        h, y0 = a["h"], 24.0
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        s.node("GateTower", None, p, {"transform": T3(cx, 0, cz), "size": V3(x1 - x0, h, z1 - z0), "kind": 1, "elevation": y0,
                                      "seed": round(rng.random() * 100, 2)}, instance="scenes/world/props/building.tscn")
        mesh_node(s, p, "GateSoffit", s.sub_res("BoxMesh", size=V3(x1 - x0 + .6, 1.2, z1 - z0 + .6)), s.ext_res(M("roof")), T3(cx, y0 - .6, cz))
        self.glow_box(p, "GateGlowX", cx, y0 - 1.22, cz, x1 - x0 - 2, .04, .12, "magenta")
        self.glow_box(p, "GateGlowZ", cx, y0 - 1.22, cz, .12, .04, z1 - z0 - 2, "cyan")
        for x, z in ((x0 + .9, z0 + .9), (x1 - .9, z0 + .9), (x0 + .9, z1 - .9), (x1 - .9, z1 - .9)):
            leg = self.solid(p, "GateLeg", x, y0 / 2, z, 1.8, y0, 1.8)
            mesh_node(s, leg, "Mesh", s.sub_res("BoxMesh", size=V3(1.8, y0, 1.8)), s.ext_res(M("metal_dark")))
            self.glow_box(leg, "Strip", 0, 0, 0, 1.84, y0 * .8, .06, "magenta")
            W.box(x - .9, x + .9, z - .9, z + .9, 0, y0)
        W.box(x0, x1, z0, z1, y0 - 1.2, h)
        self.kit(p, "crown_a" if rng.random() < .5 else "crown_b", cx, h + .3, cz, 0, (x1 - x0) / 10, (x1 - x0) / 10, (z1 - z0) / 10)
        self.pool_at(p, cx, cz, 9, "#ff2bd6", .4)

    # ------------------------------------------------------------------ elevated routes
    def run_seg(self, parent, c, d, L, seg, y, name):
        n = math.ceil(L / seg)
        for k in range(n):
            t = -L / 2 + (k + .5) * L / n
            self.kit(parent, name, c[0] + d[0] * t, y, c[1] + d[1] * t, ryd(d), 1, 1, (L / n) / seg)

    def deck(self, parent, name, cx, cz, L, Wd, d, b, t):
        self.solid(parent, name, cx, (b + t) / 2, cz, Wd, t - b, L, ryd(d))
        W.ob(cx, cz, L, Wd, d[0], d[1], b, t)

    def lift_beside(self, parent, c, d, t0, edge, top, deck_top):
        dx, dz = d
        sx, sz = -dz, dx
        ry = ryd(d)
        for o in (edge + 3, edge + 5.5, edge + 8.5):
            for ts in (0, 4, -4, 8, -8):
                for sgn in (1, -1):
                    t = t0 + ts
                    lx, lz = c[0] + dx * t + sx * sgn * o, c[1] + dz * t + sz * sgn * o
                    if not col_clear(lx, lz, top) or in_plaza(lx, lz) or abs(lx) > BND[1] - 2 or abs(lz) > BND[3] - 2:
                        continue
                    self.lift(parent, lx, lz, top)
                    w = o - 1.6 - edge
                    lo = edge + w / 2
                    if w > .2:
                        self.landing(parent, c[0] + dx * t + sx * sgn * lo, c[1] + dz * t + sz * sgn * lo, w, 3, deck_top, ry)
                    return (sgn, t)
        return None

    def highways(self):
        s, hp = self.s, self.d["Highways"]
        for i, h in enumerate(LAY["highways"]):
            g = s.node("Highway%d" % i, "Node3D", hp)
            dx, dz = h["d"]
            sx, sz = -dz, dx
            self.run_seg(g, h["c"], h["d"], h["L"], 20, HWY, "highway_seg")
            self.deck(g, "Deck", h["c"][0], h["c"][1], h["L"], 11, h["d"], HWY - 1.2, HWY)
            for sgn in (-1, 1):
                self.deck(g, "Rail", h["c"][0] + sx * sgn * 5.25, h["c"][1] + sz * sgn * 5.25, h["L"], .6, h["d"], HWY - 1.2, HWY + 1.1)
            ons = []
            for q in h["supports"]:
                t = (q[0] - h["c"][0]) * dx + (q[1] - h["c"][1]) * dz
                ons.append((h["c"][0] + dx * t, h["c"][1] + dz * t, t))
            for x, z, _ in ons:
                self.kit(g, "highway_pylon", x, 0, z, ryd(h["d"]) + P2, 1, (HWY - 2.4) / 16.6, 1)
                self.solid(g, "PylonBody", x, (HWY - 2.4) / 2, z, 2.6, HWY - 2.4, 2.6)
                W.box(x - 1.3, x + 1.3, z - 1.3, z + 1.3, 0, HWY - 2.4)
                self.pool_at(g, x, z, 4, "#21e6ff", .35)
            ons.sort(key=lambda o: o[2])
            for q in (ons[1], ons[-2]):
                self.lift_beside(g, h["c"], h["d"], q[2] + 5, 5.5, HWY + .6, HWY)

    def bridges(self):
        s = self.s
        for i, b in enumerate(LAY["bridges"]):
            g = s.node("Bridge%d" % i, "Node3D", self.d["Bridges"])
            dx, dz = b["d"]
            sx, sz = -dz, dx
            top = b["top"]
            self.run_seg(g, b["c"], b["d"], b["L"], 10, top, "ped_bridge")
            self.deck(g, "Deck", b["c"][0], b["c"][1], b["L"], 7, b["d"], top - .5, top)
            for sgn in (-1, 1):
                self.deck(g, "Rail", b["c"][0] + sx * sgn * 3.3, b["c"][1] + sz * sgn * 3.3, b["L"] - 1, .4, b["d"], top - .5, top + .9)
            for e in (-1, 1):
                self.lift_beside(g, b["c"], b["d"], e * (b["L"] / 2 - 3), 3.5, top + .6, top)
        for i, sb in enumerate(LAY["skybridges"]):
            g = s.node("SkyBridge%d_%s" % (i, sb.get("name", "")), "Node3D", self.d["SkyBridges"])
            dx, dz = sb["d"]
            sx, sz = -dz, dx
            top = sb["top"]
            self.run_seg(g, sb["c"], sb["d"], sb["L"], 10, top, "skybridge")
            self.deck(g, "Deck", sb["c"][0], sb["c"][1], sb["L"], 7.4, sb["d"], top - .6, top)
            self.deck(g, "Roof", sb["c"][0], sb["c"][1], sb["L"], 7.4, sb["d"], top + 4.8, top + 5.3)
            ls = [self.lift_beside(g, sb["c"], sb["d"], e * (sb["L"] / 2 - 2), 3.7, top + .6, top) for e in (-1, 1)]
            # shatterable glass side walls in 5 m panels, left open where a lift landing meets the corridor
            for k in (-1, 1):
                t0 = -sb["L"] / 2
                while t0 < sb["L"] / 2 - .01:
                    t1 = min(sb["L"] / 2, t0 + 5)
                    tm, ln = (t0 + t1) / 2, t1 - t0
                    if not any(r and r[0] == k and abs(tm - r[1]) < 2.2 + ln / 2 for r in ls) and \
                            not W.sol(sb["c"][0] + dx * tm, top + 2, sb["c"][1] + dz * tm):
                        x, z = sb["c"][0] + sx * k * 3.6 + dx * tm, sb["c"][1] + sz * k * 3.6 + dz * tm
                        s.node("Glass", None, g, {"transform": T3(x, top + 2.4, z, 0, ryd(sb["d"]), 0, order="YXZ", s=(1, 1, (ln - .1) / 5))},
                               instance="scenes/world/props/glass_panel.tscn")
                        W.ob(x, z, ln, .3, dx, dz, top, top + 4.8)
                    t0 += 5
        # transit hub canopy (walkable glass roof) over the platform
        x0, x1, z0, z1 = LAY["transit_canopy"]
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        g = s.node("TransitCanopy", "Node3D", self.d["Districts"])
        mesh_node(s, g, "Roof", s.sub_res("BoxMesh", size=V3(x1 - x0, .35, z1 - z0)), s.sub_res("StandardMaterial3D", albedo_color=hexcol("#3a5a7a", .55), transparency=1, metallic=.8, roughness=.1), T3(cx, 13.6, cz))
        self.solid(g, "RoofBody", cx, 13.6, cz, x1 - x0, .4, z1 - z0)
        W.box(x0, x1, z0, z1, 13.4, 13.8)
        x = x0 + 2
        while x < x1:
            for z in (z0 + 1, z1 - 1):
                mesh_node(s, g, "Post", s.sub_res("BoxMesh", size=V3(.6, 13.6, .6)), s.ext_res(M("metal_dark")), T3(x, 6.8, z))
                self.solid(g, "PostBody", x, 6.8, z, .6, 13.6, .6)
                W.box(x - .3, x + .3, z - .3, z + .3, 0, 13.6)
            x += 8
        self.glow_box(g, "Glow", cx, 13.4, cz, x1 - x0, .08, .1, "cyan")
        mesh_node(s, g, "Platform", s.sub_res("BoxMesh", size=V3(x1 - x0 - 4, 1, 5)), s.ext_res(M("roof")), T3(cx, .5, cz))
        self.solid(g, "PlatformBody", cx, .5, cz, x1 - x0 - 4, 1, 5)
        W.box(cx - (x1 - x0 - 4) / 2, cx + (x1 - x0 - 4) / 2, cz - 2.5, cz + 2.5, 0, 1)
        self.glow_box(g, "PlatformGlow", cx, 1.01, cz + 2.45, x1 - x0 - 4, .02, .12, "orange")

    def skyport(self):
        s, g = self.s, self.d["Skyport"]
        x0, x1, z0, z1 = LAY["skyport"]["box"]
        top = LAY["skyport"]["top"]
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        self.kit(g, "skyport", cx, top, cz, 0, MAPK, 1, MAPK)
        self.solid(g, "Deck", cx, top - 1, cz, 62 * MAPK, 2, 38 * MAPK)
        W.box(cx - 31 * MAPK, cx + 31 * MAPK, cz - 19 * MAPK, cz + 19 * MAPK, top - 2, top)
        for sgn in (-1, 1):
            self.solid(g, "RailZ", cx, top - .45, cz + sgn * 18.9 * MAPK, 62 * MAPK, 3.1, .4)
            self.solid(g, "RailX", cx + sgn * 30.9 * MAPK, top - .45, cz, .4, 3.1, 38 * MAPK)
        for x in (-24 * MAPK, 0, 24 * MAPK):
            for z in (-14 * MAPK, 14 * MAPK):
                mesh_node(s, g, "Pillar", s.sub_res("BoxMesh", size=V3(2.4, top - 2, 2.4)), s.ext_res(M("concrete")), T3(cx + x, (top - 2) / 2, cz + z))
                self.solid(g, "PillarBody", cx + x, (top - 2) / 2, cz + z, 2.4, top - 2, 2.4)
                W.box(cx + x - 1.2, cx + x + 1.2, cz + z - 1.2, cz + z + 1.2, 0, top - 2)
        done = False
        for ox in (-8, 8, -18, 18, 0, -26, 26):
            for sgn in (1, -1):
                if done:
                    break
                lx, lz = cx + ox, cz + sgn * 21.6 * MAPK
                if abs(lz) > BND[3] - 2 or not col_clear(lx, lz, top + .6):
                    continue
                self.lift(g, lx, lz, top + .6)
                self.landing(g, lx, cz + sgn * 19.8 * MAPK, 2.4, 2.2, top, 0)
                done = True
        for oz in (0, -8, 8, -14, 14):
            for sgn in (-1, 1):
                if done:
                    break
                lx, lz = cx + sgn * 34.6 * MAPK, cz + oz
                if abs(lx) > BND[1] - 2 or not col_clear(lx, lz, top + .6):
                    continue
                self.lift(g, lx, lz, top + .6)
                self.landing(g, cx + sgn * 32.3 * MAPK, lz, 3.2, 2.4, top, P2)
                done = True
        self.pool_at(g, cx, cz, 30, "#8a3bff", .3)

    # ------------------------------------------------------------------ districts
    def districts(self):
        s, dg = self.s, self.d["Districts"]
        m0, m1, m2 = LAY["zones"]["Market"][:3]
        mk = s.node("Market", "Node3D", dg)
        for i in range(4):
            for j in range(2):
                x, z = m0 + 4 + i * 6.5, m2 + 5 + j * 11
                ry = math.pi if j else 0
                self.kit(mk, "market_stall", x, 0, z, ry)
                oz = -.7 if j else .7
                self.solid(mk, "StallBody", x, .525, z + oz, 3.2, 1.05, 1)
                W.box(x - 1.6, x + 1.6, z + oz - .5, z + oz + .5, 0, 1.05)
                self.pool_at(mk, x, z + oz * 2, 3, pick(["#ff2bd6", "#21e6ff", "#ff9a3c", "#8a3bff"]), .6)
        self.sign(mk, pick(SHOP_SIGNS), m0 + 14, 6.5, m2 + .2, 10, 2.5, 0, pick(NEON))
        # rooftop arena: a 10 m block with parapets, barriers and lifts at both ends
        x0, x1, z0, z1 = LAY["zones"]["Rooftop"]
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        ra = s.node("RooftopArena", "Node3D", dg)
        self.building(x0, x1, z0, z1, 10, 'res', ra)
        W.box(x0, x1, z0, z1, 0, 10)
        for sgn in (-1, 1):
            z = cz + sgn * ((z1 - z0) / 2 - .35)
            mesh_node(s, ra, "Parapet", s.sub_res("BoxMesh", size=V3(x1 - x0, 1.2, .7)), s.ext_res(M("roof")), T3(cx, 10.9, z))
            self.solid(ra, "ParapetBody", cx, 10.9, z, x1 - x0, 1.2, .7)
            self.glow_box(ra, "ParapetGlow", cx, 11.52, z, x1 - x0, .03, .72, "magenta")
        for c0, c1, w, d in LAY["covers"]:
            if x0 < c0 < x1 and z0 < c1 < z1:
                self.barrier(ra, c0, c1, P2 if d > w else 0.0, 10.0)
        self.lift(ra, x0 - 2.6, cz, 10.6)
        self.lift(ra, x1 + 2.6, cz, 10.6)
        for c0, c1, w, d in LAY["covers"]:
            for k in ("Market", "Transit"):
                a, b, e, f = LAY["zones"][k]
                if a < c0 < b and e < c1 < f:
                    self.barrier(self.d["Cover"], c0, c1, P2 if d > w else 0.0)
        # billboards from the blockout
        for i, sg in enumerate(LAY["signs"]):
            ry = ryd(sg["d"]) - P2
            h, w = sg["y1"] - sg["y0"], sg["L"]
            t1, t2, a, c = ADS[i % 4]
            self.s.node("Billboard", None, self.d["Signs"], {"transform": T3(sg["c"][0], (sg["y0"] + sg["y1"]) / 2, sg["c"][1], 0, ry, 0, order="YXZ"),
                                                             "size": V2(w, h), "title": t1, "slogan": t2, "color_a": hexcol(a), "color_b": hexcol(c)},
                        instance="scenes/world/props/billboard.tscn")
        # spawn beacons (decorative launch-pad rings at the four drop points)
        for x, z in LAY["spawns"]:
            self.kit(dg, "launch_pad", x, 0, z, nm="SpawnBeacon")
            self.pool_at(dg, x, z, 5, "#2f8bff", .6)

    def street_props(self):
        sp = self.d["StreetProps"]
        for r in LAY["roads"]:
            dx, dz = r["d"]
            sx, sz = -dz, dx
            for k in range(int(r["L"] // 30)):
                t = -r["L"] / 2 + 15 + k * 30
                for sgn in (-1, 1):
                    x, z = r["c"][0] + dx * t + sx * sgn * (r["W"] / 2 + 1.2), r["c"][1] + dz * t + sz * sgn * (r["W"] / 2 + 1.2)
                    if in_plaza(x, z) or in_road(x, z, -.4) or W.sol(x, 1, z) or any(math.hypot(q[0] - x, q[1] - z) < 3.5 for q in self.lifts):
                        continue
                    self.kit(sp, "street_lamp", x, 0, z, math.atan2(-sx * sgn, -sz * sgn))
                    self.solid(sp, "LampBody", x, 3.7, z, .3, 7.4, .3)
                    W.box(x - .3, x + .3, z - .3, z + .3, 0, 7.4)
                    self.pool_at(sp, x - sx * sgn * 2.2, z - sz * sgn * 2.2, 6, "#21e6ff" if sgn < 0 else "#ff2bd6", .55)

    def vehicles(self):
        vg = self.d["Vehicles"]
        placed = []

        def in_other(x, z, r):
            for q in LAY["roads"]:
                if q is r:
                    continue
                px, pz = x - q["c"][0], z - q["c"][1]
                if abs(px * q["d"][0] + pz * q["d"][1]) <= q["L"] / 2 + 2 and abs(-px * q["d"][1] + pz * q["d"][0]) <= q["W"] / 2 + 2:
                    return True
            return False

        def foot_ok(cx, cz, L, Wd, ry, r, gap):
            c, sn = math.cos(ry), math.sin(ry)
            a = -L / 2
            while a <= L / 2 + .01:
                b = -Wd / 2
                while b <= Wd / 2 + .01:
                    x, z = cx + a * c + b * sn, cz - a * sn + b * c
                    if W.sol(x, .4, z) or W.sol(x, 2.2, z) or in_plaza(x, z, 1) or abs(x) > BND[1] - 3 or abs(z) > BND[3] - 3 or in_other(x, z, r):
                        return False
                    b += .6
                a += .6
            return not any(math.hypot(q[0] - cx, q[1] - cz) < L / 2 + 3.5 for q in self.lifts) and \
                not any(math.hypot(q[0] - cx, q[1] - cz) < (q[2] + L) / 2 + gap for q in placed)

        along = lambda r, t, off, sgn: (r["c"][0] + r["d"][0] * t - r["d"][1] * sgn * off, r["c"][1] + r["d"][1] * t + r["d"][0] * sgn * off)
        ships = 0
        tints = ["orange", "blue", "pink"]
        for n in range(900):
            if ships >= 10:
                break
            r = LAY["roads"][n % len(LAY["roads"])]
            t = rr(-r["L"] / 2 + 14, r["L"] / 2 - 14)
            sgn = 1 if n % 2 else -1
            x, z = along(r, t, r["W"] / 2 - 2.05, sgn)
            ry = math.atan2(-r["d"][1], r["d"][0]) + (math.pi if sgn > 0 else 0) + rr(-.04, .04)
            if not foot_ok(x, z, 5.4, 6.8, ry, r, 6):
                continue
            tint = tints[(ships >> 1) % 3] if ships % 2 else "stock"
            self.s.node("Spacecraft", None, vg, {"transform": T3(x, 0, z, 0, ry, 0, order="YXZ"), "light_tint": tint}, instance="scenes/world/props/spacecraft.tscn")
            placed.append((x, z, 5.4))
            ships += 1
            W.ob(x, z, 5.2, 3.4, math.sin(ry + P2), math.cos(ry + P2), 0, 2.2)
        bikes = 0
        for n in range(900):
            if bikes >= 14:
                break
            r = LAY["roads"][(n * 3 + 1) % len(LAY["roads"])]
            t0 = rr(-r["L"] / 2 + 10, r["L"] / 2 - 10)
            sgn = 1 if n % 2 else -1
            cnt, ang = 1 + n % 3, rr(.55, .9)
            for j in range(cnt):
                if bikes >= 14:
                    break
                t = t0 + j * 1.3
                sx, sz = -r["d"][1] * sgn, r["d"][0] * sgn
                vx = r["d"][0] * math.cos(ang) - sx * math.sin(ang)
                vz = r["d"][1] * math.cos(ang) - sz * math.sin(ang)
                ry = math.atan2(-vz, vx)
                x, z = along(r, t, r["W"] / 2 - .3 - 1.05 * math.sin(ang), sgn)
                if not foot_ok(x, z, 2.2, .8, ry, r, .35):
                    break
                self.s.node("Motorcycle", None, vg, {"transform": T3(x, 0, z, 0, ry, 0, order="YXZ"), "red": bikes % 2 == 1}, instance="scenes/world/props/motorcycle.tscn")
                placed.append((x, z, 2.2))
                bikes += 1

    def launch_pads(self):
        """Pads that throw you onto two sky-bridge roofs, the Spire podium and the transit canopy."""
        tv = self.d["Traversal"]

        def roof_pt(sb, p):
            best, bd = None, 1e9
            t = -sb["L"] / 2 + 5
            while t < sb["L"] / 2 - 5:
                x, z, y = sb["c"][0] + sb["d"][0] * t, sb["c"][1] + sb["d"][1] * t, sb["top"] + 5.3
                if not (W.sol(x, y + .4, z) or W.sol(x, y + 1.8, z)) and W.sol(x, y - .2, z):
                    d = math.hypot(x - p[0], z - p[1])
                    if d < bd:
                        bd, best = d, (x, y, z)
                t += 1
            return best or (p[0], sb["top"] + 5.3, p[1])

        def arc_clear(x, z, tx, ty, tz):
            g = 26.0
            vy = math.sqrt(2 * g * (ty + PAD_APEX))
            tf = vy / g + math.sqrt(2 * PAD_APEX / g)
            if not col_clear(x, z, 1.5):
                return False
            t = .02
            while t < tf - .05:
                u = t / tf
                px, pz, py = x + (tx - x) * u, z + (tz - z) * u, vy * t - 13 * t * t
                for h in (-.6, .2, 1, 2.1):
                    for oa, ob in ((0, 0), (.5, .5), (-.5, -.5), (.5, -.5), (-.5, .5)):
                        if W.sol(px + oa, py + h, pz + ob) and not (t > tf - .12 and h < 0):
                            return False
                t += .024
            return True

        targets = [roof_pt(LAY["skybridges"][0], LAY["pads"][0]), roof_pt(LAY["skybridges"][1], LAY["pads"][1]),
                   (-10, 12.8, 10.5), (38 * MAPK, 14, 19 * MAPK)]
        for tx, ty, tz in targets:
            done = False
            for strict in (True, False):
                for R in ((12, 14, 16, 18, 22, 26, 30, 34, 38, 42) if strict else (12, 14, 16, 18)):
                    for k in range(16):
                        if done:
                            break
                        a = k / 16 * math.tau + .2
                        x, z = tx + math.cos(a) * R, tz + math.sin(a) * R
                        if abs(x) < BND[1] - 3 and abs(z) < BND[3] - 3 and (not strict or not in_plaza(x, z, -8)) and arc_clear(x, z, tx, ty, tz):
                            self.s.node("LaunchPad", None, tv, {"transform": T3(x, 0, z), "target": V3(tx, ty, tz)}, instance="scenes/world/props/launch_pad.tscn")
                            done = True
                if done:
                    break
            if not done:
                print("  no launch spot for target", (tx, ty, tz))

    def bay(self):
        b = self.d["Bay"]
        for m in LAY["mountains"]:
            L = math.hypot(m["c"][0], m["c"][1]) or 1
            x, z = m["c"][0] + m["c"][0] / L * 45, m["c"][1] + m["c"][1] / L * 45
            big = m["h"] > 30
            self.kit(b, "rock_0" if abs(x) % 2 < 1 else "rock_1", x, -4.5, z, rng.random() * 6, m["r"] * 1.1, (m["h"] * 1.9 if big else m["h"] * 1.2) + 4.5, m["r"] * 1.1, nm="Mountain")

    def cargo(self):
        """v74's crate stacks, skipping cells that now collide with the city or sit on lifts / the plaza core."""
        rng2 = random.Random(7)
        for x, z, w, d, h in ((-24, 14, 3, 2, 3), (-16, 22, 2, 2, 4), (-28, 10, 2, 2, 2), (13, 13, 3, 2, 3), (22, 22, 2, 3, 4), (14, 26, 3, 2, 2), (30, 30, 2, 2, 3),
                              (22, -26, 2, 2, 2), (-10, -20, 2, 2, 3), (2, -28, 1, 2, 2), (-4, -40, 1, 1, 2), (-6, 26, 1, 1, 2), (4, 40, 1, 1, 2), (-36, -2, 1, 2, 2), (36, 2, 1, 1, 3)):
            stack = self.s.node("Stack", "Node3D", self.d["CargoBlocks"])
            for a in range(w):
                for b in range(d):
                    wx, wz = (x + a) * 2 + 1, (z + b) * 2 + 1
                    if W.sol(wx, .5, wz) or W.sol(wx - 1, .5, wz - 1) or W.sol(wx + 1, .5, wz + 1) or math.hypot(wx, wz) < 19 or \
                            any(math.hypot(q[0] - wx, q[1] - wz) < 4 for q in self.lifts):
                        continue
                    for y in range(h):
                        r = rng2.random()
                        self.s.node("Block", None, stack, {"transform": T3(wx, y * 2 + 1, wz), "variant": 0 if r < .86 else (1 if r < .93 else 2)},
                                    instance="scenes/world/props/crate_block.tscn")

    def prime_world(self):
        """Register every elevated deck in the solid model up front, so lifts placed for one route don't end up under another."""
        for h in LAY["highways"]:
            W.ob(h["c"][0], h["c"][1], h["L"], 11, h["d"][0], h["d"][1], HWY - 1.2, HWY + 1.1)
        for b in LAY["bridges"]:
            W.ob(b["c"][0], b["c"][1], b["L"], 7, b["d"][0], b["d"][1], b["top"] - .5, b["top"] + .9)
        for b in LAY["skybridges"]:
            W.ob(b["c"][0], b["c"][1], b["L"], 7.4, b["d"][0], b["d"][1], b["top"] - .6, b["top"])
            W.ob(b["c"][0], b["c"][1], b["L"], 7.4, b["d"][0], b["d"][1], b["top"] + 4.8, b["top"] + 5.3)
        x0, x1, z0, z1 = LAY["transit_canopy"]
        W.box(x0, x1, z0, z1, 13.4, 13.8)
        x0, x1, z0, z1 = LAY["zones"]["Rooftop"]
        W.box(x0, x1, z0, z1, 0, 12.1)
        m0, m1, m2 = LAY["zones"]["Market"][:3]
        W.box(m0 + 2, m0 + 26, m2 + 3, m2 + 18, 0, 3)
        x0, x1, z0, z1 = LAY["skyport"]["box"]
        cx, cz, top = (x0 + x1) / 2, (z0 + z1) / 2, LAY["skyport"]["top"]
        W.box(cx - 31 * MAPK, cx + 31 * MAPK, cz - 19 * MAPK, cz + 19 * MAPK, top - 2, top + 2.6)

    def save(self):
        self.prime_world()
        self.ground()
        self.plaza()
        self.parks()
        self.buildings()
        self.highways()
        self.bridges()
        self.skyport()
        self.districts()
        self.roads()
        self.street_props()
        self.vehicles()
        self.launch_pads()
        self.bay()
        self.cargo()
        self.s.save("scenes/world/arena.tscn")
        print("lifts:", len(self.lifts))


# ------------------------------------------------------------------ prop scenes used above
def prop_scenes():
    # road segment
    s = Scene("Road", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/road.gd")
    loc = dict(resource_local_to_scene=True)
    mesh_node(s, ".", "Asphalt", s.sub_res("PlaneMesh", size=V2(13.77, 40), **loc),
              s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/road.gdshader"), **loc), cast_shadow=0)
    for tag in ("L", "R"):
        mesh_node(s, ".", "Kerb" + tag, s.sub_res("BoxMesh", size=V3(.24, .14, 40), **loc), s.ext_res(M("roof")))
        mesh_node(s, ".", "KerbGlow" + tag, s.sub_res("BoxMesh", size=V3(.06, .02, 40), **loc), s.ext_res(M("glow_violet")), cast_shadow=0)
        mesh_node(s, ".", "Walk" + tag, s.sub_res("BoxMesh", size=V3(3.5, .12, 40), **loc), s.ext_res(M("paver")))
    s.save("scenes/world/props/road.tscn")
    # gravity lift
    s = Scene("Lift", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/lift.gd")
    s.node("Pad", None, ".", {}, instance="assets/models/kit/lift.glb")
    mesh_node(s, ".", "Beam", s.sub_res("CylinderMesh", top_radius=1.35, bottom_radius=1.35, height=20, radial_segments=24, cap_top=False, cap_bottom=False, **loc),
              s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/lift_beam.gdshader"), **loc), T3(0, 10, 0), cast_shadow=0)
    pool(s, ".", "Pool", "#21e6ff", 3.2, .6)
    s.save("scenes/world/props/lift.tscn")
    # launch pad
    s = Scene("LaunchPad", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/launch_pad.gd")
    s.node("Pad", None, ".", {}, instance="assets/models/kit/launch_pad.glb")
    pool(s, ".", "Pool", "#2f8bff", 3, .6)
    s.save("scenes/world/props/launch_pad.tscn")
    # glass panel (5 m sky-bridge window)
    s = Scene("GlassPanel", "StaticBody3D", {"collision_mask": 0})
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/glass_panel.gd")
    mesh_node(s, ".", "Mesh", s.sub_res("BoxMesh", size=V3(.05, 4.8, 5)),
              s.sub_res("StandardMaterial3D", transparency=1, albedo_color=hexcol("#8fd8ff", .26), metallic=.1, roughness=.04, clearcoat_enabled=True), cast_shadow=0)
    s.node("Shape", "CollisionShape3D", ".", {"shape": s.sub_res("BoxShape3D", size=V3(.3, 4.8, 5))})
    s.save("scenes/world/props/glass_panel.tscn")
    # glass shards burst
    s = Scene("GlassShards", "Node3D")
    s.nodes[0][3].update({"script": s.ext_res("scripts/fx/one_shot_fx.gd"), "lifetime": 2.4})
    pm = s.sub_res("ParticleProcessMaterial", emission_shape=3, emission_box_extents=V3(.05, 2.4, 2.5), direction=V3(1, .3, 0), spread=180.0,
                   initial_velocity_min=.5, initial_velocity_max=3.0, gravity=V3(0, -26, 0), color=hexcol("#bfeaff"),
                   color_ramp=s.sub_res("GradientTexture1D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.7, 1)"),
                                                                                colors=Raw("PackedColorArray(1, 1, 1, 0.9, 1, 1, 1, 0.6, 1, 1, 1, 0)"))))
    s.node("Shards", "GPUParticles3D", ".", {"emitting": False, "amount": 220, "lifetime": 2.2, "one_shot": True, "explosiveness": 1.0, "process_material": pm,
                                             "draw_pass_1": s.sub_res("QuadMesh", size=V2(.07, .07)), "material_override": s.ext_res(M("fx_glow_particle")),
                                             "cast_shadow": 0, "visibility_aabb": Raw("AABB(-8, -8, -8, 16, 16, 16)")})
    s.save("scenes/fx/glass_shards.tscn")
    # parked spacecraft (v74 SHIP_S = 0.18) with tintable LED strip
    s = Scene("Spacecraft", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/spacecraft.gd")
    s.node("Model", None, ".", {"transform": T3(s=.18)}, instance="assets/models/vehicles/ship.glb")
    static_box(s, ".", "Hull", V3(3.4, 2.2, 5.2), T3(0, 1.1, 0, 0, P2, 0))
    static_box(s, ".", "Fins", V3(6.7, 2.0, 1.1), T3(-1.5, 1.0, 0, 0, P2, 0))
    pool(s, ".", "Pool", "#ff9a3c", 4.2, .5)
    s.save("scenes/world/props/spacecraft.tscn")
    # motorcycle (v74 MOTO_S = 0.41), black or red clearcoat paint
    s = Scene("Motorcycle", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/motorcycle.gd")
    s.node("Model", None, ".", {"transform": T3(s=.41)}, instance="assets/models/vehicles/moto.glb")
    static_box(s, ".", "Body", V3(2.1, 1.0, .7), T3(0, .5, 0))
    s.save("scenes/world/props/motorcycle.tscn")
    # floating planet in the sky
    s = Scene("Planet", "Node3D")
    mesh_node(s, ".", "Globe", s.sub_res("SphereMesh", radius=80, height=160, radial_segments=64, rings=32),
              s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/planet.gdshader")), cast_shadow=0)
    mesh_node(s, ".", "Atmosphere", s.sub_res("SphereMesh", radius=86, height=172, radial_segments=48, rings=24),
              s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/planet_rim.gdshader")), cast_shadow=0)
    s.nodes[-1][3]["script"] = s.ext_res("scripts/world/props/spinner.gd")
    s.save("scenes/world/props/planet.tscn")


def build_arena_ncc():
    prop_scenes()
    NCC().save()


if __name__ == "__main__":
    build_arena_ncc()
    print("ncc arena ok")
