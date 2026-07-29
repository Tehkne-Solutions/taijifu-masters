#!/usr/bin/env python3
"""Calcula a prontidão objetiva de promoção dos packs TGAP registrados."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

REQUIRED_PROMOTION_GATES = (
    "all_expected_assets_present",
    "all_sha256_valid",
    "image_gate_passed",
    "animation_gate_passed",
    "runtime_gate_passed",
    "approval_signed",
)


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_paths(pack_root: Path, expected: dict[str, Any]) -> list[Path]:
    paths = [pack_root / item for item in expected.get("required_single_files", [])]
    animations = expected.get("animations", {})
    for animation, count in animations.items():
        for frame in range(1, int(count) + 1):
            paths.append(pack_root / "frames" / animation / f"char_lian_wu__{animation}__f{frame:02d}.png")
        paths.append(pack_root / "metadata" / f"{animation}.json")
    summary = expected.get("summary", {})
    vfx_total = int(summary.get("vfx_frames", 0))
    water_slash = min(8, vfx_total)
    water_dragon = max(0, vfx_total - water_slash)
    for frame in range(1, water_slash + 1):
        paths.append(pack_root / "vfx" / "water_slash" / f"vfx_lian_wu__water_slash__f{frame:02d}.png")
    for frame in range(1, water_dragon + 1):
        paths.append(pack_root / "vfx" / "water_dragon" / f"vfx_lian_wu__water_dragon__f{frame:02d}.png")
    return paths


def read_gate_evidence(pack_root: Path) -> dict[str, bool]:
    evidence_path = pack_root / "promotion-evidence.json"
    if not evidence_path.is_file():
        return {gate: False for gate in REQUIRED_PROMOTION_GATES}
    raw = load_json(evidence_path)
    gates = raw.get("gates", {}) if isinstance(raw, dict) else {}
    return {gate: bool(gates.get(gate, False)) for gate in REQUIRED_PROMOTION_GATES}


def inspect_pack(repo: Path, entry: dict[str, Any]) -> dict[str, Any]:
    pack_root = repo / entry["root"]
    manifest_path = pack_root / "manifest.json"
    expected_path = pack_root / "expected-assets.json"
    errors: list[str] = []
    if not manifest_path.is_file():
        return {"pack_id": entry["pack_id"], "ready": False, "errors": ["manifest_missing"]}
    if not expected_path.is_file():
        return {"pack_id": entry["pack_id"], "ready": False, "errors": ["expected_assets_missing"]}

    manifest = load_json(manifest_path)
    expected = load_json(expected_path)
    paths = expected_paths(pack_root, expected)
    unique_paths = list(dict.fromkeys(paths))
    present = [path for path in unique_paths if path.is_file()]
    missing = [path.relative_to(pack_root).as_posix() for path in unique_paths if not path.is_file()]
    expected_total = int(expected.get("summary", {}).get("total_expected", len(unique_paths)))
    inventory_matches = len(unique_paths) == expected_total
    if not inventory_matches:
        errors.append(f"inventory_formula_mismatch:{len(unique_paths)}!={expected_total}")

    hashes = {
        path.relative_to(pack_root).as_posix(): sha256(path)
        for path in present
        if path.stat().st_size > 0
    }
    empty = [path.relative_to(pack_root).as_posix() for path in present if path.stat().st_size == 0]
    gates = read_gate_evidence(pack_root)
    gates["all_expected_assets_present"] = not missing and inventory_matches and not empty
    gates["all_sha256_valid"] = gates["all_expected_assets_present"] and len(hashes) == expected_total

    required_by_manifest = set(manifest.get("promotion", {}).get("requires", REQUIRED_PROMOTION_GATES))
    unknown_requirements = sorted(required_by_manifest - set(REQUIRED_PROMOTION_GATES))
    if unknown_requirements:
        errors.extend(f"unknown_requirement:{item}" for item in unknown_requirements)

    failed_gates = [gate for gate in REQUIRED_PROMOTION_GATES if not gates[gate]]
    ready = not failed_gates and not errors
    declared_blocked = bool(manifest.get("promotion", {}).get("blocked", True))
    state = str(manifest.get("state", "unknown"))
    transition_allowed = ready and declared_blocked and state in {"specified", "production", "validation", "approved"}

    return {
        "pack_id": entry["pack_id"],
        "version": entry.get("version"),
        "state": state,
        "declared_promotion_blocked": declared_blocked,
        "expected_total": expected_total,
        "enumerated_total": len(unique_paths),
        "present_total": len(present),
        "missing_total": len(missing),
        "empty_total": len(empty),
        "missing": missing,
        "empty": empty,
        "gates": gates,
        "failed_gates": failed_gates,
        "errors": errors,
        "ready": ready,
        "promotion_transition_allowed": transition_allowed,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", type=Path, default=Path("tgap-registry.json"))
    parser.add_argument("--pack", action="append", default=[])
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    registry_path = args.registry if args.registry.is_absolute() else repo / args.registry
    registry = load_json(registry_path)
    selected = set(args.pack)
    entries = [entry for entry in registry.get("packs", []) if not selected or entry["pack_id"] in selected]
    packs = [inspect_pack(repo, entry) for entry in entries]
    blocked = [pack["pack_id"] for pack in packs if not pack.get("ready", False)]
    report = {
        "schema": "tgap/promotion-readiness/v1",
        "registry": str(registry_path),
        "packs": packs,
        "summary": {
            "inspected": len(packs),
            "ready": len(packs) - len(blocked),
            "blocked": len(blocked),
            "blocked_pack_ids": blocked,
        },
    }
    output = repo / "artifacts/tgap/promotion-readiness.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 1 if args.strict and blocked else 0


if __name__ == "__main__":
    raise SystemExit(main())
