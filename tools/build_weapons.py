"""First-person gun scenes, ported from the original gunModel(): grip at the origin, barrel along +Z,
every piece a named MeshInstance3D so the guns can be re-modelled in the editor."""
import math
from godot_writer import *
from build_resources import WEAPONS

X = math.pi / 2
SIGHT = {'pulse': dict(yc=.125, rear=[-.04, .098], front=[.62, .068], hg=[.28, .66, .032, .047], mw=[0, -.032, .112, .054, .034, .086, .2], bore=.035),
         'smg': dict(yc=.115, rear=[-.04, .092], front=[.33, .06], hg=[.18, .355, .03, .037], mw=[0, -.03, .15, .046, .03, .058, 0], bore=.03),
         'burst': dict(yc=.135, rear=[-.15, .111], front=[.37, .065], hg=[.19, .385, .04, .033], bore=.04),
         'chain': dict(yc=.125, rear=[-.04, .102], front=[.36, .06], mw=[0, -.03, .1, .06, .03, .13, 0], bore=.035),
         'scatter': dict(yc=.128, rear=[-.04, .106], front=[.66, .087], hg=[.52, .69, .065, .03], bore=.065),
         'ion': dict(yc=.172, rear=[-.02, .154], front=[.14, .154], mw=[0, -.045, .06, .095, .03, .15, 0], bore=.03),
         'rail': dict(yc=.13, bore=.03), 'arc': dict(yc=.12, rear=[-.06, .085], front=[.55, .075, 'Front'], bore=.06),
         'cryo': dict(yc=.115, rear=[.07, .08], front=[.27, .08], bore=.035), 'void': dict(yc=.14, rear=[-.06, .085], front=[.30, .124], bore=.035)}
HW = dict(pulse=.033, scatter=.04, rail=.03, smg=.03, arc=.035, ion=.05, cryo=.035, void=.035, burst=.0325, chain=.035)


