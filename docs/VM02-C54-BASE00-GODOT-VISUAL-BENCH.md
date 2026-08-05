# VM02-C54 — BASE-00 Godot Visual Bench

Signature: Tehkné Solutions

## Objective

Validate the canonical BASE-00 fighter body inside Godot before BASE-01 production begins.

The bench proves that the promoted `base_fighter_v1_master.png` is not only a valid PNG, but also renders correctly at gameplay scale through the modular fighter assembly path.

## Canonical input

`assets/modular_fighters/base_00/base_fighter_v1_master.png`

Expected SHA-256:

`fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe`

## Bench acceptance

- asset loads as a Godot `Texture2D`;
- source canvas is 1024×1024 RGBA;
- source alpha bounds are read from the real PNG;
- visible gameplay height is normalized to approximately 132 px;
- bottom-center baseline remains stable;
- original and horizontally flipped presentations share the same baseline;
- visual body is attached through `ModularFighterAssembler` in the `body_base` slot;
- no procedural fighter drawing is used;
- a 1920×1080 runtime capture is produced;
- human review remains required for edge quality, silhouette, contact with floor and gameplay readability.

## Output

`artifacts/vm02-c54/base00-godot-bench-1920x1080.png`

## Progress policy

C54 does not promote V.2 or project percentages from a technical capture alone. Progress remains frozen until the human visual review confirms the BASE-00 body inside Godot.

After visual approval, BASE-01 — Faces & Skin may begin.

Tehkné Solutions
