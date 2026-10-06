"""Materials, item data, icons, theme, audio buses and project settings."""
import os
from godot_writer import *

# ---------------------------------------------------------------- palette (original PAL / HEX)
PAL = {"cyan": "#21e6ff", "magenta": "#ff2bd6", "violet": "#8a3bff", "blue": "#2f8bff", "teal": "#14b8a6",
       "orange": "#ff9a3c", "red": "#ff3355", "warm": "#ffc069", "white": "#dff6ff", "green": "#3dff9a",
       "yellow": "#ffd23c", "lime": "#a6ff3c", "ice": "#c8d0ff"}


def glow_material(name, hexc, energy=2.6):
    r = Resource("StandardMaterial3D")
    r.props.update(albedo_color=hexcol(hexc), emission_enabled=True, emission=hexcol(hexc),
                   emission_energy_multiplier=energy, roughness=0.6)
    return r.save("assets/materials/glow_%s.tres" % name)


def std_material(name, hexc, metal=0.5, rough=0.5, **extra):
    r = Resource("StandardMaterial3D")
    r.props.update(albedo_color=hexcol(hexc), metallic=metal, roughness=rough)
    r.props.update(extra)
    return r.save("assets/materials/%s.tres" % name)


def shader_material(name, shader, **params):
    r = Resource("ShaderMaterial")
    r.props["shader"] = r.ext_res("assets/shaders/%s.gdshader" % shader)
    for k, v in params.items():
        r.props["shader_parameter/" + k] = v
    return r.save("assets/materials/%s.tres" % name)


def overlay(name, hexc, k):
    r = Resource("StandardMaterial3D")
    r.props.update(transparency=1, blend_mode=1, shading_mode=0, albedo_color=hexcol(hexc, 1.0, k))
    return r.save("assets/materials/%s.tres" % name)


def build_materials():
    for n, h in PAL.items():
        glow_material(n, h)
    std_material("metal_dark", "#2a2830", 0.6, 0.4)
    std_material("metal_mid", "#3a3a50", 0.7, 0.35)
    std_material("metal_pole", "#2a2a38", 0.7, 0.4)
    std_material("roof", "#16141e", 0.3, 0.7)
    std_material("concrete", "#1e1c26", 0.2, 0.8)
    std_material("barrier", "#2a2830", 0.2, 0.75)
    std_material("planter", "#34323c", 0.2, 0.8)
    std_material("foliage", "#1c3a26", 0.0, 0.9)
    std_material("crane_paint", "#d8742a", 0.4, 0.5)
    std_material("tank", "#3a3430", 0.5, 0.55)
    std_material("pipe_rust", "#5a2a2a", 0.6, 0.6)
    std_material("canopy", "#0a0c18", 0.9, 0.1)
    std_material("paver", "#24223a", 0.4, 0.4)
    std_material("plaza", "#1a1828", 0.5, 0.35)
    std_material("pad", "#05030f", 0.0, 0.9)
    std_material("tram_body", "#1a1a28", 0.6, 0.4)
    std_material("vending", "#1a1a26", 0.5, 0.4)
    std_material("spider_hull", "#ffffff", 0.6, 0.34, vertex_color_use_as_albedo=True)
    # weapon finishes (original MeshPhysicalMaterial values)
    std_material("gun_body", "#2a2e36", 0.85, 0.32, clearcoat_enabled=True, clearcoat=0.55, clearcoat_roughness=0.28)
    std_material("gun_dark", "#14161b", 0.15, 0.7)
    std_material("gun_steel", "#4a4f58", 1.0, 0.36)
    std_material("gun_bronze", "#8c6a3c", 0.95, 0.32)
    std_material("gun_rubber", "#0b0b0d", 0.0, 0.95)
    std_material("gun_black", "#020203", 0.2, 1.0)
    glow_material("gun_tritium", "#5dff8a", 3.0)
    # procedural shaders
    shader_material("facade_residential", "facade", style=0, wall_color=hexcol("#262434"), lit_a=hexcol("#ffb54a"), lit_b=hexcol("#ff9d5c"),
                    neon_a=hexcol(PAL["magenta"]), neon_b=hexcol("#9b7bff"), lit_chance=0.42, neon_chance=0.1)
    shader_material("facade_commercial", "facade", style=1, wall_color=hexcol("#101a3a"), lit_a=hexcol("#9fdcff"), lit_b=hexcol("#e6f4ff"),
                    neon_a=hexcol(PAL["magenta"]), neon_b=hexcol("#c8a2ff"), lit_chance=0.3, neon_chance=0.06, bay_width=2.0)
    shader_material("facade_industrial", "facade", style=2, wall_color=hexcol("#2a2220"), lit_a=hexcol("#ff9a3c"), lit_b=hexcol("#ff8a2a"),
                    neon_a=hexcol("#ff8a2a"), neon_b=hexcol("#ffc069"), lit_chance=0.4, neon_chance=0.0, emission_strength=1.6)
    shader_material("shopfront", "facade", style=1, wall_color=hexcol("#14121c"), lit_a=hexcol(PAL["magenta"]), lit_b=hexcol(PAL["cyan"]),
                    neon_a=hexcol(PAL["orange"]), neon_b=hexcol(PAL["violet"]), lit_chance=0.6, neon_chance=0.3, bay_width=4.0, floor_height=4.5,
                    emission_strength=1.8)
    shader_material("ground", "ground")
    shader_material("water", "water")
    shader_material("light_pool", "light_pool")
    shader_material("billboard_screen", "billboard")
    shader_material("crate_steel", "crate", tint=hexcol("#9aa0b0"), glow_color=hexcol("#ff9a3c"), glow_strength=0.5)
    shader_material("crate_magenta", "crate", tint=hexcol("#d0b0d0"), glow_color=hexcol("#ff2bd6"), glow_strength=1.3)
    shader_material("crate_cyan", "crate", tint=hexcol("#a8c8d0"), glow_color=hexcol("#21e6ff"), glow_strength=1.3)
    overlay("overlay_flash", "#1a7cff", 0.9)
    overlay("overlay_chill", "#66d9ff", 0.6)
    overlay("overlay_stun", "#ffffff", 0.85)
    # additive unshaded material for particles / tracers / flashes (tinted by vertex colour or albedo)
    r = Resource("StandardMaterial3D")
    r.props.update(transparency=1, blend_mode=1, shading_mode=0, vertex_color_use_as_albedo=True, billboard_mode=3,
                   particles_anim_h_frames=1, particles_anim_v_frames=1, particles_anim_loop=False,
                   albedo_texture=r.sub_res("GradientTexture2D", gradient=r.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.3, 1)"),
                       colors=Raw("PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0.6, 1, 1, 1, 0)")), fill=1, fill_from=V2(0.5, 0.5), fill_to=V2(1, 0.5)))
    r.save("assets/materials/fx_glow_particle.tres")
    r = Resource("StandardMaterial3D")
    r.props.update(transparency=1, shading_mode=0, vertex_color_use_as_albedo=True, billboard_mode=3,
                   particles_anim_h_frames=1, particles_anim_v_frames=1, particles_anim_loop=False,
                   albedo_texture=r.sub_res("GradientTexture2D", gradient=r.sub_res("Gradient", offsets=Raw("PackedFloat32Array(0, 0.5, 1)"),
                       colors=Raw("PackedColorArray(1, 1, 1, 0.5, 1, 1, 1, 0.25, 1, 1, 1, 0)")), fill=1, fill_from=V2(0.5, 0.5), fill_to=V2(1, 0.5)))
    r.save("assets/materials/fx_smoke_particle.tres")
    r = Resource("StandardMaterial3D")
    r.props.update(transparency=1, blend_mode=1, shading_mode=0, albedo_color=col(1, 1, 1, 1), no_depth_test=False)
    r.save("assets/materials/fx_additive.tres")
    r = Resource("StandardMaterial3D")
    r.props.update(vertex_color_use_as_albedo=True, metallic=0.15, roughness=0.85)
    r.save("assets/materials/fx_debris.tres")


