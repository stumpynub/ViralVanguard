"""The Neo-Kairo match arena, laid out from the original city generator as plain editable nodes.
Central Spire plaza at the origin, Residential NW, Commercial NE, Industrial SW, Docks SE, harbor water past the
east and south quays; north is -Z (the player spawns at z = 70 facing it)."""
import math, random
from godot_writer import *
from build_props import mesh_node, static_box, pool

P2 = math.pi / 2
M = lambda n: "assets/materials/%s.tres" % n
rng = random.Random(90210)
rr = lambda a, b: a + (b - a) * rng.random()
pick = lambda a: a[int(rng.random() * len(a))]

SHOP_SIGNS = ['NOODLES', 'HOTEL', 'SYNTH', 'RAMEN', 'CYBER BAR', '24/7', 'CLINIC', 'ARCADE', 'SUSHI', 'PAWN', 'TECH', 'CAFE', 'OPEN', 'CLUB',
              'MOTEL', 'DATA', 'VR DEN', 'PHARMA', 'LOUNGE', 'GYM', 'DINER', 'FIX-IT', 'BIO', 'KARAOKE']
BLADE_SIGNS = ['HOTEL', 'RAMEN', 'BAR', 'NEON', 'CLUB', 'BYTES', 'LIVE', 'SUSHI', 'OPEN', 'SYNC', 'CAFE', 'BOTS']
NEON = ['#ff2bd6', '#21e6ff', '#ff9a3c', '#8a3bff', '#2f8bff', '#14b8a6', '#ff3355']
ADS = [('AURORA SYSTEMS', 'THINK FASTER', '#21e6ff', '#8a3bff'), ('VOLT COLA', 'CHARGE UP', '#ff2bd6', '#ff9a3c'),
       ('DREAM//OS', 'SLEEP IS OPTIONAL', '#8a3bff', '#21e6ff'), ('NEO-KAIRO', 'NIGHT NEVER ENDS', '#ff2bd6', '#2f8bff')]
KIND = {'res': 0, 'com': 1, 'ind': 2}


