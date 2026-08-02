# VM02-C3 — Lian Wu Body Hook Runtime Integration

Signature: **Tehkné Solutions**

## Goal
Integrate the approved VM02-C2 `ji_body_hook` six-keypose visual sequence with the VM02-C1 combat timing/hitbox contract and the VM02-B2 player-controlled locomotion controller.

## Runtime contract
- Real player attack input: `p1_attack` (`F` via `InputBootstrapRuntime`).
- Technique data source: `TechniqueCatalog.get_technique(&"ji_body_hook")`.
- Logical phases remain authoritative: `startup -> active -> recovery -> idle`.
- Visual mapping:
  - startup: F01 guard -> F02 chamber -> F03 torque
  - active: F04 impact
  - recovery: F05 recoil -> F06 recover
- Hitbox is physically enabled only during `active`.
- Movement is locked during the technique.
- One hit maximum per execution in the deterministic gate.
- A second attack must be accepted after the first recovery completes.

## Automated gate
`tools/RUN-VM02-C3-BODY-HOOK-RUNTIME-GATE.ps1`

The runner regenerates the six C2 attack frames, launches Godot, executes two body hooks against a deterministic dummy, validates the full visual/timing/hitbox chain and produces a 1920x1080 capture.

Required final markers:

```text
VM02_C3_ATTACK_VISUAL_FRAMES=6
VM02_C3_COMBAT_VISUAL_RUNTIME=PASS
VM02_C3_KEYPOSE_SEQUENCE=PASS
VM02_C3_PHASE_TIMING=PASS
VM02_C3_ACTIVE_F04_BINDING=PASS
VM02_C3_HITBOX_WINDOW=PASS
VM02_C3_SINGLE_HIT_PER_ATTACK=PASS
VM02_C3_REATTACK=PASS
VM02_C3_RETURN_IDLE=PASS
VM02_C3_CAPTURE=PASS
VM02_C3_BODY_HOOK_RUNTIME_GATE=PASS
```

Evidence:

`artifacts/vm02-c3/lian-wu-body-hook-runtime-1920x1080.png`