# ---------------------------------------------------------------- item data (original WEAPONS / ARMORS / SKILLS)
WEAPONS = [
    dict(id='pulse', carry='Low ready', rl_name='Magazine swap', name='VX-9 Helix Carbine', cls='Assault', desc='Steady full-auto fire that works at any range.', dmg=20, rate=.09, mag=30, rl=1.4, pel=1, spr=.004, rec=.012, kick=.006, brk=.9, hex='#21e6ff', mode='ads', brass=1, yc=.125),
    dict(id='scatter', carry='Port arms', rl_name='Shell feed and pump', name='Breacher-12 Scattergun', cls='Shotgun', desc='Eight pellets a shell. Tears through walls and anything close.', dmg=13, rate=.65, mag=6, rl=2, pel=8, spr=.09, rec=.05, kick=.03, brk=.75, hex='#ff8a2b', mode='hip', ads_t=.24, brass=2, yc=.128),
    dict(id='rail', carry='Sling ready', rl_name='Power cell exchange', name='Orion Rail Lance', cls='Marksman', desc='Pierces every infected in a line and punches through three blocks.', dmg=110, rate=.85, mag=5, rl=2.1, pel=1, spr=0, rec=.04, kick=.025, brk=1.1, pierce=True, hex='#b46bff', mode='release', ads_t=.32, ads_z=.45, scoped=True, yc=.13),
    dict(id='sniper', carry='Shoulder sling', rl_name='Stripper clip', name='Nightfall .408 Bolt Rifle', cls='Precision', desc='Bolt-action precision rifle. Heavy rounds with real travel time and drop; a headshot is lethal. Hold sprint while scoped to steady your breath. Your scope glints at whoever you are watching.', dmg=95, rate=1.0, mag=5, rl=2.9, pel=1, spr=.0, rec=.07, kick=.06, brk=1.0, hex='#e0302a', mode='onetap', ads_t=.24, ads_z=.3, scoped=True, yc=.2645, range=420, bolt=True, bolt_t=.95, bspd=330, bgrav=12.0, hs=2.6, zoom=6.0, sway=.0065, breath=3.2, hip=.075, settle=.2, brass=1),
    dict(id='smg', carry='High ready', rl_name='Drum swap', name='Hornet-7 PDW', cls='Close quarters', desc='Very fast fire and quick reloads, with light hits.', dmg=10, rate=.05, mag=45, rl=1.2, pel=1, spr=.018, rec=.006, kick=.003, brk=.7, hex='#3dff9a', mode='hip', brass=1, yc=.115),
    dict(id='arc', carry='Hip carry', rl_name='Break-open load', name='Nova Arc Mortar', cls='Explosive', desc='Rounds detonate on impact and hit everything nearby.', dmg=60, rate=.6, mag=4, rl=2, pel=1, spr=0, rec=.05, kick=.03, brk=2.4, boom=3.6, hex='#ffd23d', mode='mixed', ads_t=.28, yc=.12),
    dict(id='ion', carry='Underarm carry', rl_name='Belt box change', name='Tempest Ion Repeater', cls='Heavy', desc='Barrels spin up the longer you fire, reaching a torrent of bolts. You move 15% slower.', dmg=14, rate=.055, spin=1, move=.85, mag=90, rl=2.6, pel=1, spr=.02, rec=.004, kick=.003, brk=.8, hex='#3d8bff', mode='hip', yc=.172),
    dict(id='cryo', carry='Low ready', rl_name='Canister twist', name='Glacier Cryo Projector', cls='Control', desc='Short-range freezing stream. Chilled infected move at 40% speed.', dmg=8, rate=.06, mag=60, rl=1.8, pel=1, spr=.012, rec=.002, kick=.001, brk=.5, chill=2.2, range=22, hex='#9fe8ff', mode='hip', yc=.115),
    dict(id='void', carry='Close carry', rl_name='Core recharge', name='Event Horizon Voidcaster', cls='Exotic', desc='Opens a gravity well that drags nearby infected in and crushes them.', dmg=40, rate=1.1, mag=3, rl=2.4, pel=1, spr=0, rec=.05, kick=.02, brk=1.4, well=1.8, hex='#e14dff', mode='onetap', ads_t=.3, ads_z=.3, yc=.14),
    dict(id='burst', carry='Compressed ready', rl_name='Side-mag slap', name='Fang-3 Burst Rifle', cls='Burst', desc='Three-round bursts with tight grouping and heavy hits.', dmg=28, rate=.38, burst=3, mag=24, rl=1.5, pel=1, spr=.003, rec=.01, kick=.005, brk=.9, hex='#ff3d5a', mode='ads', ads_t=.22, brass=1, yc=.135),
    dict(id='chain', carry='Cross carry', rl_name='Capacitor flip', name='Stormcaller Chain Emitter', cls='Energy', desc='Lightning that jumps from the target to three more infected nearby.', dmg=34, rate=.32, chain=3, mag=12, rl=1.9, pel=1, spr=0, rec=.02, kick=.008, brk=.8, hex='#cfe0ff', mode='hip', brass=1, yc=.125),
]
SHORT = {'sniper': 'NIGHTFALL', 'pulse': 'HELIX', 'scatter': 'BREACH', 'rail': 'ORION', 'smg': 'HORNET', 'arc': 'NOVA', 'ion': 'TEMPEST', 'cryo': 'GLACIER', 'void': 'HORIZON', 'burst': 'FANG-3', 'chain': 'STORM'}
ARMORS = [
    dict(id='recon', name='Recon', cls='Light', hp=80, spd=1.2, dr=0, reg=2, c1='#21e6ff', c2='#dfe9ff', perk='Moves 20% faster than standard.'),
    dict(id='vanguard', name='Vanguard', cls='Medium', hp=110, spd=1, dr=.1, reg=2, c1='#ff2bd6', c2='#cfcae8', perk='Takes 10% less damage.'),
    dict(id='jugg', name='Juggernaut', cls='Heavy', hp=170, spd=.8, dr=.25, reg=1, c1='#ff2a3d', c2='#6a6386', perk='Takes 25% less damage. Slow to move.'),
    dict(id='specter', name='Specter', cls='Stealth', hp=85, spd=1.12, dr=0, reg=2, eslow=.8, c1='#b46bff', c2='#2a2448', perk='Infected close in 20% slower while they track you.'),
    dict(id='medic', name='Medic', cls='Support', hp=100, spd=1, dr=.05, reg=7, c1='#3dff9a', c2='#eef3f0', perk='Regenerates 7 health per second.'),
    dict(id='eng', name='Engineer', cls='Tech', hp=115, spd=.95, dr=.08, reg=2, cdr=.35, c1='#ffd23d', c2='#4a4466', perk='Skill and blast recharge 35% faster.'),
    dict(id='mk2', tier=1, name='Sentinel Mk II', cls='Upgrade I', hp=130, spd=1.02, dr=.14, reg=3, cdr=.1, c1='#2f7bff', c2='#c9d4e6', perk='Layered chest overplate, heavy segmented pauldrons, vambraces and thigh plates. 14% less damage, skills recharge 10% faster.'),
    dict(id='mk3', tier=2, name='Warden Mk III', cls='Upgrade II', hp=155, spd=1.06, dr=.18, reg=4, cdr=.2, eslow=.9, jmp=1.08, c1='#19b8ff', c2='#e3e8ef', perk='Back-mounted power pack with exhaust stacks, armoured knees, hip plates, helmet fins. Jetpack: hold jump in mid-air. 18% less damage, 20% faster recharge, higher jumps, Infected near you move 10% slower.'),
    dict(id='mk4', tier=3, name='Ascendant Mk IV', cls='Upgrade III', hp=180, spd=1.1, dr=.24, reg=5, cdr=.3, eslow=.8, jmp=1.18, c1='#5a8cff', c2='#ffcf6a', perk='Chest reactor core, swept thruster wings, gold-trimmed crown helmet and glowing conduits. Twin-nozzle jetpack with more thrust and fuel: hold jump in mid-air. 24% less damage, 30% faster recharge, highest jumps, Infected near you move 20% slower.'),
]
SKILLS = [
    dict(id='dash', name='Phase Dash', short='DASH', cd=5, col='#21e6ff', desc='Blink forward and ignore damage for half a second.'),
    dict(id='shield', name='Overshield', short='SHIELD', cd=14, col='#7ad7ff', desc='Block all incoming damage for 4 seconds.'),
    dict(id='drone', name='Hunter Drone', short='DRONE', cd=18, col='#ff2bd6', desc='Your drone fires on the nearest infected for 8 seconds.'),
    dict(id='chrono', name='Chrono Field', short='CHRONO', cd=16, col='#b46bff', desc='Slow every infected by 70% for 5 seconds.'),
    dict(id='nanite', name='Nanite Surge', short='HEAL', cd=12, col='#3dff9a', desc='Restore 50 health instantly.'),
    dict(id='grapple', name='Grapple Gun', short='GRAPPLE', cd=2.5, col='#3dffc8', desc='Fire a cable up to 20 m at any building or obstacle and reel yourself in. Aim near a roof edge to land on the roof. Hit a high wall and you cling to it: fire again to climb higher or jump to kick off.'),
]


