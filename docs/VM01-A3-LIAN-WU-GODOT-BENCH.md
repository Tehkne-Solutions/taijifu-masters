# VM01-A3 — Lian Wu Godot Character Lock Bench

Signature: Tehkné Solutions

## Scope

This milestone does not promote animation packs. It proves the canonical Lian Wu Character Lock against the real FighterController runtime before replacing the procedural fallback.

## Canonical inputs

- `lian_wu_neutral.png` — canonical neutral, 1024×1024 RGBA.
- `lian_wu_combat_stance.png` — Rig v1 stance candidate promoted into the bench only after visual review.
- normalized pivot: `(0.5, 0.92)`.
- native facing: right.

## Runtime facts captured from main

The current Fighter scene uses a capsule with radius 16, height 78 and local position `(0,-16)`. The provisional presenter currently positions visual content around `(0,-17)` and flips horizontally when `fighter.facing < 0`.

The bench deliberately binds to the same FighterController and facing signal instead of inventing a parallel controller.

## Required gate

A real Godot run must provide a 1920×1080 screenshot and report:

- neutral texture imported;
- combat stance imported;
- pivot visually aligned with the floor contact;
- facing right correct;
- horizontal flip correct;
- fighter capsule remains centered under the character;
- no visible clipping at minimum/maximum gameplay zoom;
- shadow/contact point remains coherent;
- procedural fallback can be hidden without changing gameplay state.

## Promotion policy

`CHARACTER_LOCK=PASS` is forbidden until the real Godot run and screenshot exist.

`ANIMATION_PACK_ALLOWED=FALSE` remains in force until that promotion.

## Local execution

Run the contract first:

```text
godot --headless --path . --script res://tests/lian_wu_character_lock_bench_contract.gd
```

Expected static result:

```text
VM01_A3_GODOT_BENCH_CONTRACT=PASS
```

This static PASS does **not** mean the visual bench passed. It only proves the runtime contract is wired. The visual gate still requires the actual imported PNGs and 1920×1080 in-engine evidence.
