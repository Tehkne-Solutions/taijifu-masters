# VM02-C35 — Canonical Arena Visual Proof

C35 is the first runtime visual proof after Mountain Dojo Night reaches the canonical C30/C34 intake contract.

## Gate contract

- C34 canonical runtime preflight must PASS;
- `Mountain Dojo Night` must be the active arena ID;
- the `CanonicalArenaParallax` runtime node must exist;
- the old procedural parallax/final-layer nodes must be absent;
- Godot must produce a normalized 1920×1080 runtime capture;
- evidence artifact: `artifacts/vm02-c35/mountain-dojo-night-runtime-1920x1080.png`.

## Operator flow

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\RUN-CURRENT-VM02-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"
```

Expected terminal marker:

```text
VM02_C35_VISUAL_PROOF_GATE=PASS
```

Visual review remains mandatory before the arena is considered visually final for V.2.

Tehkné Solutions
