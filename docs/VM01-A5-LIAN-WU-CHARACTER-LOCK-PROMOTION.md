# VM01-A5 — Lian Wu Character Lock Promotion

Signature: Tehkné Solutions

## Decision

`LIAN_WU_CHARACTER_LOCK=PASS`

This promotion is limited to the Character Lock milestone. It does **not** mark Pack 01 complete.

## Canonical inputs

- `assets/characters/lian_wu/character_lock/lian_wu_neutral.png`
  - SHA-256: `0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5`
- `assets/characters/lian_wu/character_lock/lian_wu_combat_stance.png`
  - SHA-256: `c8e6cd1feece7c2a54cf2279085c2a4bb33338dd6a3dcb3e4d5a2402b537631c`

## Runtime evidence

Godot: `4.7.1.stable`

Visual bench:

- runtime: PASS
- normalized capture: PASS
- output: `artifacts/vm01-a4/lian-wu-character-lock-bench-1920x1080.png`
- output size: 1920×1080
- evidence SHA-256: `cff39c65941544693bc1eeac2fa01bccb56c9f2bb10c207668d1368a5fc5c45c`

The final bench uses the real `fighter.tscn`, disables only physics simulation for diagnostic stability, hides the procedural presenter, and compares:

- neutral / right / 1.00×
- neutral / flip / 0.75×
- stance / right / 1.00×
- stance / flip / 1.35×

## Visual review

PASS:

- all four comparison states remain inside the logical 1280×720 canvas;
- opaque feet baseline aligns to the FighterController origin/ground line;
- no diagnostic drift occurs during capture;
- native right facing is coherent;
- horizontal flip preserves support point and scale;
- neutral and combat stance share the same alpha-derived bottom-center pivot policy;
- silhouette remains legible at 0.75×, 1.00× and 1.35×;
- contact shadow remains coherent with the support point;
- canonical identity is preserved between neutral and stance.

## Promotion scope

```text
LIAN_WU_CHARACTER_LOCK=PASS
fallback_replacement_ready=PASS
ANIMATION_PACK_01=UNBLOCKED
PACK_01_COMPLETE=FALSE
```

The procedural fallback remains available as a rollback path until Animation Pack 01 is integrated and validated in the first playable.

## Next milestone

`VM02-A1 — Lian Wu Animation Pack 01 / Locomotion Core`

Initial animation contract:

- idle
- walk
- run
- jump_start
- jump_rise
- jump_apex
- fall
- land
- air_jump
- wall_contact
- wall_jump
- wall_climb

Animation generation must use the approved Character Lock as the identity source. Independent generative redraws are not promotable.