# v74: every gun has a max range (nothing registers beyond it); damage falls off past half of it
WRANGE = dict(pulse=90, burst=85, smg=45, scatter=24, rail=170, arc=75, ion=60, cryo=22, void=45, chain=32)


def build_data():
    db = Resource("Resource", "scripts/data/game_database.gd", "GameDatabase")
    ws, as_, ss = [], [], []
    for w in WEAPONS:
        r = Resource("Resource", "scripts/data/weapon_data.gd", "WeaponData")
        r.props.update(id=w['id'], display_name=w['name'], short_name=SHORT[w['id']], weapon_class=w['cls'], description=w['desc'],
                       carry=w['carry'], reload_name=w['rl_name'], model_scene=r.ext_res("scenes/weapons/%s.tscn" % w['id']),
                       icon=r.ext_res("assets/icons/weapon_%s.svg" % w['id']), color=hexcol(w['hex']),
                       damage=float(w['dmg']), fire_interval=w['rate'], magazine=w['mag'], reload_time=float(w['rl']), pellets=w['pel'],
                       spread=float(w['spr']), recoil=w['rec'], kick=w['kick'], block_break=w['brk'], max_range=float(WRANGE.get(w['id'], w.get('range', 80))),
                       fire_mode=w['mode'], ads_time=w.get('ads_t', .2), ads_zoom=w.get('ads_z', .22), scoped=w.get('scoped', False),
                       sight_height=w['yc'], brass=w.get('brass', 0), burst_count=w.get('burst', 0), spin_up=float(w.get('spin', 0)),
                       move_multiplier=w.get('move', 1.0), pierce=w.get('pierce', False), explosion_radius=float(w.get('boom', 0)),
                       chill_time=float(w.get('chill', 0)), gravity_well_time=float(w.get('well', 0)), chain_jumps=w.get('chain', 0))
        if w.get('bolt'):
            r.props.update(bolt_action=True, bolt_time=w['bolt_t'], bullet_speed=float(w['bspd']), bullet_gravity=w['bgrav'], headshot_mult=w['hs'],
                           scope_zoom=w['zoom'], scope_sway=w['sway'], hold_breath=w['breath'], hip_spread=w['hip'], settle_time=w['settle'])
        ws.append(db.ext_res(r.save("data/weapons/%s.tres" % w['id'])[6:]))
    for a in ARMORS:
        r = Resource("Resource", "scripts/data/armor_data.gd", "ArmorData")
        r.props.update(id=a['id'], display_name=a['name'], armor_class=a['cls'], perk=a['perk'], tier=a.get('tier', 0),
                       primary_color=hexcol(a['c1']), secondary_color=hexcol(a['c2']), icon=r.ext_res("assets/icons/armor_%s.svg" % a['id']),
                       max_health=a['hp'], speed=float(a['spd']), damage_reduction=float(a['dr']), regen=float(a['reg']),
                       cooldown_reduction=float(a.get('cdr', 0)), enemy_slow=float(a.get('eslow', 1)), jump_multiplier=float(a.get('jmp', 1)))
        as_.append(db.ext_res(r.save("data/armors/%s.tres" % a['id'])[6:]))
    for s in SKILLS:
        r = Resource("Resource", "scripts/data/skill_data.gd", "SkillData")
        r.props.update(id=s['id'], display_name=s['name'], short_name=s['short'], cooldown=float(s['cd']), color=hexcol(s['col']),
                       description=s['desc'], icon=r.ext_res("assets/icons/skill_%s.svg" % s['id']))
        ss.append(db.ext_res(r.save("data/skills/%s.tres" % s['id'])[6:]))
    wsc = db.ext_res("scripts/data/weapon_data.gd")
    asc = db.ext_res("scripts/data/armor_data.gd")
    ssc = db.ext_res("scripts/data/skill_data.gd")
    db.props["weapons"] = Raw("Array[%s](%s)" % (wsc.v, fmt(ws)))
    db.props["armors"] = Raw("Array[%s](%s)" % (asc.v, fmt(as_)))
    db.props["skills"] = Raw("Array[%s](%s)" % (ssc.v, fmt(ss)))
    db.save("data/database.tres")


