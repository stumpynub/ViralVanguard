---
name: atlas-assets
description: Generate real game assets for Viral Vanguard (images, textures, icons, 3D models as GLB, sound effects, voice lines) with the user's Atlas Cloud, Tripo and ElevenLabs accounts under hard budgets. Use when the user asks to generate, create or replace art, textures, images, 3D models, sounds or voice for the game.
---

# Atlas asset generation

Generates assets through Atlas Cloud with `scripts/atlas.py` (in this skill's directory). Every call is
checked against a dollar cap and logged to `.atlas/ledger.json` (prompt, model, cost, file) for provenance.

Run it from the project root:

```bash
python3 .claude/skills/atlas-assets/scripts/atlas.py budget
```

## Rules

1. **Money is real.** Check `budget` first. If no cap is set, ask the user for one and run `budget set <USD>` with their number. Never raise the cap without the user saying so.
2. **Never ask for, print, or handle the API key.** The script reads `$ATLASCLOUD_API_KEY` or `~/.config/atlas-assets/api_key`. If it's missing, tell the user to put it there themselves.
3. **Estimate before batches.** For anything over ~10 generations or over $0.25, run with `--dry-run` and tell the user the estimated cost before spending.
4. **Start small.** Generate 1–2 variations, look at the result (Read the image), then batch the ones that work. Don't regenerate blindly.
5. **No trademarks, real people, or brands in prompts.** The game is published on itch.io (treat it as commercial). Prompts must not name real companies, products, celebrities, or copyrighted characters.
6. **License gate (hard rule).** Only use models whose license is *verified from a primary source* to allow commercial use with no royalties. The script enforces an `APPROVED_MODELS` allowlist and refuses everything else. Atlas Cloud's terms don't grant ownership of outputs, so proprietary models resold through Atlas (Tripo, Meshy, Hi3D, Seed3D, Seed Audio, MiniMax, ElevenLabs, Suno, Gemini TTS, xAI, OpenAI, Midjourney…) are **not** allowed. Open-weight models under Apache-2.0/MIT are, and FLUX Dev (non-commercial) is not. To approve a new model: find its license on the official model card or repo, add it to `APPROVED_MODELS` with the source URL, and add a row to `ASSET_LICENSES.md`. Never use an asset in the game before its license row exists.
7. **Placeholders (owner-approved exception).** The owner allowed temporary 3D models from non-approved Atlas models (e.g. `tencent/hunyuan3d-rapid/text-to-3d`) with `--placeholder`. Output must go under `assets/placeholder/`, each file gets a "PLACEHOLDER" row in `ASSET_LICENSES.md`, and they must be replaced before the next public release (itch push). Never use `--placeholder` without the owner asking.
8. **Report spend** after each batch: files created, cost, and remaining budget.

## Commands

| Asset | Command | Default model / price |
|---|---|---|
| Image | `atlas.py image "<prompt>" -o assets/generated/<group>/<name>.png [-n 4] [--size 1024*1024]` | `z-image/turbo`, $0.01 (FLUX Schnell was failing server-side on Atlas, 2026-10) |
| 3D model | **Direct Tripo account (not via Atlas):** `python3 .claude/skills/atlas-assets/scripts/tripo.py image3d assets/generated/prop_refs/<name>.png -o assets/generated/models/<name>.glb` (or `text3d "<prompt>"`). Credit cap: `tripo.py budget set <credits>`. Refuses to run until `tripo.py confirm-paid`, which you run only after the user confirms the account is paid (Tripo Terms §5.2.2: paid users own outputs, royalty-free; §5.2.1: free users don't). Check with `tripo.py balance` | Tripo v3.1, credits |
| Voice | **Direct ElevenLabs:** `python3 .claude/skills/atlas-assets/scripts/elevenlabs.py voice "<line>" -o assets/generated/audio/<event>_<n>.mp3 --voice FGY2WhTYpPnrIDTdsKH5` (premade "Laura"; pick a fitting premade voice for announcer / operative lines). Cap: `elevenlabs.py budget set <credits>`. Refuses free-tier accounts | ~1 credit/char |
| Sound effect | `elevenlabs.py sfx "<description>" -o assets/generated/sfx/<name>_<n>.mp3 --seconds 0.5-30 [--loop]`. Name files after the `scripts/autoload/sfx.gd` sound they replace (impact, explosion, enemy_die, slash_windup, slash_hit, slash_miss, footstep, land, glass, lift, launch, casing, reload_out, reload_in, jet, ambience, fire_<weapon id>). Those sounds are synthesized today, so `sfx.gd` needs to load the file to use it | ~40 credits/sec |
| Music | none approved on Atlas: every music model there is proprietary. Music is procedural, made in-game | blocked |
| Other model | any kind with `--model <id> --price <USD>` | price must come from the model's Atlas page |
| Log | `atlas.py log` | |
| Resume | `atlas.py resume` (finish jobs interrupted after submit, no double charge) | |

Output extensions are corrected to the real file format automatically. `--mock` runs the whole flow offline for free (placeholder files).

## Using assets in the game

- Put files under `assets/generated/<group>/` with lowercase snake_case names.
- After adding files, run `godot-dotnet --headless --path . --import` so Godot imports them, then load with `load("res://assets/generated/...")`.
- Images: 1024×1024 by default. For UI icons (weapons, armour, skills), ask for "flat icon, centered, plain dark background". Match the neon cyberpunk look: magenta / cyan / violet neon on dark navy.
- 3D: GLB imports as a scene; check the scale in-game. Keep prompts to a single object ("a single sci-fi street vending machine, game asset, no background"). Web builds use the Compatibility renderer, so keep textures ≤1024 and triangle counts modest.
- Audio: short MP3s import as AudioStreamMP3. Keep voice lines under ~10s.

## Errors

- `budget: ... exceeds remaining`: stop and tell the user the cost and remaining budget.
- `Atlas rejected the request` / `reported failure`: not charged. Read the message (often a bad model id or a content filter) and adjust.
- `timed out` / `download failed`: the cost stays charged (Atlas likely billed it). The output URL, if any, is in the ledger.
