# VM02-C23 — Knockdown Visual State + Get-Up Animation

Tehkné Solutions

## Objective

Turn the C22 knockdown/launch/recovery contract into an unmistakable visual reaction sequence. The rival must visibly pass through AIRBORNE, DOWNED and GET_UP before returning to READY, without changing the inherited C22 combat semantics.

## Visual contract

- AIRBORNE: visible lift plus backward rotation.
- DOWNED: fighter body rotated into a horizontal floor pose.
- GET_UP: interpolated return from floor pose to upright stance.
- READY: canonical rival stance restored after recovery.
- Recovery invulnerability remains inherited from C22.

## Gate markers

- `VM02_C23_AIRBORNE_VISUAL=PASS`
- `VM02_C23_DOWNED_VISUAL=PASS`
- `VM02_C23_GETUP_VISUAL=PASS`
- `VM02_C23_READY_RESTORE=PASS`
- `VM02_C23_C22_CONTRACT=PASS`
- `VM02_C23_RUNTIME=PASS`
- `VM02_C23_CAPTURE=PASS`

The dedicated evidence frame is captured while DOWNED so visual review can verify that knockdown no longer reads as a standing displacement.
