"""HUD, hangar, avatar turntable, pause / end screens and the main scene."""
import math
from godot_writer import *
from build_props import mesh_node

M = lambda n: "assets/materials/%s.tres" % n
P2 = math.pi / 2


def full(**extra):
    d = {"layout_mode": 1, "anchors_preset": 15, "anchor_right": 1.0, "anchor_bottom": 1.0, "grow_horizontal": 2, "grow_vertical": 2, "mouse_filter": 2}
    d.update(extra)
    return d


def anchored(al, at, ar, ab, ol, ot, orr, ob, **extra):
    d = {"layout_mode": 1, "anchor_left": al, "anchor_top": at, "anchor_right": ar, "anchor_bottom": ab,
         "offset_left": ol, "offset_top": ot, "offset_right": orr, "offset_bottom": ob}
    if al == ar == 0.5: d["grow_horizontal"] = 2
    if ar == 1.0 and al == 1.0: d["grow_horizontal"] = 0
    if ab == 1.0 and at == 1.0: d["grow_vertical"] = 0
    d.update(extra)
    return d


def C(**extra):
    d = {"layout_mode": 2}
    d.update(extra)
    return d


def label(s, parent, name, text, size=None, color=None, variation=None, align=None, **extra):
    p = C(text=text)
    if size: p["theme_override_font_sizes/font_size"] = size
    if color: p["theme_override_colors/font_color"] = hexcol(color)
    if variation: p["theme_type_variation"] = SN(variation)
    if align is not None: p["horizontal_alignment"] = align
    p.update(extra)
    return s.node(name, "Label", parent, p)


def vignette(s, parent, name, color, inner, ring=0.0):
    mat = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/screen_vignette.gdshader"),
                    **{"shader_parameter/color": color, "shader_parameter/inner": inner, "shader_parameter/ring": ring})
    return s.node(name, "ColorRect", parent, full(material=mat, modulate=col(1, 1, 1, 0)))


