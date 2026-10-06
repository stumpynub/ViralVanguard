"""Reusable prop scenes (buildings, signs, barriers, cars...), effect scenes, the spider and the player."""
import math
from godot_writer import *

P2 = math.pi / 2
M = lambda n: "assets/materials/%s.tres" % n


def mesh_node(s, parent, name, mesh, mat, t=None, **extra):
    props = {"mesh": mesh}
    if t is not None:
        props["transform"] = t
    if mat is not None:
        props["material_override"] = mat
    props.update(extra)
    return s.node(name, "MeshInstance3D", parent, props)


def static_box(s, parent, name, size, t, layer=1):
    b = s.node(name, "StaticBody3D", parent, {"collision_layer": layer, "collision_mask": 0})
    s.node("Shape", "CollisionShape3D", b, {"transform": t, "shape": s.sub_res("BoxShape3D", size=size)})
    return b


def pool(s, parent, name, color_hex, radius, strength=0.5, t=None):
    """Additive light pool on the ground (stand-in for a real light, like the original)."""
    mat = s.sub_res("ShaderMaterial", resource_local_to_scene=True, shader=s.ext_res("assets/shaders/light_pool.gdshader"),
                    **{"shader_parameter/color": hexcol(color_hex), "shader_parameter/strength": strength})
    return mesh_node(s, parent, name, s.sub_res("QuadMesh", size=V2(radius * 2, radius * 2), orientation=1), mat, t or T3(0, 0.03, 0), cast_shadow=0)


# ---------------------------------------------------------------- city kit
def building():
    s = Scene("Building", "Node3D", {"script": None})
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/building.gd")
    loc = dict(resource_local_to_scene=True)
    mesh_node(s, ".", "Facade", s.sub_res("BoxMesh", size=V3(16, 24, 16), **loc), s.ext_res(M("facade_residential")), T3(0, 12, 0))
    mesh_node(s, ".", "ShopBand", s.sub_res("BoxMesh", size=V3(16, 4.5, 16), **loc), s.ext_res(M("shopfront")), T3(0, 2.25, 0), visible=False)
    mesh_node(s, ".", "ShopLedge", s.sub_res("BoxMesh", size=V3(16.2, .18, 16.2), **loc), s.ext_res(M("metal_dark")), T3(0, 4.55, 0), visible=False)
    mesh_node(s, ".", "Roof", s.sub_res("BoxMesh", size=V3(16.3, .3, 16.3), **loc), s.ext_res(M("roof")), T3(0, 24.15, 0))
    mesh_node(s, ".", "RoofTrim", s.sub_res("BoxMesh", size=V3(16.3, .06, .06), **loc), s.ext_res(M("glow_magenta")), T3(0, 24.32, 8.13), cast_shadow=0)
    b = s.node("Body", "StaticBody3D", ".", {"collision_mask": 0})
    s.node("Shape", "CollisionShape3D", b, {"transform": T3(0, 12, 0), "shape": s.sub_res("BoxShape3D", size=V3(16, 24, 16), **loc)})
    s.save("scenes/world/props/building.tscn")


