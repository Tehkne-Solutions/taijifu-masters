# VM02-A1 — Lian Wu Locomotion Core

Signature: Tehkné Solutions

## Source milestone

`LIAN_WU_CHARACTER_LOCK=PASS`

VM02-A1 must use the approved Character Lock / Rig lineage. Independent redraws are not promotable.

## Canonical Pack 01 inventory used by this gate

The closed Pack 01 inventory defines these locomotion animations:

| Animation | Frames |
| --- | ---: |
| idle | 6 |
| walk | 8 |
| run | 8 |
| jump_start | 4 |
| jump_loop | 3 |
| fall | 3 |
| land | 4 |
| **Total VM02-A1** | **36** |

`dash` has 5 frames in Pack 01 but is intentionally excluded from this gate and will enter the movement/combat bridge milestone after locomotion is stable.

## Required frame paths

```text
assets/pack_01_characters/lian_wu/
├── frames/
│   ├── idle/char_lian_wu__idle__f01.png ... f06.png
│   ├── walk/char_lian_wu__walk__f01.png ... f08.png
│   ├── run/char_lian_wu__run__f01.png ... f08.png
│   ├── jump_start/char_lian_wu__jump_start__f01.png ... f04.png
│   ├── jump_loop/char_lian_wu__jump_loop__f01.png ... f03.png
│   ├── fall/char_lian_wu__fall__f01.png ... f03.png
│   └── land/char_lian_wu__land__f01.png ... f04.png
└── metadata/
    ├── idle.json
    ├── walk.json
    ├── run.json
    ├── jump_start.json
    ├── jump_loop.json
    ├── fall.json
    └── land.json
```

## Art contract

- PNG RGBA, 1024×1024.
- Native facing right.
- Alpha-derived bottom-center pivot policy.
- Same canonical Lian Wu identity, outfit and weapon continuity.
- No text/logo/background embedded in frames.
- No independent generative redraw per frame.
- Frame-to-frame motion must be produced from the approved Character Lock / Rig lineage.

## Gate order

1. 36 PNGs exist under canonical names.
2. PNG format, RGBA-compatible canvas and non-empty alpha silhouette pass.
3. Seven animation metadata files exist.
4. Pivot/baseline continuity is measured.
5. Contact sheets are visually reviewed for identity and motion continuity.
6. `SpriteFrames` resource is built.
7. A Godot locomotion bench is run against the real FighterController.
8. Only then may VM02-A1 be promoted.

## Validator

```text
python tools/validate_lian_wu_locomotion_core.py
```

Before art is materialized, expected result is deliberately:

```text
VM02_A1_LOCOMOTION_CORE=BLOCKED missing_frames=36/36
```

A file-level PASS still does not imply animation promotion; Godot/runtime review remains mandatory.