# ---------------------------------------------------------------- icons (ported from WICON / armorIcon / skillIcon)
def _R(x, y, w, h, r=1): return '<rect x="%s" y="%s" width="%s" height="%s" rx="%s"/>' % (x, y, w, h, r)
def _C(x, y, r): return '<circle cx="%s" cy="%s" r="%s"/>' % (x, y, r)
def _GR(x): return '<path d="M%s 16.5h4l-1 7h-4z"/>' % x


WICON = {
    'pulse': [_R(2, 10, 10, 7, 1.5) + _R(12, 8, 22, 8, 1.5) + _R(34, 10, 20, 4) + _R(54, 10.5, 6, 3, .5) + _R(20, 4.5, 9, 3) + '<path d="M22 16h6l-1.5 9h-5z"/>' + _GR(15), _R(13, 11, 40, 1.4, .5) + _R(22.5, 19, 4, 1.2, .4), ''],
    'scatter': [_R(2, 10, 10, 7, 1.5) + _R(12, 8, 18, 9, 1.5) + _R(30, 8, 27, 3) + _R(30, 12.5, 27, 3) + _R(34, 16, 15, 4, 1.5) + _GR(15), _R(13, 10.5, 15, 1.4, .5) + _R(56, 8, 2, 7.5, .5), ''],
    'rail': [_R(2, 11, 9, 6, 1.5) + _R(11, 9, 16, 7, 1.5) + _R(27, 11.5, 33, 2.6) + _R(12, 5, 11, 3.2) + _GR(14), _R(13, 5.6, 9, 2, .5) + _C(60, 12.8, 1.6), _C(35, 12.8, 3.6) + _C(43, 12.8, 3.6) + _C(51, 12.8, 3.6)],
    'sniper': ['<path d="M2 14l9-4h12v6H12l-6 4H2z"/>' + _R(23, 10.5, 9, 6, 1) + _R(32, 12, 28, 2.2, .6) + _R(58, 11.4, 4, 3.4, .5) + _GR(19) + '<path d="M40 14.5l-3 9M40 14.5l3 9"/>',
               _R(17, 4, 16, 4.4, 2) + _R(14.5, 3.4, 3, 5.6, 1) + _R(33, 3.4, 3, 5.6, 1), _C(36, 6.2, 1.2)],
    'smg': [_R(7, 10, 7, 5, 1.5) + _R(14, 8, 20, 8, 1.5) + _R(34, 10, 10, 4) + _R(44, 10.5, 5, 3, .5) + _GR(17) + _C(27, 20, 5.5), _R(15, 10.5, 17, 1.3, .5), _C(27, 20, 5.5)],
    'arc': [_R(3, 10, 8, 6, 1.5) + _R(11, 8, 14, 9, 1.5) + _R(25, 7, 27, 11, 5.5) + _GR(14), _C(54, 12.5, 4), '<path d="M31 7v11M37 7v11M43 7v11"/>'],
    'ion': [_R(6, 8, 20, 11, 2) + _R(26, 8.5, 32, 1.6, .5) + _R(26, 11.5, 32, 1.6, .5) + _R(26, 14.5, 32, 1.6, .5) + _R(26, 17.5, 32, 1.6, .5) + _R(29, 7, 4, 13) + _R(44, 7, 4, 13) + _R(10, 19, 13, 6, 1.5) + _R(35, 19, 3, 6), _R(11, 21, 11, 1.4, .5) + _R(8, 10, 16, 1.4, .5), ''],
    'cryo': [_R(4, 10, 8, 6, 1.5) + _R(12, 9, 18, 8, 1.5) + '<path d="M30 10l14-4v15l-14-4z"/>' + _GR(15) + _R(16.5, 1.5, 7, 1.6, .5), _R(17.5, 3, 5, 6.5, 1.5), '<path d="M48 8l5-2.5M48 13.5h6M48 19l5 2.5"/>'],
    'void': [_R(4, 10, 8, 6, 1.5) + _R(12, 9, 16, 8, 1.5) + _GR(15) + _R(28, 6, 9, 2) + _R(28, 19, 9, 2), _C(44, 13.5, 3), '<circle cx="44" cy="13.5" r="8" stroke-width="2.6"/>'],
    'burst': ['<path d="M4 9h34l3 3v5H12v3H4z"/>' + _R(41, 10.5, 14, 4) + _R(55, 11, 4, 3, .5) + _GR(22), _R(25, 12, 10, 4.5, 1) + _R(6, 7.6, 28, 1.2, .4), ''],
    'chain': [_R(4, 10, 8, 6, 1.5) + _R(12, 9, 16, 8, 1.5) + _R(28, 7, 24, 2.2) + _R(28, 17.8, 24, 2.2) + _GR(15) + _R(16, 17, 8, 5, 1.5), _C(56, 13, 2), '<path d="M29 13l4-3 3 6 4-6 3 6 4-6 3 3"/>'],
}
ARMOR_EX = {
    'vanguard': '<path d="M14.5 2.5h3l1 5.5h-5z" fill="{c}"/>',
    'recon': '<path d="M10 9L6.5 2.5" stroke="#c3cbe6" stroke-width="1.4"/><circle cx="6.3" cy="2.3" r="1.5" fill="{c}"/>',
    'jugg': '<path d="M6.5 23h19v3.5l-3.5 3.5H10l-3.5-3.5z" fill="#c3cbe6"/><path d="M11 26.5v2M16 26.5v2.5M21 26.5v2" stroke="{c}" stroke-width="1.4"/>',
    'specter': '<path d="M7.5 13L2.5 6l6.5 3.5zM24.5 13l5-7-6.5 3.5z" fill="#c3cbe6"/>',
    'medic': '<path d="M14.6 1.8h2.8v2.6H20v2.8h-2.6v2.6h-2.8V7.2H12V4.4h2.6z" fill="{c}"/>',
    'eng': '<path d="M22 9l3.5-6.5" stroke="#c3cbe6" stroke-width="1.4"/><circle cx="25.7" cy="2.3" r="1.5" fill="{c}"/><circle cx="12.3" cy="12.6" r="2.4" fill="none" stroke="{c}" stroke-width="1.5"/><circle cx="19.7" cy="12.6" r="2.4" fill="none" stroke="{c}" stroke-width="1.5"/>',
    'mk2': '<path d="M3 15l4-3h3v6H5z M29 15l-4-3h-3v6h5z" fill="{c}"/>',
    'mk3': '<path d="M10 4l6-3 6 3-1 4H11z" fill="{c}"/><path d="M4 20v6M28 20v6" stroke="{c}" stroke-width="2"/>',
    'mk4': '<path d="M9 6l3-5 4 3 4-3 3 5z" fill="{c}"/><path d="M1 17l5-6v9zM31 17l-5-6v9z" fill="{c}"/>',
}
SKILL_P = {
    'dash': '<path d="M5 9l7 7-7 7M13 9l7 7-7 7M21 9l6.5 7-6.5 7"/>',
    'shield': '<path d="M16 3.5l10 4v7.5c0 7-4.5 11-10 13.5C10.5 26 6 22 6 15V7.5z"/><path d="M16 9v14M11 14h10" stroke-width="1.6"/>',
    'drone': '<circle cx="16" cy="18" r="5.5"/><path d="M3.5 11h9.5M19 11h9.5M8.3 11V7.5M23.7 11V7.5M12.5 14.5L10 11M19.5 14.5L22 11"/><circle cx="16" cy="18" r="1.8" fill="#fff"/>',
    'chrono': '<circle cx="16" cy="17.5" r="10"/><path d="M16 11.5v6l4.5 3M12.5 4h7M16 4v3.5"/>',
    'nanite': '<path d="M16 3l11 6.5v13L16 29 5 22.5v-13z"/><path d="M16 10v12M10 16h12"/>',
    'grapple': '<path d="M5 27l13-13"/><path d="M18 14l3-9 3 3 3 3-9 3z"/><path d="M21 5l-4-1M27 11l1 4"/><circle cx="5" cy="27" r="2" fill="#fff"/><path d="M8 24c2 1 3 2 3 4" stroke-dasharray="2 2"/>',
}


