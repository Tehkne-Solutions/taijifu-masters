# VM02-C16 — Guard Break / Parry Foundation

Tehkné Solutions

## Goal
Extend the validated C15 defense/stamina layer into a timing-based defensive system.

## Player controls
- `R`: hold block
- `V`: timed parry

## Runtime contract
- successful parry negates the incoming hit;
- block continues to reduce damage and knockback through C15;
- blocked pressure damages guard integrity;
- zero guard triggers a temporary guard-break state;
- guard recovers after the break window;
- stamina and guard are shown in a dedicated defensive HUD instead of the crowded center status line;
- C15/C14 combat contracts remain intact.

## Evidence
- `artifacts/vm02-c16/parry-evidence-1920x1080.png`
- `artifacts/vm02-c16/guard-break-evidence-1920x1080.png`
- `artifacts/vm02-c16/first-playable-guard-break-parry-1920x1080.png`

## Gate
`tools/RUN-VM02-C16-GUARD-BREAK-PARRY-GATE.ps1`

The gate emits the standard compact `COPY_REPORT` block.
