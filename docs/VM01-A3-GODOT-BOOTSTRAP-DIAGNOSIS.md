# VM01-A3 — Godot Bootstrap Diagnosis

Signature: Tehkné Solutions

Observed on Windows with Godot 4.7.1:

- `VM01_A3_GODOT_BENCH_CONTRACT=PASS` is printed by the contract script.
- The Godot process still exits non-zero because project autoload scripts are parsed before a fresh global `class_name` cache has been materialized.
- Downstream autoloads then report missing `FighterController`, `BuildProfile`, `TechniqueCatalog` and related global script classes.

The canonical classes do exist in the repository. For example, `scripts/fighter/fighter_controller.gd` declares `class_name FighterController`.

## Runner fix

1. Resolve Godot, including WinGet package locations.
2. Run one headless editor bootstrap (`--editor --headless --path . --quit`) to populate `.godot` imports and the global script-class cache.
3. Only then run the Character Lock bench contract.
4. Report bootstrap failure separately from contract failure.

No Character Lock visual PASS is implied by this bootstrap fix.
