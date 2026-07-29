#!/usr/bin/env python3
"""Planeja e gera bundles TGAP determinísticos a partir do registro global."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

EXCLUDED_PARTS = {"validation", "release", ".git", "__pycache__"}
FIXED_DATE = (2000, 1, 1, 0, 0, 0)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def registry_plan(repo: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    registry = load_json(repo / "tgap-registry.json")
    enabled = [item for item in registry["packs"] if item.get("enabled", True)]
    enabled.sort(key=lambda item: (item["integration_order"], item["pack_id"]))
    return registry, enabled


def pipeline_approved(pack_root: Path) -> bool:
    report = pack_root / "validation" / "pipeline-report.json"
    if not report.is_file():
        return False
    try:
        data = load_json(report)
    except Exception:
        return False
    return data.get("pipeline_passed") is True and data.get("promotion_blocked") is False


def run_pipeline(repo: Path, pack_root: Path, python: str) -> dict[str, Any]:
    process = subprocess.run(
        [python, str(repo / "scripts" / "tgap_run_pack.py"), str(pack_root)],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    return {
        "exit_code": process.returncode,
        "passed": process.returncode == 0,
        "stdout": process.stdout.strip(),
        "stderr": process.stderr.strip(),
    }


def pack_files(pack_root: Path) -> list[Path]:
    return sorted(
        path for path in pack_root.rglob("*")
        if path.is_file() and not any(part in EXCLUDED_PARTS for part in path.relative_to(pack_root).parts)
    )


def pack_digest(pack_root: Path, files: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in files:
        relative = path.relative_to(pack_root).as_posix().encode("utf-8")
        digest.update(relative + b"\0" + path.read_bytes())
    return digest.hexdigest()


def write_zip(output: Path, repo: Path, packs: list[dict[str, Any]]) -> int:
    count = 0
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for item in packs:
            root = repo / item["root"]
            for path in pack_files(root):
                relative = path.relative_to(root).as_posix()
                arcname = f"packs/{item['pack_id']}/{relative}"
                info = zipfile.ZipInfo(arcname, FIXED_DATE)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, path.read_bytes())
                count += 1
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description="Planeja e empacota packs TGAP habilitados.")
    parser.add_argument("--version", required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("artifacts/tgap/bundles"))
    parser.add_argument("--run-pipelines", action="store_true")
    parser.add_argument("--plan-only", action="store_true")
    parser.add_argument("--force", action="store_true", help="Gera bundle diagnóstico não publicável.")
    parser.add_argument("--python", default=sys.executable)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    registry, packs = registry_plan(repo)
    output_dir = args.output_dir if args.output_dir.is_absolute() else repo / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    plan = {
        "schema": "tgap/integration-plan/v1",
        "project_id": registry["project_id"],
        "registry_version": registry["registry_version"],
        "bundle_version": args.version,
        "integration_plan": [item["pack_id"] for item in packs],
        "packs": packs,
    }
    plan_path = output_dir / f"{registry['project_id']}-tgap-{args.version}.plan.json"
    plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.plan_only:
        print(json.dumps({"planned": len(packs), "plan": str(plan_path)}, ensure_ascii=False))
        return 0

    results: list[dict[str, Any]] = []
    blocked = False
    for item in packs:
        root = repo / item["root"]
        pipeline = None
        if args.run_pipelines:
            pipeline = run_pipeline(repo, root, args.python)
        approved = pipeline_approved(root)
        files = pack_files(root) if root.is_dir() else []
        if not root.is_dir() or not approved:
            blocked = True
        results.append({
            "pack_id": item["pack_id"],
            "version": item["version"],
            "root": item["root"],
            "pipeline_approved": approved,
            "pipeline_run": pipeline,
            "file_count": len(files),
            "sha256": pack_digest(root, files) if files else "0" * 64,
        })

    if blocked and not args.force:
        report = {
            "bundle_created": False,
            "promotion_blocked": True,
            "reason": "one_or_more_packs_not_approved",
            "packs": results,
            "plan": str(plan_path),
        }
        report_path = output_dir / f"{registry['project_id']}-tgap-{args.version}.bundle-report.json"
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False))
        return 1

    archive_path = output_dir / f"{registry['project_id']}-tgap-{args.version}.zip"
    file_count = write_zip(archive_path, repo, packs)
    manifest = {
        "schema": "tgap/bundle/v1",
        "project_id": registry["project_id"],
        "bundle_version": args.version,
        "registry_version": registry["registry_version"],
        "publishable": not blocked and not args.force,
        "forced": args.force,
        "integration_plan": plan["integration_plan"],
        "packs": results,
        "archive": {
            "path": archive_path.name,
            "sha256": sha256_file(archive_path),
            "file_count": file_count,
        },
    }
    schema = load_json(repo / "schemas" / "tgap" / "bundle-manifest.schema.json")
    errors = [error.message for error in Draft202012Validator(schema).iter_errors(manifest)]
    if errors:
        raise SystemExit("bundle manifest inválido: " + "; ".join(errors))

    manifest_path = archive_path.with_suffix(".manifest.json")
    checksum_path = archive_path.with_suffix(".sha256")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    checksum_path.write_text(f"{manifest['archive']['sha256']}  {archive_path.name}\n", encoding="utf-8")
    print(json.dumps({"bundle": str(archive_path), "manifest": str(manifest_path), "publishable": manifest["publishable"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
