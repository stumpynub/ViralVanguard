# Neon Core

**Neon Core** is a Godot 4.7 game built from the v77 build: the same mechanics, weapons, armors, skills, streaks,
spiders, drone, doors, glass and lifts, in a Neon Core version of the v77 city with an elevated ring road, street
footbridges and jump pads only where they reach high ground.

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
- `tools/city/` — Neon Core's changes to the v77 city generator (ring road, footbridges, pads, balconies), applied as
  exact-text patches: `node tools/city/build_city_page.mjs` writes `bake/neoncore_city.html`
- `tools/bake/` — the bake pipeline: `node tools/bake/server.mjs bake/neoncore_city.html` serves the city page, then in
  the page `VVBake.exportObject(S, 'city', {exclude: [C]})`, `VVCollision.run()` and `VVGrid.run()` write `bake/`;
  `VVPlan.draw('plan.png')` draws a plan view with any blocked deck cells
- `tools/import_bake.gd` — builds the Godot scenes from `bake/`: `-- city prepare`, then `--import`, then `-- city`;
  copy `bake/collision/*` to `assets/baked/collision/`
- `tests/play_test.tscn` — automated run that saves screenshots to `build/shots/`
- `tests/ci_test.tscn` — the headless checks GitHub Actions runs (gameplay, decks, footbridge, viaduct walk, jump pads)
