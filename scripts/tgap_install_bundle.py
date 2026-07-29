#!/usr/bin/env python3
"""Instala bundles TGAP de forma transacional no runtime."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any

from jsonschema import Draft202012Validator


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json_atomic(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def safe_members(archive: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    members: list[zipfile.ZipInfo] = []
    seen: set[str] = set()
    for info in archive.infolist():
        raw = info.filename.replace("\\", "/")
        path = PurePosixPath(raw)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"caminho inseguro no bundle: {raw}")
        canonical = str(path)
        if canonical in seen:
            raise ValueError(f"entrada duplicada no bundle: {canonical}")
        seen.add(canonical)
        members.append(info)
    return members


def locate_manifest(bundle: Path) -> Path:
    candidates = [
        bundle.with_suffix(".manifest.json"),
        bundle.parent / f"{bundle.stem}.manifest.json",
    ]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise FileNotFoundError("manifesto do bundle não encontrado")


def validate_bundle(bundle: Path, manifest_path: Path, schema_path: Path) -> dict[str, Any]:
    manifest = load_json(manifest_path)
    validator = Draft202012Validator(load_json(schema_path))
    errors = sorted(validator.iter_errors(manifest), key=lambda error: list(error.absolute_path))
    if errors:
        detail = "; ".join(error.message for error in errors)
        raise ValueError(f"manifesto inválido: {detail}")
    if not manifest.get("publishable", False):
        raise ValueError("bundle não publicável")
    expected = manifest.get("archive", {}).get("sha256")
    actual = sha256(bundle)
    if expected != actual:
        raise ValueError(f"SHA-256 divergente: esperado={expected}, atual={actual}")
    return manifest


def detect_collisions(staging: Path, active: Path) -> list[str]:
    collisions: list[str] = []
    if not active.exists():
        return collisions
    for source in staging.rglob("*"):
        if not source.is_file():
            continue
        relative = source.relative_to(staging)
        target = active / relative
        if target.is_file() and sha256(source) != sha256(target):
            collisions.append(relative.as_posix())
    return sorted(collisions)


def build_catalog(manifest: dict[str, Any], bundle_hash: str, manifest_path: Path, generation: int) -> dict[str, Any]:
    packs = []
    for pack in manifest.get("packs", []):
        packs.append({
            "pack_id": pack["pack_id"],
            "version": pack["version"],
            "root": f"packs/{pack['pack_id']}",
            "file_count": int(pack.get("file_count", 0)),
            "sha256": pack["sha256"],
        })
    return {
        "schema": "tgap/install-catalog/v1",
        "project_id": manifest["project_id"],
        "generation": generation,
        "installed_at": datetime.now(timezone.utc).isoformat(),
        "active_bundle": {
            "version": manifest["bundle_version"],
            "sha256": bundle_hash,
            "manifest": str(manifest_path),
        },
        "packs": packs,
    }


def install(bundle: Path, runtime_root: Path, allow_replace: bool, keep_backup: bool) -> dict[str, Any]:
    repo = Path(__file__).resolve().parents[1]
    manifest_path = locate_manifest(bundle)
    manifest = validate_bundle(bundle, manifest_path, repo / "schemas/tgap/bundle-manifest.schema.json")
    bundle_hash = sha256(bundle)

    transactions = runtime_root / ".tgap-transactions"
    transactions.mkdir(parents=True, exist_ok=True)
    transaction_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    transaction = transactions / transaction_id
    staging = transaction / "staging"
    backup = transaction / "backup"
    report_path = transaction / "install-report.json"
    active = runtime_root / "tgap-current"
    catalog_path = runtime_root / "tgap-catalog.json"

    report: dict[str, Any] = {
        "transaction_id": transaction_id,
        "bundle": str(bundle),
        "bundle_sha256": bundle_hash,
        "runtime_root": str(runtime_root),
        "status": "started",
        "rollback_performed": False,
        "collisions": [],
    }
    transaction.mkdir(parents=True, exist_ok=False)

    try:
        staging.mkdir(parents=True)
        with zipfile.ZipFile(bundle) as archive:
            members = safe_members(archive)
            archive.extractall(staging, members=members)

        collisions = detect_collisions(staging, active)
        report["collisions"] = collisions
        if collisions and not allow_replace:
            raise RuntimeError(f"colisões detectadas: {len(collisions)}")

        current_catalog = load_json(catalog_path) if catalog_path.is_file() else None
        generation = int(current_catalog.get("generation", 0)) + 1 if current_catalog else 1
        new_catalog = build_catalog(manifest, bundle_hash, manifest_path, generation)
        Draft202012Validator(load_json(repo / "schemas/tgap/install-catalog.schema.json")).validate(new_catalog)

        if active.exists():
            shutil.move(str(active), str(backup))
        promoted = transaction / "promoted"
        shutil.move(str(staging), str(promoted))
        os.replace(promoted, active)
        write_json_atomic(catalog_path, new_catalog)

        report.update({
            "status": "installed",
            "generation": generation,
            "catalog": str(catalog_path),
            "active_root": str(active),
        })
        if backup.exists() and not keep_backup:
            shutil.rmtree(backup)
    except Exception as exc:  # noqa: BLE001
        report["status"] = "failed"
        report["error"] = str(exc)
        if active.exists() and backup.exists():
            shutil.rmtree(active)
        if backup.exists():
            shutil.move(str(backup), str(active))
            report["rollback_performed"] = True
        write_json_atomic(report_path, report)
        raise

    write_json_atomic(report_path, report)
    return report


def rollback(runtime_root: Path, transaction_id: str) -> dict[str, Any]:
    transaction = runtime_root / ".tgap-transactions" / transaction_id
    backup = transaction / "backup"
    active = runtime_root / "tgap-current"
    if not backup.exists():
        raise FileNotFoundError(f"backup indisponível para {transaction_id}")
    displaced = transaction / "rollback-displaced"
    if active.exists():
        shutil.move(str(active), str(displaced))
    shutil.move(str(backup), str(active))
    result = {"transaction_id": transaction_id, "status": "rolled_back", "active_root": str(active)}
    write_json_atomic(transaction / "rollback-report.json", result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Instala ou reverte bundle TGAP no runtime.")
    parser.add_argument("bundle", type=Path, nargs="?")
    parser.add_argument("--runtime-root", type=Path, required=True)
    parser.add_argument("--allow-replace", action="store_true")
    parser.add_argument("--keep-backup", action="store_true")
    parser.add_argument("--rollback", metavar="TRANSACTION_ID")
    args = parser.parse_args()

    runtime_root = args.runtime_root.resolve()
    runtime_root.mkdir(parents=True, exist_ok=True)
    if args.rollback:
        result = rollback(runtime_root, args.rollback)
    else:
        if args.bundle is None:
            parser.error("bundle é obrigatório quando --rollback não é usado")
        result = install(args.bundle.resolve(), runtime_root, args.allow_replace, args.keep_backup)
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
