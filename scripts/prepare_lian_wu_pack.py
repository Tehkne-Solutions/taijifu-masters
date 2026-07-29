#!/usr/bin/env python3
"""Prepare and audit the physical structure of PACK 01 — Lian Wu.

This script never marks assets as complete by itself. It creates the required
folders, expands the closed inventory into explicit file paths and updates the
production status from files that actually exist on disk.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "assets" / "pack_01_characters" / "lian_wu"
ANIMATIONS = {
    "idle": 6,
    "walk": 8,
    "run": 8,
    "jump_start": 4,
    "jump_loop": 3,
    "fall": 3,
    "land": 4,
    "attack_light_01": 6,
    "attack_light_02": 7,
    "attack_heavy": 9,
    "dash": 5,
    "block": 4,
    "parry": 5,
    "skill_water_dragon": 10,
    "hurt": 4,
    "knockback": 5,
    "downed": 6,
    "death": 8,
    "victory": 8,
}
VFX = {"water_slash": 8, "water_dragon": 10}
SINGLE_FILES = [
    "source/char_lian_wu__master.png",
    "portraits/portrait_lian_wu__profile.png",
    "portraits/portrait_lian_wu__battle.png",
    "portraits/portrait_lian_wu__defeated.png",
    "icons/icon_lian_wu__character.png",
    "icons/icon_lian_wu__water_element.png",
    "atlases/char_lian_wu__atlas.png",
    "atlases/char_lian_wu__atlas.json",
    "runtime/lian_wu_spriteframes.tres",
    "runtime/lian_wu_runtime_manifest.json",
    "validation/pack01_lian_wu_validation.tscn",
    "validation/pack01_lian_wu_validation.gd",
    "preview/pack01_lian_wu_preview.png",
]


def expected_paths() -> list[str]:
    paths = list(SINGLE_FILES)
    for animation, count in ANIMATIONS.items():
        paths.extend(
            f"frames/{animation}/char_lian_wu__{animation}__f{frame:02d}.png"
            for frame in range(1, count + 1)
        )
        paths.append(f"metadata/{animation}.json")
    for effect, count in VFX.items():
        paths.extend(
            f"vfx/{effect}/vfx_lian_wu__{effect}__f{frame:02d}.png"
            for frame in range(1, count + 1)
        )
    return sorted(paths)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    paths = expected_paths()
    for relative in paths:
        (PACK / relative).parent.mkdir(parents=True, exist_ok=True)

    inventory = []
    present = 0
    for relative in paths:
        path = PACK / relative
        exists = path.is_file()
        present += int(exists)
        inventory.append(
            {
                "id": relative.replace("/", "__").replace(".", "_"),
                "path": relative,
                "present": exists,
                "sha256": sha256(path) if exists else None,
                "approved": False,
            }
        )

    expected = len(paths)
    expanded = {
        "pack_id": "pack_01_characters_lian_wu",
        "closed_inventory": True,
        "expected_count": expected,
        "assets": inventory,
    }
    (PACK / "expected-assets.expanded.json").write_text(
        json.dumps(expanded, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    missing = expected - present
    status = {
        "pack_id": "pack_01_characters_lian_wu",
        "status": "production" if present else "specified",
        "expected": expected,
        "present": present,
        "approved": 0,
        "missing": missing,
        "progress_percent": round((present / expected) * 100, 2),
        "gates": {
            "files": missing == 0,
            "dimensions": False,
            "transparency": False,
            "pivots": False,
            "hashes": missing == 0,
            "visual_approval": False,
            "godot_import": False,
            "runtime_integration": False,
            "archive": False,
        },
        "promotion_blocked": True,
        "blocking_reasons": [
            f"{missing} arquivos físicos ausentes" if missing else "validação técnica pendente",
            "aprovação visual pendente",
            "integração Godot pendente",
            "archive final e SHA-256 pendentes",
        ],
    }
    (PACK / "production-status.json").write_text(
        json.dumps(status, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"PACK 01: {present}/{expected} arquivos físicos presentes")
    return 0 if missing == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
