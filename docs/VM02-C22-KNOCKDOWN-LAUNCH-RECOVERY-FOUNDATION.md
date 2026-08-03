# VM02-C22 — Knockdown / Launch / Recovery Foundation

Tehkné Solutions

## Goal

Extend the validated C21 spatial reaction contract with a first deterministic body-state layer for stronger impacts.

## Scope

- launch reaction for riposte/heavy impact
- knockdown state for launch landing and sweep contact
- timed recovery/get-up phase
- short recovery invulnerability contract
- dedicated reaction evidence capture
- preserve C21 spatial separation and all inherited combat contracts
- clipboard-ready PowerShell report

## Runtime contract

Strong reactions move through `launch -> knockdown -> recovery -> idle`. Sweep may enter directly into `knockdown`. The visual displacement is intentionally conservative and remains inside the existing first-playable presentation layer so the combat logic beneath C21 is not replaced.

## Acceptance markers

- `VM02_C22_KNOCKDOWN_CONTRACT=PASS`
- `VM02_C22_LAUNCH_CONTRACT=PASS`
- `VM02_C22_RECOVERY_CONTRACT=PASS`
- `VM02_C22_RECOVERY_INVULNERABILITY_CONTRACT=PASS`
- `VM02_C22_REACTION_EVIDENCE_COVERAGE=PASS`
- `VM02_C22_C21_CONTRACT=PASS`
- `VM02_C22_RUNTIME=PASS`
- `VM02_C22_CAPTURE=PASS`

## Validation

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\RUN-VM02-C22-KNOCKDOWN-LAUNCH-RECOVERY-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"
```

The gate generates a compact `COPY_REPORT` block and copies it to the clipboard.
