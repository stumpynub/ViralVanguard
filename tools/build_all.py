#!/usr/bin/env python3
"""Regenerates every generated scene / resource of the project.
The generated files are ordinary Godot scenes: once you start hand-editing one in the editor, stop regenerating it
(or delete its builder call here) so your edits are not overwritten."""
import build_resources, build_weapons, build_props, build_arena, build_arena_ncc, build_duel_arena, build_ui

build_resources.build_materials()
build_resources.build_icons()
build_resources.build_data()
build_resources.build_theme()
build_resources.build_project()
build_weapons.build_weapons()
build_props.build_props()
build_props.build_fx()
build_props.build_spider()
build_props.build_player()
build_arena.awning()
build_arena_ncc.build_arena_ncc()   # Neon Core City (v74); build_arena.build_arena() makes the older Neo-Kairo map
build_duel_arena.build_duel_arena()   # 1v1 sniper duel rooftops
build_ui.build_ui()
print("all scenes built")
