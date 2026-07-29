#!/usr/bin/env python3
"""Gera release determinística de um pack TGAP aprovado."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

FIXED_ZIP_TIME = (2020, 1, 1, 0, 0, 0)
EXCLUDED_DIRS = {"validation", "release", ".git", "__pycache__"}
EXCLUDED_SUFFIXES = {".tmp", ".bak", ".psd", ".xcf"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"Falha ao ler JSON obrigatório: {path}: {exc}") from exc


def collect_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = path.relative_to(root)
        if any(part in EXCLUDED_DIRS for part in rel.parts):
            continue
        if path.suffix.lower() in EXCLUDED_SUFFIXES:
            continue
        files.append(path)
    return sorted(files, key=lambda item: item.relative_to(root).as_posix())


def write_deterministic_zip(root: Path, files: list[Path], target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        target.unlink()
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            rel = path.relative_to(root).as_posix()
            info = zipfile.ZipInfo(rel, FIXED_ZIP_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def main() -> int:
    parser = argparse.ArgumentParser(description="Gera ZIP e checksums de um pack TGAP aprovado.")
    parser.add_argument("pack_root", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--force", action="store_true", help="Ignora bloqueio apenas para diagnóstico local.")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    root = args.pack_root if args.pack_root.is_absolute() else repo / args.pack_root
    root = root.resolve()
    pipeline_path = root / "validation" / "pipeline-report.json"
    pipeline = read_json(pipeline_path)

    approved = pipeline.get("pipeline_passed") is True and pipeline.get("promotion_blocked") is False
    if not approved and not args.force:
        print(json.dumps({
            "release_created": False,
            "promotion_blocked": True,
            "reason": "pipeline_not_approved",
            "pipeline_report": str(pipeline_path),
        }, ensure_ascii=False))
        return 2

    manifest = read_json(root / "manifest.json")
    pack_id = manifest.get("pack_id") or root.name
    safe_version = args.version.strip().replace("/", "-").replace("\\", "-")
    output = args.output_dir or (root / "release")
    output = output if output.is_absolute() else repo / output
    output.mkdir(parents=True, exist_ok=True)

    files = collect_files(root)
    entries = []
    for path in files:
        entries.append({
            "path": path.relative_to(root).as_posix(),
            "size_bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    release_name = f"{pack_id}-{safe_version}"
    zip_path = output / f"{release_name}.zip"
    write_deterministic_zip(root, files, zip_path)
    zip_hash = sha256(zip_path)

    distribution = {
        "tgap_version": "1.0",
        "pack_id": pack_id,
        "version": safe_version,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "pipeline_approved": approved,
        "forced": bool(args.force and not approved),
        "archive": {
            "file": zip_path.name,
            "size_bytes": zip_path.stat().st_size,
            "sha256": zip_hash,
            "deterministic_timestamp": "2020-01-01T00:00:00Z",
        },
        "file_count": len(entries),
        "files": entries,
    }

    manifest_path = output / f"{release_name}.manifest.json"
    checksums_path = output / f"{release_name}.sha256"
    manifest_path.write_text(json.dumps(distribution, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    checksum_lines = [f"{entry['sha256']}  {entry['path']}" for entry in entries]
    checksum_lines.append(f"{zip_hash}  {zip_path.name}")
    checksum_lines.append(f"{sha256(manifest_path)}  {manifest_path.name}")
    checksums_path.write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")

    print(json.dumps({
        "release_created": True,
        "archive": str(zip_path),
        "manifest": str(manifest_path),
        "checksums": str(checksums_path),
        "file_count": len(entries),
        "sha256": zip_hash,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