def neon_sign():
    s = Scene("NeonSign", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/neon_sign.gd")
    loc = dict(resource_local_to_scene=True)
    mesh_node(s, ".", "Rim", s.sub_res("BoxMesh", size=V3(3.08, .83, .04), **loc),
              s.sub_res("StandardMaterial3D", albedo_color=hexcol("#ff2bd6"), emission_enabled=True, emission=hexcol("#ff2bd6"), emission_energy_multiplier=2.0, **loc), T3(0, 0, -.03), cast_shadow=0)
    mesh_node(s, ".", "Backing", s.sub_res("BoxMesh", size=V3(3, .75, .08), **loc), s.sub_res("StandardMaterial3D", albedo_color=hexcol("#06040e"), roughness=0.4), cast_shadow=0)
    s.node("Label", "Label3D", ".", {"transform": T3(0, 0, .05), "text": "NOODLES", "font_size": 64, "outline_size": 18, "pixel_size": 0.006,
                                     "modulate": col(2.6, .45, 2.2), "outline_modulate": hexcol("#ff2bd6", .6), "double_sided": False, "shaded": False,
                                     "font": s.sub_res("SystemFont", font_names=Raw('PackedStringArray("Impact", "Arial Black", "DejaVu Sans")'), font_weight=900)})
    s.save("scenes/world/props/neon_sign.tscn")


def billboard():
    s = Scene("Billboard", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/billboard.gd")
    loc = dict(resource_local_to_scene=True)
    mesh_node(s, ".", "Frame", s.sub_res("BoxMesh", size=V3(14.8, 14.8, .3), **loc), s.ext_res(M("metal_dark")), T3(0, 0, -.2))
    mesh_node(s, ".", "Screen", s.sub_res("QuadMesh", size=V2(14, 14), **loc),
              s.sub_res("ShaderMaterial", resource_local_to_scene=True, shader=s.ext_res("assets/shaders/billboard.gdshader")), cast_shadow=0)
    font = s.sub_res("SystemFont", font_names=Raw('PackedStringArray("Impact", "Arial Black", "DejaVu Sans")'), font_weight=900)
    s.node("Title", "Label3D", ".", {"text": "VOLT COLA", "font": font, "font_size": 96, "outline_size": 24, "horizontal_alignment": 0, "shaded": False, "double_sided": False, "pixel_size": .015})
    s.node("Slogan", "Label3D", ".", {"text": "CHARGE UP", "font": font, "font_size": 64, "outline_size": 8, "horizontal_alignment": 0, "shaded": False, "double_sided": False, "pixel_size": .009})
    s.save("scenes/world/props/billboard.tscn")


def tinted(name, paint="#2a2a3a", glow="#21e6ff"):
    s = Scene(name, "Node3D")
    s.nodes[0][3].update({"script": s.ext_res("scripts/world/props/tinted_prop.gd"), "paint": hexcol(paint), "glow": hexcol(glow)})
    return s


def local_glow(s, hexc, energy=2.6):
    return s.sub_res("StandardMaterial3D", resource_local_to_scene=True, albedo_color=hexcol(hexc), emission_enabled=True, emission=hexcol(hexc), emission_energy_multiplier=energy)


def jersey_barrier():
    """Quarantine jersey barrier: 1.2 m low cover with knee strobes and a stencil."""
    s = tinted("JerseyBarrier", "#2a2830", "#8a3bff")
    mat = s.ext_res(M("barrier"))
    mesh_node(s, ".", "Base", s.sub_res("BoxMesh", size=V3(3.2, .5, .8)), mat, T3(0, .25, 0))
    mesh_node(s, ".", "Wall", s.sub_res("BoxMesh", size=V3(3.2, .7, .46)), mat, T3(0, .85, 0))
    mesh_node(s, ".", "TopGlow", s.sub_res("BoxMesh", size=V3(3.2, .05, .12)), local_glow(s, "#8a3bff"), T3(0, 1.215, 0), cast_shadow=0)
    strobe = s.ext_res("scripts/world/props/blinker.gd")
    red = s.ext_res(M("glow_red"))
    sm = s.sub_res("BoxMesh", size=V3(.18, .1, .04))
    k = 0
    for sx in (-1, 1):
        for f in (-1, 1):
            n = mesh_node(s, ".", "Strobe", sm, red, T3(sx * 1.35, .45, f * .42), cast_shadow=0)
            s.nodes[-1][3].update({"script": strobe, "rate": 7.0, "duty": 0.2, "phase": k * 0.7})
            k += 1
    for f, ry in ((1, 0), (-1, math.pi)):
        s.node("Stencil", "Label3D", ".", {"transform": T3(0, .82, f * .236, 0, ry, 0), "text": "QUARANTINE - DO NOT CROSS", "font_size": 40,
                                           "pixel_size": .0024, "modulate": hexcol("#ffd23c"), "outline_size": 0, "double_sided": False})
    static_box(s, ".", "Body", V3(3.2, 1.2, .8), T3(0, .6, 0))
    pool(s, ".", "Pool", "#ff3355", 2.4, .25)
    s.nodes[0][3].update({"paint_targets": Raw('Array[NodePath]([])'), "glow_targets": Raw('Array[NodePath]([NodePath("TopGlow")])'),
                          "pool_targets": Raw('Array[NodePath]([])')})
    s.save("scenes/world/props/jersey_barrier.tscn")


def planter():
    s = tinted("Planter", "#34323c", "#14b8a6")
    mesh_node(s, ".", "Box", s.sub_res("BoxMesh", size=V3(3, 1, 1.2)), s.ext_res(M("planter")), T3(0, .5, 0))
    mesh_node(s, ".", "Trim", s.sub_res("BoxMesh", size=V3(3.04, .05, 1.24)), local_glow(s, "#14b8a6", 2.0), T3(0, 1.0, 0), cast_shadow=0)
    bush = s.sub_res("SphereMesh", radius=.5, height=.55, radial_segments=10, rings=6)
    for o in (-1, 0, 1):
        mesh_node(s, ".", "Shrub", bush, s.ext_res(M("foliage")), T3(o * .95, 1.08, 0, s=(1.1, 1, 1)))
    static_box(s, ".", "Body", V3(3, 1.2, 1.2), T3(0, .6, 0))
    s.nodes[0][3].update({"glow_targets": Raw('Array[NodePath]([NodePath("Trim")])')})
    s.save("scenes/world/props/planter.tscn")


def hover_car():
    """Parked hover car: cover you can vault."""
    s = tinted("HoverCar", "#5a1a4a", "#21e6ff")
    body = s.sub_res("StandardMaterial3D", resource_local_to_scene=True, albedo_color=hexcol("#5a1a4a"), metallic=0.8, roughness=0.3, clearcoat_enabled=True, clearcoat=0.8)
    mesh_node(s, ".", "Body", s.sub_res("BoxMesh", size=V3(2.1, .7, 4.4)), body, T3(0, .75, 0))
    mesh_node(s, ".", "Canopy", s.sub_res("BoxMesh", size=V3(1.7, .55, 2.1)), s.ext_res(M("canopy")), T3(0, 1.35, -.2))
    mesh_node(s, ".", "UnderGlow", s.sub_res("BoxMesh", size=V3(1.9, .05, 4)), local_glow(s, "#21e6ff"), T3(0, .38, 0), cast_shadow=0)
    lamp = s.sub_res("BoxMesh", size=V3(.5, .12, .05))
    for sx in (-1, 1):
        mesh_node(s, ".", "TailLight", lamp, s.ext_res(M("glow_red")), T3(sx * .7, .85, -2.22), cast_shadow=0)
        mesh_node(s, ".", "HeadLight", lamp, s.ext_res(M("glow_white")), T3(sx * .7, .85, 2.22), cast_shadow=0)
    static_box(s, ".", "Collision", V3(2.1, 1.6, 4.4), T3(0, .8, 0))
    pool(s, ".", "Pool", "#21e6ff", 3.2, .5)
    s.nodes[0][3].update({"paint_targets": Raw('Array[NodePath]([NodePath("Body")])'), "glow_targets": Raw('Array[NodePath]([NodePath("UnderGlow")])'),
                          "pool_targets": Raw('Array[NodePath]([NodePath("Pool")])')})
    s.save("scenes/world/props/hover_car.tscn")


def street_lamp():
    s = tinted("StreetLamp", "#2a2a38", "#21e6ff")
    pole = s.ext_res(M("metal_pole"))
    mesh_node(s, ".", "Pole", s.sub_res("CylinderMesh", top_radius=.1, bottom_radius=.1, height=7.2, radial_segments=8), pole, T3(0, 3.6, 0))
    mesh_node(s, ".", "Arm", s.sub_res("BoxMesh", size=V3(.14, .14, 2.6)), pole, T3(0, 7.2, 1.3))
    mesh_node(s, ".", "LightBar", s.sub_res("BoxMesh", size=V3(.34, .09, 1.8)), local_glow(s, "#21e6ff", 3.0), T3(0, 7.11, 2.0), cast_shadow=0)
    mesh_node(s, ".", "BaseRing", s.sub_res("BoxMesh", size=V3(.22, .04, .22)), s.ext_res(M("glow_white")), T3(0, 1.1, 0), cast_shadow=0)
    pool(s, ".", "Pool", "#21e6ff", 6, .55, T3(0, .03, 2.2))
    static_box(s, ".", "Body", V3(.3, 7.2, .3), T3(0, 3.6, 0))
    s.nodes[0][3].update({"glow_targets": Raw('Array[NodePath]([NodePath("LightBar")])'), "pool_targets": Raw('Array[NodePath]([NodePath("Pool")])')})
    s.save("scenes/world/props/street_lamp.tscn")


def vending_machine():
    s = tinted("VendingMachine", "#1a1a26", "#21e6ff")
    mesh_node(s, ".", "Cabinet", s.sub_res("BoxMesh", size=V3(1, 2.2, .9)), s.ext_res(M("vending")), T3(0, 1.1, 0))
    mesh_node(s, ".", "Front", s.sub_res("QuadMesh", size=V2(.8, 1.5)), local_glow(s, "#21e6ff", 2.2), T3(0, 1.25, .46), cast_shadow=0)
    static_box(s, ".", "Body", V3(1.1, 2.2, 1.1), T3(0, 1.1, 0))
    pool(s, ".", "Pool", "#21e6ff", 2.2, .6, T3(0, .03, .8))
    s.nodes[0][3].update({"glow_targets": Raw('Array[NodePath]([NodePath("Front")])'), "pool_targets": Raw('Array[NodePath]([NodePath("Pool")])')})
    s.save("scenes/world/props/vending_machine.tscn")


def storage_tank():
    s = Scene("StorageTank", "Node3D")
    tank = s.ext_res(M("tank"))
    mesh_node(s, ".", "Shell", s.sub_res("CylinderMesh", top_radius=5, bottom_radius=5, height=12, radial_segments=32), tank, T3(0, 6, 0))
    mesh_node(s, ".", "Dome", s.sub_res("SphereMesh", radius=5, height=5, is_hemisphere=True, radial_segments=24, rings=8), tank, T3(0, 12, 0, s=(1, .7, 1)))
    ring = s.sub_res("TorusMesh", inner_radius=4.98, outer_radius=5.1, rings=48, ring_segments=6)
    for y in (2, 5, 8, 11):
        mesh_node(s, ".", "Band", ring, s.ext_res(M("glow_orange")), T3(0, y, 0), cast_shadow=0)
    b = s.node("Body", "StaticBody3D", ".", {"collision_mask": 0})
    s.node("Shape", "CollisionShape3D", b, {"transform": T3(0, 6.5, 0), "shape": s.sub_res("CylinderShape3D", height=13, radius=5)})
    s.save("scenes/world/props/storage_tank.tscn")


def crate_block():
    s = Scene("CrateBlock", "StaticBody3D", {"collision_mask": 0}, groups=["blocks"])
    s.nodes[0][3]["script"] = s.ext_res("scripts/world/props/crate_block.gd")
    mesh_node(s, ".", "Mesh", s.sub_res("BoxMesh", size=V3(2, 2, 2)), s.ext_res(M("crate_steel")))
    s.node("Shape", "CollisionShape3D", ".", {"shape": s.sub_res("BoxShape3D", size=V3(2, 2, 2))})
    s.save("scenes/world/props/crate_block.tscn")


def spire():
    """Central Spire: 70 m tower with glowing rings, needle, blinking beacon, rotating halos and the 24 m sniper deck."""
    s = Scene("Spire", "Node3D")
    mesh_node(s, ".", "Core", s.sub_res("CylinderMesh", top_radius=3.6, bottom_radius=5, height=70, radial_segments=8), s.ext_res(M("facade_commercial")), T3(0, 35.4, 0))
    for k, (y, r, c) in enumerate(((12, 6.8, "cyan"), (24, 6.3, "magenta"), (40, 5.6, "violet"), (58, 4.9, "cyan"))):
        mesh_node(s, ".", "Ring", s.sub_res("TorusMesh", inner_radius=r - .16, outer_radius=r + .16, rings=64, ring_segments=8), s.ext_res(M("glow_" + c)), T3(0, y, 0), cast_shadow=0)
        mesh_node(s, ".", "Collar", s.sub_res("CylinderMesh", top_radius=r - .25, bottom_radius=r - .25, height=.45, radial_segments=32), s.ext_res(M("metal_dark")), T3(0, y - .25, 0))
    for i in range(8):
        a = (i + .5) / 8 * math.pi * 2
        mesh_node(s, ".", "Rib", s.sub_res("BoxMesh", size=V3(.16, 70, .16)), s.ext_res(M("glow_magenta" if i % 2 else "glow_cyan")),
                  T3(math.sin(a) * 4.4, 35.4, math.cos(a) * 4.4, -math.atan2(1.4, 70) * 0, a, 0, order="YXZ"), cast_shadow=0)
    mesh_node(s, ".", "Cap", s.sub_res("CylinderMesh", top_radius=3.9, bottom_radius=3.9, height=2.2, radial_segments=16), s.ext_res(M("metal_dark")), T3(0, 71.6, 0))
    mesh_node(s, ".", "Needle", s.sub_res("CylinderMesh", top_radius=.1, bottom_radius=2, height=40, radial_segments=8), s.ext_res(M("metal_mid")), T3(0, 92.6, 0))
    for i in range(4):
        a = i * P2 + .4
        mesh_node(s, ".", "NeedleGlow", s.sub_res("BoxMesh", size=V3(.08, 38, .08)), s.ext_res(M("glow_cyan")), T3(math.sin(a), 91, math.cos(a)), cast_shadow=0)
    mesh_node(s, ".", "Beacon", s.sub_res("SphereMesh", radius=.7, height=1.4), s.ext_res(M("glow_red")), T3(0, 113, 0), cast_shadow=0)
    s.nodes[-1][3].update({"script": s.ext_res("scripts/world/props/blinker.gd"), "rate": 3.0, "duty": 0.6})
    halo = s.node("Halos", "Node3D", ".")
    spin = s.ext_res("scripts/world/props/spinner.gd")
    for i, c in enumerate(("cyan", "magenta", "violet")):
        h = s.node("Halo", "Node3D", halo, {"transform": T3(0, 18 + i * 10, 0, (i - 1) * .18), "script": spin, "speed": -0.25 if i % 2 else 0.35})
        mesh_node(s, h, "Ring", s.sub_res("TorusMesh", inner_radius=9 + i * 2.4 - .07, outer_radius=9 + i * 2.4 + .07, rings=128, ring_segments=6), s.ext_res(M("glow_" + c)), cast_shadow=0)
    for ry in (0, math.pi):
        s.node("Billboard", None, ".", {"transform": T3(math.sin(ry) * 5.36, 32, math.cos(ry) * 5.36, 0, ry, 0), "size": V2(7, 14),
                                        "title": "NEO-KAIRO" if ry else "AURORA", "slogan": "NIGHT NEVER ENDS" if ry else "THINK FASTER",
                                        "color_a": hexcol("#ff2bd6" if ry else "#21e6ff"), "color_b": hexcol("#2f8bff" if ry else "#8a3bff")},
               instance="scenes/world/props/billboard.tscn")
    static_box(s, ".", "Body", V3(10, 90, 10), T3(0, 45, 0))
    # sniper deck at 24 m: a ring platform around the core, reached by grapple
    deck = s.node("SniperDeck", "CSGCombiner3D", ".", {"use_collision": True, "collision_mask": 0})
    s.node("Platform", "CSGCylinder3D", deck, {"transform": T3(0, 23.7, 0), "radius": 10.9, "height": .6, "sides": 48, "material": s.ext_res(M("metal_dark"))})
    s.node("CoreCut", "CSGBox3D", deck, {"transform": T3(0, 23.7, 0), "operation": 2, "size": V3(10, 1, 10)})
    s.node("Parapet", "CSGCylinder3D", deck, {"transform": T3(0, 24.6, 0), "radius": 10.9, "height": 1.2, "sides": 48, "material": s.ext_res(M("metal_dark"))})
    s.node("ParapetHollow", "CSGCylinder3D", deck, {"transform": T3(0, 24.6, 0), "operation": 2, "radius": 10.6, "height": 1.4, "sides": 48})
    for a in (math.pi / 4, math.pi * 5 / 4):
        s.node("CrouchShield", "CSGBox3D", deck, {"transform": T3(math.sin(a) * 8.3, 24.6, math.cos(a) * 8.3, 0, a, 0), "size": V3(2.4, 1.2, .35), "material": s.ext_res(M("metal_dark"))})
    for r, c, y in ((10.95, "violet", 23.42), (7.6, "cyan", 24.04)):
        mesh_node(s, ".", "DeckGlow", s.sub_res("TorusMesh", inner_radius=r - .06, outer_radius=r + .06, rings=96, ring_segments=6), s.ext_res(M("glow_" + c)), T3(0, y, 0), cast_shadow=0)
    mesh_node(s, ".", "RailGlow", s.sub_res("TorusMesh", inner_radius=10.7, outer_radius=10.8, rings=96, ring_segments=6), s.ext_res(M("glow_violet")), T3(0, 25.22, 0), cast_shadow=0)
    s.save("scenes/world/props/spire.tscn")


def plaza():
    s = Scene("Plaza", "Node3D")
    mesh_node(s, ".", "Paving", s.sub_res("CylinderMesh", top_radius=25.5, bottom_radius=25.5, height=.1, radial_segments=96), s.ext_res(M("paver")), T3(0, .05, 0))
    for r, c in ((24.6, "cyan"), (20, "magenta"), (15.2, "violet"), (9.6, "cyan")):
        mesh_node(s, ".", "LightRing", s.sub_res("TorusMesh", inner_radius=r - .12, outer_radius=r + .12, rings=128, ring_segments=4), s.ext_res(M("glow_" + c)), T3(0, .11, 0, s=(1, .15, 1)), cast_shadow=0)
    inlay = s.sub_res("BoxMesh", size=V3(.08, .02, 4.2))
    for i in range(24):
        a = i / 24 * math.pi * 2
        mesh_node(s, ".", "Inlay", inlay, s.ext_res(M("glow_blue")), T3(math.sin(a) * 17.6, .11, math.cos(a) * 17.6, 0, a, 0), cast_shadow=0)
    mesh_node(s, ".", "Podium", s.sub_res("CylinderMesh", top_radius=12.4, bottom_radius=12.4, height=.24, radial_segments=64), s.ext_res(M("plaza")), T3(0, .12, 0))
    mesh_node(s, ".", "PodiumTop", s.sub_res("CylinderMesh", top_radius=10, bottom_radius=10, height=.2, radial_segments=64), s.ext_res(M("metal_dark")), T3(0, .3, 0))
    b = s.node("Body", "StaticBody3D", ".", {"collision_mask": 0})
    s.node("Shape", "CollisionShape3D", b, {"transform": T3(0, .2, 0), "shape": s.sub_res("CylinderShape3D", height=.4, radius=12.4)})
    pool(s, ".", "Pool", "#8a3bff", 30, .5, T3(0, .14, 0))
    for i in range(24):   # bollards
        a = i / 24 * math.pi * 2 + .07
        if abs(math.sin(a * 2)) < .35:
            continue
        x, z = math.sin(a) * 23.4, math.cos(a) * 23.4
        mesh_node(s, ".", "Bollard", s.sub_res("CylinderMesh", top_radius=.14, bottom_radius=.14, height=.9, radial_segments=8), s.ext_res(M("metal_pole")), T3(x, .45, z))
        mesh_node(s, ".", "BollardCap", s.sub_res("BoxMesh", size=V3(.3, .06, .3)), s.ext_res(M("glow_magenta" if i % 2 else "glow_cyan")), T3(x, .93, z), cast_shadow=0)
    s.save("scenes/world/props/plaza.tscn")


def ring_walkway():
    """Elevated ring walkway around the plaza (deck at 9 m) on four pylons."""
    s = Scene("RingWalkway", "Node3D")
    deck = s.node("Deck", "CSGCombiner3D", ".", {"use_collision": True, "collision_mask": 0})
    s.node("Outer", "CSGCylinder3D", deck, {"transform": T3(0, 8.5, 0), "radius": 33.2, "height": 1.0, "sides": 96, "material": s.ext_res(M("metal_dark"))})
    s.node("Inner", "CSGCylinder3D", deck, {"transform": T3(0, 8.5, 0), "operation": 2, "radius": 28.4, "height": 1.2, "sides": 96})
    for r in (28.45, 33.15):
        mesh_node(s, ".", "UnderGlow", s.sub_res("TorusMesh", inner_radius=r - .06, outer_radius=r + .06, rings=160, ring_segments=6), s.ext_res(M("glow_violet")), T3(0, 7.95, 0), cast_shadow=0)
        mesh_node(s, ".", "Rail", s.sub_res("TorusMesh", inner_radius=r - .05, outer_radius=r + .05, rings=160, ring_segments=6), s.ext_res(M("glow_magenta")), T3(0, 10.1, 0), cast_shadow=0)
    for i in range(4):
        a = math.pi / 4 + i * P2
        x, z = math.sin(a) * 30.8, math.cos(a) * 30.8
        p = s.node("Pylon", "StaticBody3D", ".", {"transform": T3(x, 0, z, 0, a, 0), "collision_mask": 0})
        mesh_node(s, p, "Column", s.sub_res("CylinderMesh", top_radius=.8, bottom_radius=.8, height=9, radial_segments=8), s.ext_res(M("metal_dark")), T3(0, 4.5, 0))
        mesh_node(s, p, "Strip", s.sub_res("BoxMesh", size=V3(1.65, 8.6, .08)), s.ext_res(M("glow_cyan")), T3(0, 4.5, 0), cast_shadow=0)
        s.node("Shape", "CollisionShape3D", p, {"transform": T3(0, 4.5, 0), "shape": s.sub_res("CylinderShape3D", height=9, radius=.85)})
    s.save("scenes/world/props/ring_walkway.tscn")


def stair_tower():
    """Stair run from the ring walkway (landing at 9 m) down to the street, 15 m long. Visual treads over a smooth ramp."""
    s = Scene("StairTower", "Node3D")
    run, rise = 15.25, 9.15
    L = math.hypot(run, rise)
    th = math.atan2(rise, run)
    land = s.node("Landing", "CSGBox3D", ".", {"transform": T3(0, 8.7, 0), "size": V3(4, .6, 4), "use_collision": True, "collision_mask": 0, "material": s.ext_res(M("metal_dark"))})
    steps = [(0.0, 0.0)]
    for k in range(30):
        z, y = .5 * k, 9.15 - .3 * k
        steps += [(z, y), (z + .5, y)]
    steps += [(15.25, 0.0)]
    poly = "PackedVector2Array(" + ", ".join("%s, %s" % (num(z), num(y)) for z, y in steps) + ")"
    s.node("Treads", "CSGPolygon3D", ".", {"transform": T3(2.0, 0, 2.0, 0, -P2, 0), "polygon": Raw(poly), "depth": 4.0, "material": s.ext_res(M("metal_mid"))})
    tread_glow = s.sub_res("BoxMesh", size=V3(3.9, .02, .06))
    for k in range(0, 30, 5):
        mesh_node(s, ".", "Nosing", tread_glow, s.ext_res(M("glow_cyan")), T3(0, 9.17 - .3 * k, 2.47 + .5 * k), cast_shadow=0)
    ramp = s.node("Ramp", "StaticBody3D", ".", {"collision_mask": 0})
    s.node("Shape", "CollisionShape3D", ramp, {"transform": T3(0, rise / 2 - .25 * math.cos(th), 2 + run / 2, th), "shape": s.sub_res("BoxShape3D", size=V3(4.1, .5, L))})
    for ex in (-2.05, 2.05):
        mesh_node(s, ".", "Handrail", s.sub_res("BoxMesh", size=V3(.06, .06, L)), s.ext_res(M("glow_magenta")), T3(ex, rise / 2 + 1.08, 2 + run / 2, th), cast_shadow=0)
        mesh_node(s, ".", "Stringer", s.sub_res("BoxMesh", size=V3(.08, .3, L)), s.ext_res(M("metal_dark")), T3(ex, rise / 2, 2 + run / 2, th))
    mesh_node(s, ".", "BackWall", s.sub_res("BoxMesh", size=V3(4.1, 8.2, .06)), s.ext_res(M("metal_dark")), T3(0, 4.1, 2.02))
    pool(s, ".", "Pool", "#21e6ff", 3, .5, T3(0, .03, 18.5))
    s.save("scenes/world/props/stair_tower.tscn")


# ---------------------------------------------------------------- effects
def particles(s, parent, name, amount, lifetime, mesh, mat, pm, tint=False, explosiveness=1.0, t=None):
    props = {"emitting": False, "amount": amount, "lifetime": lifetime, "one_shot": True, "explosiveness": explosiveness,
             "process_material": pm, "draw_pass_1": mesh, "cast_shadow": 0, "visibility_aabb": Raw("AABB(-8, -8, -8, 16, 16, 16)")}
    if mat is not None:
        props["material_override"] = mat
    if t is not None:
        props["transform"] = t
    return s.node(name, "GPUParticles3D", parent, props, groups=["tint"] if tint else None)


def pmat(s, direction=(0, 1, 0), spread=45, vmin=1, vmax=4, gravity=(0, -9.8, 0), smin=1, smax=1, color="#ffffff", alpha_fade=True, grow=None, damping=0.0, box=None):
    props = dict(direction=V3(*direction), spread=spread, initial_velocity_min=vmin, initial_velocity_max=vmax, gravity=V3(*gravity),
                 scale_min=smin, scale_max=smax, color=hexcol(color), damping_min=damping, damping_max=damping)
    if box:
        props.update(emission_shape=3, emission_box_extents=V3(*box))
    curve = None
    if alpha_fade:
        props["color_ramp"] = s.sub_res("GradientTexture1D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.6, 1)"),
                                        colors=Raw("PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0.7, 1, 1, 1, 0)")))
    if grow:
        props["scale_curve"] = s.sub_res("CurveTexture", curve=s.sub_res("Curve", _data=Raw("[Vector2(0, %s), 0.0, 0.0, 0, 0, Vector2(1, 1), 0.0, 0.0, 0, 0]" % num(grow)), point_count=2))
    return s.sub_res("ParticleProcessMaterial", **props)


