#!/usr/bin/env python3
"""Audit the active canonical visual integration of the Taijifu First Playable.

The historical TGAP production-status file describes the larger 163-asset Pack 01
roadmap and is not the release contract of the current First Playable. This audit
therefore validates the runtime assets actually loaded by the First Playable:
Lian Wu 45-frame SpriteFrames + Training Rival 44-frame SpriteFrames, both through
real presenters and with no procedural character renderer.

Assinatura: Tehkné Solutions
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
LIAN_ROOT = ROOT / "assets/tgap/pack_01_lian_wu/first_playable_lot_01"
RIVAL_ROOT = ROOT / "assets/tgap/training_rival/first_playable_lot_01"
LIAN_MANIFEST = LIAN_ROOT / "manifest.json"
RIVAL_IMPORT_MANIFEST = RIVAL_ROOT / "c28-import-manifest.json"
LIAN_FRAMES = LIAN_ROOT / "lian_wu_first_playable_frames.tres"
RIVAL_FRAMES = RIVAL_ROOT / "training_rival_first_playable_frames.tres"
IDENTITY_PATH = ROOT / "scripts/vertical_slice/first_playable_character_identity.gd"
LIAN_PRESENTER = ROOT / "scripts/vertical_slice/first_playable_lot01_presenter.gd"
RIVAL_PRESENTER = ROOT / "scripts/vertical_slice/training_rival_lot01_presenter.gd"
SCENE_PATH = ROOT / "scenes/vertical_slice/first_playable.tscn"
SIGNATURE = "Tehkné Solutions"


def _read_text(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError(path.relative_to(ROOT))
    return path.read_text(encoding="utf-8")


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(_read_text(path))


def _png_count(root: Path) -> int:
    animation_root = root / "animations"
    if not animation_root.is_dir():
        return 0
    return sum(1 for path in animation_root.rglob("*.png") if path.is_file())


def _texture_reference_count(path: Path) -> int:
    return _read_text(path).count('ext_resource type="Texture2D"')


def audit() -> dict[str, Any]:
    lian_manifest = _read_json(LIAN_MANIFEST)
    rival_manifest = _read_json(RIVAL_IMPORT_MANIFEST)
    identity = _read_text(IDENTITY_PATH)
    scene = _read_text(SCENE_PATH)

    lian_present = _png_count(LIAN_ROOT)
    rival_present = _png_count(RIVAL_ROOT)
    lian_refs = _texture_reference_count(LIAN_FRAMES)
    rival_refs = _texture_reference_count(RIVAL_FRAMES)

    lian_ready = (
        lian_present == 45
        and lian_refs == 45
        and lian_manifest.get("signature") == SIGNATURE
        and lian_manifest.get("frame_count") == 45
        and lian_manifest.get("animation_count") == 10
        and lian_manifest.get("status") == "approved_first_playable_runtime"
        and lian_manifest.get("visual_review") == "pass"
    )
    rival_ready = (
        rival_present == 44
        and rival_refs == 44
        and rival_manifest.get("signature") == SIGNATURE
        and rival_manifest.get("frame_count") == 44
        and len(rival_manifest.get("required_animations", {})) == 10
    )

    procedural_draw = "func _draw_lian_wu()" in identity or "func _draw_training_rival()" in identity or "func _draw()" in identity
    real_presenter_handoff = all(
        marker in identity
        for marker in (
            'LIAN_WU_PRESENTER := preload("res://scripts/vertical_slice/first_playable_lot01_presenter.gd")',
            'TRAINING_RIVAL_PRESENTER := preload("res://scripts/vertical_slice/training_rival_lot01_presenter.gd")',
            'presenter.name = "FirstPlayableRealAssetPresenter"',
            '"procedural_character_renderer": false',
            '"procedural_fallback_until_real_assets": false',
        )
    )
    presenter_scripts_ready = LIAN_PRESENTER.is_file() and RIVAL_PRESENTER.is_file()
    canonical_scene = "FirstPlayable" in scene
    total_frames = lian_present + rival_present
    visual_release_ready = (
        lian_ready
        and rival_ready
        and total_frames == 89
        and real_presenter_handoff
        and presenter_scripts_ready
        and not procedural_draw
        and canonical_scene
    )

    blockers: list[str] = []
    if not lian_ready:
        blockers.append(f"Lian Wu runtime incompleto/inválido: PNG={lian_present}/45 SpriteFrames={lian_refs}/45")
    if not rival_ready:
        blockers.append(f"Training Rival runtime incompleto/inválido: PNG={rival_present}/44 SpriteFrames={rival_refs}/44")
    if total_frames != 89:
        blockers.append(f"Baseline de lutadores divergente: {total_frames}/89")
    if procedural_draw:
        blockers.append("Renderer procedural de personagem detectado na identidade ativa")
    if not real_presenter_handoff:
        blockers.append("Handoff para FirstPlayableRealAssetPresenter não está canônico")
    if not presenter_scripts_ready:
        blockers.append("Um ou mais presenters canônicos estão ausentes")
    if not canonical_scene:
        blockers.append("Cena canônica do First Playable não foi reconhecida")

    return {
        "schema": "tehkne/taijifu-first-playable-visual-audit/v2",
        "signature": SIGNATURE,
        "scene": str(SCENE_PATH.relative_to(ROOT)),
        "fighters": {
            "lian_wu": {
                "expected": 45,
                "present": lian_present,
                "spriteframe_references": lian_refs,
                "animations": 10,
                "ready": lian_ready,
            },
            "training_rival": {
                "expected": 44,
                "present": rival_present,
                "spriteframe_references": rival_refs,
                "animations": 10,
                "ready": rival_ready,
            },
            "total_expected": 89,
            "total_present": total_frames,
        },
        "runtime": {
            "real_presenter_handoff": real_presenter_handoff,
            "presenter_scripts_ready": presenter_scripts_ready,
            "procedural_character_renderer": procedural_draw,
        },
        "visual_release_ready": visual_release_ready,
        "blockers": blockers,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true", help="return exit code 1 while canonical visual release is blocked")
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
