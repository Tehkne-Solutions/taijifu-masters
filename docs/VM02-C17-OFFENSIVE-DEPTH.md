# VM02-C17 — Offensive Combat Depth Foundation

Tehkné Solutions

## Objective

Evolve the first playable combat loop from a single offensive weight into a tactical light/heavy decision while preserving the complete C16 defense contract.

## Runtime contract

- **F** keeps the canonical light/combo path.
- **G + F** arms a heavy version of the same canonical attack chain during manual play.
- Autoplay executes one light combo followed by one heavy combo for deterministic validation.
- Light and heavy attacks both spend offensive stamina.
- Heavy attacks apply a deterministic damage multiplier and additional guard pressure.
- C16 parry, guard break, guard recovery, block and stamina behavior must remain valid.

## Presentation contract

C17 moves the defensive resources into a dedicated compact panel below the player health area. The panel contains stamina, guard, defensive state and current attack weight so combat information no longer crosses the center HUD.

## Evidence

The gate generates:

- `artifacts/vm02-c17/first-playable-offensive-depth-1920x1080.png`
- `artifacts/vm02-c17/heavy-impact-evidence-1920x1080.png`

## Gate

Run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\RUN-VM02-C17-OFFENSIVE-DEPTH-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"
```

The gate emits a clipboard-ready `COPY_REPORT_BEGIN ... COPY_REPORT_END` block.
