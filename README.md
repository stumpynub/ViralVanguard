# Viral Vanguard (Godot 4.7)

A port of the single-file Three.js game Viral Vanguard to Godot 4.7 (GDScript, Forward+, Jolt), now following the
**v74** build: hold **Neon Core City** against waves of spider-robot swarmers. Open the project and press F5.

### v74 (Neon Core City)

- **Map:** `scenes/world/arena.tscn` is generated from `data/ncc_layout.json` by `tools/build_arena_ncc.py`. It includes:
  - the Grand Plaza and the 217 m Central Spire
  - 8 boulevards (`RoadSegment` nodes, markings drawn by `road.gdshader`)
  - about 100 buildings and towers, plus gateway towers straddling the street (`Building.elevation`)
  - three elevated highways, pedestrian bridges and glass sky-bridges, the skyport, the market, the transit canopy, parks
  - parked spacecraft and motorcycles, the bay with mountains, and a floating planet

  The kit meshes (`assets/models/kit/`), vehicles and drone come from `tools/extract_v74.py`.
- **Traversal:**
  - Gravity lifts (`lift.tscn`, group `lifts`) carry you up to decks.
  - Launch pads (`launch_pad.tscn`, group `pads`) throw you along a fixed arc onto roofs. Steering is locked until you land.
  - The grapple reaches 20 m.
- **Combat:**
  - Per-weapon max range, with damage falling to 35% at max range.
  - Spider hit zones: head end 1.3x, body 1x, legs only 0.35x.
  - Sky-bridge windows (`GlassPanel`) shatter when shot or caught in a blast.
  - Killed spiders topple, curl up and burn to ash (`SpiderCorpse`).
- **Presentation:**
  - Deploy fly-through (`scenes/ui/deploy_cinematic.tscn`, skippable; `Main.play_cinematic` turns it off).
  - Boot splash art and the v74 hunter drone.
- **Networking is unchanged:** it uses the same WebRTC/PeerJS + ENet `Net` autoload and host-authoritative arena RPCs.
  - Glass breaks go through `Arena.shatter_glass()`. The host makes them official and late joiners receive the broken list.
  - Corpses and lifts/pads are local physics and visuals on each peer.
- Local split-screen co-op from v74 is **not** ported.

### Dark cel style, the hunter, the sniper and the duel

- **Look:** black / grey / crimson cel shading with hairline ink everywhere: `assets/shaders/menu/toon.gdshader` +
  `outline.gdshader` (applied at runtime by `ToonStyle`), the menu's comic pass (`ink3d.gdshader`, `post.gdshader`) and
  the in-match film / ink grade (`assets/shaders/game_post.gdshader`). UI theme: `assets/ui/theme_menu.tres`.
