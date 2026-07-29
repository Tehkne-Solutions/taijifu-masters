#!/usr/bin/env python3
"""Valida coerência semântica entre os documentos de um pack TGAP."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ANIMATED_CLASSES = {"character", "unit", "vfx"}
ADVANCED_STATES = {"approved", "integrated", "released"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def asset_paths(expected: dict[str, Any]) -> set[str]:
    paths: set[str] = set()
    for item in expected.get("assets", []):
        if isinstance(item, str):
            paths.add(item)
        elif isinstance(item, dict) and isinstance(item.get("path"), str):
            paths.add(item["path"])
    return paths


def frame_count(value: Any) -> int | None:
    if isinstance(value, int):
        return value
    if isinstance(value, dict) and isinstance(value.get("frame_count"), int):
        return value["frame_count"]
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida coerência semântica TGAP.")
    parser.add_argument("pack_root", type=Path)
    parser.add_argument("--include-pipeline-report", action="store_true")
    args = parser.parse_args()

    root = args.pack_root.resolve()
    validation = root / "validation"
    validation.mkdir(parents=True, exist_ok=True)

    manifest = load_json(root / "manifest.json")
    expected = load_json(root / "expected-assets.json")
    status_path = root / "production-status.json"
    status = load_json(status_path) if status_path.is_file() else {}

    errors: list[str] = []
    checks: list[dict[str, Any]] = []

    def check(name: str, passed: bool, detail: str) -> None:
        checks.append({"name": name, "passed": passed, "detail": detail})
        if not passed:
            errors.append(f"{name}: {detail}")

    manifest_pack = manifest.get("pack_id")
    expected_pack = expected.get("pack_id")
    check("pack_id_manifest_expected", manifest_pack == expected_pack, f"manifest={manifest_pack!r}, expected={expected_pack!r}")

    if status:
        status_pack = status.get("pack_id")
        check("pack_id_status", status_pack in (None, manifest_pack), f"manifest={manifest_pack!r}, status={status_pack!r}")
        status_state = status.get("state")
        check("state_manifest_status", status_state in (None, manifest.get("state")), f"manifest={manifest.get('state')!r}, status={status_state!r}")

    declared_root = manifest.get("root")
    if isinstance(declared_root, str):
        check("root_matches_pack", root.as_posix().endswith(declared_root.strip("/")), f"declared={declared_root!r}, actual={root.as_posix()!r}")

    asset_class = manifest.get("asset_class")
    animations = expected.get("animations", {})
    animated = asset_class in ANIMATED_CLASSES or bool(manifest.get("validation_profile", {}).get("animated"))
    if animated:
        check("animated_pack_has_animations", isinstance(animations, dict) and bool(animations), f"asset_class={asset_class!r}, animations={animations!r}")
    else:
        check("static_pack_animation_contract", not animations or isinstance(animations, dict), "animations deve ser ausente ou objeto em packs estáticos")

    runtime = manifest.get("runtime")
    paths = asset_paths(expected)
    if isinstance(runtime, dict):
        runtime_files = [runtime.get(key) for key in ("atlas_png", "atlas_json", "spriteframes", "manifest")]
        missing_inventory = [path for path in runtime_files if isinstance(path, str) and path not in paths]
        check("runtime_files_in_inventory", not missing_inventory, f"ausentes do inventário: {missing_inventory}")

        runtime_manifest_path = root / str(runtime.get("manifest", ""))
        if runtime_manifest_path.is_file():
            runtime_manifest = load_json(runtime_manifest_path)
            runtime_pack = runtime_manifest.get("pack_id")
            check("runtime_pack_id", runtime_pack == manifest_pack, f"manifest={manifest_pack!r}, runtime={runtime_pack!r}")

            entity_id = runtime.get("entity_id")
            runtime_entity = runtime_manifest.get("entity_id", runtime_manifest.get("character_id"))
            check("runtime_entity_id", runtime_entity in (None, entity_id), f"manifest={entity_id!r}, runtime={runtime_entity!r}")

            runtime_animations = runtime_manifest.get("animations", {})
            animation_errors: list[str] = []
            for name, expected_count in animations.items() if isinstance(animations, dict) else []:
                actual = frame_count(runtime_animations.get(name)) if isinstance(runtime_animations, dict) else None
                if actual != expected_count:
                    animation_errors.append(f"{name}: expected={expected_count}, runtime={actual}")
            extras = sorted(set(runtime_animations) - set(animations)) if isinstance(runtime_animations, dict) and isinstance(animations, dict) else []
            if extras:
                animation_errors.append(f"extras={extras}")
            check("runtime_animation_counts", not animation_errors, "; ".join(animation_errors) or "contagens coerentes")

    state = manifest.get("state")
    if state in ADVANCED_STATES:
        check("advanced_state_closed_inventory", expected.get("closed_inventory", expected.get("inventory", {}).get("closed")) is True, f"state={state!r} exige inventário fechado")
        quality_errors = []
        for item in expected.get("assets", []):
            if isinstance(item, dict) and item.get("quality") not in {"final", "approved", "integrated", "released"}:
                quality_errors.append(item.get("path", "<sem path>"))
        check("advanced_state_final_assets", not quality_errors, f"assets não finais: {quality_errors[:20]}")

    if args.include_pipeline_report:
        pipeline_path = validation / "pipeline-report.json"
        pipeline = load_json(pipeline_path)
        step_names = [step.get("name") for step in pipeline.get("steps", [])]
        required = ["contract_gate", "semantic_gate", "inventory", "visual_gate", "animation_gate", "runtime_gate", "pipeline_contract_gate"]
        missing_steps = [name for name in required if name not in step_names]
        check("pipeline_required_steps", not missing_steps, f"etapas ausentes: {missing_steps}")
        if pipeline.get("pipeline_passed"):
            failed = [step.get("name") for step in pipeline.get("steps", []) if not step.get("passed")]
            check("pipeline_passed_consistency", not failed and pipeline.get("promotion_blocked") is False, f"failed={failed}, blocked={pipeline.get('promotion_blocked')}")

    passed = not errors
    report = {
        "tgap_version": "1.0",
        "gate": "semantic",
        "semantic_gate_passed": passed,
        "promotion_blocked": not passed,
        "checks": checks,
        "errors": errors,
    }
    (validation / "semantic-gate-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"semantic_gate_passed": passed, "checks": len(checks), "errors": len(errors)}, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