def build_icons():
    d = os.path.join(ROOT, "assets/icons")
    os.makedirs(d, exist_ok=True)
    for w in WEAPONS:
        b, f, s = WICON[w['id']]
        c = w['hex']
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="112" viewBox="0 0 64 28"><g fill="#c3cbe6">%s</g><g fill="%s">%s</g>'
               '<g fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>') % (b, c, f, c, s)
        open(os.path.join(d, "weapon_%s.svg" % w['id']), "w").write(svg)
    for a in ARMORS:
        c = a['c1']
        stripe = '#b46bff' if a['id'] == 'specter' else '#3d7dff'
        wide = ' transform="translate(16 17) scale(1.1 1) translate(-16 -17)"' if a['id'] == 'jugg' else ''
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 32 32"><g%s><path d="M6 19c0-7 4.5-12 10-12s10 5 10 12v4l-4 4H10l-4-4z" fill="#c3cbe6"/>'
               '<path d="M8.5 15.5l7.5 4 7.5-4M16 19.5V25" stroke="%s" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
               '<circle cx="6.2" cy="19" r="2.1" fill="#0a0620" stroke="%s" stroke-width="1.4"/><circle cx="25.8" cy="19" r="2.1" fill="#0a0620" stroke="%s" stroke-width="1.4"/></g>%s</svg>'
               ) % (wide, stripe, c, c, ARMOR_EX.get(a['id'], '').replace('{c}', c))
        open(os.path.join(d, "armor_%s.svg" % a['id']), "w").write(svg)
    for s in SKILLS:
        c = s['col']
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="144" height="144" viewBox="-2 -2 36 36" fill="none"><defs><radialGradient id="g" cx="50%%" cy="38%%" r="62%%">'
               '<stop offset="0" stop-color="%s" stop-opacity=".55"/><stop offset="1" stop-color="#0a0620" stop-opacity=".9"/></radialGradient></defs>'
               '<path d="M16 -.5l14.3 8.25v16.5L16 32.5 1.7 24.25V7.75z" fill="url(#g)" stroke="%s" stroke-width="1.4" stroke-opacity=".9"/>'
               '<path d="M16 2.2l12 6.9v13.8L16 29.8 4 22.9V9.1z" stroke="#fff" stroke-opacity=".14" stroke-width=".8"/>'
               '<g transform="translate(16 16) scale(.62) translate(-16 -16)" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>'
               ) % (c, c, SKILL_P[s['id']])
        open(os.path.join(d, "skill_%s.svg" % s['id']), "w").write(svg)