class Arena:
    def __init__(self):
        s = self.s = Scene("Arena", "Node3D")
        s.nodes[0][3]["script"] = s.ext_res("scripts/world/arena.gd")
        self.env()
        s.node("PlayerSpawn", "Marker3D", ".", {"transform": T3(0, 0.1, 70)})
        self.city = s.node("City", "Node3D", ".")
        s.node("Enemies", "Node3D", ".")
        s.node("FX", "Node3D", ".")
        self.d = {k: s.node(k, "Node3D", self.city) for k in
                  ("Streets", "Plaza", "Residential", "Commercial", "Industrial", "Docks", "StreetProps", "Cover", "CargoBlocks", "Skyline", "Maglev", "Signs")}

    # ------------------------------------------------------------ environment and light
    def env(self):
        s = self.s
        sky_mat = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/sky.gdshader"))
        env = s.sub_res("Environment", background_mode=2, sky=s.sub_res("Sky", sky_material=sky_mat), ambient_light_source=2,
                        ambient_light_color=hexcol("#6a6cd8"), ambient_light_energy=1.1, tonemap_mode=3, tonemap_exposure=1.05,
                        glow_enabled=True, glow_intensity=0.7, glow_strength=1.0, glow_bloom=0.05, glow_blend_mode=1, glow_hdr_threshold=0.9,
                        **{"glow_levels/1": 1.0, "glow_levels/2": 1.0, "glow_levels/3": 1.0, "glow_levels/5": 0.6},
                        fog_enabled=True, fog_light_color=hexcol("#140f38"), fog_density=0.0075, fog_sky_affect=0.25, fog_aerial_perspective=0.2)
        s.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env})
        moon = s.node("Moon", "DirectionalLight3D", ".", {"transform": Raw(self._look((40, 80, -60), (0, 0, 0))), "light_color": hexcol("#9aa8ff"),
                                                         "light_energy": 0.45, "shadow_enabled": True, "directional_shadow_max_distance": 140.0})
        lights = s.node("DistrictLights", "Node3D", ".")
        for c, x, y, z, name in (("#ff2bd6", -52, 14, -52, "Residential"), ("#21e6ff", 52, 16, -52, "Commercial"), ("#ff9a3c", -52, 12, 52, "Industrial"),
                                 ("#14b8a6", 52, 12, 52, "Docks"), ("#8a3bff", 0, 24, 0, "Spire")):
            s.node(name, "OmniLight3D", lights, {"transform": T3(x, y, z), "light_color": hexcol(c), "light_energy": 6.0, "omni_range": 115.0, "omni_attenuation": 1.4})

    @staticmethod
    def _look(eye, target):
        ex, ey, ez = eye
        f = [target[i] - eye[i] for i in range(3)]
        l = math.sqrt(sum(x * x for x in f)); f = [x / l for x in f]
        z = [-x for x in f]                        # Godot looks down -Z
        up = (0, 1, 0)
        x = [up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0]]
        l = math.sqrt(sum(v * v for v in x)); x = [v / l for v in x]
        y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
        vals = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2], ex, ey, ez]
        return "Transform3D(" + ", ".join(num(v) for v in vals) + ")"

    # ------------------------------------------------------------ kit
    def inst(self, parent, name, scene, t, **props):
        props = dict(props)
        props["transform"] = t
        return self.s.node(name, None, parent, props, instance="scenes/world/props/%s.tscn" % scene)

    def sign(self, parent, text, x, y, z, w, h, ry, color, vertical=False):
        return self.inst(parent, "Sign_" + "".join(c for c in text.title() if c.isalnum())[:14], "neon_sign", T3(x, y, z, 0, ry, 0),
                         text=text, size=V2(w, h), color=hexcol(color), vertical=vertical)

    def building(self, x0, x1, z0, z1, h, kind, district, shops=None, blade=None, bill=None, solid=True, clutter=True):
        s = self.s
        b = self.inst(district, "Building", "building", T3((x0 + x1) / 2, 0, (z0 + z1) / 2), size=V3(x1 - x0, h, z1 - z0), kind=KIND[kind],
                      shops=bool(shops), solid=solid, seed=round(rng.random() * 100, 2), rooftop_clutter=clutter)
        if shops:
            sides = shops

            def edge(ax, az, bx, bz, ry, ox, oz):
                L = math.hypot(bx - ax, bz - az)
                t = 2.0
                while t < L - 2:
                    w = min(rr(2.6, 4), L - t - 1)
                    cx = ax + (bx - ax) * (t + w / 2) / L
                    cz = az + (bz - az) * (t + w / 2) / L
                    if rng.random() < .75:
                        self.inst(district, "Awning", "awning", T3(cx + ox * .02, 3.75, cz + oz * .02, 0, ry, 0, s=(w, 1, 1)), glow=hexcol(pick(NEON[:4])), paint=hexcol(pick(NEON[:4]), 1, .35))
                    if rng.random() < .6:
                        self.sign(self.d["Signs"], pick(SHOP_SIGNS), cx + ox * .1, 5.6, cz + oz * .1, w * .95, w * .24, ry, pick(NEON))
                    t += rr(4.5, 7) + w
            if sides.get('s'): edge(x0, z1 + .02, x1, z1 + .02, 0, 0, 1)
            if sides.get('n'): edge(x1, z0 - .02, x0, z0 - .02, math.pi, 0, -1)
            if sides.get('e'): edge(x1 + .02, z1, x1 + .02, z0, P2, 1, 0)
            if sides.get('w'): edge(x0 - .02, z0, x0 - .02, z1, -P2, -1, 0)
        if blade:
            sx, sz, ry = blade
            self.sign(self.d["Signs"], pick(BLADE_SIGNS), sx, rr(8, max(9, h - 6)), sz, 1.5, 6, ry, pick(NEON), vertical=True)
        if bill:
            bx, by, bz, ry, i = bill
            t1, t2, a, c = ADS[i]
            self.inst(self.d["Signs"], "Billboard", "billboard", T3(bx, by, bz, 0, ry, 0), title=t1, slogan=t2, color_a=hexcol(a), color_b=hexcol(c))
        return b

    # ------------------------------------------------------------ streets, plaza, spire
    def streets(self):
        s, st = self.s, self.d["Streets"]
        g = s.node("Ground", "StaticBody3D", st, {"collision_mask": 0})
        mesh_node(s, g, "Asphalt", s.sub_res("PlaneMesh", size=V2(500, 500), subdivide_width=4, subdivide_depth=4), s.ext_res(M("ground")), T3(92 - 250, 0, 92 - 250))
        s.node("Plane", "CollisionShape3D", g, {"shape": s.sub_res("WorldBoundaryShape3D")})
        water = s.ext_res(M("water"))
        wm = s.sub_res("PlaneMesh", size=V2(600, 600))
        mesh_node(s, st, "HarborEast", wm, water, T3(92 + 300, -.6, 92), cast_shadow=0)
        mesh_node(s, st, "HarborSouth", wm, water, T3(-300 + 92, -.6, 92 + 300), cast_shadow=0)
        # harbor edge: walls you can't walk off
        static_box(s, st, "QuayWallEast", V3(4, 6, 200), T3(90, 3, -4), 1)
        static_box(s, st, "QuayWallSouth", V3(200, 6, 4), T3(-4, 3, 90), 1)
        mesh_node(s, st, "QuayEast", s.sub_res("BoxMesh", size=V3(4, .12, 192)), s.ext_res(M("concrete")), T3(90, .06, -4))
        mesh_node(s, st, "QuaySouth", s.sub_res("BoxMesh", size=V3(192, .12, 4)), s.ext_res(M("concrete")), T3(-4, .06, 90))
        mesh_node(s, st, "QuayGlowEast", s.sub_res("BoxMesh", size=V3(.1, .06, 192)), s.ext_res(M("glow_teal")), T3(90, .14, -4), cast_shadow=0)
        mesh_node(s, st, "QuayGlowSouth", s.sub_res("BoxMesh", size=V3(192, .06, .1)), s.ext_res(M("glow_teal")), T3(-4, .14, 90), cast_shadow=0)
        # outer playfield fence on the land sides (north / west)
        static_box(s, st, "BoundaryNorth", V3(200, 30, 2), T3(0, 15, -90), 1)
        static_box(s, st, "BoundaryWest", V3(2, 30, 200), T3(-90, 15, 0), 1)
        # sidewalks along the boulevard and avenue
        RW, PR, EDGE = 10, 26, 96
        walks = s.node("Sidewalks", "StaticBody3D", st, {"collision_mask": 0})
        paver = s.ext_res(M("paver"))
        k = 0
        for sgn in (-1, 1):
            a0, a1 = (RW, RW + 4) if sgn > 0 else (-RW - 4, -RW)
            for (x0, x1, z0, z1) in ((a0, a1, -EDGE, -PR), (a0, a1, PR, EDGE), (-EDGE, -PR, a0, a1), (PR, EDGE, a0, a1)):
                size = V3(x1 - x0, .12, z1 - z0)
                t = T3((x0 + x1) / 2, .06, (z0 + z1) / 2)
                mesh_node(s, walks, "Walk%d" % k, s.sub_res("BoxMesh", size=size), paver, t)
                s.node("Shape%d" % k, "CollisionShape3D", walks, {"transform": t, "shape": s.sub_res("BoxShape3D", size=size)})
                k += 1
        # arrows pointing at the plaza
        arrow = s.sub_res("BoxMesh", size=V3(.25, .02, 1.8))
        for cx, cz in ((0, -62), (0, 62), (-62, 0), (62, 0)):
            ax = (cx > 0) - (cx < 0); az = (cz > 0) - (cz < 0)
            ry = math.atan2(-ax, -az)
            for i in range(3):
                for l in (-1, 1):
                    px, pz = cx - ax * i * 2.2, cz - az * i * 2.2
                    ox, oz = l * .55 * math.cos(ry), -l * .55 * math.sin(ry)
                    mesh_node(s, st, "Arrow", arrow, s.ext_res(M("glow_orange")), T3(px + ox, .03, pz + oz, 0, ry + l * .75, 0), cast_shadow=0)

    def centre(self):
        s, pz = self.s, self.d["Plaza"]
        self.inst(pz, "Plaza", "plaza", T3())
        self.inst(pz, "Spire", "spire", T3())
        self.inst(pz, "RingWalkway", "ring_walkway", T3())
        for sx in (-1, 1):
            for sz in (-1, 1):
                self.inst(pz, "StairTower", "stair_tower", T3(sx * 23, 0, sz * 22, 0, 0 if sz > 0 else math.pi, 0))

    # ------------------------------------------------------------ districts (exact footprints from the original)
    def districts(self):
        R, C, I, D = self.d["Residential"], self.d["Commercial"], self.d["Industrial"], self.d["Docks"]
        b = self.building
        b(-88, -68, -88, -62, 36, 'res', R, {'e': 1, 's': 1}, blade=[-67.9, -74, P2])
        b(-60, -42, -88, -70, 30, 'res', R, {'s': 1, 'e': 1}, blade=[-42, -78, P2])
        b(-88, -70, -54, -34, 24, 'res', R, {'e': 1, 's': 1})
        b(-60, -42, -60, -40, 20, 'res', R, {'s': 1, 'e': 1, 'n': 1}, blade=[-50, -39.9, 0])
        b(-34, -20, -88, -74, 32, 'res', R, {'e': 1, 's': 1, 'w': 1})
        b(-34, -22, -64, -44, 16, 'res', R, {'e': 1, 's': 1, 'w': 1})
        b(-34, -25, -36, -25, 12, 'res', R, {'e': 1, 's': 1, 'n': 1})
        b(-88, -72, -26, -18, 12, 'res', R, {'e': 1, 'n': 1, 's': 1})
        b(-62, -48, -28, -18, 14, 'res', R, {'s': 1, 'n': 1, 'e': 1})
        b(24, 48, -88, -70, 40, 'com', C, {'s': 1, 'w': 1, 'e': 1}, bill=[36, 24, -69.85, 0, 1])
        b(56, 88, -88, -66, 46, 'com', C, {'s': 1, 'w': 1}, bill=[72, 26, -65.85, 0, 3])
        b(70, 88, -54, -30, 28, 'com', C, {'w': 1, 's': 1}, bill=[69.85, 16, -42, -P2, 0])
        b(30, 44, -28, -18, 8, 'com', C, {'s': 1, 'w': 1, 'e': 1, 'n': 1})
        b(48, 62, -50, -36, 18, 'com', C, {'s': 1, 'w': 1, 'e': 1, 'n': 1})
        b(-88, -62, 60, 88, 18, 'ind', I); b(-44, -28, 70, 88, 13, 'ind', I); b(-88, -76, 18, 28, 10, 'ind', I); b(-50, -36, 40, 52, 9, 'ind', I)
        b(60, 88, 16, 36, 13, 'ind', D, {'w': 1}); b(40, 52, 56, 70, 10, 'ind', D, {'w': 1, 'n': 1})
        s = self.s
        # industrial: storage tanks, smokestacks, pipe rack
        for x, z in ((-70, 36), (-70, 50)):
            self.inst(I, "StorageTank", "storage_tank", T3(x, 0, z))
        for x, z in ((-80, 72), (-68, 80)):
            st = s.node("Smokestack", "Node3D", I, {"transform": T3(x, 18, z)})
            mesh_node(s, st, "Stack", s.sub_res("CylinderMesh", top_radius=1.6, bottom_radius=1.6, height=16, radial_segments=16), s.ext_res(M("tank")), T3(0, 8, 0))
            mesh_node(s, st, "Warning", s.sub_res("BoxMesh", size=V3(3.25, .25, 3.25)), s.ext_res(M("glow_red")), T3(0, 15.6, 0), cast_shadow=0)
        rack = s.node("PipeRack", "Node3D", I)
        mesh_node(s, rack, "Pipe", s.sub_res("CylinderMesh", top_radius=.5, bottom_radius=.5, height=48, radial_segments=12), s.ext_res(M("metal_mid")), T3(-56, 7.4, 57, 0, 0, P2))
        mesh_node(s, rack, "HotPipe", s.sub_res("CylinderMesh", top_radius=.35, bottom_radius=.35, height=48, radial_segments=12), s.ext_res(M("pipe_rust")), T3(-56, 8.6, 57, 0, 0, P2))
        post = s.sub_res("BoxMesh", size=V3(.4, 8, .4)); beam = s.sub_res("BoxMesh", size=V3(.4, .4, 2.4))
        for x in range(-80, -31, 12):
            mesh_node(s, rack, "Post", post, s.ext_res(M("metal_dark")), T3(x, 4, 57))
            mesh_node(s, rack, "Beam", beam, s.ext_res(M("metal_dark")), T3(x, 8, 57))
        # docks: gantry crane, mooring bollards, pier
        cr = s.node("Crane", "Node3D", D, {"transform": T3(72, 0, 66)})
        paint = s.ext_res(M("crane_paint"))
        for a, c in ((-5, -5), (5, -5), (-5, 5), (5, 5)):
            leg = s.node("Leg", "StaticBody3D", cr, {"transform": T3(a, 0, c), "collision_mask": 0})
            mesh_node(s, leg, "Mesh", s.sub_res("BoxMesh", size=V3(.9, 26, .9)), paint, T3(0, 13, 0))
            s.node("Shape", "CollisionShape3D", leg, {"transform": T3(0, 13, 0), "shape": s.sub_res("BoxShape3D", size=V3(1.2, 26, 1.2))})
        mesh_node(s, cr, "Deck", s.sub_res("BoxMesh", size=V3(11, 1.4, 11)), paint, T3(0, 26.6, 0))
        mesh_node(s, cr, "Boom", s.sub_res("BoxMesh", size=V3(46, 1.4, 2)), paint, T3(12, 28.4, 0))
        mesh_node(s, cr, "Counterweight", s.sub_res("BoxMesh", size=V3(9, 3, 4.4)), s.ext_res(M("metal_mid")), T3(-12, 28.4, 0))
        mesh_node(s, cr, "Cable", s.sub_res("BoxMesh", size=V3(.12, 8, .12)), s.ext_res(M("metal_mid")), T3(30, 24, 0))
        mesh_node(s, cr, "Hook", s.sub_res("BoxMesh", size=V3(2, 1.1, 2)), s.ext_res(M("metal_dark")), T3(30, 19.6, 0))
        lamp = s.sub_res("BoxMesh", size=V3(.6, .12, .05))
        for i in range(9):
            mesh_node(s, cr, "BoomLight", lamp, s.ext_res(M("glow_red")), T3(-10 + i * 5, 29.15, 1.01), cast_shadow=0)
        bol = s.sub_res("CylinderMesh", top_radius=.25, bottom_radius=.25, height=.7, radial_segments=10)
        for t in range(-84, 85, 12):
            mesh_node(s, D, "Bollard", bol, s.ext_res(M("metal_pole")), T3(89.2, .35, t))
            mesh_node(s, D, "Bollard", bol, s.ext_res(M("metal_pole")), T3(t, .35, 89.2))
        pier = s.node("Pier", "Node3D", D)
        mesh_node(s, pier, "Deck", s.sub_res("BoxMesh", size=V3(44, .2, 6)), s.ext_res(M("crane_paint" if False else "tank")), T3(114, .1, 24))
        pile = s.sub_res("CylinderMesh", top_radius=.3, bottom_radius=.3, height=2.4, radial_segments=8)
        for x in range(94, 136, 5):
            mesh_node(s, pier, "Pile", pile, s.ext_res(M("metal_dark")), T3(x, -1, 21.2))
            mesh_node(s, pier, "Pile", pile, s.ext_res(M("metal_dark")), T3(x, -1, 26.8))
        for z in (21.05, 26.95):
            mesh_node(s, pier, "EdgeGlow", s.sub_res("BoxMesh", size=V3(44, .04, .04)), s.ext_res(M("glow_orange")), T3(114, .22, z), cast_shadow=0)
        # grapple-perch roofs get 1.2 m parapets
        for x0, x1, z0, z1, h, c in ((30, 44, -28, -18, 8, "cyan"), (60, 88, 16, 36, 13, "orange"), (56, 88, -88, -66, 46, "cyan"), (-34, -25, -36, -25, 12, "magenta"),
                                     (24, 48, -88, -70, 40, "cyan"), (70, 88, -54, -30, 28, "cyan"), (48, 62, -50, -36, 18, "cyan")):
            pp = s.node("Parapet", "CSGCombiner3D", self.d["Cover"], {"use_collision": True, "collision_mask": 0})
            t, ph = .7, 1.2
            cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
            y = h + .3 + ph / 2 - .15
            for bx, bz, bw, bd in ((cx, z0 + t / 2, w, t), (cx, z1 - t / 2, w, t), (x0 + t / 2, cz, t, d - 2 * t), (x1 - t / 2, cz, t, d - 2 * t)):
                s.node("Wall", "CSGBox3D", pp, {"transform": T3(bx, y, bz), "size": V3(bw, ph, bd), "material": s.ext_res(M("roof"))})
            gl = s.ext_res(M("glow_" + c))
            for bx, bz, bw, bd in ((cx, z1 - t / 2, w, t + .02), (cx, z0 + t / 2, w, t + .02), (x0 + t / 2, cz, t + .02, d), (x1 - t / 2, cz, t + .02, d)):
                mesh_node(s, self.d["Cover"], "ParapetGlow", s.sub_res("BoxMesh", size=V3(bw, .03, bd)), gl, T3(bx, h + 1.37, bz), cast_shadow=0)

    # ------------------------------------------------------------ street props and cover
    def props(self):
        sp, cv = self.d["StreetProps"], self.d["Cover"]
        for sgn in (-1, 1):
            for t in range(34, 89, 18):
                ry = P2 if sgn < 0 else -P2
                self.inst(sp, "StreetLamp", "street_lamp", T3(sgn * 12.6, 0, -t, 0, ry, 0), glow=hexcol("#21e6ff"))
                self.inst(sp, "StreetLamp", "street_lamp", T3(sgn * 12.6, 0, t, 0, ry, 0), glow=hexcol("#21e6ff"))
                ry2 = 0 if sgn < 0 else math.pi
                self.inst(sp, "StreetLamp", "street_lamp", T3(-t, 0, sgn * 12.6, 0, ry2, 0), glow=hexcol("#ff2bd6"))
                self.inst(sp, "StreetLamp", "street_lamp", T3(t, 0, sgn * 12.6, 0, ry2, 0), glow=hexcol("#ff2bd6"))
        for text, x, z, ry, c in (('RESIDENTIAL', -14.8, -32, P2, '#ff2bd6'), ('COMMERCIAL', 14.8, -32, -P2, '#21e6ff'), ('INDUSTRIAL', -14.8, 32, P2, '#ff9a3c'),
                                  ('DOCKS', 14.8, 32, -P2, '#14b8a6'), ('SPIRE', -3, 90, math.pi, '#8a3bff')):
            mesh_node(self.s, sp, "SignPost", self.s.sub_res("CylinderMesh", top_radius=.08, bottom_radius=.08, height=3.6, radial_segments=8), self.s.ext_res(M("metal_pole")), T3(x, 1.8, z))
            self.sign(sp, text, x, 4.4, z, 2.4, 2.4, ry, c)
        for x, z, ry, paint in ((30, -44, .3, "#5a1a4a"), (50, -28, P2, "#1a3a5a"), (54, -56, -.2, "#2a2a3a"), (36, -60, P2 + .1, "#3a1a1a"), (66, -22, 0, "#1a1a3a"),
                                (18, -46, .8, "#3a2a5a"), (-40, -30, P2, "#2a2a3a"), (-17, -58, 0, "#4a1a3a"), (40, 22, 0, "#1a3a5a"), (30, 46, P2, "#2a1a3a"), (-22, 46, .2, "#3a2a2a")):
            self.inst(sp, "HoverCar", "hover_car", T3(x, 0, z, 0, ry, 0), paint=hexcol(paint))
        for x, z, ry, c in ((-41.3, -50, P2, '#21e6ff'), (-21.3, -54, P2, '#ff2bd6'), (-60.7, -78, -P2, '#ff9a3c'), (-19.3, -80, P2, '#8a3bff')):
            self.inst(sp, "VendingMachine", "vending_machine", T3(x, 0, z, 0, ry, 0), glow=hexcol(c))
        for x, z, ry in ((-5, -29, 0), (5, -31.5, 0), (5, 29, 0), (-5, 31.5, 0), (29, 5, P2), (31.5, -5, P2), (-29, -5, P2), (-31.5, 5, P2),
                         (-4, 46, 0), (5, 58, 0), (4, -44, 0), (-5, -64, 0), (46, -4, P2), (64, 5, P2), (-46, 4, P2), (-64, -5, P2), (40, -40, 0), (60, -62, 0), (28, -52, 0)):
            self.inst(cv, "JerseyBarrier", "jersey_barrier", T3(x, 0, z, 0, ry, 0))
        for x, z, ry in ((12.7, 12.7, 0), (-12.7, 12.7, 0), (12.7, -12.7, 0), (-12.7, -12.7, 0), (46, -31, 0), (66, -44, P2), (-38, -32, 0), (44, -58, P2)):
            self.inst(cv, "Planter", "planter", T3(x, 0, z, 0, ry, 0))
        # graffiti
        for text, x, y, z, ry, c in (('BOATS 0400 ->', 52.07, 2.1, 63, P2, '#ff2bd6'), ('THEY CAME FROM THE DRAINS', -34.07, 2.2, -30.5, -P2, '#a6ff3c'),
                                     ('THEY CAME FROM THE DRAINS', -43, 2.3, 39.93, math.pi, '#a6ff3c')):
            self.s.node("Graffiti", "Label3D", self.d["Signs"], {"transform": T3(x, y, z, 0, ry, 0), "text": text, "font_size": 72, "pixel_size": .012,
                                                                 "modulate": hexcol(c, 1, 1.6), "outline_size": 0, "double_sided": False, "shaded": False})

    # ------------------------------------------------------------ destructible cargo blocks (original buildArena list)
    def cargo(self):
        rng2 = random.Random(7)
        for x, z, w, d, h in ((-24, 14, 3, 2, 3), (-16, 22, 2, 2, 4), (-28, 10, 2, 2, 2), (13, 13, 3, 2, 3), (22, 22, 2, 3, 4), (14, 26, 3, 2, 2), (30, 30, 2, 2, 3),
                              (22, -26, 2, 2, 2), (-10, -20, 2, 2, 3), (2, -28, 1, 2, 2), (-4, -40, 1, 1, 2), (-6, 26, 1, 1, 2), (4, 40, 1, 1, 2), (-36, -2, 1, 2, 2), (36, 2, 1, 1, 3)):
            stack = self.s.node("Stack", "Node3D", self.d["CargoBlocks"])
            for a in range(w):
                for b in range(d):
                    for y in range(h):
                        r = rng2.random()
                        v = 0 if r < .86 else (1 if r < .93 else 2)
                        self.s.node("Block", None, stack, {"transform": T3((x + a) * 2 + 1, y * 2 + 1, (z + b) * 2 + 1), "variant": v}, instance="scenes/world/props/crate_block.tscn")

    # ------------------------------------------------------------ the city around the arena
    def skyline(self):
        sk = self.d["Skyline"]
        for gx in range(-250, 97, 28):
            for gz in range(-250, 97, 28):
                x0, z0 = gx + rr(0, 3), gz + rr(0, 3)
                w, d = rr(15, 22), rr(15, 22)
                x1, z1 = x0 + w, z0 + d
                if x1 > -92 and z1 > -92:
                    continue
                dist = math.hypot((x0 + x1) / 2, (z0 + z1) / 2)
                h = rr(24, 50) + max(0, dist - 100) * rr(.3, .9)
                r = rng.random()
                kind = 'com' if r < .45 else ('res' if rng.random() < .85 else 'ind')
                near = dist < 150
                self.building(x0, x1, z0, z1, h, kind, sk, {'e': x1 > -110, 's': z1 > -110} if near and (x1 > -110 or z1 > -110) else None,
                              blade=[x1 + .05, (z0 + z1) / 2, P2] if kind == 'res' and rng.random() < .6 else None,
                              bill=[(x0 + x1) / 2, h * .6, z1 + .15, 0, int(rng.random() * 4)] if kind == 'com' and rng.random() < .35 and near else None,
                              solid=False, clutter=near)
        for i in range(46):
            a, r = rr(-.25, 1.85), rr(150, 240)
            x, z = math.cos(a) * r + 80, math.sin(a) * r + 80
            if x < 150 and z < 150:
                continue
            w, h = rr(14, 28), rr(40, 150)
            self.building(x - w / 2, x + w / 2, z - w / 2, z + w / 2, h, 'com' if rng.random() < .6 else 'res', sk, solid=False, clutter=False)

    def maglev(self):
        s, ml = self.s, self.d["Maglev"]
        pts = []
        for i in range(41):
            t = i / 40
            pts.append((-260 + t * 480, 20 + math.sin(t * 6) * 2, -112 - math.sin(t * 3.1) * 16))
        data = []
        for p in pts:
            data += [0, 0, 0, 0, 0, 0, p[0], p[1], p[2]]
        curve = s.sub_res("Curve3D", _data=Raw('{\n"points": PackedVector3Array(%s),\n"tilts": PackedFloat32Array(%s)\n}' % (
            ", ".join(num(v) for v in data), ", ".join("0" for _ in pts))), point_count=len(pts))
        path = s.node("Track", "Path3D", ml, {"curve": curve})
        circle = lambda r, n=6: Raw("PackedVector2Array(" + ", ".join("%s, %s" % (num(math.cos(i / n * math.tau) * r), num(math.sin(i / n * math.tau) * r)) for i in range(n)) + ")")
        s.node("Rail", "CSGPolygon3D", ml, {"polygon": circle(.45), "mode": 2, "path_node": NP("../Track"), "path_interval": 3.0, "material": s.ext_res(M("metal_dark"))})
        for dy, c in ((.5, "cyan"), (-.5, "magenta")):
            s.node("RailGlow", "CSGPolygon3D", ml, {"transform": T3(0, dy, 0), "polygon": circle(.07, 4), "mode": 2, "path_node": NP("../Track"), "path_interval": 3.0, "material": s.ext_res(M("glow_" + c))})
        col_mesh = s.sub_res("CylinderMesh", top_radius=.5, bottom_radius=.5, height=1, radial_segments=8)
        for i in range(0, 41, 2):
            x, y, z = pts[i]
            mesh_node(s, ml, "Pylon", col_mesh, s.ext_res(M("metal_dark")), T3(x, y / 2, z, s=(1, y, 1)))
        follow = s.node("Tram", "PathFollow3D", path, {"script": s.ext_res("scripts/world/props/tram.gd"), "loop": False, "transform": T3()})
        tram = s.node("Car", "Node3D", follow, {"transform": T3(0, 1.6, 0)})
        mesh_node(s, tram, "Body", s.sub_res("BoxMesh", size=V3(3, 2.4, 14)), s.ext_res(M("tram_body")))
        mesh_node(s, tram, "Windows", s.sub_res("BoxMesh", size=V3(3.04, .7, 12.5)), s.ext_res(M("glow_white")), T3(0, .3, 0), cast_shadow=0)
        mesh_node(s, tram, "Stripe", s.sub_res("BoxMesh", size=V3(3.06, .08, 14)), s.ext_res(M("glow_magenta")), T3(0, -.5, 0), cast_shadow=0)

    def save(self):
        self.streets(); self.centre(); self.districts(); self.props(); self.cargo(); self.skyline(); self.maglev()
        self.s.save("scenes/world/arena.tscn")


