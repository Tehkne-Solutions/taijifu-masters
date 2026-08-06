# VM02-C55 — BASE-01 Faces & Skin Foundation

Signature: Tehkné Solutions

## Status

`BASE00_CLOSEOUT=PASS`

`BASE01_FOUNDATION=READY`

The canonical BASE-00 body has passed package QA, Godot runtime assembly, authored/flipped presentation and human visual review. BASE-01 is therefore released as the next modular character-production stage.

## Production decision

Skin tone must be palette-driven rather than produced as a full duplicated body PNG for every tone. This reduces asset duplication, prevents seam drift between tones and keeps every fighter on the same canonical BASE-00 silhouette.

Face identity is assembled from three existing runtime slots:

- `face` — nose, mouth, ear/jaw and cheek detail;
- `eyes` — eye shape, iris, pupil and upper-lash treatment;
- `brows` — eyebrow shape and attitude.

Hair remains outside BASE-01 and will be produced in BASE-02.

## Initial production lot

The first reusable lot targets:

- 8 skin-tone palettes;
- 4 face variants;
- 6 eye variants;
- 6 brow variants;
- 6 expression families: neutral, focus, effort, hit, victory and KO.

The first implementation deliverable is smaller and must prove the pipeline before the whole catalog is produced:

`BASE01_DEFAULT_IDENTITY_MODULES_v1.0.0`

It contains:

- one default skin palette;
- one face overlay;
- one eye overlay;
- one brow overlay;
- manifest and checksums;
- contact sheet used only as QA evidence, never as a runtime source;
- authored and flipped gameplay-scale Godot evidence.

## Asset rules

Every visual overlay must:

- be an individual 1024×1024 RGBA PNG;
- use native transparency;
- preserve BASE-00 root anchor and pivot `0.5 / 0.92`;
- align to the BASE-00 face without changing body silhouette;
- contain no hair, clothing, text, frame, logo, background or fixed shadow;
- remain reusable across Lian Wu, Training Rival, NPCs and player-created characters;
- be reviewed at authored scale and at gameplay scale.

Skin palettes are data assets and may not be baked as duplicated full-body PNGs.

## Canonical paths

```text
assets/modular_fighters/base_01/palettes/
assets/modular_fighters/base_01/face/
assets/modular_fighters/base_01/eyes/
assets/modular_fighters/base_01/brows/
assets/modular_fighters/base_01/qa/
assets/modular_fighters/base_01/manifest.json
```

## Identity policy

The default BASE-01 modules are neutral reusable options, not Lian Wu or Training Rival assets. Character-specific identity is created later by presets selecting combinations and palettes.

BASE-01 must visibly differentiate fighters without depending on hair, uniform or weapon. This proves that the face system is actually modular rather than cosmetic metadata attached to an unchanged drawing.

## Gate policy

C55 foundation may pass while artwork is pending. No gameplay or project percentage is promoted by the contract alone.

Art becomes PASS only after:

1. individual runtime assets exist;
2. alpha and alignment checks pass;
3. default modules render through `ModularFighterAssembler`;
4. authored and flipped Godot evidence passes human visual review;
5. changing face, eyes, brows and skin does not alter BASE-00 hitboxes or baseline.

## Next action

Produce `BASE01_DEFAULT_IDENTITY_MODULES_v1.0.0` from the approved BASE-00 master, beginning with the default warm skin palette and neutral/focused facial modules.

Tehkné Solutions
