class_name V77Data
## v77 loadout data, copied field for field from the original game (WEAPONS, ARMORS, SKILLS, STREAKS and the
## per-weapon tables beside them). Colours are 0xRRGGBB like v77; use col() for a Color.

const MAPK := 0.765

const WEAPONS := [
	{"id": "pulse", "carry": "Low ready", "rlName": "Magazine swap", "name": "VX-9 Helix Carbine", "cls": "Assault", "desc": "Steady full-auto fire that works at any range.", "dmg": 20, "rate": .09, "mag": 30, "rl": 1.4, "pel": 1, "spr": .004, "rec": .012, "kick": .006, "brk": .9, "col": 0x21e6ff, "hex": "#21e6ff", "snd": 520},
	{"id": "scatter", "carry": "Port arms", "rlName": "Shell feed and pump", "name": "Breacher-12 Scattergun", "cls": "Shotgun", "desc": "Eight pellets a shell. Tears through walls and anything close.", "dmg": 13, "rate": .65, "mag": 6, "rl": 2, "pel": 8, "spr": .09, "rec": .05, "kick": .03, "brk": .75, "col": 0xff8a2b, "hex": "#ff8a2b", "snd": 180},
	{"id": "rail", "carry": "Sling ready", "rlName": "Power cell exchange", "name": "Orion Rail Lance", "cls": "Marksman", "desc": "Pierces every infected in a line and punches through three blocks.", "dmg": 110, "rate": .85, "mag": 5, "rl": 2.1, "pel": 1, "spr": 0, "rec": .04, "kick": .025, "brk": 1.1, "pierce": 1, "col": 0xb46bff, "hex": "#b46bff", "snd": 900},
	{"id": "smg", "carry": "High ready", "rlName": "Drum swap", "name": "Hornet-7 PDW", "cls": "Close quarters", "desc": "Very fast fire and quick reloads, with light hits.", "dmg": 10, "rate": .05, "mag": 45, "rl": 1.2, "pel": 1, "spr": .018, "rec": .006, "kick": .003, "brk": .7, "col": 0x3dff9a, "hex": "#3dff9a", "snd": 760},
	{"id": "arc", "carry": "Hip carry", "rlName": "Break-open load", "name": "Nova Arc Mortar", "cls": "Explosive", "desc": "Rounds detonate on impact and hit everything nearby.", "dmg": 60, "rate": .6, "mag": 4, "rl": 2, "pel": 1, "spr": 0, "rec": .05, "kick": .03, "brk": 2.4, "boom": 3.6, "col": 0xffd23d, "hex": "#ffd23d", "snd": 140},
	{"id": "ion", "carry": "Underarm carry", "rlName": "Belt box change", "name": "Tempest Ion Repeater", "cls": "Heavy", "desc": "Barrels spin up the longer you fire, reaching a torrent of bolts. You move 15% slower.", "dmg": 14, "rate": .055, "spin": 1, "move": .85, "mag": 90, "rl": 2.6, "pel": 1, "spr": .02, "rec": .004, "kick": .003, "brk": .8, "col": 0x3d8bff, "hex": "#3d8bff", "snd": 300},
	{"id": "cryo", "carry": "Low ready", "rlName": "Canister twist", "name": "Glacier Cryo Projector", "cls": "Control", "desc": "Short-range freezing stream. Chilled infected move at 40% speed.", "dmg": 8, "rate": .06, "mag": 60, "rl": 1.8, "pel": 1, "spr": .012, "rec": .002, "kick": .001, "brk": .5, "chill": 2.2, "range": 22, "col": 0x9fe8ff, "hex": "#9fe8ff", "snd": 1200},
	{"id": "void", "carry": "Close carry", "rlName": "Core recharge", "name": "Event Horizon Voidcaster", "cls": "Exotic", "desc": "Opens a gravity well that drags nearby infected in and crushes them.", "dmg": 40, "rate": 1.1, "mag": 3, "rl": 2.4, "pel": 1, "spr": 0, "rec": .05, "kick": .02, "brk": 1.4, "well": 1.8, "col": 0xe14dff, "hex": "#e14dff", "snd": 90},
	{"id": "burst", "carry": "Compressed ready", "rlName": "Side-mag slap", "name": "Fang-3 Burst Rifle", "cls": "Burst", "desc": "Three-round bursts with tight grouping and heavy hits.", "dmg": 28, "rate": .38, "burst": 3, "mag": 24, "rl": 1.5, "pel": 1, "spr": .003, "rec": .01, "kick": .005, "brk": .9, "col": 0xff3d5a, "hex": "#ff3d5a", "snd": 640},
	{"id": "chain", "carry": "Cross carry", "rlName": "Capacitor flip", "name": "Stormcaller Chain Emitter", "cls": "Energy", "desc": "Lightning that jumps from the target to three more infected nearby.", "dmg": 34, "rate": .32, "chain": 3, "mag": 12, "rl": 1.9, "pel": 1, "spr": 0, "rec": .02, "kick": .008, "brk": .8, "col": 0xcfe0ff, "hex": "#cfe0ff", "snd": 1500},
]

