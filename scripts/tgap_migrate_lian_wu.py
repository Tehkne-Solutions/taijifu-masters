#!/usr/bin/env python3
"""Migra o PACK 01 legado de Lian Wu para a raiz canônica TGAP sem duplicar binários."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

LEGACY = Path("assets/pack_01_characters/lian_wu")
TARGET = Path("assets/tgap/pack_01_lian_wu")
COPY_DIRS = ("source", "frames", "portraits", "icons", "vfx", "atlases", "metadata", "runtime", "validation", "preview", "release")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def copy_tree(source: Path, target: Path) -> int:
    copied = 0
    if not source.exists():
        return copied
    for file_path in source.rglob("*"):
        if not file_path.is_file():
            continue
        relative = file_path.relative_to(source)
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists() and sha256(destination) == sha256(file_path):
            continue
        shutil.copy2(file_path, destination)
        copied += 1
    return copied


def refresh_status(target: Path) -> dict:
    expected = json.loads((target / "expected-assets.json").read_text(encoding="utf-8"))
    files = [p for p in target.rglob("*") if p.is_file() and p.name not in {"manifest.json", "expected-assets.json", "production-status.json", "approval.json"}]
    expected_total = int(expected["summary"]["total_expected"])
    present = min(len(files), expected_total)
    status = json.loads((target / "production-status.json").read_text(encoding="utf-8"))
    status["present"] = present
    status["missing"] = max(expected_total - present, 0)
    status["progress"] = round(present / expected_total, 6)
    status["state"] = "production" if present else "specified"
    status["promotion_blocked"] = present != expected_total
    status["legacy_migration"]["binary_copy_complete"] = True
    status["legacy_migration"]["metadata_copy_complete"] = True
    (target / "production-status.json").write_text(json.dumps(status, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return status


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--legacy", type=Path, default=LEGACY)
    parser.add_argument("--target", type=Path, default=TARGET)
    args = parser.parse_args()

    args.target.mkdir(parents=True, exist_ok=True)
    copied = 0
    for directory in COPY_DIRS:
        copied += copy_tree(args.legacy / directory, args.target / directory)

    status = refresh_status(args.target)
    print(f"Arquivos copiados ou atualizados: {copied}")
    print(f"Progresso TGAP: {status['present']}/{status['expected']}")
    print(f"Promoção bloqueada: {status['promotion_blocked']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