def fx_root(name, lifetime, light=None, fade=.25):
    s = Scene(name, "Node3D")
    s.nodes[0][3].update({"script": s.ext_res("scripts/fx/one_shot_fx.gd"), "lifetime": lifetime, "light_fade": fade})
    if light:
        s.node("Flash", "OmniLight3D", ".", {"light_color": hexcol(light[0]), "light_energy": light[1], "omni_range": light[2]}, groups=["tint"] if len(light) > 3 else None)
        s.nodes[0][3]["light"] = NodeRef("Flash")
    return s


def build_fx():
    glowp = M("fx_glow_particle")
    smokep = M("fx_smoke_particle")
    # tracer
    s = Scene("Tracer", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/fx/tracer.gd")
    add = s.ext_res(M("fx_additive"))
    mesh_node(s, ".", "Head", s.sub_res("BoxMesh", size=V3(.024, .024, 1)), add, cast_shadow=0)
    mesh_node(s, ".", "Trail", s.sub_res("BoxMesh", size=V3(.007, .007, 1)), add, cast_shadow=0)
    s.nodes[0][3].update({"head": NodeRef("Head"), "trail": NodeRef("Trail")})
    s.save("scenes/fx/tracer.tscn")
    # bullet impact (oriented so -Z is the surface normal)
    s = fx_root("Impact", 6.0, ("#ffd9a0", 2.0, 3.0, 1), .08)
    q = s.sub_res("QuadMesh", size=V2(.06, .06))
    particles(s, ".", "Sparks", 12, .45, q, s.ext_res(glowp), pmat(s, (0, 0, -1), 50, 4, 12, smin=.6, smax=1.2, color="#ffb060", damping=1.0))
    particles(s, ".", "Chips", 5, 1.2, s.sub_res("BoxMesh", size=V3(.03, .02, .03)), s.ext_res(M("fx_debris")), pmat(s, (0, 0, -1), 40, 2, 5, (0, -14, 0), color="#3a3a40", alpha_fade=False))
    particles(s, ".", "Dust", 3, 1.1, s.sub_res("QuadMesh", size=V2(.5, .5)), s.ext_res(smokep), pmat(s, (0, 0, -1), 20, .4, .9, (0, .25, 0), color="#8a8c96", grow=.2), explosiveness=.9)
    hole = s.sub_res("GradientTexture2D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.2, 0.3, 0.55, 1)"),
                     colors=Raw("PackedColorArray(0, 0, 0, 1, 0.03, 0.03, 0.04, 1, 0.12, 0.12, 0.13, 0.9, 0.08, 0.07, 0.08, 0.45, 0, 0, 0, 0)")),
                     fill=1, fill_from=V2(.5, .5), fill_to=V2(1, .5), width=64, height=64)
    s.node("Hole", "Decal", ".", {"transform": T3(0, 0, 0, -P2), "size": V3(.18, .3, .18), "texture_albedo": hole, "cull_mask": 1})
    s.save("scenes/fx/impact.tscn")
    # explosion
    s = fx_root("Explosion", 3.0, ("#ffb070", 10.0, 16.0, 1), .35)
    particles(s, ".", "Fireball", 12, .6, s.sub_res("QuadMesh", size=V2(1.8, 1.8)), s.ext_res(glowp), pmat(s, (0, 1, 0), 180, .5, 3.5, (0, 1, 0), .6, 1.4, "#ff8a30", grow=.4), tint=True)
    particles(s, ".", "Core", 3, .3, s.sub_res("QuadMesh", size=V2(3.2, 3.2)), s.ext_res(glowp), pmat(s, (0, 1, 0), 180, 0, .5, (0, 0, 0), 1, 1, "#ffe0b0"))
    particles(s, ".", "Smoke", 8, 2.6, s.sub_res("QuadMesh", size=V2(3, 3)), s.ext_res(smokep), pmat(s, (0, 1, 0), 60, .6, 2.0, (0, .4, 0), .7, 1.3, "#4a4b52", grow=.3, damping=.8), explosiveness=.8)
    particles(s, ".", "Sparks", 40, 1.0, s.sub_res("QuadMesh", size=V2(.08, .08)), s.ext_res(glowp), pmat(s, (0, 1, 0), 90, 6, 20, (0, -9.8, 0), .6, 1.4, "#ffa040", damping=1.2))
    particles(s, ".", "Debris", 14, 2.5, s.sub_res("BoxMesh", size=V3(.12, .08, .12)), s.ext_res(M("fx_debris")), pmat(s, (0, 1, 0), 70, 4, 11, (0, -14, 0), .5, 1.4, "#202024", alpha_fade=False))
    s.save("scenes/fx/explosion.tscn")
    # puff: small coloured spark burst
    s = fx_root("Puff", 1.2, ("#ffffff", 1.5, 4.0, 1), .15)
    particles(s, ".", "Sparks", 10, .5, s.sub_res("QuadMesh", size=V2(.07, .07)), s.ext_res(glowp), pmat(s, (0, 1, 0), 180, 2, 6, (0, -6, 0), color="#21e6ff", damping=1.0), tint=True)
    particles(s, ".", "Smoke", 4, .8, s.sub_res("QuadMesh", size=V2(.7, .7)), s.ext_res(smokep), pmat(s, (0, 1, 0), 90, .3, 1.2, (0, .4, 0), color="#8a8c96", grow=.3), tint=True)
    s.save("scenes/fx/puff.tscn")
    # blood: the swarmers bleed glowing blue coolant
    s = fx_root("Blood", 1.8)
    drop = s.sub_res("StandardMaterial3D", albedo_color=hexcol("#0a3cff"), emission_enabled=True, emission=hexcol("#1a6cff"), emission_energy_multiplier=2.0, roughness=.15)
    particles(s, ".", "Droplets", 30, 1.4, s.sub_res("SphereMesh", radius=.03, height=.06, radial_segments=6, rings=4), drop, pmat(s, (0, 0, -1), 35, 3, 9, (0, -14, 0), .5, 1.6, alpha_fade=False))
    particles(s, ".", "Mist", 3, .6, s.sub_res("QuadMesh", size=V2(.9, .9)), s.ext_res(glowp), pmat(s, (0, 0, -1), 25, .5, 1.5, (0, 0, 0), color="#2a8cff", grow=.4))
    s.save("scenes/fx/blood.tscn")
    # cargo block chunks
    s = fx_root("Chunks", 2.8)
    particles(s, ".", "Chunks", 7, 2.4, s.sub_res("BoxMesh", size=V3(.3, .2, .3)), s.ext_res(M("fx_debris")), pmat(s, (0, 1, 0), 70, 3, 8, (0, -14, 0), .5, 1.5, "#3a2a80", alpha_fade=False, box=(.5, .5, .5)), tint=True)
    particles(s, ".", "Dust", 4, 1.4, s.sub_res("QuadMesh", size=V2(1.8, 1.8)), s.ext_res(smokep), pmat(s, (0, 1, 0), 60, .3, .9, (0, .3, 0), color="#6a6c74", grow=.3))
    s.save("scenes/fx/chunks.tscn")
    # ash: a dead swarmer disintegrating into drifting embers
    s = fx_root("Ash", 3.4)
    particles(s, ".", "Embers", 90, 2.6, s.sub_res("QuadMesh", size=V2(.06, .06)), s.ext_res(glowp),
              pmat(s, (0, 1, 0), 60, .3, 1.6, (0, 1.1, 0), .5, 1.4, "#ff7a30", damping=.6, box=(1.0, .5, 1.0)), explosiveness=.7)
    particles(s, ".", "Soot", 26, 3.0, s.sub_res("QuadMesh", size=V2(.7, .7)), s.ext_res(smokep),
              pmat(s, (0, 1, 0), 50, .2, .8, (0, .5, 0), .5, 1.2, "#2a2a30", grow=.3, damping=.4, box=(.9, .4, .9)), explosiveness=.6)
    s.save("scenes/fx/ash.tscn")
    # void well
    s = Scene("VoidWell", "Node3D")
    s.nodes[0][3]["script"] = s.ext_res("scripts/fx/void_well.gd")
    mesh_node(s, ".", "Core", s.sub_res("SphereMesh", radius=.7, height=1.4), s.sub_res("StandardMaterial3D", shading_mode=0, albedo_color=hexcol("#05000a")), cast_shadow=0)
    mesh_node(s, ".", "Ring", s.sub_res("TorusMesh", inner_radius=1.35, outer_radius=1.45, rings=40, ring_segments=8),
              s.sub_res("StandardMaterial3D", transparency=1, albedo_color=hexcol("#e14dff", .85), emission_enabled=True, emission=hexcol("#e14dff"), emission_energy_multiplier=3.0), cast_shadow=0)
    s.node("Light", "OmniLight3D", ".", {"light_color": hexcol("#e14dff"), "light_energy": 3.0, "omni_range": 9.0})
    s.save("scenes/fx/void_well.tscn")


