#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA = "taijifu/character-dna/v1"
OUTPUT_SCHEMA = "taijifu/character-factory-report/v1"
REQUIRED_FIELDS = {
    "id", "name", "pack_id", "origin", "faction", "combat_style",
    "movement", "palette", "personality", "lore", "skills", "ultimate",
    "rarity", "source_assets", "animations"
}


def slug(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    if not normalized:
        raise ValueError("invalid empty slug")
    return normalized


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate(dna: dict) -> list[str]:
    errors: list[str] = []
    if dna.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    missing = sorted(REQUIRED_FIELDS - set(dna))
    if missing:
        errors.append("missing fields: " + ", ".join(missing))
    if dna.get("id") and slug(dna["id"]) != dna["id"]:
        errors.append("id must be lowercase snake_case")
    if dna.get("pack_id") and slug(dna["pack_id"]) != dna["pack_id"]:
        errors.append("pack_id must be lowercase snake_case")
    if not isinstance(dna.get("source_assets"), list) or not dna.get("source_assets"):
        errors.append("source_assets must be a non-empty list")
    if not isinstance(dna.get("animations"), list) or not dna.get("animations"):
        errors.append("animations must be a non-empty list")
    return errors


def render_contracts(dna: dict) -> dict[str, dict]:
    pack_id = dna["pack_id"]
    character_id = dna["id"]
    source_assets = dna["source_assets"]
    animations = dna["animations"]
    root = f"artifacts/asset-forge/{pack_id}"

    return {
        f"asset-forge/packs/{pack_id}.json": {
            "schema": "taijifu/asset-forge-pack/v1",
            "pack_id": pack_id,
            "character_id": character_id,
            "no_placeholders": True,
            "required_source_assets": source_assets,
            "required_animations": animations,
            "output_root": root,
        },
        f"asset-forge/intake/{pack_id}.json": {
            "schema": "taijifu/asset-forge-intake-config/v1",
            "pack_id": pack_id,
            "destination": f"asset-forge/incoming/{pack_id}",
            "required_files": source_assets,
            "reject_unknown_files": True,
            "max_files": max(16, len(source_assets) + 8),
        },
        f"asset-forge/review/{pack_id}.json": {
            "schema": "taijifu/asset-forge-review-config/v1",
            "pack_id": pack_id,
            "title": f"{dna['name']} — visual review",
            "assets_root": f"asset-forge/incoming/{pack_id}",
            "required_assets": source_assets,
            "output": f"{root}/review/index.html",
        },
        f"asset-forge/release/{pack_id}.json": {
            "schema": "taijifu/asset-forge-release-config/v2",
            "pack_id": pack_id,
            "intake_config": f"asset-forge/intake/{pack_id}.json",
            "orchestration_config": f"asset-forge/orchestration/{pack_id}.json",
            "pack_spec": f"asset-forge/packs/{pack_id}.json",
            "review_config": f"asset-forge/review/{pack_id}.json",
            "approval": f"{root}/review/approval.json",
            "report": f"{root}/{pack_id}__release-pipeline.json",
        },
        f"assets/tgap/{pack_id}/character_dna.json": dna,
    }


def write_contracts(repo: Path, contracts: dict[str, dict], force: bool) -> list[str]:
    created: list[str] = []
    for relative, payload in contracts.items():
        path = repo / relative
        if path.exists() and not force:
            raise FileExistsError(f"refusing to overwrite {relative}; use --force")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        created.append(relative)
    return created


def main() -> int:
    parser = argparse.ArgumentParser(description="Taijifu Character Factory")
    parser.add_argument("dna", type=Path, help="Character DNA JSON")
    parser.add_argument("--repo", type=Path, default=Path("."))
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--check", action="store_true", help="validate only")
    args = parser.parse_args()

    dna = load_json(args.dna)
    errors = validate(dna)
    report = {
        "schema": OUTPUT_SCHEMA,
        "character_id": dna.get("id"),
        "pack_id": dna.get("pack_id"),
        "valid": not errors,
        "errors": errors,
        "created": [],
    }
    if errors:
        print(json.dumps(report, ensure_ascii=False))
        return 13
    if not args.check:
        report["created"] = write_contracts(args.repo, render_contracts(dna), args.force)
    print(json.dumps(report, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
