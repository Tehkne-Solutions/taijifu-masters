#!/usr/bin/env python3
"""Audit legacy asset references and optionally rewrite safe call sites."""
from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".json", ".cfg", ".md"}
SKIP_PARTS = {".git", ".godot", "artifacts", "node_modules", ".venv"}
PATTERNS = {
    "legacy_registry": re.compile(r"\bAssetPackRegistry\b"),
    "legacy_pack_root": re.compile(r"res://assets/packs/"),
    "legacy_pack_json": re.compile(r"(?:^|[\"'])pack\.json(?:$|[\"'])"),
    "direct_tgap_path": re.compile(r"res://assets/tgap/pack_[a-z0-9_]+/"),
}
SAFE_REWRITES = (
    ("AssetPackRegistry.load_asset(", "TgapAssetLoader.load_resource("),
    ("AssetPackRegistry.resolve_asset(", "TgapAssetLoader.resolve("),
)


def iter_files(root: Path):
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        if any(part in SKIP_PARTS for part in path.parts):
            continue
        yield path


def audit(root: Path) -> dict:
    findings = []
    counts = Counter()
    for path in iter_files(root):
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for number, line in enumerate(lines, 1):
            for kind, pattern in PATTERNS.items():
                if pattern.search(line):
                    counts[kind] += 1
                    findings.append({
                        "kind": kind,
                        "path": path.relative_to(root).as_posix(),
                        "line": number,
                        "text": line.strip()[:300],
                        "severity": "error" if kind == "legacy_pack_root" else "warning",
                    })
    return {
        "schema": "tgap/legacy-audit/v1",
        "root": root.as_posix(),
        "summary": {
            "total_findings": len(findings),
            "files_affected": len({item["path"] for item in findings}),
            "by_kind": dict(sorted(counts.items())),
        },
        "findings": findings,
    }


def migrate(root: Path) -> list[str]:
    changed = []
    for path in iter_files(root):
        if path.suffix.lower() != ".gd" or path.name == "asset_pack_registry.gd":
            continue
        text = path.read_text(encoding="utf-8")
        updated = text
        for old, new in SAFE_REWRITES:
            updated = updated.replace(old, new)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed.append(path.relative_to(root).as_posix())
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path, default=Path("artifacts/tgap/legacy-usage-report.json"))
    parser.add_argument("--migrate-safe", action="store_true")
    parser.add_argument("--fail-on-findings", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    migrated = migrate(root) if args.migrate_safe else []
    report = audit(root)
    report["migration"] = {"safe_rewrites_applied": migrated, "count": len(migrated)}
    output = args.output if args.output.is_absolute() else root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 1 if args.fail_on_findings and report["summary"]["total_findings"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
