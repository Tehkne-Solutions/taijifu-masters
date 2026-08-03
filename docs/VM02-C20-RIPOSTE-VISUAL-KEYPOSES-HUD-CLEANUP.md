# VM02-C20 — Riposte Visual Keyposes + Combat HUD Cleanup

Tehkné Solutions

## Goal

Promote C19 from a mechanically dedicated riposte into a visually dedicated technique while cleaning the resource/status HUD collision visible in the validated C19 capture.

## Scope

- dedicated `ji_riposte` keypose family;
- stop reusing the body-hook visual handoff for riposte presentation;
- preserve C19 damage, stamina, guard pressure and single-consume contracts;
- dedicated riposte impact/readability timing;
- compact resource HUD with no collision against the centered round/status line;
- dedicated visual bench/evidence and runtime capture;
- standard clipboard-ready PowerShell gate report.

## Visual observations from C19

- riposte mechanic is readable and functional;
- impact cue is visible;
- center status text currently collides horizontally with the left HUD/resource region;
- the runtime still uses the body-hook character pose as the riposte visual handoff;
- C20 must fix both issues without changing the validated C19 combat contract.

## Acceptance

- `RIPOSTE_KEYPOSES=PASS`
- `RIPOSTE_VISUAL_BINDING=PASS`
- `HUD_COLLISION_FREE=PASS`
- `RIPOSTE_IMPACT_READABILITY=PASS`
- `C19_CONTRACT=PASS`
- `RUNTIME=PASS`
- `CAPTURE=PASS`

