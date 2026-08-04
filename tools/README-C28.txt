VM02-C28 — V.2 RIVAL INTAKE BRIDGE
Tehkné Solutions

Purpose:
Turn the second-fighter blocker into a one-command pipeline.

The gate automatically:
- resolves the sibling taijifu-masters-assets repository;
- clones it when missing;
- fast-forward syncs it;
- validates the Training Rival work manifest;
- checks the exact 44 canonical PNG filenames;
- imports the complete pack atomically into the game only after 44/44 are valid;
- leaves the current mirrored proxy untouched while the canonical pack is incomplete.

Run on branch vm02-c28-v2-rival-intake-bridge:

powershell -ExecutionPolicy Bypass -File ".\tools\RUN-CURRENT-VM02-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters"

If the assets repository lives elsewhere:

powershell -ExecutionPolicy Bypass -File ".\tools\RUN-VM02-C28-V2-RIVAL-INTAKE-GATE.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters" `
  -AssetsRepoRoot "<path-to-taijifu-masters-assets>"

A PASS gate with RIVAL_CANONICAL_READY=BLOCKED is expected until real approved rival art is present. No provisional proxy is promoted as V.2 content.