def build_hud():
    s = Scene("HUD", "CanvasLayer", {"layer": 2, "visible": False})
    r = s.nodes[0][3]
    r["script"] = s.ext_res("scripts/ui/hud.gd")
    vignette(s, ".", "Damage", hexcol("#ff2a3d", .8), .4)
    vignette(s, ".", "Shield", hexcol("#e6e2da", .55), .55, .7)
    vignette(s, ".", "Chrono", hexcol("#b46bff", .47), .45)
    vignette(s, ".", "Heal", hexcol("#d9d6d0", .55), .45)
    s.node("Scope", "ColorRect", ".", full(visible=False, material=s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/scope.gdshader"))))
    s.node("Crosshair", "Control", ".", anchored(.5, .5, .5, .5, -15, -15, 15, 15, mouse_filter=2, script=s.ext_res("scripts/ui/crosshair.gd")))
    s.node("Minimap", "Control", ".", {"layout_mode": 0, "offset_left": 20, "offset_top": 24, "offset_right": 180, "offset_bottom": 184, "mouse_filter": 2,
                                       "script": s.ext_res("scripts/ui/minimap.gd")})
    top = s.node("Top", "VBoxContainer", ".", anchored(.5, 0, .5, 0, -150, 8, 150, 70, alignment=1, mouse_filter=2, **{"theme_override_constants/separation": 4}))
    row = s.node("Score", "HBoxContainer", top, C(alignment=1))
    label(s, row, "WaveTag", "WAVE", 11)
    label(s, row, "Wave", "1", 18, "#e6e2da")
    label(s, row, "Gap", "   ", 11)
    label(s, row, "ScoreTag", "SCORE", 11)
    label(s, row, "ScoreValue", "0", 18, "#e6e2da")
    s.node("HP", "ProgressBar", top, C(custom_minimum_size=V2(240, 9), size_flags_horizontal=4, max_value=100.0, value=100.0, show_percentage=False))
    label(s, top, "HPText", "100 / 100", 9, "#8a8890", align=1)
    s.node("JetFuel", "ProgressBar", top, C(custom_minimum_size=V2(150, 6), size_flags_horizontal=4, max_value=1.0, value=1.0, show_percentage=False, visible=False,
                                            **{"theme_override_styles/fill": s.sub_res("StyleBoxFlat", bg_color=hexcol("#8a8890"), corner_radius_top_left=3, corner_radius_top_right=3, corner_radius_bottom_left=3, corner_radius_bottom_right=3)}))
    s.node("KillFeed", "VBoxContainer", ".", anchored(.5, 0, .5, 0, -140, 92, 140, 200, mouse_filter=2, alignment=0))
    # weapon card (bottom centre)
    card = s.node("WeaponCard", "PanelContainer", ".", anchored(.5, 1, .5, 1, -110, -76, 110, -18, theme_type_variation=SN("Card"), mouse_filter=2))
    hb = s.node("Row", "HBoxContainer", card, C(**{"theme_override_constants/separation": 14}))
    vb = s.node("Main", "VBoxContainer", hb, C(size_flags_horizontal=3, **{"theme_override_constants/separation": 0}))
    label(s, vb, "WeaponName", "VX-9 HELIX CARBINE", 9, "#8a8890", clip_text=True)
    label(s, vb, "Ammo", "30/30", 22, "#ffffff", **{"theme_override_colors/font_shadow_color": hexcol("#e6e2da"), "theme_override_constants/shadow_outline_size": 8})
    vb2 = s.node("Swap", "VBoxContainer", hb, C(alignment=1))
    label(s, vb2, "SwapTag", "SWAP [X]", 9, "#e6e2da", align=2)
    label(s, vb2, "Other", "HORNET", 11, align=2)
    # abilities (bottom right)
    ab = s.node("Abilities", "HBoxContainer", ".", anchored(1, 1, 1, 1, -560, -70, -20, -24, alignment=2, mouse_filter=2, **{"theme_override_constants/separation": 8}))
    sk = s.node("Skill", "PanelContainer", ab, C(theme_type_variation=SN("Card"), custom_minimum_size=V2(96, 0)))
    skv = s.node("V", "VBoxContainer", sk, C())
    label(s, skv, "SkillLabel", "SHIELD", 11, "#d9d6d0", align=1)
    s.node("SkillBar", "ProgressBar", skv, C(custom_minimum_size=V2(0, 4), max_value=1.0, value=1.0, show_percentage=False))
    label(s, skv, "Key", "[Q]", 8, "#8a8890", align=1)
    for nm, txt, c in (("Blast", "BLAST", "#c8101a"), ("Stun", "STUN x2", "#ffffff")):
        p = s.node(nm, "PanelContainer", ab, C(theme_type_variation=SN("Card"), custom_minimum_size=V2(80, 0)))
        v = s.node("V", "VBoxContainer", p, C())
        label(s, v, nm + "Label", txt, 11, c, align=1)
        label(s, v, "Key", "[E]" if nm == "Blast" else "[G]", 8, "#8a8890", align=1)
    for i, (nm, c) in enumerate((("SENTRY", "#e6e2da"), ("STRIKE", "#ff2a3d"), ("OVERDRIVE", "#d9d6d0"))):
        p = s.node("Streak%d" % (i + 1), "PanelContainer", ab, C(theme_type_variation=SN("Card"), custom_minimum_size=V2(72, 0)))
        v = s.node("V", "VBoxContainer", p, C())
        label(s, v, "Label", "0/%d" % (5 * (i + 1)), 11, c, align=1)
        label(s, v, "Key", "[%d]" % (i + 4), 8, "#8a8890", align=1)
    label(s, ".", "Hint", "WASD move · Mouse aim · LMB fire · RMB aim · Shift sprint · Space jump · C crouch (hold: prone) · R reload · X swap · E blast · G stun · Q skill · 4/5/6 streaks · V 180 · T view · M map · P pause",
          10, "#8a8890", align=1, **anchored(0, 1, 1, 1, 0, -16, 0, 0, modulate=col(1, 1, 1, .7)))
    s.nodes[-1][3]["layout_mode"] = 1
    r.update({"wave_label": NodeRef("Top/Score/Wave"), "score_label": NodeRef("Top/Score/ScoreValue"), "hp_bar": NodeRef("Top/HP"), "hp_label": NodeRef("Top/HPText"),
              "kill_feed": NodeRef("KillFeed"), "weapon_name": NodeRef("WeaponCard/Row/Main/WeaponName"), "ammo_label": NodeRef("WeaponCard/Row/Main/Ammo"),
              "other_weapon": NodeRef("WeaponCard/Row/Swap/Other"), "skill_label": NodeRef("Abilities/Skill/V/SkillLabel"), "skill_bar": NodeRef("Abilities/Skill/V/SkillBar"),
              "blast_label": NodeRef("Abilities/Blast/V/BlastLabel"), "stun_label": NodeRef("Abilities/Stun/V/StunLabel"),
              "streak_labels": Raw('Array[NodePath]([NodePath("Abilities/Streak1/V/Label"), NodePath("Abilities/Streak2/V/Label"), NodePath("Abilities/Streak3/V/Label")])'),
              "jet_bar": NodeRef("Top/JetFuel"), "crosshair": NodeRef("Crosshair"), "minimap": NodeRef("Minimap"), "damage_overlay": NodeRef("Damage"),
              "shield_overlay": NodeRef("Shield"), "chrono_overlay": NodeRef("Chrono"), "heal_overlay": NodeRef("Heal"), "scope": NodeRef("Scope"), "hint": NodeRef("Hint")})
    s.save("scenes/ui/hud.tscn")


def build_avatar_stage():
    """Main-menu stage: a rain-soaked rooftop over the city at night. Cel-shaded (assets/shaders/menu/*): the operative
    on the turntable, the featured sniper on a holo pedestal, a sigil banner in the wind, crates, a flickering
    work lamp and something with red eyes on the parapet. The painted skyline behind it is a 2D backdrop."""
    s = Scene("AvatarStage", "Node3D")
    r = s.nodes[0][3]
    r["script"] = s.ext_res("scripts/ui/avatar_stage.gd")
    toon = s.ext_res("assets/shaders/menu/toon.gdshader")
    outline = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/outline.gdshader"), **{"shader_parameter/width": .0011, "shader_parameter/max_width": .008})

    def tmat(tex=None, tint="#ffffff", world=False, scale=.25, wet=0.0, desat=.6, ol=True, emit_thr=2.0, rim=1.6):
        props = {"shader": toon, "shader_parameter/tint": hexcol(tint), "shader_parameter/world_uv": world, "shader_parameter/world_scale": scale,
                 "shader_parameter/rim_strength": rim,
                 "shader_parameter/wet": wet, "shader_parameter/desaturate": desat, "shader_parameter/emission_threshold": emit_thr}
        if tex:
            props["shader_parameter/albedo_tex"] = s.ext_res(tex)
        if ol:
            props["next_pass"] = outline
        return s.sub_res("ShaderMaterial", **props)
    env = s.sub_res("Environment", background_mode=1, background_color=col(0, 0, 0, 0), ambient_light_source=2, ambient_light_color=hexcol("#5a6070"),
                    ambient_light_energy=0.35, tonemap_mode=3, tonemap_exposure=1.0, glow_enabled=True, glow_intensity=0.35, glow_bloom=0.0, glow_hdr_threshold=1.4,
                    fog_enabled=True, fog_light_color=hexcol("#0e0e12"), fog_density=0.02, fog_height=0.4, fog_height_density=0.6, fog_sky_affect=0.0)
    s.node("Environment", "WorldEnvironment", ".", {"environment": env})
    s.node("Key", "DirectionalLight3D", ".", {"transform": T3(0, 0, 0, -.7, .55, 0, order="YXZ"), "light_color": hexcol("#c8d2ff"), "light_energy": 2.0, "shadow_enabled": True,
                                              "directional_shadow_max_distance": 20.0})
    s.node("RimLeft", "OmniLight3D", ".", {"transform": T3(-1.2, 2.3, -1.4), "light_color": hexcol("#ff1a10"), "light_energy": 3.2, "omni_range": 3.6})
    s.node("RimRight", "OmniLight3D", ".", {"transform": T3(1.0, 1.6, -1.2), "light_color": hexcol("#ff2a1a"), "light_energy": 2.0, "omni_range": 3.0})
    s.node("Spot", "SpotLight3D", ".", {"transform": T3(0, 4.6, 1.0, -1.35, 0, 0), "light_color": hexcol("#e8ecff"), "light_energy": 5.0, "spot_range": 9.0,
                                        "spot_angle": 22.0, "shadow_enabled": True})
    s.node("Lightning", "DirectionalLight3D", ".", {"transform": T3(0, 0, 0, -.4, 3.0, 0, order="YXZ"), "light_color": hexcol("#d8e0ff"), "light_energy": 0.0})
    s.node("Turntable", "Node3D", ".")
    # rooftop
    roof = s.node("Rooftop", "StaticBody3D", ".")
    mesh_node(s, roof, "Floor", s.sub_res("PlaneMesh", size=V2(16, 12)), tmat("assets/generated/menu/floor_top_01.png", "#2c2c32", True, .33, wet=.3, ol=False, rim=0.0), T3(0, 0, -2))
    wall = tmat("assets/generated/menu/wall_01.png", "#b0b0b8", True, .55, emit_thr=1.2)
    mesh_node(s, roof, "Parapet", s.sub_res("BoxMesh", size=V3(14, .7, .45)), wall, T3(0, .35, -3.2))
    mesh_node(s, roof, "ParapetCap", s.sub_res("BoxMesh", size=V3(14.2, .08, .6)), tmat(tint="#202024"), T3(0, .74, -3.2))
    mesh_node(s, roof, "VentL", s.sub_res("BoxMesh", size=V3(1.2, 1.2, 1.0)), wall, T3(-3.6, .6, -2.4, 0, .25, 0))
    mesh_node(s, roof, "VentR", s.sub_res("BoxMesh", size=V3(1.0, 1.6, 1.0)), wall, T3(4.4, .8, -2.6, 0, -.2, 0))
    rail = tmat(tint="#141418")
    for x in range(-6, 7, 2):
        mesh_node(s, roof, "RailPost", s.sub_res("BoxMesh", size=V3(.05, .6, .05)), rail, T3(x, 1.08, -3.25))
    mesh_node(s, roof, "Rail", s.sub_res("BoxMesh", size=V3(14, .04, .04)), rail, T3(0, 1.38, -3.25))
    # crates (hard cases) stacked stage right
    case = tmat("assets/generated/menu/wall_01.png", "#8a8a92", False, emit_thr=1.2)
    for nm, x, y, z, w, h, d, ry in (("CaseA", 2.25, .35, -1.3, 1.1, .7, .7, .15), ("CaseB", 2.15, 1.0, -1.35, .9, .6, .6, -.1), ("CaseC", -2.4, .3, -1.0, .8, .6, .6, -.4)):
        mesh_node(s, roof, nm, s.sub_res("BoxMesh", size=V3(w, h, d)), case, T3(x, y, z, 0, ry, 0))
    # sigil banner on a pole, stage left
    mesh_node(s, ".", "BannerPole", s.sub_res("CylinderMesh", top_radius=.03, bottom_radius=.03, height=3.0), rail, T3(-2.75, 1.5, -2.9))
    mesh_node(s, ".", "BannerBar", s.sub_res("CylinderMesh", top_radius=.02, bottom_radius=.02, height=.8), rail, T3(-2.38, 2.95, -2.9, 0, 0, P2))
    cloth = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/cloth.gdshader"), **{"shader_parameter/sigil": s.ext_res("assets/generated/menu/sigil_01.jpg")})
    mesh_node(s, ".", "Banner", s.sub_res("PlaneMesh", size=V2(.7, 1.8), subdivide_width=8, subdivide_depth=20, orientation=2), cloth, T3(-2.38, 2.03, -2.88))
    # featured weapon: the sniper on a holo pedestal
    ped = s.node("Pedestal", "Node3D", ".", {"transform": T3(1.45, 0, .1)})
    mesh_node(s, ped, "Base", s.sub_res("CylinderMesh", top_radius=.32, bottom_radius=.4, height=.75, radial_segments=6), tmat(tint="#1a1a1e"), T3(0, .375, 0))
    mesh_node(s, ped, "Ring", s.sub_res("TorusMesh", inner_radius=.33, outer_radius=.36, rings=48, ring_segments=4),
              s.sub_res("StandardMaterial3D", shading_mode=0, albedo_color=hexcol("#ff1a10"), emission_enabled=True, emission=hexcol("#ff1a10"), emission_energy_multiplier=1.6), T3(0, .77, 0, s=(1, .3, 1)), cast_shadow=0)
    hover = s.node("Hover", "Node3D", ped, {"transform": T3(0, 1.25, 0)})
    s.node("Sniper", None, hover, {"transform": T3(0, 0, 0, 0, P2, -.08, s=1.6)}, instance="assets/placeholder/models/sniper.glb")
    s.node("EdgeLight", "OmniLight3D", ped, {"transform": T3(.5, 1.9, .9), "light_color": hexcol("#dfe6ff"), "light_energy": 2.5, "omni_range": 2.2})
    # a flickering work lamp on the parapet
    s.node("Lamp", "OmniLight3D", ".", {"transform": T3(-3.2, 1.5, -2.6), "light_color": hexcol("#ffb080"), "light_energy": 1.8, "omni_range": 4.0})
    mesh_node(s, ".", "LampBulb", s.sub_res("SphereMesh", radius=.06, height=.12),
              s.sub_res("StandardMaterial3D", shading_mode=0, albedo_color=hexcol("#ffcf9a"), emission_enabled=True, emission=hexcol("#ffb080"), emission_energy_multiplier=4.0), T3(-3.2, 1.25, -2.95), cast_shadow=0)
    # it watches from the parapet
    s.node("Lurker", None, ".", {"transform": T3(2.9, .78, -3.2, 0, -2.2, 0, s=.55)}, instance="assets/models/spider.glb")
    # weather: rain streaks, low drifting ground fog, a few cinders
    rain = s.sub_res("ParticleProcessMaterial", emission_shape=3, emission_box_extents=V3(5, .1, 3), direction=V3(.12, -1, 0), spread=2.0,
                     initial_velocity_min=11.0, initial_velocity_max=14.0, gravity=V3(0, -9.8, 0))
    s.node("Rain", "GPUParticles3D", ".", {"transform": T3(0, 6, -.5), "amount": 700, "lifetime": .6, "preprocess": 1.0, "process_material": rain,
                                           "draw_pass_1": s.sub_res("QuadMesh", size=V2(.004, .28)),
                                           "material_override": s.sub_res("StandardMaterial3D", shading_mode=0, transparency=1, albedo_color=hexcol("#b8bcc8", .22),
                                                                          billboard_mode=2, billboard_keep_scale=True),
                                           "cast_shadow": 0, "visibility_aabb": Raw("AABB(-6, -8, -4, 12, 10, 8)")})
    fogp = s.sub_res("ParticleProcessMaterial", emission_shape=3, emission_box_extents=V3(5, .1, 2.5), direction=V3(1, 0, 0), spread=10.0,
                     initial_velocity_min=.15, initial_velocity_max=.35, gravity=V3(0, 0, 0), scale_min=.7, scale_max=1.4, color=hexcol("#45454c"),
                     color_ramp=s.sub_res("GradientTexture1D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.3, 0.7, 1)"),
                                          colors=Raw("PackedColorArray(1, 1, 1, 0, 1, 1, 1, 0.22, 1, 1, 1, 0.22, 1, 1, 1, 0)"))))
    s.node("GroundFog", "GPUParticles3D", ".", {"transform": T3(0, .25, -1), "amount": 26, "lifetime": 14.0, "preprocess": 14.0, "process_material": fogp,
                                                "draw_pass_1": s.sub_res("QuadMesh", size=V2(3, 1.0)), "material_override": s.ext_res(M("fx_smoke_particle")), "cast_shadow": 0})
    pm = s.sub_res("ParticleProcessMaterial", emission_shape=3, emission_box_extents=V3(2.5, .1, 1.5), direction=V3(0, 1, 0), spread=25.0,
                   initial_velocity_min=.08, initial_velocity_max=.3, gravity=V3(.05, .03, 0), color=hexcol("#ff3a1a"))
    s.node("Cinders", "GPUParticles3D", ".", {"transform": T3(0, 0, -.6), "amount": 30, "lifetime": 9.0, "preprocess": 9.0, "process_material": pm,
                                              "draw_pass_1": s.sub_res("QuadMesh", size=V2(.014, .014)), "material_override": s.ext_res(M("fx_glow_particle")), "cast_shadow": 0})
    s.node("Camera", "Camera3D", ".", {"transform": Raw(_look((0, 1.3, 7.0), (0, 1.15, -.5))), "fov": 30.0, "current": True})
    r.update({"turntable": NodeRef("Turntable"), "ring": NodeRef("Pedestal/Ring"), "camera": NodeRef("Camera"), "featured": NodeRef("Pedestal/Hover"),
              "lurker": NodeRef("Lurker"), "lamp": NodeRef("Lamp"), "lightning_light": NodeRef("Lightning"), "spot": NodeRef("Spot")})
    s.save("scenes/ui/avatar_stage.tscn")