class Gun:
    def __init__(self, w):
        self.w = w
        self.id = w['id']
        self.s = Scene(self.id.capitalize(), "Node3D")
        s = self.s
        s.nodes[0][3]["script"] = s.ext_res("scripts/weapons/weapon_model.gd")
        s.nodes[0][3]["weapon_id"] = self.id
        self.body = s.ext_res("assets/materials/gun_body.tres")
        self.dark = s.ext_res("assets/materials/gun_dark.tres")
        self.steel = s.ext_res("assets/materials/gun_steel.tres")
        self.bronze = s.ext_res("assets/materials/gun_bronze.tres")
        self.rubber = s.ext_res("assets/materials/gun_rubber.tres")
        self.black = s.ext_res("assets/materials/gun_black.tres")
        self.tri = s.ext_res("assets/materials/glow_gun_tritium.tres")
        self.glow = s.sub_res("StandardMaterial3D", albedo_color=hexcol(w['hex']), emission_enabled=True, emission=hexcol(w['hex']),
                              emission_energy_multiplier=2.2, roughness=0.5)
        self.line = s.ext_res("assets/materials/glow_blue.tres")
        self._mesh_cache = {}
        self.counts = {}
        self.offsets = {".": (0, 0, 0)}

    # mesh resources (shared between identical parts)
    def _mesh(self, kind, *a):
        k = (kind,) + tuple(round(x, 5) for x in a)
        if k in self._mesh_cache:
            return self._mesh_cache[k]
        s = self.s
        if kind == "box":
            m = s.sub_res("BoxMesh", size=V3(*a))
        elif kind == "cyl":
            r1, r2, h, seg = a
            m = s.sub_res("CylinderMesh", top_radius=r1, bottom_radius=r2, height=h, radial_segments=int(seg), rings=1)
        elif kind == "torus":
            R, r, seg = a
            m = s.sub_res("TorusMesh", inner_radius=R - r, outer_radius=R + r, rings=int(seg), ring_segments=8)
        elif kind == "sphere":
            r, = a
            m = s.sub_res("SphereMesh", radius=r, height=2 * r, radial_segments=14, rings=8)
        self._mesh_cache[k] = m
        return m

    def A(self, parent, name, mesh, mat, x=0, y=0, z=0, rx=0, ry=0, rz=0, pre=None, glow=False, sc=None):
        n = self.counts.get(name, 0)
        self.counts[name] = n + 1
        props = {"transform": T3(x, y, z, rx, ry, rz, pre=pre, s=sc), "mesh": mesh, "material_override": mat}
        if mat is self.glow:
            glow = True
            props["cast_shadow"] = 0
        return self.s.node(name if n == 0 else "%s%d" % (name, n + 1), "MeshInstance3D", parent, props, groups=["glow"] if glow else None)

    def box(self, p, name, w, h, d, mat, *pos): return self.A(p, name, self._mesh("box", w, h, d), mat, *pos)
    def cyl(self, p, name, r1, r2, h, mat, *pos, seg=18): return self.A(p, name, self._mesh("cyl", r1, r2, h, seg), mat, *pos)
    def torus(self, p, name, R, r, mat, x=0, y=0, z=0, rx=0, ry=0, rz=0, seg=26):
        return self.A(p, name, self._mesh("torus", R, r, seg), mat, x, y, z, rx, ry, rz, pre=TORUS_TO_XY)
    def sphere(self, p, name, r, mat, *pos): return self.A(p, name, self._mesh("sphere", r), mat, *pos)

    def group(self, name, x=0, y=0, z=0):
        path = self.s.node(name, "Node3D", ".", {"transform": T3(x, y, z)})
        self.offsets[path] = (x, y, z)
        return path

    def build(self):
        i, g = self.id, "."
        B, D, G = self.body, self.dark, self.glow
        # shared furniture: grip, stock, butt
        self.box(g, "Grip", .035, .11, .05, D, 0, -.075, -.01, .3)
        if i != 'burst':
            self.box(g, "Stock", .05, .085, .2, B, 0, .03, -.17)
            self.box(g, "Butt", .055, .1, .03, D, 0, .02, -.28)
        mz = .78
        if i == 'scatter':
            self.box(g, "Receiver", .08, .11, .34, B, 0, .035, .08)
            for y in (.065, .0):
                self.cyl(g, "Barrel", .022, .022, .42, D, 0, y, .48, X)
            top = self.group("Top", 0, -.035, .42)
            self.box(top, "Pump", .07, .055, .16, D)
            for k in range(4):
                self.box(top, "PumpRib", .072, .006, .01, B, 0, -.02, -.06 + k * .04)
            mag = self.group("Mag", 0, -.01, .12)
            self.cyl(mag, "Shell", .013, .013, .06, G, 0, 0, 0, X, seg=12)
            self.s.nodes[-2][3]["visible"] = False   # the loose shell only shows while loading
            self.box(g, "GlowStripR", .004, .012, .26, G, .042, .06, .1)
            self.box(g, "GlowStripL", .004, .012, .26, G, -.042, .06, .1)
            mz = .7
        elif i == 'rail':
            self.box(g, "Receiver", .06, .09, .34, B, 0, .035, .08)
            self.box(g, "RailHousing", .042, .05, .66, B, 0, .03, .6)
            for z in (.42, .58, .75):
                self.torus(g, "Coil", .045, .008, G, 0, .03, z)
            self.sphere(g, "Emitter", .02, G, 0, .03, .93)
            mag = self.group("Mag", 0, .095, -.08)
            self.box(mag, "Cell", .045, .045, .15, D)
            self.box(mag, "CellGlow", .047, .02, .12, G, 0, .012, 0)
            self.cyl(g, "ScopeMount", .022, .022, .13, D, 0, .108, .1, X)
            mz = .95
        elif i == 'smg':
            self.box(g, "Receiver", .06, .08, .26, B, 0, .035, .05)
            self.box(g, "Shroud", .05, .06, .18, B, 0, .03, .27)
            self.cyl(g, "Barrel", .016, .016, .07, D, 0, .03, .39, X)
            mag = self.group("Mag", 0, -.03, .15)
            self.box(mag, "Feed", .036, .05, .05, D, 0, -.005, 0)
            self.cyl(mag, "Drum", .068, .068, .082, B, 0, -.088, .012, 0, 0, X, seg=32)
            for sx in (-1, 1):
                self.torus(mag, "DrumRing", .056, .004, D, sx * .042, -.088, .012, 0, X, 0, seg=30)
            top = self.group("Top", .035, .07, -.02)
            self.box(top, "ChargingHandle", .02, .02, .04, D)
            mz = .44
        elif i == 'arc':
            self.box(g, "Receiver", .07, .1, .3, B, 0, .035, .05)
            front = self.group("Front", 0, -.015, .2)
            self.cyl(front, "Tube", .045, .045, .42, B, 0, .045, .21, X, seg=26)
            for z in (.08, .2, .32):
                self.torus(front, "Coil", .05, .008, G, 0, .045, z)
            self.sphere(front, "Muzzle", .045, G, 0, .045, .42)
            mag = self.group("Mag", 0, .03, .24)
            self.sphere(mag, "Round", .035, G)
            self.s.nodes[-2][3]["visible"] = False
            mz = .66
        elif i == 'ion':
            self.box(g, "Receiver", .1, .12, .36, B, 0, .03, .06)
            spin = self.group("Spin", 0, .03, .26)
            for x, y in ((.025, .025), (-.025, .025), (.025, -.025), (-.025, -.025)):
                self.cyl(spin, "Barrel", .013, .013, .42, D, x, y, .2, X, seg=10)
            for z in (.03, .2, .38):
                self.cyl(spin, "Clamp", .048, .048, .025, B, 0, 0, z, X, seg=20)
            self.box(g, "Foregrip", .03, .09, .04, D, 0, -.06, .3, -.3)
            mag = self.group("Mag", 0, -.1, .06)
            self.box(mag, "BeltBox", .085, .1, .14, D)
            self.box(mag, "BeltGlow", .087, .012, .1, G, 0, .02, 0)
            mz = .68
        elif i == 'cryo':
            self.box(g, "Receiver", .07, .09, .3, B, 0, .035, .06)
            self.A(g, "Nozzle", self.s.sub_res("CylinderMesh", top_radius=0.0, bottom_radius=.05, height=.16, radial_segments=20, rings=1, cap_top=False, cap_bottom=False), D, 0, .035, .33, -X)
            for z in (.22, .26, .3):
                self.torus(g, "Coil", .04, .006, G, 0, .035, z, seg=24)
            mag = self.group("Mag", 0, .135, .0)
            canister = self.s.sub_res("StandardMaterial3D", transparency=1, shading_mode=0, albedo_color=hexcol(self.w['hex'], .75))
            self.cyl(mag, "Canister", .028, .028, .12, canister)
            self.cyl(mag, "CapTop", .031, .031, .02, D, 0, .065, 0)
            self.cyl(mag, "CapBottom", .031, .031, .02, D, 0, -.065, 0)
            mz = .42
        elif i == 'void':
            self.box(g, "Receiver", .07, .1, .3, B, 0, .035, .04)
            self.torus(g, "Halo", .075, .014, D, 0, .035, .3, seg=32)
            self.torus(g, "HaloGlow", .058, .006, G, 0, .035, .3, seg=30)
            for sx in (-1, 1):
                self.box(g, "Prong", .012, .03, .14, B, sx * .07, .035, .25)
            mag = self.group("Mag", 0, .035, .3)
            self.sphere(mag, "Singularity", .035, G)
            for sx, nm in ((-1, "VaneL"), (1, "VaneR")):
                v = self.group(nm, sx * .035, .087, .08)
                self.box(v, "Vane", .034, .006, .13, B, -sx * .017, 0, 0)
                self.box(v, "VaneGlow", .02, .003, .1, G, -sx * .017, -.004, 0)
            mz = .32
        elif i == 'burst':
            self.box(g, "Receiver", .065, .11, .42, B, 0, .035, -.02)
            self.box(g, "Buttpad", .06, .09, .04, D, 0, .02, -.25)
            self.box(g, "Shroud", .045, .05, .2, B, 0, .04, .29)
            self.cyl(g, "Barrel", .015, .015, .06, D, 0, .04, .41, X)
            self.box(g, "TopGlow", .07, .012, .3, G, 0, .093, -.02)
            mag = self.group("Mag", .06, .02, -.08)
            self.box(mag, "SideMag", .09, .035, .13, D)
            self.box(mag, "SideMagGlow", .091, .008, .1, G, 0, .012, 0)
            top = self.group("Top", 0, .1, -.06)
            self.box(top, "ChargingHandle", .025, .02, .05, D)
            mz = .44
        elif i == 'chain':
            self.box(g, "Receiver", .07, .1, .3, B, 0, .035, .04)
            for sx in (-1, 1):
                self.box(g, "Rail", .012, .05, .24, B, sx * .032, .035, .3)
            for z in (.22, .27, .32, .37):
                self.torus(g, "Coil", .022, .005, G, 0, .035, z, seg=20)
            self.sphere(g, "Tip", .016, G, 0, .035, .42)
            mag = self.group("Mag", 0, -.075, .1)
            self.box(mag, "Capacitor", .05, .06, .12, D)
            self.box(mag, "CapacitorGlow", .052, .012, .08, G, 0, .015, 0)
            mz = .44
        else:  # pulse
            self.box(g, "Receiver", .066, .1, .34, B, 0, .035, .1)
            self.box(g, "Handguard", .056, .072, .42, B, 0, .032, .48)
            self.cyl(g, "Barrel", .016, .016, .09, D, 0, .035, .73, X)
            for sx in (-1, 1):
                self.box(g, "GlowStrip", .004, .012, .26, G, sx * .035, .05, .12)
            mag = self.group("Mag", 0, -.06, .12)
            self.box(mag, "Magazine", .045, .14, .07, D, 0, -.05, 0, .2)
            self.box(mag, "MagGlow", .046, .01, .05, G, 0, -.01, 0, .2)
            top = self.group("Top", .04, .07, .02)
            self.box(top, "ChargingHandle", .02, .02, .04, D)
            mz = .78
        self.box(g, "SightLine", .01, .004, .2, self.line, 0, .088, .14)

        K = SIGHT.get(i, {})
        # trigger guard and trigger
        self.box(g, "TriggerGuard", .008, .008, .09, D, 0, -.084, .05)
        self.box(g, "TriggerGuardFront", .008, .05, .008, D, 0, -.06, .097)
        self.box(g, "Trigger", .007, .035, .008, self.bronze, 0, -.052, .046, .25)
        # vented handguard
        if 'hg' in K:
            z0, z1, y, r = K['hg']
            L = z1 - z0
            self.A(g, "VentedHandguard", self._mesh("cyl", r, r, L, 8), B, 0, y, (z0 + z1) / 2, X, math.pi / 8, 0)
            n = max(3, int((L - .05) / .034))
            for k in range(n):
                z = z0 + .03 + k * (L - .06) / (n - 1)
                for sx in (-1, 1):
                    self.box(g, "Vent", .003, r * .42, .018, D, sx * r * .97, y, z)
            # fluted steel barrel out to the muzzle
            zb0, zb1 = z1, mz - .03
            if zb1 - zb0 > .04:
                self.cyl(g, "FlutedBarrel", .0125, .0125, zb1 - zb0, self.steel, 0, K['bore'], (zb0 + zb1) / 2, X, seg=16)
        # mag well
        if 'mw' in K:
            x, y, z, w, h, d, rx = K['mw']
            mw = self.s.node("MagWell", "Node3D", ".", {"transform": T3(x, y, z, rx)})
            self.box(mw, "Front", w, h, .006, B, 0, 0, d / 2 - .003)
            self.box(mw, "Back", w, h, .006, B, 0, 0, -d / 2 + .003)
            for sx in (-1, 1):
                self.box(mw, "Side", .006, h, d, B, sx * (w / 2 - .003), 0, 0)
            self.box(mw, "Lip", w + .012, .008, d + .014, D, 0, -h / 2, 0)
        # iron sights on a common sight line
        if 'yc' in K:
            yc = K['yc']
            if 'rear' in K:
                zr, yb = K['rear']
                self.box(g, "RearSightBase", .03, yc - .016 - yb, .026, D, 0, (yc - .016 + yb) / 2, zr)
                self.torus(g, "RearAperture", .012, .0032, D, 0, yc, zr, seg=22)
                for sx in (-1, 1):
                    self.box(g, "RearEar", .004, yc + .016 - yb, .022, D, sx * .019, (yc + .016 + yb) / 2, zr)
                    self.sphere(g, "TritiumDot", .0026, self.tri, sx * .0105, yc + .0015, zr + .014)
            if 'front' in K:
                f = K['front']
                zf, yb = f[0], f[1]
                par = f[2] if len(f) > 2 else None
                parent = par if par else g
                ox, oy, oz = self.offsets.get(parent, (0, 0, 0))
                self.box(parent, "FrontSightBase", .024, yc - .006 - yb, .018, D, -ox, (yc - .006 + yb) / 2 - oy, zf - oz)
                self.box(parent, "FrontPost", .0032, .012, .0032, B, -ox, yc - .004 - oy, zf - oz)
                for sx in (-1, 1):
                    self.box(parent, "FrontWing", .0035, .022, .014, D, sx * .012 - ox, yc - .002 - oy, zf - oz)
                if not par:
                    self.sphere(g, "FrontTritium", .0024, self.tri, 0, yc + .004, zf + .009)
        # rails, vents, scope
        def rail(z0, z1, y):
            self.box(g, "PicatinnyRail", .03, .008, z1 - z0, D, 0, y, (z0 + z1) / 2)
            z = z0 + .008
            while z < z1:
                self.box(g, "RailTooth", .034, .007, .007, D, 0, y + .007, z)
                z += .016

        def vents(x, y, z0, n, step):
            for k in range(n):
                self.box(g, "SideVent", .003, .014, .008, D, x, y, z0 + k * step)
        if i == 'pulse': rail(-.06, .2, .09); vents(.03, .03, .32, 5, .035); vents(-.03, .03, .32, 5, .035)
        elif i == 'scatter': rail(-.06, .18, .095)
        elif i == 'smg': rail(-.06, .14, .081); vents(.026, .03, .22, 3, .03); vents(-.026, .03, .22, 3, .03)
        elif i == 'burst': rail(-.18, .12, .1); vents(.023, .04, .24, 4, .03); vents(-.023, .04, .24, 4, .03)
        elif i == 'chain': rail(-.06, .14, .091)
        elif i == 'rail':
            sc = self.s.node("Scope", "Node3D", ".", {"transform": T3(0, .13, .04)})
            self.cyl(sc, "ScopeTube", .022, .022, .2, D, 0, 0, 0, X, seg=20)
            self.cyl(sc, "ScopeBell", .028, .022, .04, D, 0, 0, .11, X, seg=20)
            lens = self.s.sub_res("StandardMaterial3D", albedo_color=hexcol("#12306a"), metallic=1.0, roughness=0.05)
            self.cyl(sc, "ScopeLens", .026, .026, .008, lens, 0, 0, .132, X, seg=20)
            self.box(g, "ScopeRingRear", .012, .02, .012, D, 0, .108, -.02)
            self.box(g, "ScopeRingFront", .012, .02, .012, D, 0, .108, .1)
            vents(.031, .03, .48, 6, .05); vents(-.031, .03, .48, 6, .05)
        elif i == 'ion':
            self.box(g, "CarryPost", .02, .05, .02, D, 0, .115, -.02); self.box(g, "CarryPost", .02, .05, .02, D, 0, .115, .14)
            self.box(g, "CarryHandle", .02, .018, .18, D, 0, .145, .06); vents(.051, .04, -.06, 6, .03); vents(-.051, .04, -.06, 6, .03)
        elif i == 'cryo':
            self.cyl(g, "Gauge", .02, .02, .012, D, .036, .05, .1, 0, 0, X); vents(.036, .03, -.02, 4, .03)
        elif i == 'arc': vents(.036, .04, -.06, 5, .03); self.box(g, "Hinge", .02, .04, .02, D, 0, .105, .0)
        elif i == 'void': vents(.036, .035, -.06, 5, .03); vents(-.036, .035, -.06, 5, .03)
        # micro detail: fasteners, ejection port with bolt face, selector, charging handle, stippled grip, sling cup, muzzle device
        hw = HW.get(i, .033)
        for sx in (-1, 1):
            for y, z in ((.06, -.08), (.06, .17), (.005, .17), (.005, -.03)):
                self.cyl(g, "HexBolt", .006, .006, .004, B, sx * (hw + .002), y, z, 0, 0, X, seg=6)
            gp = self.box(g, "GripPanel", .004, .07, .036, self.rubber, sx * .0195, -.072, -.008, .3)
        self.box(g, "EjectionPort", .002, .024, .07, D, hw + .0015, .045, .08)
        self.box(g, "BoltFace", .003, .016, .05, self.steel, hw + .0006, .045, .08)
        self.cyl(g, "Selector", .006, .006, .006, B, -hw - .003, 0, -.005, 0, 0, X, seg=12)
        self.box(g, "SelectorLever", .003, .004, .022, B, -hw - .007, 0, .002, .5)
        self.box(g, "RearCharger", .016, .012, .02, D, 0, .085, -.13)
        if i != 'burst':
            self.torus(g, "SlingCup", .007, .0022, self.steel, hw + .004, .03, -.24, 0, math.pi / 2, 0, seg=16)
        if i in ('pulse', 'smg', 'burst', 'scatter', 'chain'):
            md = self.s.node("MuzzleDevice", "Node3D", ".", {"transform": T3(0, .065 if i == 'scatter' else .035, mz - .02)})
            self.cyl(md, "Brake", .019, .017, .05, D, 0, 0, 0, X, seg=16)
            for k in range(3):
                self.box(md, "Port", .04, .004, .006, self.black, 0, .008, -.012 + k * .012)
            self.cyl(md, "Bore", .0085, .0085, .052, self.black, 0, 0, .001, X, seg=12)

        # muzzle marker, flash and light
        bore = K.get('bore', .035)
        self.s.node("Muzzle", "Marker3D", ".", {"transform": T3(0, bore, mz)})
        fl = self.s.node("Flash", "Node3D", ".", {"transform": T3(0, bore, mz + .03), "visible": False})
        tint = "#%02x%02x%02x" % tuple(int(255 * (a * .75 + b * .25)) for a, b in zip((1, .86, .66), [int(self.w['hex'][k:k + 2], 16) / 255 for k in (1, 3, 5)]))
        star = self.s.sub_res("GradientTexture2D", gradient=self.s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.18, 0.5, 1)"),
                              colors=Raw("PackedColorArray(1, 1, 1, 1, 1, 0.94, 0.82, 0.9, 1, 0.67, 0.31, 0.25, 1, 0.47, 0.16, 0)")),
                              fill=1, fill_from=V2(0.5, 0.5), fill_to=V2(1, 0.5), width=64, height=64)
        fm = self.s.sub_res("StandardMaterial3D", transparency=1, blend_mode=1, shading_mode=0, cull_mode=2, albedo_color=hexcol(tint, 0.7), albedo_texture=star)
        self.A(fl, "FlashFace", self.s.sub_res("QuadMesh", size=V2(.2, .2)), fm)
        side = self.s.sub_res("QuadMesh", size=V2(.26, .065))
        self.A(fl, "FlashSide", side, fm, 0, 0, .12, 0, -X, 0)
        self.A(fl, "FlashSide", side, fm, 0, 0, .12, X, -X, 0, )
        self.s.node("FlashLight", "OmniLight3D", ".", {"transform": T3(0, bore, mz + .1), "light_color": hexcol(self.w['hex']), "light_energy": 0.0, "omni_range": 10.0})
        # IK targets for a full-body character: right wrist above the pistol grip, left wrist under the handguard
        # (the original's per-weapon RIG.fore points; on the scattergun the support hand rides the pump)
        FORE = {'pulse': (0, -.03, .36), 'rail': (0, -.02, .3), 'smg': (0, -.02, .24), 'arc': (0, -.03, .42), 'ion': (0, -.1, .3),
                'cryo': (0, -.02, .18), 'void': (0, -.02, .18), 'burst': (0, -.02, .3), 'chain': (0, -.03, .17)}
        self.s.node("GripHand", "Marker3D", ".", {"transform": T3(0, -.015, -.06)})
        if i == 'scatter':
            self.s.node("SupportHand", "Marker3D", "Top", {"transform": T3(.045, -.1, -.05)})
            support = "Top/SupportHand"
        else:
            fx, fy, fz = FORE[i]
            # held close to the magwell so the (short-armed, heavily armoured) operative can reach it
            self.s.node("SupportHand", "Marker3D", ".", {"transform": T3(fx + .045, fy - .075, min(fz - .07, .2))})
            support = "SupportHand"
        root = self.s.nodes[0][3]
        root["grip_hand"] = NodeRef("GripHand")
        root["support_hand"] = NodeRef(support)
        root["muzzle"] = NodeRef("Muzzle")
        root["flash"] = NodeRef("Flash")
        root["flash_light"] = NodeRef("FlashLight")
        return self.s.save("scenes/weapons/%s.tscn" % i)


