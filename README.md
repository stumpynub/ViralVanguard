# Neon Core

**Neon Core** is a Godot 4.7 game built from the v77 build — same city layout, mechanics, weapons, armors, skills, streaks,
spiders, drone, doors, glass, lifts and jump pads

## Play
- **Windows:** download `NeonCore-Windows.zip` from Releases, unzip, run `NeonCore.exe` (keep `NeonCore.pck` next to it).
- **From source:** open this folder in Godot 4.7 (Compatibility renderer) and press F5.

## Controls
WASD move · Mouse aim · LMB fire · RMB aim · Shift sprint · Space jump · C crouch (hold: prone) · R reload ·
X swap · E lethal · G stun · Q skill · 4/5/6 streaks · V 180 · M map · P/Esc pause

## Layout
- `scenes/main.tscn` — entry: boot → hangar menu → deploy cinematic → play
- `scripts/v77/` — game logic ported from v77 (`game.gd`, `data.gd`, `collision.gd`, `hud.gd`, `sfx.gd`, `main.gd`, `hangar_stage.gd`)
- `shaders/` — three.js material ports, operative shader, hologram
- `assets/baked/` — city, weapons, spider, drone, operative and collision data baked from v77
- `tools/` — the bake pipeline (`tools/bake/*.js` run inside v77, `import_bake.gd` builds Godot scenes)
- `tests/play_test.tscn` — automated run that saves screenshots to `build/shots/`