def _look(eye, target):
    f = [target[i] - eye[i] for i in range(3)]
    l = math.sqrt(sum(x * x for x in f)); f = [x / l for x in f]
    z = [-x for x in f]
    x = [z[2], 0, -z[0]]
    l = math.sqrt(sum(v * v for v in x)); x = [v / l for v in x]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    vals = [x[0], y[0], z[0], x[1], y[1], z[1], x[2], y[2], z[2]] + list(eye)
    return "Transform3D(" + ", ".join(num(v) for v in vals) + ")"


def build_hangar():
    s = Scene("Hangar", "Control", full(layout_mode=3, mouse_filter=0))
    r = s.nodes[0][3]
    r["script"] = s.ext_res("scripts/ui/hangar.gd")
    r["theme"] = s.ext_res("assets/ui/theme_menu.tres", "Theme")
    # the painted city (assets/generated/menu/city_02) animated by a shader: fog, rain, searchlights, lightning
    bd = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/backdrop.gdshader"))
    s.node("Backdrop", "TextureRect", ".", full(texture=s.ext_res("assets/generated/menu/city_02.jpg"), expand_mode=1, stretch_mode=6, material=bd))
    shade = s.sub_res("GradientTexture2D", gradient=s.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.2, 0.62, 1)"),
                      colors=Raw("PackedColorArray(0, 0, 0, 0.75, 0, 0, 0, 0, 0, 0, 0, 0.1, 0, 0, 0, 0.92)")),
                      fill_from=V2(0, 0), fill_to=V2(0, 1), width=4, height=64)
    s.node("Shade", "TextureRect", ".", full(texture=shade, expand_mode=1, stretch_mode=0))
    ink = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/ink3d.gdshader"))
    view = s.node("AvatarView", "SubViewportContainer", ".", full(stretch=True, mouse_filter=0, mouse_default_cursor_shape=6, material=ink))
    vp = s.node("Viewport", "SubViewport", view, {"own_world_3d": True, "transparent_bg": True, "handle_input_locally": False, "msaa_3d": 2, "size": Raw("Vector2i(1600, 900)"), "render_target_update_mode": 4})
    s.node("AvatarStage", None, vp, {}, instance="scenes/ui/avatar_stage.tscn")
    # comic post-process over backdrop + 3D (ink edges, posterise, crimson grade, halftone, grain); UI draws on top
    post = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/post.gdshader"))
    s.node("Post", "ColorRect", ".", full(material=post, mouse_filter=2))
    label(s, ".", "DragHint", "⟷  DRAG TO ROTATE", 10, "#6a6870", **anchored(0, 1, 0, 1, 22, -110, 260, -90, mouse_filter=2))
    s.nodes[-1][3]["layout_mode"] = 1
    who = s.node("Who", "VBoxContainer", ".", anchored(0, 0, 0, 0, 22, 16, 520, 230, mouse_filter=2, **{"theme_override_constants/separation": 2}))
    brand = s.node("Brand", "HBoxContainer", who, C(**{"theme_override_constants/separation": 10}))
    sig = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/sigil_key.gdshader"))
    s.node("Sigil", "TextureRect", brand, C(texture=s.ext_res("assets/generated/menu/sigil_01.jpg"), custom_minimum_size=V2(58, 58), expand_mode=1, stretch_mode=5, material=sig))
    tv = s.node("Titles", "VBoxContainer", brand, C(**{"theme_override_constants/separation": -4}))
    title_mat = s.sub_res("ShaderMaterial", shader=s.ext_res("assets/shaders/menu/title.gdshader"))
    label(s, tv, "Title", "VIRAL VANGUARD", 40, "#ece8e0", material=title_mat, **{"theme_override_constants/shadow_outline_size": 0, "theme_override_constants/outline_size": 0})
    label(s, tv, "Tag", "NEON CORE CITY  //  THE NIGHT DOESN'T END", 10, "#c8101a")
    s.node("Gap", "Control", who, C(custom_minimum_size=V2(0, 10)))
    label(s, who, "Class", "OPERATIVE · MEDIUM FRAME", 10, "#8a8890")
    label(s, who, "Name", "VANGUARD", 18)
    label(s, who, "Perk", "Takes 10% less damage.", 12, "#b8b4ac", autowrap_mode=3, custom_minimum_size=V2(320, 0))
    bar = s.node("Bar", "HBoxContainer", ".", anchored(0, 1, 1, 1, 16, -76, -16, -12, **{"theme_override_constants/separation": 8}))
    for nm in ("WeaponSlot", "ArmorSlot", "SkillSlot"):
        s.node(nm, "Button", bar, C(size_flags_horizontal=3, alignment=0, expand_icon=True, text="SLOT", clip_text=True, custom_minimum_size=V2(0, 64),
                                    **{"theme_override_font_sizes/font_size": 11, "theme_override_constants/icon_max_width": 62}))
    s.node("Gear", "Button", bar, C(text="⚙", custom_minimum_size=V2(64, 64), **{"theme_override_font_sizes/font_size": 24}))
    s.node("Mode", "Button", bar, C(text="MODE\nCO-OP", custom_minimum_size=V2(110, 64), tooltip_text="Co-op against the swarm, or a 1v1 sniper duel on the rooftops",
                                    **{"theme_override_font_sizes/font_size": 12}))
    s.node("Deploy", "Button", bar, C(text="PLAY SOLO", custom_minimum_size=V2(170, 64), theme_type_variation=SN("CTA")))
    pop = s.node("Popup", "PanelContainer", ".", anchored(1, 0, 1, 1, -420, 12, -16, -98, visible=False, mouse_filter=0))
    v = s.node("V", "VBoxContainer", pop, C(**{"theme_override_constants/separation": 8}))
    hd = s.node("Header", "HBoxContainer", v, C())
    label(s, hd, "Title", "WEAPON", 13, size_flags_horizontal=3)
    label(s, hd, "Subtitle", "10 classes", 10, "#8a8890")
    s.node("Close", "Button", hd, C(text="✕", custom_minimum_size=V2(32, 32)))
    s.node("Grid", "GridContainer", v, C(columns=5, **{"theme_override_constants/h_separation": 5, "theme_override_constants/v_separation": 5}))
    st = s.node("Settings", "VBoxContainer", v, C(visible=False, **{"theme_override_constants/separation": 6}))
    for nm, txt, lo, hi, step in (("Sensitivity", "Look sensitivity", .4, 2.5, .05), ("FOV", "Field of view", 70, 110, 1), ("GameVolume", "Game volume", 0, 1, .01), ("MusicVolume", "Music volume", 0, 1, .01)):
        row = s.node(nm + "Row", "HBoxContainer", st, C())
        label(s, row, "Label", txt, 12, size_flags_horizontal=3)
        s.node(nm, "HSlider", row, C(custom_minimum_size=V2(170, 20), min_value=float(lo), max_value=float(hi), step=float(step), size_flags_vertical=4))
    row = s.node("AdsRow", "HBoxContainer", st, C())
    label(s, row, "Label", "Aim down sights", 12, size_flags_horizontal=3)
    s.node("AdsMode", "OptionButton", row, C(custom_minimum_size=V2(170, 0)))
    det = s.node("DetailsPanel", "PanelContainer", v, C(size_flags_vertical=3))
    dv = s.node("V", "VBoxContainer", det, C(**{"theme_override_constants/separation": 8}))
    s.node("Details", "RichTextLabel", dv, C(bbcode_enabled=True, fit_content=True, text="", size_flags_vertical=0))
    s.node("Bars", "VBoxContainer", dv, C(**{"theme_override_constants/separation": 5}))
    s.node("Done", "Button", v, C(text="DONE", theme_type_variation=SN("Ghost")))
    # online play: quick match, private room codes, LAN / direct IP (desktop)
    mp = s.node("Multiplayer", "PanelContainer", ".", anchored(1, 0, 1, 0, -340, 12, -16, 330, mouse_filter=0))
    mv = s.node("V", "VBoxContainer", mp, C(**{"theme_override_constants/separation": 7}))
    label(s, mv, "Title", "PLAY ONLINE", 13)
    nr = s.node("NameRow", "HBoxContainer", mv, C())
    label(s, nr, "Label", "CALLSIGN", 10, "#8a8890", custom_minimum_size=V2(80, 0))
    s.node("Name", "LineEdit", nr, C(size_flags_horizontal=3, max_length=16, placeholder_text="OPERATIVE"))
    s.node("QuickPlay", "Button", mv, C(text="QUICK PLAY", theme_type_variation=SN("CTA"), custom_minimum_size=V2(0, 46),
                                        tooltip_text="Join a public match in progress, or start one others can drop into"))
    s.node("HostPrivate", "Button", mv, C(text="HOST PRIVATE ROOM", custom_minimum_size=V2(0, 36)))
    jr = s.node("JoinRow", "HBoxContainer", mv, C())
    s.node("Code", "LineEdit", jr, C(size_flags_horizontal=3, max_length=5, placeholder_text="ROOM CODE"))
    s.node("Join", "Button", jr, C(text="JOIN", custom_minimum_size=V2(80, 0)))
    lr = s.node("LanRow", "HBoxContainer", mv, C())
    s.node("HostLan", "Button", lr, C(text="HOST LAN", size_flags_horizontal=3))
    s.node("Address", "LineEdit", lr, C(size_flags_horizontal=3, placeholder_text="127.0.0.1"))
    s.node("JoinIp", "Button", lr, C(text="JOIN IP"))
    s.node("Status", "Label", mv, C(text="", autowrap_mode=3, custom_minimum_size=V2(300, 0), **{"theme_override_font_sizes/font_size": 11, "theme_override_colors/font_color": hexcol("#8a8890")}))
    r.update({"mp_panel": NodeRef("Multiplayer"), "name_edit": NodeRef("Multiplayer/V/NameRow/Name"), "quick_play": NodeRef("Multiplayer/V/QuickPlay"),
              "host_private": NodeRef("Multiplayer/V/HostPrivate"), "code_edit": NodeRef("Multiplayer/V/JoinRow/Code"), "join_button": NodeRef("Multiplayer/V/JoinRow/Join"),
              "lan_row": NodeRef("Multiplayer/V/LanRow"), "host_lan": NodeRef("Multiplayer/V/LanRow/HostLan"), "address_edit": NodeRef("Multiplayer/V/LanRow/Address"),
              "join_ip": NodeRef("Multiplayer/V/LanRow/JoinIp"), "status_label": NodeRef("Multiplayer/V/Status")})
    PS = "Popup/V/Settings/"
    r.update({"stage": NodeRef("AvatarView/Viewport/AvatarStage"), "avatar_view": NodeRef("AvatarView"), "operative_class": NodeRef("Who/Class"),
              "operative_name": NodeRef("Who/Name"), "operative_perk": NodeRef("Who/Perk"), "weapon_slot": NodeRef("Bar/WeaponSlot"), "armor_slot": NodeRef("Bar/ArmorSlot"),
              "skill_slot": NodeRef("Bar/SkillSlot"), "settings_button": NodeRef("Bar/Gear"), "deploy_button": NodeRef("Bar/Deploy"), "mode_button": NodeRef("Bar/Mode"), "popup": NodeRef("Popup"),
              "popup_title": NodeRef("Popup/V/Header/Title"), "popup_subtitle": NodeRef("Popup/V/Header/Subtitle"), "close_button": NodeRef("Popup/V/Header/Close"),
              "grid": NodeRef("Popup/V/Grid"), "details": NodeRef("Popup/V/DetailsPanel/V/Details"), "bars": NodeRef("Popup/V/DetailsPanel/V/Bars"),
              "settings_box": NodeRef("Popup/V/Settings"), "sensitivity": NodeRef(PS + "SensitivityRow/Sensitivity"), "fov": NodeRef(PS + "FOVRow/FOV"),
              "vol_game": NodeRef(PS + "GameVolumeRow/GameVolume"), "vol_music": NodeRef(PS + "MusicVolumeRow/MusicVolume"), "ads_mode": NodeRef(PS + "AdsRow/AdsMode"),
              "done_button": NodeRef("Popup/V/Done"), "drag_hint": NodeRef("DragHint"), "backdrop": NodeRef("Backdrop"), "title_label": NodeRef("Who/Brand/Titles/Title")})
    s.save("scenes/ui/hangar.tscn")


