#!/usr/bin/env python3
"""Audit the real visual integration state of the Taijifu First Playable.

This gate intentionally distinguishes a technically playable build from a build
that is using approved production assets. It uses only repository state and the
Python standard library so it can run locally and in CI.

Assinatura: Tehkné Solutions
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
STATUS_PATH = ROOT / "assets/tgap/pack_01_lian_wu/production-status.json"
IDENTITY_PATH = ROOT / "scripts/vertical_slice/first_playable_character_identity.gd"
CONTROLLER_PATH = ROOT / "scripts/vertical_slice/first_playable.gd"
SCENE_PATH = ROOT / "scenes/vertical_slice/first_playable.tscn"


def _read_text(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError(path.relative_to(ROOT))
    return path.read_text(encoding="utf-8")


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(_read_text(path))


def audit() -> dict[str, Any]:
    status = _read_json(STATUS_PATH)
    identity = _read_text(IDENTITY_PATH)
    controller = _read_text(CONTROLLER_PATH)
    scene = _read_text(SCENE_PATH)

    procedural_lian_wu = "func _draw_lian_wu()" in identity
    procedural_rival = "func _draw_training_rival()" in identity
    identity_attached = "FirstPlayableIdentity" in controller
    canonical_scene = "FirstPlayable" in scene

    expected = int(status.get("expected", 0))
    present = int(status.get("present", 0))
    missing = int(status.get("missing", max(0, expected - present)))
    promotion_blocked = bool(status.get("promotion_blocked", True))
    gates = status.get("gates", {})
    all_pack_gates_green = bool(gates) and all(bool(value) for value in gates.values())

    real_pack_ready = (
        expected > 0
        and present == expected
        and missing == 0
        and not promotion_blocked
        and all_pack_gates_green
    )
    procedural_runtime_active = identity_attached and (procedural_lian_wu or procedural_rival)
    visual_release_ready = canonical_scene and real_pack_ready and not procedural_runtime_active

    blockers: list[str] = []
    if present != expected or missing != 0:
        blockers.append(f"Pack 01 incompleto: {present}/{expected} presentes; {missing} ausentes")
    if promotion_blocked:
        blockers.append("Promoção do Pack 01 está bloqueada")
    if not all_pack_gates_green:
        blockers.append("Um ou mais gates do Pack 01 estão vermelhos")
    if procedural_lian_wu:
        blockers.append("Lian Wu ainda usa desenho procedural no First Playable")
    if procedural_rival:
        blockers.append("Rival de Treino ainda usa desenho procedural no First Playable")
    if not canonical_scene:
        blockers.append("Cena canônica do First Playable não foi reconhecida")

    return {
        "schema": "tehkne/taijifu-first-playable-visual-audit/v1",
        "signature": "Tehkné Solutions",
        "scene": str(SCENE_PATH.relative_to(ROOT)),
        "pack_01": {
            "state": status.get("state", "unknown"),
            "expected": expected,
            "present": present,
            "missing": missing,
            "promotion_blocked": promotion_blocked,
            "gates": gates,
            "ready": real_pack_ready,
        },
        "runtime": {
            "identity_overlay_attached": identity_attached,
            "procedural_lian_wu": procedural_lian_wu,
            "procedural_training_rival": procedural_rival,
            "procedural_runtime_active": procedural_runtime_active,
        },
        "visual_release_ready": visual_release_ready,
        "blockers": blockers,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true", help="return exit code 1 while visual release is blocked")
    parser.add_argument("--output", type=Path, help="optional JSON output path")
    args = parser.parse_args()

    try:
        report = audit()
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        print(json.dumps({"error": str(exc), "visual_release_ready": False}, ensure_ascii=False, indent=2))
        return 2

    payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    print(payload, end="")
    if args.output:
        output = args.output if args.output.is_absolute() else ROOT / args.output
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(payload, encoding="utf-8")

    if args.strict and not report["visual_release_ready"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