- **Main character:** the night hunter (`scenes/characters/hunter_operative.tscn`), auto-rigged from a generated mesh by
  `tools/rig/blender_rig_any.py` (fits the arms, adds finger / thumb chains, re-poses to the rig's rest) and
  `tools/rig/build_rig.gd -- <name> <src> <weighted> <joints.json>`. Locomotion is CC0 mocap (Quaternius UAL) retargeted
  in world space; the `*_rifle` clips leave arms / hands / fingers / chest / neck untracked (bone filter) so the IK owns them.
- **Full-body first person** (after `docs/first_person_animation.md` from Vooxle, adapted): modifiers in order
  SpineStabilizer → FirstPersonHead (shares the view pitch down the spine, gives the eye) → FullBodyIK (arms, palms,
  finger curl, feet) → GripLock. The camera rides the animated head; weapon / view feel are damped springs (look and
  move sway, landing dip, view / FOV punch, recoil that is paid back).
- **Nightfall .408 bolt rifle** (`data/weapons/sniper.tres`, `scenes/weapons/sniper.tscn`): hand-worked bolt cycle and a
  stripper-clip reload with the hands on the bolt / clip, brass ejection, real projectiles (travel time + drop), 6x scope
  with breathing sway, hold breath (sprint while scoped, it winds you), quickscope settle, one-shot headshots, scope glint
  that the other player sees.
- **Sniper duel** (hangar MODE button): `scenes/world/arena_duel.tscn` (`tools/build_duel_arena.py`), 1v1 on two rooftops,
  first to 5. Same networking: quick play has a separate duel pool, private duel codes start with D, and every joiner
  learns the host's mode from `Net._welcome` before deploying. Hits go to the victim's peer, the host scores kills.
  Solo it's a practice range.
- **Assets:** generated with the `atlas-assets` plugin (`.claude/skills/atlas-assets/`; images via Atlas, sounds via
  ElevenLabs) and CC0 downloads (Poly Haven textures). See `ASSET_LICENSES.md`: the hunter and sniper models are
  **placeholders** made with a non-cleared model and must be replaced before a commercial release.

## Layout

| Path | What it is |
|---|---|
| `scenes/main.tscn` | Flow: hangar → deploy → pause / death screens → hangar |
| `scenes/ui/hangar.tscn` | Loadout menu with the 3D operative turntable (`avatar_stage.tscn`) |
| `scenes/ui/hud.tscn`, `pause_menu.tscn`, `end_screen.tscn` | In-match UI |
| `scenes/world/arena.tscn` | The city. Every building, prop, sign and crate is a node under `City/<District>` |
| `scenes/world/props/*.tscn` | Reusable pieces: `building`, `neon_sign`, `billboard`, `hover_car`, `street_lamp`, `jersey_barrier`, `planter`, `crate_block`, `spire`, `plaza`, `ring_walkway`, `stair_tower`, … |
| `scenes/player/player.tscn` | Player body, camera, gun holder, drone, jet plume; scripts `player.gd`, `weapon_controller.gd`, `abilities.gd` |
| `scenes/weapons/<id>.tscn` | The 10 guns, built from named primitive parts (`Mag`, `Top`, `Spin`, … drive the reload animations) |
| `scenes/characters/sick_operative.tscn` | The main character: rigged `sick_rig.glb` (Skeleton3D with Godot humanoid bone names, skinned mesh, AnimationPlayer, chest weapon mount). Used in the hangar and as the player's body |
| `scenes/enemies/spider.tscn` | Swarmer (uses `assets/models/spider.glb`) |
| `scenes/fx/*.tscn` | Tracer, impact, explosion, blood, block chunks, void well |
| `data/weapons|armors|skills/*.tres` | All gameplay numbers. `data/database.tres` lists what appears in the hangar |
| `assets/models/` | Spider and the four operative armour suits, decoded from the original's packed mesh data |
| `assets/shaders/` | Procedural facades, wet road markings, sky, water, crates, billboards, scope |

## Editing

- **Tuning:** open a `.tres` in `data/` (damage, fire rate, health, cooldowns, fire mode…).
- **New weapon:** duplicate a weapon `.tres` and a gun scene, point `model_scene` at the new scene, add it to `data/database.tres`.
- **City:** move or duplicate nodes in `arena.tscn`. `Building`, `NeonSign`, `Billboard` and the tinted props are `@tool` scripts, so changing `size`, `text`, `paint`, etc. updates them live in the editor.
- **Sounds** are synthesized at startup from recipes in `scripts/autoload/sfx.gd` (a port of the original WebAudio synth). Music is in `assets/audio/`.

## The main character rig

`assets/models/sick_rig.glb` is rigged by a two-step pipeline:

```bash
~/Documents/blender-5.2.2-linux-x64/blender -b -P tools/rig/blender_weights.py -- assets/models/sick_rig.glb tools/rig/sick_weighted.glb
godot --headless --path . res://tools/rig/build_rig.tscn
```

1. Blender builds the armature, weights a voxel-remeshed proxy with automatic (heat) weights, and transfers them to the real mesh. Run on the mesh directly, heat weighting fails on separate armor plates.
2. Godot remaps the weights onto a 23-bone humanoid skeleton and removes cross-limb leaks and the few faces where the gloves touch the thighs. It then authors the animations: `idle`, `walk`, `run`, `jump`, `death`, plus `idle_rifle`, `walk_rifle`, `run_rifle`, `jump_rifle` and `crouch_rifle`, with the hands placed on the gun by IK. Bone names follow `SkeletonProfileHumanoid`, so Mixamo-style animations can be retargeted onto it on import. `tools/rig/stretch.tscn` reports any triangles that stretch in the walk cycle.

### Full body in game

The player *is* the character: in first person you see your own arms, hands, torso and legs.

- **Camera alignment:** the body slides each frame so its eye marker sits at the camera, so crouch, prone and look up/down line up with the view (`Player.eye_setback`).
- **`FullBodyIK`** (`scripts/characters/full_body_ik.gd`, a `SkeletonModifier3D` after the animation and the spine aim bend):
  - **Arms:** two-bone IK to the gun's `GripHand` / `SupportHand` markers, with clavicle assist for reach, finger direction, and a rifle-stance chest twist. During reloads the left hand follows the magazine.
  - **Legs:** each foot is planted on the real ground under it (stairs, curbs, crouching).
- **First-person rendering:** the helmet surface is hidden but still casts its shadow. Body pixels near the camera dither out (`fp_fade_near` / `fp_fade_far`), with the radius growing as you look down, so the collar never fills the screen.
- **Tuning:** the view-model gun sits where the character can reach (`Player.gun_hip`, `view_model_scale`).
- **Third person (T):** same IK, with the hands on the chest-mounted gun.
- `tests/fullbody_views.tscn` captures reference shots of all of this.

## Multiplayer (co-op, up to 8)

Peer-to-peer over **WebRTC**, so it runs straight from itch.io with no game server.

- **Matchmaking:** a free signaling relay (the public PeerJS server, `Net.SIGNAL_SERVER`) introduces players. It only carries the WebRTC handshake; gameplay goes directly between browsers.
- **Hangar → Play Online:**
  - **Quick Play** scans the public rooms. It joins a match in progress, or becomes the host of an empty room that others then drop into.
  - **Host Private Room** shows a 5-letter code, and **Join** takes one.
  - Desktop builds also have **Host LAN / Join IP** (ENet, port 7777), used by `tests/mp_test.tscn`.
- **Authority:**
  - The host (peer 1) runs the swarm, waves, score, crates, gravity wells and game over.
  - Each player simulates their own movement and hit detection and sends hits to the host (`Arena.damage_enemy / area_damage / destroy_blocks`).
  - Other players are `remote` bodies driven by 20 Hz state packets, with full-body animation and IK on their gun.
- **Deaths:** a downed player respawns after 8 s next to a teammate. When everyone is down it's game over, and the host can redeploy the whole squad.
- **Versioning:** `Net.VERSION` is part of every room name. Bump it whenever you change the network code so old and new builds never meet.
- **Web URL options:** `?quick=1`, `?room=CODE`, `?name=ACE`.

Known limits:
- Browsers freeze background tabs, so a host who switches tabs pauses the match for everyone. Another window or monitor is fine.
- There is no host migration. If the host leaves, everyone returns to the hangar.
- Without a TURN server, a minority of players behind strict NATs / corporate firewalls can't connect. Add one in `Net.ICE_SERVERS`.
- The public PeerJS relay is a free shared service. For a popular game, run your own (`npx peerjs --port 9000`, or any Node host) and point `SIGNAL_SERVER` at it.

## Publishing on itch.io

```bash
./tools/export_web.sh
```

This produces `build/viral-vanguard-web.zip` (~26 MB): a no-threads web build, so it needs no special headers. On itch:

1. Create a project and set **Kind of project** to **HTML**.
2. Upload the zip and tick **This file will be played in the browser**.
3. Set the viewport to 1280 × 720 and enable the **Fullscreen button**. Leave **SharedArrayBuffer support** off.
4. Save and view the page. Two people pressing **Quick Play** land in the same match.

The web build uses the Compatibility renderer (`rendering_method.web`). Shaders avoid per-instance uniforms because WebGL allows very few.

## Regenerating

`tools/` holds the Python scripts that produced the scenes from the original source:

```bash
python3 tools/extract_assets.py "/path/to/viral-vanguard.html"
python3 tools/extract_v74.py "/path/to/Viral_Vanguard_v74_coop.html"
python3 tools/build_all.py
```

`build_all.py` **overwrites** the generated scenes and resources. Once you hand-edit a scene in Godot, stop regenerating it.

## Tests

`tests/smoke_test.tscn` deploys with every weapon, armour and skill, fires and uses every ability (run headless:
`godot --headless --path . res://tests/smoke_test.tscn`). `tests/views.tscn` saves reference screenshots.
`tests/city_views.tscn` photographs Neon Core City (into `build/shots/`) and rides the lifts and launch pads.
`tests/fp_sniper.tscn` (`-- duel`), `tests/hands_view.tscn`, `tests/duel_views.tscn` and `tests/menu_shot.tscn` capture the
sniper, grips, duel map and menu; `tests/duel_mp_test.tscn -- host|client` plays a networked duel over ENet.

## Differences from the original

- Desktop controls only. The touch layout (virtual stick and buttons) is not ported.
- First-person arms and the hand-driven reload IK are left out. Guns animate their own parts (the original `RLD` choreography).
- Neon Core City skips some v74 decoration: aerial traffic, holo panels, light cones and the cinematic audio reverb engine.
- Grapple and ledge mantle use Godot physics raycasts instead of the original 1 m collision grid. Blood splats come from particles instead of decals.