def build_sniper():
    """Nightfall bolt rifle: the generated mesh (assets/placeholder/models/sniper.glb, muzzle at -Z in the file) turned
    to the WeaponModel convention (grip at the origin, barrel along +Z), plus the moving / marker parts the bolt-action
    choreography needs: Bolt (handle + knob, the right hand rides BoltHand), Eject port, ScopeEye (sight line),
    Clip (stripper clip for reloads), Glint (lens flare others see), muzzle flash and light."""
    s = Scene("Sniper", "Node3D")
    r = s.nodes[0][3]
    r.update({"script": s.ext_res("scripts/weapons/weapon_model.gd"), "weapon_id": "sniper"})
    S = 1.15
    s.node("Model", None, ".", {"transform": T3(0, .092, .1725, 0, math.pi, 0, s=S)}, instance="assets/placeholder/models/sniper.glb")
    steel = s.sub_res("StandardMaterial3D", albedo_color=hexcol("#2a2a2e"), metallic=.9, roughness=.32)
    black = s.sub_res("StandardMaterial3D", albedo_color=hexcol("#0c0c0e"), metallic=.6, roughness=.5)
    brass = s.sub_res("StandardMaterial3D", albedo_color=hexcol("#b8873a"), metallic=1.0, roughness=.25)
    # bolt: pivots about the bore axis (lift) and slides back along -Z (rack)
    bolt = s.node("Bolt", "Node3D", ".", {"transform": T3(-.034, .175, .045)})
    s.node("Handle", "MeshInstance3D", bolt, {"transform": T3(-.03, -.012, 0, 0, 0, -1.2), "mesh": s.sub_res("CylinderMesh", top_radius=.006, bottom_radius=.007, height=.07, radial_segments=10), "material_override": steel})
    s.node("Knob", "MeshInstance3D", bolt, {"transform": T3(-.062, -.026, 0), "mesh": s.sub_res("SphereMesh", radius=.014, height=.028, radial_segments=12, rings=8), "material_override": black})
    s.node("BoltHand", "Marker3D", bolt, {"transform": T3(-.07, -.035, -.03)})
    s.node("Eject", "Marker3D", ".", {"transform": T3(-.03, .19, .085)})
    s.node("ScopeEye", "Marker3D", ".", {"transform": T3(0, .2645, .08)})
    # stripper clip (shown only while loading): five rounds on a strip
    clip = s.node("Clip", "Node3D", ".", {"transform": T3(-.02, .215, .085), "visible": False})
    s.node("Strip", "MeshInstance3D", clip, {"mesh": s.sub_res("BoxMesh", size=V3(.012, .004, .07)), "material_override": steel})
    rnd = s.sub_res("CylinderMesh", top_radius=.0045, bottom_radius=.006, height=.07, radial_segments=8)
    for k in range(5):
        s.node("Round", "MeshInstance3D", clip, {"transform": T3(0, .036, -.028 + k * .014, 0, 0, 0), "mesh": rnd, "material_override": brass})
    # lens glint (seen by the other player; the owner never sees their own)
    gl = s.sub_res("StandardMaterial3D", transparency=1, blend_mode=1, shading_mode=0, billboard_mode=1, no_depth_test=False, albedo_color=col(1, .25, .18, .9),
                   albedo_texture=s.sub_res("GradientTexture2D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.1, 0.35, 1)"),
                                            colors=Raw("PackedColorArray(1, 1, 1, 1, 1, 0.85, 0.75, 0.9, 1, 0.3, 0.2, 0.25, 1, 0, 0, 0)")),
                                            fill=1, fill_from=V2(.5, .5), fill_to=V2(1, .5), width=64, height=64))
    s.node("Glint", "MeshInstance3D", ".", {"transform": T3(0, .2645, .27), "mesh": s.sub_res("QuadMesh", size=V2(.5, .5)), "material_override": gl,
                                            "visible": False, "cast_shadow": 0})
    # muzzle flash: a hot star with a long side jet (big-bore), and its light
    mz = .75
    s.node("Muzzle", "Marker3D", ".", {"transform": T3(0, .1645, mz)})
    fl = s.node("Flash", "Node3D", ".", {"transform": T3(0, .1645, mz + .04), "visible": False})
    star = s.sub_res("GradientTexture2D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.18, 0.5, 1)"),
                     colors=Raw("PackedColorArray(1, 1, 1, 1, 1, 0.92, 0.75, 0.9, 1, 0.55, 0.2, 0.25, 1, 0.3, 0.1, 0)")),
                     fill=1, fill_from=V2(0.5, 0.5), fill_to=V2(1, 0.5), width=64, height=64)
    fm = s.sub_res("StandardMaterial3D", transparency=1, blend_mode=1, shading_mode=0, cull_mode=2, albedo_color=hexcol("#ffd0a0", .85), albedo_texture=star)
    X = math.pi / 2
    s.node("FlashFace", "MeshInstance3D", fl, {"mesh": s.sub_res("QuadMesh", size=V2(.34, .34)), "material_override": fm, "cast_shadow": 0})
    side = s.sub_res("QuadMesh", size=V2(.6, .12))
    s.node("FlashSide", "MeshInstance3D", fl, {"transform": T3(0, 0, .26, 0, -X, 0), "mesh": side, "material_override": fm, "cast_shadow": 0})
    s.node("FlashSide2", "MeshInstance3D", fl, {"transform": T3(0, 0, .26, X, -X, 0), "mesh": side, "material_override": fm, "cast_shadow": 0})
    s.node("FlashLight", "OmniLight3D", ".", {"transform": T3(0, .1645, mz + .15), "light_color": hexcol("#ffb070"), "light_energy": 0.0, "omni_range": 14.0})
    s.node("GripHand", "Marker3D", ".", {"transform": T3(0, -.015, -.06)})
    s.node("SupportHand", "Marker3D", ".", {"transform": T3(.05, .05, .23)})     # under the front of the receiver: in reach, palm up
    r.update({"grip_hand": NodeRef("GripHand"), "support_hand": NodeRef("SupportHand"), "muzzle": NodeRef("Muzzle"), "flash": NodeRef("Flash"),
              "flash_light": NodeRef("FlashLight")})
    s.save("scenes/weapons/sniper.tscn")


def build_weapons():
    build_sniper()
    for w in WEAPONS:
        if w['id'] != 'sniper':       # the sniper is a mesh model (build_sniper), not primitive parts
            Gun(w).build()


if __name__ == "__main__":
    build_weapons()
    print("weapons ok")