const ARMORS := [
	{"id": "recon", "name": "Recon", "cls": "Light", "hp": 80, "spd": 1.2, "dr": 0.0, "reg": 2, "c1": "#21e6ff", "c2": "#dfe9ff", "perk": "Moves 20% faster than standard."},
	{"id": "vanguard", "name": "Vanguard", "cls": "Medium", "hp": 110, "spd": 1.0, "dr": .1, "reg": 2, "c1": "#ff2bd6", "c2": "#cfcae8", "perk": "Takes 10% less damage."},
	{"id": "jugg", "name": "Juggernaut", "cls": "Heavy", "hp": 170, "spd": .8, "dr": .25, "reg": 1, "c1": "#ff2a3d", "c2": "#6a6386", "perk": "Takes 25% less damage. Slow to move."},
	{"id": "specter", "name": "Specter", "cls": "Stealth", "hp": 85, "spd": 1.12, "dr": 0.0, "reg": 2, "eslow": .8, "c1": "#b46bff", "c2": "#2a2448", "perk": "Infected close in 20% slower while they track you."},
	{"id": "medic", "name": "Medic", "cls": "Support", "hp": 100, "spd": 1.0, "dr": .05, "reg": 7, "c1": "#3dff9a", "c2": "#eef3f0", "perk": "Regenerates 7 health per second."},
	{"id": "eng", "name": "Engineer", "cls": "Tech", "hp": 115, "spd": .95, "dr": .08, "reg": 2, "cdr": .35, "c1": "#ffd23d", "c2": "#4a4466", "perk": "Skill and blast recharge 35% faster."},
	{"id": "mk2", "tier": 1, "name": "Sentinel Mk II", "cls": "Upgrade I", "hp": 130, "spd": 1.02, "dr": .14, "reg": 3, "cdr": .1, "c1": "#2f7bff", "c2": "#c9d4e6", "perk": "Layered chest overplate, heavy segmented pauldrons, vambraces and thigh plates. 14% less damage, skills recharge 10% faster."},
	{"id": "mk3", "tier": 2, "name": "Warden Mk III", "cls": "Upgrade II", "hp": 155, "spd": 1.06, "dr": .18, "reg": 4, "cdr": .2, "eslow": .9, "jmp": 1.08, "c1": "#19b8ff", "c2": "#e3e8ef", "perk": "Back-mounted power pack with exhaust stacks, armoured knees, hip plates, helmet fins. Jetpack: hold jump in mid-air. 18% less damage, 20% faster recharge, higher jumps, Infected near you move 10% slower."},
	{"id": "mk4", "tier": 3, "name": "Ascendant Mk IV", "cls": "Upgrade III", "hp": 180, "spd": 1.1, "dr": .24, "reg": 5, "cdr": .3, "eslow": .8, "jmp": 1.18, "c1": "#5a8cff", "c2": "#ffcf6a", "perk": "Chest reactor core, swept thruster wings, gold-trimmed crown helmet and glowing conduits. Twin-nozzle jetpack with more thrust and fuel: hold jump in mid-air. 24% less damage, 30% faster recharge, regenerates 5/s, highest jumps, Infected 20% slower."},
]

const SKILLS := [
	{"id": "dash", "name": "Phase Dash", "short": "DASH", "cd": 5, "col": "#21e6ff", "desc": "Blink forward and ignore damage for half a second."},
	{"id": "shield", "name": "Overshield", "short": "SHIELD", "cd": 14, "col": "#7ad7ff", "desc": "Block all incoming damage for 4 seconds."},
	{"id": "drone", "name": "Hunter Drone", "short": "DRONE", "cd": 18, "col": "#ff2bd6", "desc": "Your drone fires on the nearest infected for 8 seconds."},
	{"id": "chrono", "name": "Chrono Field", "short": "CHRONO", "cd": 16, "col": "#b46bff", "desc": "Slow every infected by 70% for 5 seconds."},
	{"id": "nanite", "name": "Nanite Surge", "short": "HEAL", "cd": 12, "col": "#3dff9a", "desc": "Restore 50 health instantly."},
	{"id": "grapple", "name": "Grapple Gun", "short": "GRAPPLE", "cd": 2.5, "col": "#3dffc8", "desc": "Fire a cable up to 20 m at any building or obstacle and reel yourself in. Aim near a roof edge to land on the roof. Hit a high wall and you cling to it: fire again to climb higher or jump to kick off."},
]

const STREAKS := [{"n": "SENTRY", "c": 5}, {"n": "STRIKE", "c": 10}, {"n": "OVERDRIVE", "c": 15}]
const FMODE := {"pulse": "ads", "scatter": "hip", "rail": "release", "smg": "hip", "arc": "mixed", "ion": "hip", "cryo": "hip", "void": "onetap", "burst": "ads", "chain": "hip"}
const ADS_T := {"rail": .32, "void": .3, "arc": .28, "burst": .22, "scatter": .24}
const ADS_Z := {"rail": .45, "void": .3}
const WRANGE := {"pulse": 90, "burst": 85, "smg": 45, "scatter": 24, "rail": 170, "arc": 75, "ion": 60, "cryo": 22, "void": 45, "chain": 32}
const SHORT := {"pulse": "HELIX", "scatter": "BREACH", "rail": "ORION", "smg": "HORNET", "arc": "NOVA", "ion": "TEMPEST", "cryo": "GLACIER", "void": "HORIZON", "burst": "FANG-3", "chain": "STORM"}
const SIGHT_YC := {"pulse": .125, "smg": .115, "burst": .135, "chain": .125, "scatter": .128, "ion": .172, "rail": .13, "arc": .12, "cryo": .115, "void": .14}
const SCOPED := {"rail": 1}
const STM := [1.0, .55, .25]       ## stance speed: stand / crouch / prone
const EYE := [1.65, 1.15, .55]     ## stance eye height


static func pick(arr: Array, id: String) -> Dictionary:
	for x in arr:
		if x.id == id:
			return x
	return arr[0]


static func col(hex: int) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255)


static func weapon_range(w: Dictionary) -> float:
	return float(WRANGE.get(w.id, w.get("range", 80)))