# ---------------------------------------------------------------- spider + player
def build_spider():
    s = Scene("Spider", "CharacterBody3D", {"collision_layer": 4, "collision_mask": 5, "floor_snap_length": 0.5, "wall_min_slide_angle": 0.2}, groups=["enemies"])
    s.nodes[0][3]["script"] = s.ext_res("scripts/enemies/spider.gd")
    s.node("Shape", "CollisionShape3D", ".", {"transform": T3(0, 1.05, 0), "shape": s.sub_res("BoxShape3D", size=V3(2.1, 2.1, 2.1))})
    s.node("Model", None, ".", {"transform": T3(s=1.45)}, instance="assets/models/spider.glb")
    s.nodes[0][3]["model"] = NodeRef("Model")
    s.save("scenes/enemies/spider.tscn")


def build_player():
    s = Scene("Player", "CharacterBody3D", {"collision_layer": 2, "collision_mask": 5, "floor_snap_length": 0.6, "floor_max_angle": math.radians(46)}, groups=["player"])
    root = s.nodes[0][3]
    root["script"] = s.ext_res("scripts/player/player.gd")
    s.node("Shape", "CollisionShape3D", ".", {"transform": T3(0, .9, 0), "shape": s.sub_res("CapsuleShape3D", radius=.35, height=1.8)})
    head = s.node("Head", "Node3D", ".", {"transform": T3(0, 1.65, 0)})
    cam = s.node("Camera", "Camera3D", head, {"fov": 85.0, "near": 0.03, "far": 900.0, "current": True})
    gh = s.node("GunHolder", "Node3D", cam, {"transform": T3(.3, -.28, -.6)})
    s.node("GunWrap", "Node3D", gh)
    s.node("FillLight", "OmniLight3D", cam, {"transform": T3(.1, .25, .1), "light_color": hexcol("#b4c4ff"), "light_energy": 2.0, "omni_range": 2.6})
    dr = s.node("Drone", "Node3D", cam, {"transform": T3(-.6, .35, -1.2)})
    s.node("Model", None, dr, {"transform": T3(0, 0, 0, 0, math.pi, 0, s=.32)}, instance="assets/models/drone.glb")   # v74 hunter drone
    mesh_node(s, dr, "Eye", s.sub_res("SphereMesh", radius=.035, height=.07, radial_segments=8, rings=6),
              s.sub_res("StandardMaterial3D", albedo_color=hexcol("#21e6ff"), emission_enabled=True, emission=hexcol("#21e6ff"), emission_energy_multiplier=3.0), T3(0, 0, -.17), cast_shadow=0)
    mesh_node(s, ".", "Cable", s.sub_res("BoxMesh", size=V3(.012, .012, 1)),
              s.sub_res("StandardMaterial3D", albedo_color=hexcol("#9aa4b8"), metallic=1.0, roughness=.35, emission_enabled=True, emission=hexcol("#3dffc8"), emission_energy_multiplier=.4), cast_shadow=0)
    s.node("Body", None, ".", {}, instance="scenes/characters/hunter_operative.tscn")   # the night hunter (tools/rig/blender_rig_any.py)
    jet = s.node("JetFX", "Node3D", ".", {"transform": T3(0, 1.12, 0)})
    flame = s.sub_res("CylinderMesh", top_radius=.08, bottom_radius=0.0, height=1.35, radial_segments=10)
    fm = s.sub_res("StandardMaterial3D", transparency=1, blend_mode=1, shading_mode=0, albedo_color=hexcol("#4f8cff", .8))
    for sx in (-1, 1):
        mesh_node(s, jet, "Plume", flame, fm, T3(sx * .26, -.675, .25), cast_shadow=0)
    s.node("Glow", "OmniLight3D", jet, {"transform": T3(0, -.6, .3), "light_color": hexcol("#6aa0ff"), "light_energy": 2.2, "omni_range": 7.0})
    s.node("WeaponController", "Node", ".", {"script": s.ext_res("scripts/player/weapon_controller.gd"), "player": NodeRef(".."), "gun_wrap": NodeRef("../Head/Camera/GunHolder/GunWrap")})
    s.node("Abilities", "Node", ".", {"script": s.ext_res("scripts/player/abilities.gd"), "player": NodeRef(".."), "drone": NodeRef("../Head/Camera/Drone"), "drone_eye": NodeRef("../Head/Camera/Drone/Eye")})
    root.update({"head": NodeRef("Head"), "camera": NodeRef("Head/Camera"), "gun_holder": NodeRef("Head/Camera/GunHolder"),
                 "weapons": NodeRef("WeaponController"), "abilities": NodeRef("Abilities"), "jet_fx": NodeRef("JetFX"), "cable": NodeRef("Cable"), "body": NodeRef("Body")})
    s.save("scenes/player/player.tscn")


def build_props():
    building(); neon_sign(); billboard(); jersey_barrier(); planter(); hover_car(); street_lamp(); vending_machine()
    storage_tank(); crate_block(); spire(); plaza(); ring_walkway(); stair_tower()


if __name__ == "__main__":
    build_props(); build_fx(); build_spider(); build_player()
    print("props ok")