def overlay_screen(name, title, para, buttons, stats=False):
    s = Scene(name, "CanvasLayer", {"layer": 10, "visible": False, "process_mode": 3})
    s.node("Dim", "ColorRect", ".", full(color=hexcol("#050506", .93), mouse_filter=0))
    cc = s.node("Center", "CenterContainer", ".", full(mouse_filter=2))
    v = s.node("V", "VBoxContainer", cc, C(alignment=1, **{"theme_override_constants/separation": 14}))
    label(s, v, "Title", title, 58, "#ffffff", align=1, **{"theme_override_colors/font_shadow_color": hexcol("#c8101a"), "theme_override_constants/shadow_outline_size": 22})
    if stats:
        s.node("Stats", "Label", v, C(text="SCORE 0 · WAVE 1", horizontal_alignment=1, unique_name_in_owner=True, **{"theme_override_font_sizes/font_size": 15, "theme_override_colors/font_color": hexcol("#e6e2da")}))
    if para:
        label(s, v, "Body", para, 14, "#8a8890", align=1, autowrap_mode=3, custom_minimum_size=V2(420, 0))
    row = s.node("Buttons", "HBoxContainer", v, C(alignment=1, **{"theme_override_constants/separation": 10}))
    for nm, txt, var in buttons:
        s.node(nm, "Button", row, C(text=txt, theme_type_variation=SN(var), custom_minimum_size=V2(150, 48), unique_name_in_owner=True))
    return s