def awning():
    s = Scene("Awning", "Node3D")
    s.nodes[0][3].update({"script": s.ext_res("scripts/world/props/tinted_prop.gd"), "paint": hexcol("#5a0a4a"), "glow": hexcol("#ff2bd6")})
    canvas = s.sub_res("StandardMaterial3D", resource_local_to_scene=True, albedo_color=hexcol("#5a0a4a"), roughness=.8, cull_mode=2)
    mesh_node(s, ".", "Canvas", s.sub_res("BoxMesh", size=V3(1, .04, 1.7)), canvas, T3(0, 0, .7, .42))
    mesh_node(s, ".", "Edge", s.sub_res("BoxMesh", size=V3(1, .06, .06)),
              s.sub_res("StandardMaterial3D", resource_local_to_scene=True, albedo_color=hexcol("#ff2bd6"), emission_enabled=True, emission=hexcol("#ff2bd6"), emission_energy_multiplier=2.4),
              T3(0, -.33, 1.45), cast_shadow=0)
    s.nodes[0][3].update({"paint_targets": Raw('Array[NodePath]([NodePath("Canvas")])'), "glow_targets": Raw('Array[NodePath]([NodePath("Edge")])')})
    s.save("scenes/world/props/awning.tscn")


def build_arena():
    awning()
    Arena().save()


if __name__ == "__main__":
    build_arena()
    print("arena ok")
