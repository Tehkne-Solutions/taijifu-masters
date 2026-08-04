# VM02-C34 — V.2 Arena Runtime Binding

C34 wires the canonical Mountain Dojo Night pack into the existing first-playable environment without promoting incomplete content.

Behavior:
- when the three canonical PNG layers are absent, the current procedural environment remains available as development fallback;
- after C30 imports all six arena files, `FirstPlayableEnvironmentArt` switches automatically to `CanonicalArenaParallax`;
- background, midground and foreground use the canonical 0.18 / 0.48 / 1.0 parallax contract;
- procedural sky, mountains, platform readability overlay and placeholder arena layers are retired while the canonical arena is active;
- combat logic and balance remain untouched.

Validation:

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\RUN-VM02-C34-V2-ARENA-RUNTIME-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"
```

The gate can PASS as a pipeline while `CANONICAL_RUNTIME_READY=BLOCKED` until C33 supplies the three real PNG layers and C30 imports them.

Tehkné Solutions
