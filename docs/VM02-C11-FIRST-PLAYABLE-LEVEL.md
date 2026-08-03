# VM02-C11 — First Playable Level Foundation

Tehkné Solutions

## Goal
Move Taijifu Masters out of isolated runtime benches into the first cohesive playable fight scene.

## Included
- stylized courtyard stage foundation (non-grid, game presentation)
- fixed gameplay camera
- Lian Wu spawn using the validated locomotion/combat controller
- visual sparring rival using the validated opponent AI
- bilateral HP HUD
- round intro and `FIGHT` transition
- continuous AI combat
- player combo `ji_body_hook -> ji_sweep`
- player damage reception
- victory / defeat round states
- deterministic autoplay gate and 1920x1080 evidence capture
- standard `COPY_REPORT` output

## Manual play
Open or run:

`res://scenes/runtime/first_playable_level.tscn`

Controls shown in the HUD:
- Move: A/D or arrows
- Run: Shift
- Jump: Space
- Attack / combo: F

## Gate

`tools/RUN-VM02-C11-FIRST-PLAYABLE-GATE.ps1`

The gate runs the same scene with deterministic autoplay. The rival has 29 HP in this foundation so two validated body-hook/sweep combos prove a complete round and victory flow in a short reproducible run.

## Scope note
The courtyard is a first-level visual foundation built directly in Godot. It is intentionally game-like and non-grid, but it is not yet the final production environment art pack.