def build_screens():
    overlay_screen("PauseMenu", "PAUSED", None, (("Resume", "RESUME", "CTA"), ("PauseHangar", "HANGAR", "Ghost"))).save("scenes/ui/pause_menu.tscn")
    s = overlay_screen("EndScreen", "OVERRUN", "The swarm took the arena. Change your loadout or drop straight back in.",
                       (("Redeploy", "REDEPLOY", "CTA"), ("EndHangar", "HANGAR", "Ghost")), stats=True)
    # rename Stats -> EndStats for main.gd
    s.nodes = [(("EndStats" if n == "Stats" else n), t, p, pr, i, g, u) for n, t, p, pr, i, g, u in s.nodes]
    s.save("scenes/ui/end_screen.tscn")


def build_cinematic():
    s = Scene("DeployCinematic", "CanvasLayer", {"layer": 9})
    s.nodes[0][3]["script"] = s.ext_res("scripts/ui/deploy_cinematic.gd")
    s.node("Fade", "ColorRect", ".", full(color=col(0, 0, 0, 0), unique_name_in_owner=True))
    s.node("BarTop", "ColorRect", ".", anchored(0, 0, 1, .11, 0, 0, 0, 0, color=col(0, 0, 0, 1), mouse_filter=2))
    s.node("BarBottom", "ColorRect", ".", anchored(0, .89, 1, 1, 0, 0, 0, 0, color=col(0, 0, 0, 1), mouse_filter=2))
    sh = {"theme_override_colors/font_shadow_color": col(0, 0, 0, .9), "theme_override_constants/shadow_outline_size": 10}
    cap = s.node("CaptionAnchor", "Control", ".", anchored(.05, .89, .05, .89, 0, -150, 700, -22, mouse_filter=2))
    v = s.node("Caption", "VBoxContainer", cap, full(alignment=2, unique_name_in_owner=True, **{"theme_override_constants/separation": 4}))
    label(s, v, "Sector", "SECTOR 01", 11, "#21e6ff", unique_name_in_owner=True, **sh)
    label(s, v, "Title", "CENTRAL SPIRE PLAZA", 40, "#e8eeff", unique_name_in_owner=True, **sh)
    label(s, v, "Desc", "", 13, "#b9c3e6", unique_name_in_owner=True, autowrap_mode=3, custom_minimum_size=V2(520, 0), **sh)
    label(s, ".", "Tip", "TIP", 11, "#9aa6d0", unique_name_in_owner=True, **anchored(.05, .055, .95, .055, 0, -9, 0, 9))
    ld = s.node("Loading", "HBoxContainer", ".", anchored(1, .945, 1, .945, -560, -10, -64, 10, alignment=2, mouse_filter=2, **{"theme_override_constants/separation": 14}))
    label(s, ld, "Deploying", "DEPLOYING TO NEON CORE CITY", 10, "#9aa6d0")
    fill = s.sub_res("StyleBoxFlat", bg_color=hexcol("#21e6ff"), corner_radius_top_left=2, corner_radius_top_right=2, corner_radius_bottom_left=2, corner_radius_bottom_right=2)
    s.node("Bar", "ProgressBar", ld, C(custom_minimum_size=V2(240, 3), size_flags_vertical=4, show_percentage=False, unique_name_in_owner=True,
                                       **{"theme_override_styles/fill": fill, "theme_override_styles/background": s.sub_res("StyleBoxFlat", bg_color=col(1, 1, 1, .13))}))
    label(s, ld, "Skip", "CLICK / SPACE TO SKIP", 10, "#ffffff88")
    s.save("scenes/ui/deploy_cinematic.tscn")


