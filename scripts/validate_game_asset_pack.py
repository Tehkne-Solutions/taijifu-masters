#!/usr/bin/env python3
"""Validate a Tehkné game asset pack without trusting manual status flags."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ALLOWED_STATUSES = {
    "scaffold",
    "specified",
    "production",
    "validation",
    "approved",
    "integrated",
    "released",
}


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"arquivo obrigatório ausente: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"JSON inválido em {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"objeto JSON esperado em {path}")
    return data


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate(pack_dir: Path) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    manifest = load_json(pack_dir / "manifest.json")
    expected = load_json(pack_dir / "expected-assets.json")
    status = str(manifest.get("status", ""))

    if status not in ALLOWED_STATUSES:
        errors.append(f"status inválido: {status!r}")

    assets = expected.get("assets")
    if not isinstance(assets, list):
        errors.append("expected-assets.json precisa conter uma lista 'assets'")
        assets = []

    seen_ids: set[str] = set()
    seen_paths: set[str] = set()
    counts = {"expected": 0, "present": 0, "valid": 0, "approved": 0}

    for index, item in enumerate(assets):
        if not isinstance(item, dict):
            errors.append(f"assets[{index}] não é um objeto")
            continue

        if not item.get("required", True):
            continue

        counts["expected"] += 1
        asset_id = str(item.get("id", "")).strip()
        relative_path = str(item.get("path", "")).strip()

        if not asset_id:
            errors.append(f"assets[{index}] sem ID canônico")
        elif asset_id in seen_ids:
            errors.append(f"ID duplicado: {asset_id}")
        else:
            seen_ids.add(asset_id)

        if not relative_path:
            errors.append(f"assets[{index}] sem caminho")
            continue
        if relative_path in seen_paths:
            errors.append(f"caminho duplicado: {relative_path}")
        seen_paths.add(relative_path)

        path = (pack_dir / relative_path).resolve()
        try:
            path.relative_to(pack_dir.resolve())
        except ValueError:
            errors.append(f"caminho inseguro fora do pack: {relative_path}")
            continue

        if not path.is_file():
            errors.append(f"asset ausente: {relative_path}")
            continue

        counts["present"] += 1
        recorded_hash = item.get("sha256")
        actual_hash = sha256(path)
        if recorded_hash and str(recorded_hash).lower() != actual_hash:
            errors.append(f"SHA-256 divergente: {relative_path}")
            continue

        counts["valid"] += 1
        if item.get("approved") is True:
            counts["approved"] += 1

    if status in {"approved", "integrated", "released"}:
        if counts["expected"] == 0:
            errors.append("pack promovido sem assets obrigatórios")
        if counts["valid"] != counts["expected"]:
            errors.append("pack promovido com assets ausentes ou inválidos")
        if counts["approved"] != counts["expected"]:
            errors.append("pack promovido sem aprovação de todos os assets")

    if status in {"integrated", "released"}:
        promotion = manifest.get("promotion", {})
        if not isinstance(promotion, dict) or not promotion.get("integrated"):
            errors.append("status integrado sem promotion.integrated=true")

    if status == "released":
        promotion = manifest.get("promotion", {})
        if not isinstance(promotion, dict):
            errors.append("bloco promotion ausente")
        else:
            if not promotion.get("released"):
                errors.append("status released sem promotion.released=true")
            if not promotion.get("release_archive") or not promotion.get("release_sha256"):
                errors.append("release sem archive e SHA-256 registrados")

    return errors, counts


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_dir", type=Path)
    args = parser.parse_args()

    try:
        errors, counts = validate(args.pack_dir)
    except ValueError as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 2

    print(json.dumps({"counts": counts, "errors": errors}, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
