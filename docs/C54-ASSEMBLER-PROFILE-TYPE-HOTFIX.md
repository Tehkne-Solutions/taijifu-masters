# C54 — Assembler/Profile Type Hotfix

Signature: Tehkné Solutions

## Observed failure

The C54 bench reached Godot 4.7.1 and loaded the BASE-00 image path, but compilation stopped in `modular_fighter_assembler.gd` because the first-run CLI session could not resolve the global `ModularFighterProfile` class while the editor class cache was still unavailable.

The resulting errors were:

- `Could not find type ModularFighterProfile in the current scope`;
- dependent bench compilation failure;
- `AssemblerClass.new()` unavailable because the assembler script did not compile;
- `VM02_C54_MODULAR_ASSEMBLY=BLOCKED`.

The WASAPI messages are unrelated. Godot correctly falls back to its dummy audio driver and the visual bench does not depend on audio.

## Correction

`modular_fighter_assembler.gd` no longer requires the global profile class cache for its parameter and member declarations. It now:

- accepts the profile through the runtime object contract;
- verifies that `validate_against_standard` exists;
- validates the returned `PackedStringArray` contract;
- keeps the canonical BASE-00 and visual-slot checks unchanged;
- reads `profile_id` through the runtime property interface;
- clears its profile together with visual layers.

This preserves the modular fighter behavior while making first-run command-line Godot compilation deterministic.

No visual asset, SHA-256, pivot, baseline, gameplay behavior or progress percentage changes in this hotfix.

Tehkné Solutions
