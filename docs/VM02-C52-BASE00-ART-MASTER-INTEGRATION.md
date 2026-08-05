# VM02-C52 — BASE-00 Art Master Integration

Signature: Tehkné Solutions

## Objective

Promote the approved BASE-00 technical sprite into the canonical modular fighter path without accepting a promotional sheet, text, frame, fixed shadow or procedural fallback.

## Canonical asset

`assets/modular_fighters/base_00/base_fighter_v1_master.png`

Contract:

- 1024×1024 PNG RGBA;
- native transparent background;
- one bald neutral chibi manga/comic fighter;
- bottom-center root anchor;
- pivot `0.5, 0.92`;
- last visible baseline pixel at `y=941`;
- no hair, weapon, character-specific uniform, text, logo, border or scenery;
- SHA-256 `fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe`.

## Package

Expected archive:

`TAIJIFU_BASE00_FIGHTER_BODY_MASTER_v1.0.1_FINAL.zip`

The archive contains:

- canonical asset;
- machine and human QA report;
- manifest;
- checkerboard review preview.

## Installation

```powershell
powershell -ExecutionPolicy Bypass -File ".\tools\INSTALL-VM02-C52-BASE00-ART-MASTER.ps1" `
  -RepoRoot "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\taijifu-masters" `
  -PackagePath "W:\TEHKNE-SOLUTIONS\PROJETOS\JOGO-TAIJIFU-MASTERS\TAIJIFU_BASE00_FIGHTER_BODY_MASTER_v1.0.1_FINAL.zip"
```

## Gate acceptance

- package contract PASS;
- SHA-256 PASS;
- 1024×1024 RGBA PASS;
- transparent corners PASS;
- visual QA PASS;
- pivot/baseline PASS;
- BASE-00 foundation handoff PASS.

No gameplay-progress promotion occurs from asset installation alone. The next production pack after successful integration is BASE-01 — Faces & Skin.
