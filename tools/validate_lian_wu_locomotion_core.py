#!/usr/bin/env python3
"""Validate VM02-A1 Lian Wu Locomotion Core without promoting missing art.

Signature: Tehkné Solutions
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

try:
    from PIL import Image
except Exception:
    Image = None

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "assets/pack_01_characters/lian_wu/locomotion-core.contract.json"
PACK_ROOT = ROOT / "assets/pack_01_characters/lian_wu"


def expected_frames(contract: dict) -> list[Path]:
    paths: list[Path] = []
    for animation, count in contract["scope"]["animations"].items():
        for index in range(1, count + 1):
            paths.append(
                PACK_ROOT
                / "frames"
                / animation
                / f"char_lian_wu__{animation}__f{index:02d}.png"
            )
    return paths


def fail(message: str) -> None:
    print(f"VM02_A1_LOCOMOTION_CORE=BLOCKED {message}")


def main() -> int:
    if not CONTRACT.exists():
        fail(f"missing contract: {CONTRACT}")
        return 2

    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    frames = expected_frames(contract)
    missing = [path for path in frames if not path.exists()]
    if missing:
        fail(f"missing_frames={len(missing)}/{len(frames)}")
        for path in missing[:20]:
            print(f"MISSING {path.relative_to(ROOT)}")
        if len(missing) > 20:
            print(f"... {len(missing) - 20} more missing")
        return 3

    if Image is None:
        fail("Pillow is required for PNG validation")
        return 4

    invalid: list[str] = []
    for path in frames:
        try:
            with Image.open(path) as image:
                if image.format != "PNG":
                    invalid.append(f"{path.name}: format={image.format}")
                rgba = image.convert("RGBA")
                if rgba.size != (1024, 1024):
                    invalid.append(f"{path.name}: size={rgba.size}")
                alpha = rgba.getchannel("A")
                if alpha.getbbox() is None:
                    invalid.append(f"{path.name}: empty alpha silhouette")
        except Exception as exc:
            invalid.append(f"{path.name}: {exc}")

    if invalid:
        fail(f"invalid_frames={len(invalid)}")
        for item in invalid[:30]:
            print(f"INVALID {item}")
        return 5

    metadata_missing = [
        PACK_ROOT / "metadata" / f"{animation}.json"
        for animation in contract["scope"]["animations"]
        if not (PACK_ROOT / "metadata" / f"{animation}.json").exists()
    ]
    if metadata_missing:
        fail(f"missing_metadata={len(metadata_missing)}")
        for path in metadata_missing:
            print(f"MISSING {path.relative_to(ROOT)}")
        return 6

    print("VM02_A1_LOCOMOTION_CORE_FILES=PASS")
    print(f"frames={len(frames)}")
    print("PROMOTION=BLOCKED_PENDING_VISUAL_AND_GODOT_RUNTIME_REVIEW")
    return 0


if __name__ == "__main__":
    sys.exit(main())
