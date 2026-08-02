# VM02-A2 — Lian Wu Idle 6 Promotion

Signature: Tehkné Solutions

## Result

`LIAN_WU_IDLE6=PASS`

The six-frame idle loop was generated deterministically from the approved Character Lock neutral source and reviewed in Godot 4.7.1.

## Evidence

- Character Lock source SHA256: `0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5`
- Godot bench SHA256: `4aede33b1432a255a3c65f5236a6d436a9397b88a018294f9490e85c8a498062`
- output: `artifacts/vm02-a2/lian-wu-idle6-bench-1920x1080.png`
- source alpha bounds: `(320, 70, 720, 970)`
- baseline y: `969`
- frame count: `6`
- loop FPS: `8`

## Frame lineage

| Frame | SHA256 |
|---|---|
| F01 | `233741f7258860f03305fac05b4cadb604d8136b47effb9b9b4c0f8d25396dea` |
| F02 | `d139b163f7eb408d27849eb7f781a020d05cd807adc1ebbae3ab9b03c91cd126` |
| F03 | `59b7ad2eeba90fcd6f5bcb499406c7459bb4025d77f7eb4f36705f07cd43c7ea` |
| F04 | `d139b163f7eb408d27849eb7f781a020d05cd807adc1ebbae3ab9b03c91cd126` |
| F05 | `233741f7258860f03305fac05b4cadb604d8136b47effb9b9b4c0f8d25396dea` |
| F06 | `333b088b064d6dd3bc4378fd1e7da01ccd029058eb616a3303f6337b6bad9eca` |

The repeated F01/F05 and F02/F04 hashes are intentional because the breathing cycle is symmetric.

## Visual review

PASS:
- identity continuity;
- face/hair/outfit continuity;
- weapon continuity;
- transparent background;
- foot contact baseline;
- bottom-center pivot continuity;
- scale continuity;
- no visible tearing;
- no visible seam artifacts;
- no accidental pose drift.

## Locomotion Core progress

`6/36` canonical frames complete.

Remaining:
- walk: 8
- run: 8
- jump_start: 4
- jump_loop: 3
- fall: 3
- land: 4

## Next gate

`VM02-A3 — Walk 8`

Walk must use articulated body motion derived from the approved Character Lock/Rig lineage. A global whole-body warp like Idle is not sufficient for Walk promotion.
