# Taijifu Modular Fighter System — Project Standard v1

Signature: Tehkné Solutions

## Status

`PROJECT_STANDARD=APPROVED`

The Taijifu Masters character pipeline is modular by default. New playable fighters, NPC fighters, training rivals, masters and player-created avatars must use one shared fighter-body/rig contract plus interchangeable visual modules and combat loadouts.

Monolithic character production is deprecated for normal roster growth. It remains allowed only for special bosses or exceptional silhouettes that cannot safely conform to the shared rig.

## Visual quality bar

The approved visual target is chibi manga/comic with:

- strong readable silhouette at gameplay scale;
- expressive face and eyes;
- clean inked contours;
- controlled cel/anime shading;
- compact but athletic proportions;
- readable hands, feet and weapon grip;
- strong value separation between hair, skin, clothing and equipment;
- no procedural placeholder geometry in production builds;
- no contact-sheet extraction as a runtime source;
- native transparent character assets;
- consistent feet baseline and rig anchors.

## Core architecture

Every fighter is assembled from three independent contracts.

### 1. Base Fighter

Owns gameplay-safe anatomy and animation compatibility:

- canonical body proportions;
- skeleton / articulated rig;
- root and feet baseline;
- hitboxes / hurtboxes / sockets;
- shared locomotion and combat animation families;
- facing and mirroring policy;
- gameplay scale.

The production base uses a neutral fitted under-layer/mannequin, not explicit nudity. Clothing modules are layered above it.

### 2. Visual Loadout

Pure presentation modules attached to standardized slots.

Required v1 slots:

- `body_base`
- `skin`
- `face`
- `eyes`
- `brows`
- `hair_back`
- `hair_front`
- `head_accessory`
- `torso_inner`
- `torso_outer`
- `shoulders`
- `arms`
- `hands`
- `waist`
- `legs`
- `feet`
- `back_accessory`
- `weapon_main`
- `weapon_offhand`
- `weapon_back`
- `fx_aura`

A module may be empty, but may not invent its own root/pivot contract.

### 3. Combat Loadout

Gameplay configuration independent from appearance:

- Tai/Ji/Fu techniques;
- elemental forms;
- weapon discipline;
- attributes;
- stamina/mana behavior;
- passives;
- ultimate/climax;
- AI profile when used by CPU.

Visual gear may expose metadata for presentation and progression, but combat balance must not be hard-coded into sprite assets.

## Standard body/rig contract v1

- canonical source canvas: `1024x1024 RGBA` for authoring;
- native transparent background;
- normalized gameplay visual height is resolved by presenter, not baked by resizing masters;
- root: bottom-center logical anchor;
- feet baseline must be stable per animation family;
- authored facing: explicit in manifest;
- mirroring must preserve weapon-hand policy;
- all visual modules inherit the same animation timeline/frame identity;
- long hair, scarves, coats and hanging accessories may use secondary animation tracks but cannot change root motion.

## Animation families

The shared v1 runtime contract targets:

- `idle`
- `walk`
- `run`
- `jump_start`
- `airborne`
- `fall`
- `land`
- `crouch`
- `guard`
- `parry`
- `dodge`
- `hit`
- `ko`
- `attack_light`
- `attack_heavy`
- `attack_special`
- technique-specific sequences

Character-specific animation is permitted where required by weapon/style, but must derive from the same root, baseline and slot/skeleton contract.

## Preset policy

Canonical roster characters are presets of the modular system.

Initial presets:

- `preset_lian_wu`
- `preset_training_rival`

Future NPCs and masters should also be represented as presets whenever possible.

A preset defines:

- base body variant;
- appearance module IDs;
- palette values;
- weapon visuals;
- combat loadout reference;
- optional unique overlay modules;
- authored-facing policy.

## Player Character Creator

The player-facing editor must use the same runtime assembly pipeline as NPC presets. It is not a separate avatar technology.

Initial editable categories:

- body variant within approved proportions;
- skin tone;
- face;
- eyes/brows;
- hair front/back;
- hair color;
- inner/outer uniform;
- belt/waist;
- gloves/arm wraps;
- pants;
- footwear;
- accessories;
- primary weapon visual;
- palette channels.

The creator must reject combinations that violate slot compatibility or weapon-hand/facing contracts.

## Asset packs

Production is organized as modular packs:

- `BASE-00` — Fighter Body & Rig
- `BASE-01` — Faces & Skin
- `BASE-02` — Hair
- `BASE-03` — Martial Arts Uniforms
- `BASE-04` — Armor & Accessories
- `BASE-05` — Weapons
- `PRESET-01` — Lian Wu
- `PRESET-02` — Training Rival

Each module must be individually addressable, versioned, validated and reusable.

## Runtime assembly rule

The renderer must resolve:

`Base Fighter + Visual Loadout + Animation State + Combat Loadout -> Rendered Fighter`

No production fallback may draw a fighter from circles, polygons, primitive limbs or other procedural placeholder graphics.

If required canonical modules are missing, production visual gates must fail instead of silently drawing proxies.

## Migration of existing work

Existing approved Lian Wu frames remain valid source material and are migrated into `PRESET-01` / shared animation lineage rather than discarded.

The Training Rival clean master becomes `PRESET-02` visual identity and is materialized against the same base/rig contract.

The C50 visual cutover remains blocking until both initial presets render through the modular system in the canonical arena.

## Definition of Done — Modular Fighter Foundation

`MODULAR_FIGHTER_FOUNDATION=PASS` only when:

1. Base Fighter v1 contract exists in runtime.
2. Slot registry exists and validates module compatibility.
3. A visual profile can be serialized independently from combat loadout.
4. Lian Wu is represented as a preset.
5. Training Rival is represented as a different preset.
6. Both use the same assembly/presenter path.
7. Runtime contains zero procedural fighter renderer in production mode.
8. A minimal Character Creator can switch at least hair, torso outfit and weapon visual at runtime.
9. Existing combat controller/hitboxes remain behaviorally unchanged by cosmetic swaps.
10. Packaged Windows build passes visual review.

## Governance

This document is the canonical character-production standard until superseded by a versioned successor.

Any new character implementation that bypasses the modular system must document the exception and justify why the shared rig cannot represent it.

Tehkné Solutions
