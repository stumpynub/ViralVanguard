"""The sniper-duel arena: two rooftops facing each other across a rainy street canyon, cel-shaded with the gritty
CC0 texture sets (assets/textures/gritty), lit by cold moonlight and red neon. Written as plain nodes in
scenes/world/arena_duel.tscn (script: scripts/world/duel_arena.gd)."""
import math
from godot_writer import *
from build_props import mesh_node

P2 = math.pi / 2
M = lambda n: "assets/materials/%s.tres" % n
TX = lambda n, k="albedo": "assets/textures/gritty/%s_%s.jpg" % (n, k)


class Duel:
    def __init__(self):
        s = self.s = Scene("Arena", "Node3D")
        r = s.nodes[0][3]
        r["script"] = s.ext_res("scripts/world/duel_arena.gd")
        r["bounds"] = Raw("Rect2(-60, -28, 120, 56)")
        self.toon = s.ext_res("assets/shaders/menu/toon.gdshader")
        self.outline = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/outline.gdshader"),
                                 **{"shader_parameter/width": .0009, "shader_parameter/max_width": .02})
        self.mats = {}
        self.env()
        s.node("PlayerSpawn", "Marker3D", ".", {"transform": T3(-40, 14.1, 0, 0, -P2, 0)})
        s.node("SpawnA", "Marker3D", ".", {"transform": T3(-40, 14.1, 0, 0, -P2, 0)})
        s.node("SpawnB", "Marker3D", ".", {"transform": T3(40, 15.1, 0, 0, P2, 0)})
        r.update({"spawn_a": NodeRef("SpawnA"), "spawn_b": NodeRef("SpawnB")})
        self.city = s.node("City", "Node3D", ".")
        s.node("CargoBlocks", "Node3D", self.city)
        s.node("Enemies", "Node3D", ".")
        s.node("FX", "Node3D", ".")

    # materials: toon shader + a gritty texture tiled in world space
    def mat(self, tex, tint="#ffffff", scale=.25, wet=0.0, ol=True, emit=0.0, emit_col="#ff1a10"):
        key = (tex, tint, scale, wet, ol, emit)
        if key in self.mats:
            return self.mats[key]
        p = {"shader": self.toon, "shader_parameter/tint": hexcol(tint, 1, 1.6), "shader_parameter/world_uv": True, "shader_parameter/world_scale": scale,
             "shader_parameter/wet": wet, "shader_parameter/desaturate": .55, "shader_parameter/rim_strength": 0.0, "shader_parameter/bands": 3.0}
        if tex:
            p["shader_parameter/albedo_tex"] = self.s.ext_res(TX(tex))
        if emit > 0:
            p["shader_parameter/emission_color"] = hexcol(emit_col, 1, emit)
        if ol:
            p["next_pass"] = self.outline
        m = self.s.sub_res("ShaderMaterial", **p)
        self.mats[key] = m
        return m

    def glow(self, color, energy=3.0):
        return self.s.sub_res("StandardMaterial3D", shading_mode=0, albedo_color=hexcol(color), emission_enabled=True, emission=hexcol(color), emission_energy_multiplier=energy)

    def block(self, parent, name, c, size, mat, ry=0.0, solid=True):
        s = self.s
        if solid:
            b = s.node(name, "StaticBody3D", parent, {"transform": T3(*c, 0, ry, 0), "collision_mask": 0})
            mesh_node(s, b, "Mesh", s.sub_res("BoxMesh", size=V3(*size)), mat)
            s.node("Shape", "CollisionShape3D", b, {"shape": s.sub_res("BoxShape3D", size=V3(*size))})
            return b
        return mesh_node(s, parent, name, s.sub_res("BoxMesh", size=V3(*size)), mat, T3(*c, 0, ry, 0))

    def cyl(self, parent, name, c, r, h, mat, solid=True, seg=16):
        s = self.s
        b = s.node(name, "StaticBody3D" if solid else "Node3D", parent, {"transform": T3(*c)})
        mesh_node(s, b, "Mesh", s.sub_res("CylinderMesh", top_radius=r, bottom_radius=r, height=h, radial_segments=seg), mat)
        if solid:
            s.node("Shape", "CollisionShape3D", b, {"shape": s.sub_res("CylinderShape3D", radius=r, height=h)})
        return b

    def poster(self, parent, at, facing):
        """A torn hunter poster pasted on a wall facing +X (facing=1) or -X (facing=-1)."""
        s = self.s
        tex = s.ext_res("assets/generated/duel/poster_hunter.png")
        s.node("Poster", "Decal", parent, {"transform": T3(at[0], at[1], at[2], 0, 0, -facing * P2), "size": V3(1.5, .4, 2.0), "texture_albedo": tex,
                                           "modulate": col(1.0, 1.0, 1.0, .95), "upper_fade": 0.0, "lower_fade": 0.0, "cull_mask": 1})

    def env(self):
        s = self.s
        env = s.sub_res("Environment", background_mode=1, background_color=hexcol("#07070a"), ambient_light_source=2, ambient_light_color=hexcol("#6a7088"),
                        ambient_light_energy=0.9, tonemap_mode=3, tonemap_exposure=1.0, glow_enabled=True, glow_intensity=0.45, glow_bloom=0.0, glow_hdr_threshold=1.3,
                        fog_enabled=True, fog_light_color=hexcol("#2a2a32"), fog_density=0.006)
        s.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": env})
        s.node("Moon", "DirectionalLight3D", ".", {"transform": T3(0, 0, 0, -.75, 2.4, 0, order="YXZ"), "light_color": hexcol("#c6d0ff"), "light_energy": 1.5,
                                                   "shadow_enabled": True, "directional_shadow_max_distance": 120.0})
        # the city around the arena + the moon
        ring = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/backdrop_ring.gdshader"), **{"shader_parameter/city": s.ext_res("assets/generated/menu/city_02.jpg")})
        mesh_node(s, ".", "CityRing", s.sub_res("CylinderMesh", top_radius=230, bottom_radius=230, height=200, radial_segments=64, cap_top=False, cap_bottom=False), ring,
                  T3(0, 60, 0), cast_shadow=0)
        rain = s.sub_res("ParticleProcessMaterial", emission_shape=3, emission_box_extents=V3(60, .5, 30), direction=V3(.15, -1, 0), spread=2.0,
                         initial_velocity_min=16.0, initial_velocity_max=20.0, gravity=V3(0, -9.8, 0))
        s.node("Rain", "GPUParticles3D", ".", {"transform": T3(0, 34, 0), "amount": 2600, "lifetime": 1.6, "preprocess": 2.0, "process_material": rain,
                                               "draw_pass_1": s.sub_res("QuadMesh", size=V2(.012, .7)),
                                               "material_override": s.sub_res("StandardMaterial3D", shading_mode=0, transparency=1, albedo_color=hexcol("#a8b0c0", .22), billboard_mode=2, billboard_keep_scale=True),
                                               "cast_shadow": 0, "visibility_aabb": Raw("AABB(-62, -40, -32, 124, 42, 64)")})
        post = s.node("Post", "CanvasLayer", ".", {"layer": -1})
        s.node("Grade", "ColorRect", post, {"anchors_preset": 15, "anchor_right": 1.0, "anchor_bottom": 1.0, "mouse_filter": 2,
                                            "material": s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/game_post.gdshader"))})

    def street(self):
        s, c = self.s, self.city
        st = s.node("Street", "Node3D", c)
        asphalt = self.mat("asphalt_02", "#b0b0b8", .2, wet=.6, ol=False)
        self.block(st, "Ground", (0, -.5, 0), (130, 1, 70), asphalt)
        for z in (-9, 9):
            self.block(st, "Kerb", (0, .1, z), (100, .2, .4), self.mat("dirty_concrete", "#9a9aa2", .5))
            self.block(st, "Sidewalk", (0, .08, z + (4 if z > 0 else -4)), (100, .16, 7.6), self.mat("dirty_concrete", "#8a8a92", .3, wet=.3, ol=False))
        # wrecks and cover in the canyon
        for x, z, ry in ((-8, -3, .3), (9, 4, -2.6)):
            s.node("Wreck", None, st, {"transform": T3(x, 0, z, 0, ry, 0)}, instance="scenes/world/props/spacecraft.tscn")
        for x, z, ry in ((-2, 6, 1.2), (3, -6, .2), (14, -2, 1.6)):
            s.node("Barrier", None, st, {"transform": T3(x, 0, z, 0, ry, 0)}, instance="assets/models/kit/barrier.glb")
            self.block(st, "BarrierBody", (x, .625, z), (3.2, 1.25, .8), self.mat(None), ry)
        steam = s.sub_res("ParticleProcessMaterial", emission_shape=1, emission_sphere_radius=.4, direction=V3(0, 1, 0), spread=12.0,
                          initial_velocity_min=1.2, initial_velocity_max=2.2, gravity=V3(.3, .4, 0), scale_min=.8, scale_max=2.2,
                          color_ramp=s.sub_res("GradientTexture1D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.2, 1)"),
                                               colors=Raw("PackedColorArray(1, 1, 1, 0, 1, 1, 1, 0.35, 1, 1, 1, 0)"))))
        for x, z in ((-14, -6), (6, 7)):
            s.node("Steam", "GPUParticles3D", st, {"transform": T3(x, .1, z), "amount": 18, "lifetime": 4.0, "preprocess": 4.0, "process_material": steam,
                                                   "draw_pass_1": s.sub_res("QuadMesh", size=V2(1.6, 1.6)), "material_override": s.ext_res(M("fx_smoke_particle")), "cast_shadow": 0})
            self.block(st, "Grate", (x, .02, z), (1.4, .05, 1.4), self.mat("metal_grate_rusty", "#9a9aa2", 1.0), solid=False)

    def roof(self, side):
        """side -1 = west (host), +1 = east (challenger)."""
        s = self.s
        g = s.node("WestRoof" if side < 0 else "EastRoof", "Node3D", self.city)
        x0, top = 38 * side, (14 if side < 0 else 15)
        wall = self.s.sub_res("ShaderMaterial", shader=self.toon, next_pass=self.outline, **{"shader_parameter/albedo_tex": self.s.ext_res("assets/generated/duel/grime_wall.jpg"),
                              "shader_parameter/world_uv": True, "shader_parameter/world_scale": .12, "shader_parameter/tint": hexcol("#b8b8c0", 1, 1.5), "shader_parameter/desaturate": .6, "shader_parameter/bands": 3.0})
        self.block(g, "Tower", (x0, top / 2 - .5, 0), (28, top + 1, 36), wall)
        self.poster(g, (x0 - side * 14.03, 4.0, 11 * side), -side)
        self.poster(g, (x0 - side * 14.03, 6.5, -13 * side), -side)
        # lit window strips down the street face
        win = self.glow("#ff2a1a", 2.2)
        for k in range(4):
            y = 2.5 + k * 3.2
            if y < top - 1:
                self.block(g, "Windows", (x0 - side * 14.02, y, 0), (.05, .5, 30), win, solid=False)
        self.block(g, "Roof", (x0, top - .25, 0), (28.4, .5, 36.4), self.mat("dirty_concrete", "#b4b4bc", .3, wet=.2))
        rail = self.mat("rusty_metal_02", "#8a8a92", .5)
        par = self.mat("concrete_block_wall_02", "#7a7a84", .4)
        # parapet with firing gaps along the street edge, solid elsewhere
        ex = x0 - side * 13.8
        for z0, z1 in ((-18, -9), (-6, -1), (2, 7), (10, 18)):
            self.block(g, "Parapet", (ex, top + .55, (z0 + z1) / 2), (.5, 1.1, z1 - z0), par)
        for z in (-18, 18):
            self.block(g, "ParapetSide", (x0, top + .55, z), (28, 1.1, .5), par)
        self.block(g, "ParapetBack", (x0 + side * 13.8, top + .55, 0), (.5, 1.1, 36), par)
        corr = self.mat("rusty_corrugated_iron", "#a0a0a8", .4)
        shutter = self.mat("painted_metal_shutter", "#9a9aa2", .5)
        rust = self.mat("rusty_metal_02", "#a8a8b0", .5)
        if side < 0:
            # water tower perch (lift up), a shed, AC units
            tx, tz = x0 + 6, -10
            for dx in (-1.6, 1.6):
                for dz in (-1.6, 1.6):
                    self.block(g, "Leg", (tx + dx, top + 3, tz + dz), (.3, 6, .3), rail)
            self.cyl(g, "Tank", (tx, top + 8, tz), 2.6, 4.0, corr)
            self.block(g, "Deck", (tx, top + 6.1, tz), (6.4, .2, 6.4), self.mat("metal_grate_rusty", "#9a9aa2", .8))
            self.block(g, "DeckRail", (tx - 3.1, top + 6.7, tz), (.1, 1.0, 6.4), rail)
            s.node("Lift", None, g, {"transform": T3(tx - 4.2, top, tz + 1), "top": 6.4}, instance="scenes/world/props/lift.tscn")
            self.block(g, "Landing", (tx - 3.8, top + 6.05, tz + 1), (1.8, .2, 1.8), self.mat("metal_grate_rusty", "#9a9aa2", .8))
            self.block(g, "Shed", (x0 + 2, top + 1.8, 9), (6, 3.6, 4), corr)
            self.poster(g, (x0 - 1.03, top + 2.2, 10.2), -1)
            self.block(g, "ShedDoor", (x0 - 1.02, top + 1.4, 9), (.06, 2.6, 1.6), shutter, solid=False)
            for z, w in ((-2, 2.2), (3, 1.6)):
                self.block(g, "AC", (x0 - 6, top + .8, z), (w, 1.6, 2.4), rust)
        else:
            # neon billboard on a gantry (cover + light), crates, vents, an antenna
            bx = x0 - 4
            for z in (-4.5, 4.5):
                self.block(g, "Gantry", (bx, top + 3, z), (.4, 6, .4), rail)
            self.block(g, "BillboardBack", (bx, top + 5, 0), (.4, 4, 10), shutter)
            face = s.sub_res("StandardMaterial3D", shading_mode=0, albedo_texture=s.ext_res("assets/generated/duel/billboard_face.png"), albedo_color=col(1.6, 1.6, 1.6))
            mesh_node(s, g, "BillboardFace", s.sub_res("QuadMesh", size=V2(10, 4)), face, T3(bx - .21, top + 5, 0, 0, -P2, 0), cast_shadow=0)
            s.node("BillboardLight", "OmniLight3D", g, {"transform": T3(bx - 3, top + 5, 0), "light_color": hexcol("#ff2010"), "light_energy": 2.0, "omni_range": 9.0})
            for k, (x, z) in enumerate(((x0 - 7, -8), (x0 - 7, -6.2), (x0 - 5.3, -8))):
                self.block(g, "Crate", (x, top + .7 + (1.4 if k == 2 else 0) * 0, z), (1.4, 1.4, 1.4), rust)
            self.block(g, "Vent", (x0 - 8, top + .6, 8), (2.5, 1.2, 2.5), rust)
            self.cyl(g, "Mast", (x0 + 6, top + 6, -12), .12, 12, rail)
            s.node("MastBeacon", "MeshInstance3D", g, {"transform": T3(x0 + 6, top + 12.1, -12), "mesh": s.sub_res("SphereMesh", radius=.18, height=.36),
                                                      "material_override": s.ext_res(M("glow_red")), "script": s.ext_res("scripts/world/props/blinker.gd"), "rate": 2.5, "duty": .5})
            self.block(g, "Shed", (x0 + 3, top + 1.8, 10), (5, 3.6, 5), corr)
        # rooftop work light that flickers
        s.node("WorkLight", "SpotLight3D", g, {"transform": T3(x0 - side * 6, top + 4.5, -12, -1.5, 0, 0), "light_color": hexcol("#dfe4ff"), "light_energy": 0.7,
                                               "spot_range": 12.0, "spot_angle": 40.0, "shadow_enabled": True})

    def middle(self):
        s = self.s
        g = s.node("Canyon", "Node3D", self.city)
        rail = self.mat("rusty_metal_02", "#8a8a92", .5)
        grate = self.mat("metal_grate_rusty", "#9a9aa2", .8)
        # collapsed sky-bridge off the west tower: walkable deck, roof, a few glass panels left
        y = 9.0
        self.block(g, "BridgeDeck", (-16, y - .25, -2), (16, .5, 4.2), self.mat("dirty_concrete", "#9a9aa2", .35))
        self.block(g, "BridgeRoof", (-17, y + 3.6, -2), (14, .3, 4.2), self.mat("rusty_corrugated_iron", "#8a8a92", .4))
        self.block(g, "BrokenEnd", (-7.4, y - 1.2, -2, ), (1.6, .4, 4.2), self.mat("dirty_concrete", "#7a7a82", .35), 0.0)
        for k in range(3):
            s.node("Glass", None, g, {"transform": T3(-20 + k * 5, y + 1.8, -4.15, 0, P2, 0, s=(1, .75, .98))}, instance="scenes/world/props/glass_panel.tscn")
        s.node("BridgeLift", None, g, {"transform": T3(-21, 0, 2.2), "top": y}, instance="scenes/world/props/lift.tscn")
        self.block(g, "BridgeLanding", (-21, y - .1, 1.0), (1.8, .2, 2.4), grate)
        # fire-escape balcony on the east facade
        self.block(g, "Balcony", (21.4, 7, 0), (2.6, .2, 12), grate)
        self.block(g, "BalconyRail", (20.1, 7.6, 0), (.08, 1.0, 12), rail)
        for z in (-6, 6):
            self.block(g, "BalconyPost", (20.2, 3.5, z), (.15, 7, .15), rail)
        s.node("BalconyLift", None, g, {"transform": T3(19.0, 0, 6.8), "top": 7.0}, instance="scenes/world/props/lift.tscn")
        self.block(g, "BalconyLanding", (19.4, 6.95, 6.0), (1.6, .2, 1.4), grate)
        # red neon along the canyon
        for x, z, c in ((-23.9, 8, "#ff1a10"), (23.9, -8, "#ff2a1a")):
            s.node("Neon", "OmniLight3D", g, {"transform": T3(x - .8 * (1 if x > 0 else -1), 4, z), "light_color": hexcol(c), "light_energy": 0.8, "omni_range": 7.0})
            s.node("Sign", None, g, {"transform": T3(x - .1 * (1 if x > 0 else -1), 4.5, z, 0, -P2 if x > 0 else P2, 0), "text": "HOTEL" if x < 0 else "BAR",
                                     "size": V2(4, 1.1), "color": hexcol(c), "vertical": False}, instance="scenes/world/props/neon_sign.tscn")
        # side towers closing the canyon (and invisible walls)
        wall = self.mat("concrete_block_wall_02", "#6a6a74", .15)
        win = self.glow("#ff1a10", 1.6)
        for z in (-30, 30):
            self.block(g, "SideTower", (0, 20, z), (120, 40, 8), wall)
            for k in range(6):
                self.block(g, "SideWindows", (0, 4 + k * 5.5, z - 4.02 * (1 if z > 0 else -1)), (110, .3, .05), win, solid=False)
        for x in (-64, 64):
            self.block(g, "EndWall", (x, 25, 0), (2, 50, 70), wall)
        b = s.node("Bounds", "StaticBody3D", g, {"collision_mask": 0})
        s.node("Ceiling", "CollisionShape3D", b, {"transform": T3(0, 45, 0), "shape": s.sub_res("BoxShape3D", size=V3(130, 1, 70))})

    def save(self):
        self.street()
        self.roof(-1)
        self.roof(1)
        self.middle()
        self.s.save("scenes/world/arena_duel.tscn")


def build_duel_arena():
    Duel().save()


if __name__ == "__main__":
    build_duel_arena()
    print("duel arena ok")
