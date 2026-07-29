#!/usr/bin/env python3
"""Converte os faltantes de promoção TGAP em lotes progressivos de produção."""
from __future__ import annotations

import argparse
import importlib.util
import json
from collections import defaultdict
from pathlib import Path
from typing import Any

BATCH_ORDER = (
    "master_and_identity",
    "core_movement",
    "core_combat",
    "advanced_combat",
    "vfx",
    "metadata",
    "runtime_and_atlas",
    "validation_and_preview",
)

MOVEMENT = {"idle", "walk", "run", "jump_start", "jump_loop", "fall", "land", "dash"}
CORE_COMBAT = {"attack_light_01", "attack_light_02", "attack_heavy", "block", "parry", "hurt"}
ADVANCED_COMBAT = {"skill_water_dragon", "knockback", "downed", "death", "victory"}


def load_readiness_module(repo: Path):
    path = repo / "scripts/tgap_pack_promotion_readiness.py"
    spec = importlib.util.spec_from_file_location("tgap_readiness", path)
    if not spec or not spec.loader:
        raise RuntimeError(f"cannot_load:{path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def animation_from_path(path: str) -> str | None:
    parts = Path(path).parts
    if len(parts) >= 3 and parts[0] == "frames":
        return parts[1]
    if len(parts) == 2 and parts[0] == "metadata":
        return Path(parts[1]).stem
    return None


def classify(path: str) -> str:
    if path.startswith(("source/", "portraits/", "icons/")):
        return "master_and_identity"
    animation = animation_from_path(path)
    if path.startswith("frames/") and animation in MOVEMENT:
        return "core_movement"
    if path.startswith("frames/") and animation in CORE_COMBAT:
        return "core_combat"
    if path.startswith("frames/") and animation in ADVANCED_COMBAT:
        return "advanced_combat"
    if path.startswith("vfx/"):
        return "vfx"
    if path.startswith("metadata/"):
        return "metadata"
    if path.startswith(("atlases/", "runtime/")):
        return "runtime_and_atlas"
    if path.startswith(("validation/", "preview/")):
        return "validation_and_preview"
    return "master_and_identity"


def build_plan(pack: dict[str, Any]) -> dict[str, Any]:
    grouped: dict[str, list[str]] = defaultdict(list)
    for path in pack.get("missing", []):
        grouped[classify(path)].append(path)
    batches = []
    cumulative = 0
    for index, batch_id in enumerate(BATCH_ORDER, start=1):
        files = sorted(grouped.get(batch_id, []))
        cumulative += len(files)
        batches.append({
            "sequence": index,
            "batch_id": batch_id,
            "missing_total": len(files),
            "cumulative_missing_addressed": cumulative,
            "files": files,
            "done": len(files) == 0,
        })
    return {
        "pack_id": pack["pack_id"],
        "expected_total": pack.get("expected_total", 0),
        "present_total": pack.get("present_total", 0),
        "missing_total": pack.get("missing_total", 0),
        "empty_total": pack.get("empty_total", 0),
        "batches": batches,
        "next_batch": next((item["batch_id"] for item in batches if not item["done"]), None),
        "production_complete": pack.get("missing_total", 0) == 0 and pack.get("empty_total", 0) == 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", default="pack_01_lian_wu")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    registry = json.loads((repo / "tgap-registry.json").read_text(encoding="utf-8"))
    entry = next((item for item in registry.get("packs", []) if item["pack_id"] == args.pack), None)
    if entry is None:
        raise SystemExit(f"pack_not_registered:{args.pack}")

    readiness = load_readiness_module(repo)
    inspected = readiness.inspect_pack(repo, entry)
    plan = {
        "schema": "tgap/production-batches/v1",
        "generated_from": "live_repository_inventory",
        "pack": build_plan(inspected),
    }
    output = repo / "artifacts/tgap/pack-production-batches.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "pack_id": args.pack,
        "missing_total": inspected.get("missing_total", 0),
        "next_batch": plan["pack"]["next_batch"],
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
