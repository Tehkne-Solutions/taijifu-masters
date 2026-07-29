#!/usr/bin/env python3
"""Cria um novo pack compatível com o TGAP v1.0."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_ROOT = ROOT / "templates" / "tgap"
DEFAULT_OUTPUT = ROOT / "assets" / "tgap"
DIRECTORIES = (
    "source",
    "frames",
    "atlases",
    "metadata",
    "runtime",
    "validation",
    "preview",
    "release",
)
VALID_CLASSES = {
    "character", "unit", "terrain", "board", "vegetation", "prop",
    "structure", "resource", "pickup", "vfx", "ui", "card",
    "audio", "environment",
}


def slug(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    if not normalized:
        raise ValueError("pack_id inválido")
    return normalized


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def create_pack(pack_id: str, display_name: str, asset_class: str, output: Path) -> Path:
    if asset_class not in VALID_CLASSES:
        raise ValueError(f"asset_class inválida: {asset_class}")

    canonical_id = slug(pack_id)
    pack_root = output / canonical_id
    if pack_root.exists() and any(pack_root.iterdir()):
        raise FileExistsError(f"pack já existe e não está vazio: {pack_root}")

    pack_root.mkdir(parents=True, exist_ok=True)
    for directory in DIRECTORIES:
        (pack_root / directory).mkdir(exist_ok=True)
        (pack_root / directory / ".gitkeep").write_text("", encoding="utf-8")

    manifest = load_json(TEMPLATE_ROOT / "manifest.template.json")
    manifest["pack_id"] = canonical_id
    manifest["asset_class"] = asset_class
    manifest["identity"]["display_name"] = display_name
    manifest["identity"]["canonical_prefix"] = canonical_id
    write_json(pack_root / "manifest.json", manifest)

    expected = load_json(TEMPLATE_ROOT / "expected-assets.template.json")
    expected["pack_id"] = canonical_id
    expected["assets"][0]["id"] = f"{canonical_id}.source.master"
    expected["assets"][0]["path"] = f"source/{canonical_id}__master.png"
    write_json(pack_root / "expected-assets.json", expected)

    status = {
        "tgap_version": "1.0.0",
        "pack_id": canonical_id,
        "state": "scaffold",
        "expected": len(expected["assets"]),
        "present": 0,
        "missing": len(expected["assets"]),
        "approved": 0,
        "runtime_resolved": 0,
        "promotion_blocked": True,
        "blocking_reasons": ["physical assets missing", "validation not executed"],
    }
    write_json(pack_root / "production-status.json", status)

    approval = {
        "tgap_version": "1.0.0",
        "pack_id": canonical_id,
        "approved": False,
        "approved_by": None,
        "approved_at": None,
        "notes": "",
    }
    write_json(pack_root / "approval.json", approval)

    readme = f"""# {display_name}\n\nPack `{canonical_id}` criado pelo TGAP v1.0.\n\nEstado inicial: `scaffold`.\n\nNenhum preview, poster ou mockup conta como asset final.\n"""
    (pack_root / "README.md").write_text(readme, encoding="utf-8")
    return pack_root


def main() -> int:
    parser = argparse.ArgumentParser(description="Cria scaffold de pack TGAP v1.0")
    parser.add_argument("pack_id")
    parser.add_argument("--name", required=True, dest="display_name")
    parser.add_argument("--class", required=True, dest="asset_class", choices=sorted(VALID_CLASSES))
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    created = create_pack(args.pack_id, args.display_name, args.asset_class, args.output)
    print(created)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