# ---------------------------------------------------------------- UI theme
def build_theme():
    t = Resource("Theme")
    font = t.sub_res("SystemFont", font_names=Raw('PackedStringArray("Orbitron", "Chakra Petch", "Trebuchet MS", "DejaVu Sans", "sans-serif")'), font_weight=600)
    t.props["default_font"] = font
    t.props["default_font_size"] = 13

    def box(bg, border="#3a2a80", bw=1, r=10, pad=8, a=None):
        return t.sub_res("StyleBoxFlat", bg_color=hexcol(bg) if not a else hexcol(bg, a), border_color=hexcol(border),
                         border_width_left=bw, border_width_top=bw, border_width_right=bw, border_width_bottom=bw,
                         corner_radius_top_left=r, corner_radius_top_right=r, corner_radius_bottom_right=r, corner_radius_bottom_left=r,
                         content_margin_left=pad, content_margin_top=pad * 0.75, content_margin_right=pad, content_margin_bottom=pad * 0.75)
    glass = box("#0c0824", "#826ee6", 1, 12, 8, 0.62)
    p = t.props
    p["Button/styles/normal"] = glass
    p["Button/styles/hover"] = box("#140c34", "#aaa0ff", 1, 12, 8, 0.75)
    p["Button/styles/pressed"] = box("#21e6ff", "#21e6ff", 1, 12, 8, 0.18)
    p["Button/styles/focus"] = box("#000000", "#21e6ff", 2, 12, 8, 0.0)
    p["Button/styles/disabled"] = glass
    p["Button/colors/font_color"] = hexcol("#f4f0ff")
    p["Button/colors/font_hover_color"] = hexcol("#ffffff")
    p["Button/colors/font_pressed_color"] = hexcol("#21e6ff")
    p["Button/colors/font_focus_color"] = hexcol("#ffffff")
    p["Button/font_sizes/font_size"] = 12
    p["Button/constants/h_separation"] = 10
    p["Button/constants/icon_max_width"] = 64
    p["Tile/base_type"] = SN("Button")
    p["Tile/styles/normal"] = box("#0a0620", "#826ee6", 1, 8, 4, 0.55)
    p["Tile/styles/pressed"] = box("#21e6ff", "#21e6ff", 1, 8, 4, 0.12)
    p["Tile/colors/font_color"] = hexcol("#a99bd6")
    p["Tile/constants/icon_max_width"] = 72
    p["CTA/base_type"] = SN("Button")
    p["CTA/styles/normal"] = box("#ff2bd6", "#21e6ff", 2, 12, 14)
    p["CTA/styles/hover"] = box("#ff5be0", "#ffffff", 2, 12, 14)
    p["CTA/styles/pressed"] = box("#21e6ff", "#ffffff", 2, 12, 14)
    p["CTA/colors/font_color"] = hexcol("#ffffff")
    p["CTA/font_sizes/font_size"] = 17
    p["Ghost/base_type"] = SN("Button")
    p["Ghost/styles/normal"] = box("#000000", "#3a2a80", 1, 4, 14, 0.0)
    p["Ghost/styles/hover"] = box("#140c34", "#aaa0ff", 1, 4, 14)
    p["Panel/styles/panel"] = box("#0c0824", "#826ee6", 1, 14, 10, 0.62)
    p["PanelContainer/styles/panel"] = box("#0c0824", "#826ee6", 1, 14, 10, 0.62)
    p["Card/base_type"] = SN("PanelContainer")
    p["Card/styles/panel"] = box("#0a0620", "#ffffff", 1, 10, 8, 0.7)
    p["Label/colors/font_color"] = hexcol("#f4f0ff")
    p["Label/colors/font_shadow_color"] = hexcol("#000000", 0.6)
    p["Label/constants/shadow_offset_y"] = 1
    p["Label/constants/shadow_outline_size"] = 4
    p["Big/base_type"] = SN("Label")
    p["Big/font_sizes/font_size"] = 54
    p["Big/colors/font_shadow_color"] = hexcol("#ff2bd6")
    p["Big/constants/shadow_outline_size"] = 18
    p["Dim/base_type"] = SN("Label")
    p["Dim/colors/font_color"] = hexcol("#a99bd6")
    p["Dim/font_sizes/font_size"] = 11
    p["StatLabel/base_type"] = SN("Label")
    p["StatLabel/colors/font_color"] = hexcol("#a99bd6")
    p["StatLabel/font_sizes/font_size"] = 10
    p["RichTextLabel/colors/default_color"] = hexcol("#a99bd6")
    p["RichTextLabel/font_sizes/normal_font_size"] = 12
    p["RichTextLabel/font_sizes/bold_font_size"] = 12
    p["RichTextLabel/colors/font_outline_color"] = hexcol("#000000")
    p["ProgressBar/styles/background"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#ffffff", 0.12), corner_radius_top_left=3, corner_radius_top_right=3, corner_radius_bottom_right=3, corner_radius_bottom_left=3)
    p["ProgressBar/styles/fill"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#ff2bd6"), border_color=hexcol("#21e6ff"), border_width_right=3, corner_radius_top_left=3, corner_radius_top_right=3, corner_radius_bottom_right=3, corner_radius_bottom_left=3)
    p["HSlider/styles/slider"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#3a2a80"), content_margin_top=2, content_margin_bottom=2)
    p["HSlider/styles/grabber_area"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#ff2bd6"), content_margin_top=2, content_margin_bottom=2)
    p["HSlider/styles/grabber_area_highlight"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#21e6ff"), content_margin_top=2, content_margin_bottom=2)
    t.save("assets/ui/theme.tres")


def build_menu_theme():
    """Main-menu theme (dark sci-fi / cel): black panels, hairline crimson borders, skewed angular buttons."""
    t = Resource("Theme")
    base = t.sub_res("SystemFont", font_names=Raw('PackedStringArray("Rajdhani", "Chakra Petch", "Oswald", "Arial Narrow", "DejaVu Sans Condensed", "sans-serif")'), font_weight=700)
    font = t.sub_res("FontVariation", base_font=base, spacing_glyph=1)
    t.props["default_font"] = font
    t.props["default_font_size"] = 13
    RED, INK, BONE = "#c8101a", "#050506", "#d9d6d0"

    def box(bg, a=0.82, border=RED, bw=(0, 0, 0, 0), skew=0.0, pad=10, ba=1.0):
        return t.sub_res("StyleBoxFlat", bg_color=hexcol(bg, a), border_color=hexcol(border, ba), skew=V2(skew, 0),
                         border_width_left=bw[0], border_width_top=bw[1], border_width_right=bw[2], border_width_bottom=bw[3],
                         content_margin_left=pad, content_margin_top=pad * 0.7, content_margin_right=pad, content_margin_bottom=pad * 0.7,
                         anti_aliasing=False)
    p = t.props
    p["Button/styles/normal"] = box(INK, .78, "#3a3a40", (1, 1, 1, 1), -.18)
    p["Button/styles/hover"] = box("#140405", .9, RED, (1, 1, 1, 3), -.18)
    p["Button/styles/pressed"] = box(RED, .35, RED, (1, 1, 1, 3), -.18)
    p["Button/styles/focus"] = box("#000000", 0, RED, (1, 1, 1, 1), -.18)
    p["Button/styles/disabled"] = box(INK, .5, "#26262a", (1, 1, 1, 1), -.18)
    p["Button/colors/font_color"] = hexcol(BONE)
    p["Button/colors/font_hover_color"] = hexcol("#ffffff")
    p["Button/colors/font_pressed_color"] = hexcol("#ff3a3a")
    p["Button/colors/font_focus_color"] = hexcol("#ffffff")
    p["Button/colors/font_disabled_color"] = hexcol("#5a5a60")
    p["Button/font_sizes/font_size"] = 13
    p["Button/constants/h_separation"] = 10
    p["Button/constants/icon_max_width"] = 64
    p["Tile/base_type"] = SN("Button")
    p["Tile/styles/normal"] = box(INK, .7, "#2a2a30", (1, 1, 1, 1), 0, 4)
    p["Tile/styles/hover"] = box("#140405", .85, RED, (1, 1, 1, 1), 0, 4)
    p["Tile/styles/pressed"] = box(RED, .25, RED, (2, 2, 2, 2), 0, 4)
    p["Tile/colors/font_color"] = hexcol("#8a8890")
    p["Tile/constants/icon_max_width"] = 72
    p["CTA/base_type"] = SN("Button")
    p["CTA/styles/normal"] = box("#8e0a12", .95, "#ff2a2a", (0, 0, 0, 3), -.22, 16)
    p["CTA/styles/hover"] = box("#c8101a", 1, "#ffffff", (0, 0, 0, 3), -.22, 16)
    p["CTA/styles/pressed"] = box("#3a0306", 1, "#ff2a2a", (0, 0, 0, 3), -.22, 16)
    p["CTA/styles/focus"] = box("#000000", 0, "#ffffff", (1, 1, 1, 1), -.22, 16)
    p["CTA/colors/font_color"] = hexcol("#ffffff")
    p["CTA/font_sizes/font_size"] = 19
    p["Ghost/base_type"] = SN("Button")
    p["Ghost/styles/normal"] = box("#000000", 0, "#3a3a40", (0, 0, 0, 1), 0, 14)
    p["Ghost/styles/hover"] = box("#140405", .8, RED, (0, 0, 0, 1), 0, 14)
    p["Panel/styles/panel"] = box(INK, .8, "#2a2a30", (1, 1, 1, 1), 0, 12)
    p["PanelContainer/styles/panel"] = box(INK, .8, RED, (3, 0, 0, 0), 0, 12)
    p["Card/base_type"] = SN("PanelContainer")
    p["Card/styles/panel"] = box(INK, .75, "#3a3a40", (1, 1, 1, 1), 0, 8)
    p["Label/colors/font_color"] = hexcol(BONE)
    p["Label/colors/font_shadow_color"] = hexcol("#000000", .9)
    p["Label/constants/shadow_offset_x"] = 1
    p["Label/constants/shadow_offset_y"] = 1
    p["Label/constants/shadow_outline_size"] = 3
    p["LineEdit/styles/normal"] = box("#000000", .7, "#3a3a40", (0, 0, 0, 1), 0, 8)
    p["LineEdit/styles/focus"] = box("#000000", .8, RED, (0, 0, 0, 2), 0, 8)
    p["LineEdit/colors/font_color"] = hexcol("#ffffff")
    p["LineEdit/colors/font_placeholder_color"] = hexcol("#5a5a60")
    p["LineEdit/colors/caret_color"] = hexcol(RED)
    p["RichTextLabel/colors/default_color"] = hexcol("#a8a6a0")
    p["RichTextLabel/font_sizes/normal_font_size"] = 13
    p["RichTextLabel/font_sizes/bold_font_size"] = 13
    p["ProgressBar/styles/background"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#ffffff", 0.08))
    p["ProgressBar/styles/fill"] = t.sub_res("StyleBoxFlat", bg_color=hexcol(RED), border_color=hexcol("#ff6060"), border_width_right=2)
    p["HSlider/styles/slider"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#2a2a30"), content_margin_top=1, content_margin_bottom=1)
    p["HSlider/styles/grabber_area"] = t.sub_res("StyleBoxFlat", bg_color=hexcol(RED), content_margin_top=1, content_margin_bottom=1)
    p["HSlider/styles/grabber_area_highlight"] = t.sub_res("StyleBoxFlat", bg_color=hexcol("#ff3a3a"), content_margin_top=1, content_margin_bottom=1)
    p["TooltipPanel/styles/panel"] = box(INK, .95, RED, (1, 1, 1, 1), 0, 8)
    p["Big/base_type"] = SN("Label")
    p["Big/font_sizes/font_size"] = 54
    p["Big/colors/font_shadow_color"] = hexcol("#c8101a")
    p["Big/constants/shadow_outline_size"] = 14
    p["StatLabel/base_type"] = SN("Label")
    p["StatLabel/colors/font_color"] = hexcol("#8a8890")
    p["StatLabel/font_sizes/font_size"] = 11
    p["Dim/base_type"] = SN("Label")
    p["Dim/colors/font_color"] = hexcol("#8a8890")
    p["Dim/font_sizes/font_size"] = 11
    t.save("assets/ui/theme_menu.tres")


# ---------------------------------------------------------------- audio buses + project settings
def build_project():
    open(os.path.join(ROOT, "default_bus_layout.tres"), "w").write('''[gd_resource type="AudioBusLayout" format=3]

[resource]
bus/1/name = &"Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
''')

    def key(code):
        return ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
                '"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":%d,'
                '"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)') % code

    def mouse(b):
        return ('Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
                '"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),'
                '"global_position":Vector2(0, 0),"factor":1.0,"button_index":%d,"canceled":false,"pressed":false,"double_click":false,"script":null)') % b
    SHIFT, CTRL, ESC = 4194325, 4194326, 4194305
    actions = [("move_forward", [key(87)]), ("move_back", [key(83)]), ("move_left", [key(65)]), ("move_right", [key(68)]),
               ("jump", [key(32)]), ("sprint", [key(SHIFT)]), ("crouch", [key(67), key(CTRL)]), ("fire", [mouse(1)]), ("aim", [mouse(2)]),
               ("reload", [key(82)]), ("swap_weapon", [key(88)]), ("weapon_1", [key(49)]), ("weapon_2", [key(50)]),
               ("lethal", [key(69)]), ("tactical", [key(71)]), ("skill", [key(81), key(70)]),
               ("streak_1", [key(52)]), ("streak_2", [key(53)]), ("streak_3", [key(54)]),
               ("quick_turn", [key(86)]), ("toggle_view", [key(84)]), ("map", [key(77)]), ("pause", [key(80), key(ESC)])]
    inp = "\n".join('%s={\n"deadzone": 0.2,\n"events": [%s]\n}' % (n, ", ".join(ev)) for n, ev in actions)
    open(os.path.join(ROOT, "project.godot"), "w").write('''; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="Viral Vanguard"
config/description="Neon arena shooter: hold Neon Core City against waves of spider-robot swarmers."
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"
boot_splash/image="res://assets/ui/boot_art.png"
boot_splash/fullsize=true
boot_splash/bg_color=Color(0.02, 0.01, 0.06, 1)

[audio]

buses/default_bus_layout="res://default_bus_layout.tres"

[autoload]

Game="*res://scripts/autoload/game.gd"
Sfx="*res://scripts/autoload/sfx.gd"
Net="*res://scripts/autoload/net.gd"

[display]

window/size/viewport_width=1600
window/size/viewport_height=900
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[gui]

theme/custom="res://assets/ui/theme_menu.tres"

[input]

%s

[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player"
3d_physics/layer_3="enemies"

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

rendering_device/driver.windows="d3d12"
renderer/rendering_method.web="gl_compatibility"
anti_aliasing/quality/msaa_3d=1
''' % inp)


if __name__ == "__main__":
    build_materials()
    build_icons()
    build_data()
    build_theme()
    build_project()
    print("resources ok")
