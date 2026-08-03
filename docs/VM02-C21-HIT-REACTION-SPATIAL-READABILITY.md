# VM02-C21 — Hit Reaction + Spatial Readability

Tehkné Solutions

## Goal

Improve the first playable combat readability after the validated C20 riposte/HUD pass by making contact visibly change fighter spacing without replacing the existing C20/C19 combat contracts.

## Scope

- preserve all C20 riposte keypose and HUD cleanup contracts;
- add small directional separation when the player is hit;
- add technique-sensitive rival displacement when the player lands a hit;
- keep the response intentionally conservative so it does not become launch physics yet;
- capture dedicated evidence after a live contact exchange;
- keep the PowerShell gate clipboard-ready.

## Spatial response contract

- normal player reaction push: 12 px;
- light rival push: 18 px;
- sweep/heavy rival push: 26 px;
- riposte rival push: 34 px;
- clamp runtime positions to the current courtyard combat lane.

These values are foundation tuning, not final balance.

## Acceptance

- `SPATIAL_REACTION=PASS`
- `PLAYER_SEPARATION=PASS`
- `RIVAL_SEPARATION=PASS`
- `TECHNIQUE_SEPARATION=PASS`
- `SPATIAL_EVIDENCE=PASS`
- `C20_CONTRACT=PASS`
- `RUNTIME=PASS`
- `CAPTURE=PASS`

## Out of scope

- launchers / airborne juggle;
- wall splat;
- knockdown state machine;
- second canonical fighter art;
- final arena art pass.
