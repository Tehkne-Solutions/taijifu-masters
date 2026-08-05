# VM02-C50 — BASE-00 Modular Fighter Foundation

Signature: Tehkné Solutions

## Decision

BASE-00 is the canonical visual-production foundation for every fighter in Taijifu Masters.

The project no longer treats Lian Wu, Training Rival, NPCs and player-created fighters as isolated monolithic character-art pipelines. They are presets assembled from one shared fighter body/rig plus visual modules.

## Visual target

- chibi manga/comic;
- strong silhouette;
- clean inked linework;
- controlled cel/anime shading;
- gameplay-readable face, hands, feet and weapon pose;
- 1024×1024 RGBA authoring canvas;
- native transparent background;
- bottom-center root anchor;
- no text, scenery or contact-sheet material used as runtime source.

## BASE-00 source master

Expected path:

`assets/modular_fighters/base_00/base_fighter_v1_master.png`

The master is a neutral fighter body wearing only a minimal inner training layer. It must not bake in hairstyle, costume identity, armor, accessories or weapons.

## Production packs

1. BASE-00 — Fighter Body & Rig
2. BASE-01 — Faces & Skin
3. BASE-02 — Hair
4. BASE-03 — Martial Arts Uniforms
5. BASE-04 — Armor & Accessories
6. BASE-05 — Weapons
7. PRESET-01 — Lian Wu
8. PRESET-02 — Training Rival

## Runtime rule

`ModularFighterProfile` describes identity. `ModularFighterAssembler` attaches visual modules to canonical slots. Combat configuration remains independent from visual identity.

## C50 relationship

C50 remains the canonical visual cutover gate. Progress does not advance until the packaged build has:

- canonical Mountain Dojo Night;
- no procedural fighter renderer;
- real Lian Wu presentation;
- real Training Rival presentation;
- modular fighter contracts validated.

## Immediate next blocker

`BASE-00_ART_MASTER`

Do not generate more monolithic Training Rival animation packs before BASE-00 is visually approved. Once BASE-00 is approved, Training Rival becomes PRESET-02 and inherits the shared rig/animation foundation.
