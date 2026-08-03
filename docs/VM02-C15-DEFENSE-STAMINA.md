# VM02-C15 — Defense + Stamina Foundation

Tehkné Solutions

## Goal

Introduce the first defensive combat resource layer on top of the validated VM02-C14 first playable without changing the existing Tai/Ji/Fu attack contract.

## Player contract

- Hold `R` (`p1_block`) to block while not attacking.
- A successful block reduces incoming damage to 35% of the original value.
- A successful block reduces incoming knockback to 25% of the normal displacement.
- Each blocked hit costs 18 stamina.
- Stamina regenerates at 28 points/second while block is released.
- The current HUD exposes stamina and block state.

## Gate contract

The autoplay gate intentionally blocks the first AI hit and releases block for later hits. This gives a single deterministic run that proves both defensive and normal damage paths.

Required PASS markers:

- `VM02_C15_BLOCK_DAMAGE_REDUCTION=PASS`
- `VM02_C15_BLOCK_KNOCKBACK_REDUCTION=PASS`
- `VM02_C15_STAMINA_SPEND=PASS`
- `VM02_C15_STAMINA_REGEN=PASS`
- `VM02_C15_NORMAL_DAMAGE_PATH=PASS`
- `VM02_C15_BLOCK_EVIDENCE_COVERAGE=PASS`
- `VM02_C15_RUNTIME=PASS`
- inherited C14/C13 runtime contracts remain PASS

## Evidence

- final state: `artifacts/vm02-c15/first-playable-defense-stamina-1920x1080.png`
- block contact: `artifacts/vm02-c15/block-evidence-1920x1080.png`

## Run

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\RUN-VM02-C15-DEFENSE-STAMINA-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"
```

The gate emits the canonical compact `COPY_REPORT_BEGIN` / `COPY_REPORT_END` block and copies it to the clipboard.