def build_main():
    s = Scene("Main", "Node", {"process_mode": 3})
    r = s.nodes[0][3]
    r["script"] = s.ext_res("scripts/main.gd")
    s.node("World", "Node3D", ".", {"process_mode": 1})
    hl = s.node("HangarLayer", "CanvasLayer", ".")
    s.node("Hangar", None, hl, {}, instance="scenes/ui/hangar.tscn")
    s.node("HUD", None, ".", {"process_mode": 1}, instance="scenes/ui/hud.tscn")
    s.node("PauseMenu", None, ".", {}, instance="scenes/ui/pause_menu.tscn")
    s.node("EndScreen", None, ".", {}, instance="scenes/ui/end_screen.tscn")
    s.node("DeployCinematic", None, ".", {}, instance="scenes/ui/deploy_cinematic.tscn")
    r.update({"hangar": NodeRef("HangarLayer/Hangar"), "hangar_layer": NodeRef("HangarLayer"), "hud": NodeRef("HUD"), "pause_menu": NodeRef("PauseMenu"),
              "end_screen": NodeRef("EndScreen"), "world": NodeRef("World"),
              "cinematic": NodeRef("DeployCinematic")})
    s.save("scenes/main.tscn")


def build_ui():
    build_hud(); build_avatar_stage(); build_hangar(); build_screens(); build_cinematic(); build_main()


if __name__ == "__main__":
    build_ui()
    print("ui ok")
