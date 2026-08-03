# VM02-C18 — Parry Counter / Cancel Window Foundation

Tehkné Solutions

## Goal

Turn the validated C16 parry into an explicit offensive opportunity while preserving the C17 offensive-depth contract.

## Scope

- open a short counter window immediately after a successful parry;
- expose a shorter cancel window representing the transition from defensive success into offense;
- consume the counter opportunity deterministically in autoplay and through the normal attack input in player mode;
- render a readable counter-ready / counter-consumed visual cue;
- capture dedicated counter evidence;
- preserve C17 light/heavy attacks, offensive stamina, guard pressure, C16 defense contracts and the first-playable combat flow.

This sprint is deliberately a **foundation**. It validates timing, input consumption, presentation and state transition first. The next layer can bind the consumed counter window to a dedicated riposte technique without destabilizing the already validated C11–C17 combat chain.

## Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\RUN-VM02-C18-PARRY-COUNTER-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"
```

Expected compact report:

- `COUNTER_WINDOW=PASS`
- `CANCEL_WINDOW=PASS`
- `COUNTER_CONSUME=PASS`
- `COUNTER_EVIDENCE=PASS`
- `C17_CONTRACT=PASS`
- `RUNTIME=PASS`
- `CAPTURE=PASS`

Artifacts:

- `artifacts/vm02-c18/first-playable-parry-counter-1920x1080.png`
- `artifacts/vm02-c18/parry-counter-evidence-1920x1080.png`
