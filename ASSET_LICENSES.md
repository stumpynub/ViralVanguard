# Asset licenses

Viral Vanguard is published on itch.io. **Every generated asset that ships must have a license that allows
commercial use with no royalties, verified from a primary source, and recorded here before it goes in the game.**
Generation provenance (prompt, model, cost, date per file) is kept in `.atlas/` ledgers by the `atlas-assets`
skill (`.claude/skills/atlas-assets/`).

## Policy

- **Allowed:** open-weight models under permissive licenses (Apache-2.0, MIT) that place no restrictions on
  outputs; CC0 assets; assets made procedurally in our own code; direct paid accounts whose terms grant
  output ownership (Tripo paid plans, ElevenLabs paid plans).
- **Not allowed:** proprietary models resold through Atlas Cloud (Atlas's terms don't grant ownership of
  outputs), and licenses with conditions (attribution, revenue caps, region exclusions, non-commercial).
- Prompts must not name real brands, products, people or copyrighted characters.

## Approved generators

| Generator | License | Source |
|---|---|---|
| Atlas Cloud `z-image/turbo` (images) | Apache-2.0 | https://huggingface.co/Tongyi-MAI/Z-Image-Turbo |
| Atlas Cloud `black-forest-labs/flux-schnell` (images) | Apache-2.0 | https://huggingface.co/black-forest-labs/FLUX.1-schnell |
| Atlas Cloud `atlascloud/wan-2.2/image-to-video` | Apache-2.0 | https://huggingface.co/Wan-AI/Wan2.2-I2V-A14B |
| Tripo API (3D), direct **paid** account only | Tripo Terms §5.2.2: paid users own outputs, royalty-free | https://www.tripo3d.ai/terms |
| ElevenLabs (voice, sound effects), direct **paid** account only | ElevenLabs ToS §1(c), §4(c)(ii): paid plans may use output commercially and retain rights | https://elevenlabs.io/terms-of-use |

## Shipped generated assets

| Asset | Files | How it was made | License | Source | Verified |
|---|---|---|---|---|---|
| Main-menu art: city backdrop, rooftop floor and wall tiles, sigil emblem | `assets/generated/menu/{city_02,floor_top_01,wall_01,sigil_01}.*` (+ unused variations) | Atlas Cloud `z-image/turbo`, original prompts with no brands (see `.atlas/ledger.json`) | Apache-2.0 model; outputs ours | https://huggingface.co/Tongyi-MAI/Z-Image-Turbo | 2026-10-06 |

| Gritty PBR texture sets (dirty concrete, rusty metal, rusty corrugated iron, rusty metal grate, asphalt, concrete block wall, painted metal shutter), 1K albedo / normal / roughness; albedo graded darker and desaturated in-house | `assets/textures/gritty/*` | Downloaded from Poly Haven | CC0 | https://polyhaven.com/license | 2026-10-06 |
| Character animations (idle, walk, jog, sprint, jump, crouch, roll, hit, death), retargeted onto our skeleton | baked into `assets/animations/hunter_operative.res`; source `tools/rig/anim_src/ual_standard.glb` | Quaternius, Universal Animation Library (Standard), via OpenGameArt | CC0 1.0 (`tools/rig/anim_src/UAL_LICENSE.txt`) | https://opengameart.org/content/universal-animation-library | 2026-10-06 |

| Duel-arena art: billboard ad, wall grime tile, hunter poster | `assets/generated/duel/*` | Atlas Cloud `z-image/turbo`, original prompts, no brands | Apache-2.0 model; outputs ours | https://huggingface.co/Tongyi-MAI/Z-Image-Turbo | 2026-10-06 |
| Sound effects: sniper shots, bolt cycles, shell drops, scope, headshot / body hits, bullet whizzes, wet footsteps, coat swishes, hurt, death, breathing, clip load, rain loop | `assets/generated/sfx/*` | ElevenLabs sound-generation API, direct pay-as-you-go account (tier verified via API: `payg`) | ElevenLabs ToS §1(c), §4(c)(ii): paid plans may use output commercially; you retain all rights in Output | https://elevenlabs.io/terms-of-use | 2026-10-06 |

## Placeholders (NOT cleared for release; replace before the next itch push)

| Asset | Files | How it was made | Status |
|---|---|---|---|
| Night-hunter main character (rigged with `tools/rig/blender_rig_any.py`) | `assets/placeholder/models/hunter.glb` → `scenes/characters/hunter_operative.tscn` | `tripo-h3.1/text-to-3d` via Atlas Cloud, `--placeholder` at the owner's request (2026-10-06) | Atlas's terms don't grant output ownership; regenerate through the direct paid Tripo account or replace |
| Featured sniper rifle (main menu) | `assets/placeholder/models/sniper.glb` | `tripo-h3.1/text-to-3d` resold through Atlas Cloud, generated with `--placeholder` at the owner's request (2026-10-06) | Atlas's terms don't grant output ownership; regenerate through the direct paid Tripo account or replace |
