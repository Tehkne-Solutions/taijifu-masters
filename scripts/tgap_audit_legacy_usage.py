#!/usr/bin/env python3
"""Audit legacy asset references and optionally rewrite safe call sites."""
from __future__ import annotations

import argparse
import fnmatch
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
DEFAULT_POLICY = {
    "production_globs": ["scripts/**/*.gd", "scenes/**/*.tscn", "resources/**/*.tres"],
    "allowed_globs": [
        "scripts/runtime/asset_pack_registry.gd",
        "scripts/tgap_audit_legacy_usage.py",
        "tests/**",
        "docs/**",
        ".github/**",
    ],
}


def load_policy(path: Path | None) -> dict:
    if path is None or not path.exists():
        return DEFAULT_POLICY
    parsed = json.loads(path.read_text(encoding="utf-8"))
    return {
        "production_globs": parsed.get("production_globs", DEFAULT_POLICY["production_globs"]),
        "allowed_globs": parsed.get("allowed_globs", DEFAULT_POLICY["allowed_globs"]),
    }


def matches_any(value: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(value, pattern) for pattern in patterns)


def iter_files(root: Path):
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        if any(part in SKIP_PARTS for part in path.parts):
            continue
        yield path


def classify(path: str, policy: dict) -> str:
    if matches_any(path, policy["allowed_globs"]):
        return "allowed_infrastructure"
    if matches_any(path, policy["production_globs"]):
        return "production"
    return "non_production"


def audit(root: Path, policy: dict | None = None) -> dict:
    """Audit a tree using the configured policy or the stable default policy.

    ``policy`` remains optional for backwards compatibility with tests and
    external tooling that used the original single-argument API.
    """
    effective_policy = DEFAULT_POLICY if policy is None else policy
    findings = []
    counts = Counter()
    scope_counts = Counter()
    for path in iter_files(root):
        relative = path.relative_to(root).as_posix()
        scope = classify(relative, effective_policy)
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for number, line in enumerate(lines, 1):
            for kind, pattern in PATTERNS.items():
                if not pattern.search(line):
                    continue
                counts[kind] += 1
                scope_counts[scope] += 1
                severity = "info"
                if scope == "production":
                    severity = "error" if kind in {"legacy_pack_root", "direct_tgap_path"} else "warning"
                findings.append({
                    "kind": kind,
                    "path": relative,
                    "line": number,
                    "text": line.strip()[:300],
                    "scope": scope,
                    "severity": severity,
                })
    production = [item for item in findings if item["scope"] == "production"]
    return {
        "schema": "tgap/legacy-audit/v2",
        "root": root.as_posix(),
        "policy": effective_policy,
        "summary": {
            "total_findings": len(findings),
            "production_findings": len(production),
            "files_affected": len({item["path"] for item in findings}),
            "production_files_affected": len({item["path"] for item in production}),
            "by_kind": dict(sorted(counts.items())),
            "by_scope": dict(sorted(scope_counts.items())),
        },
        "findings": findings,
    }


def migrate(root: Path, policy: dict | None = None) -> list[str]:
    """Apply supported rewrites using the configured or default policy."""
    effective_policy = DEFAULT_POLICY if policy is None else policy
    changed = []
    for path in iter_files(root):
        relative = path.relative_to(root).as_posix()
        if path.suffix.lower() != ".gd" or classify(relative, effective_policy) != "production":
            continue
        text = path.read_text(encoding="utf-8")
        updated = text
        for old, new in SAFE_REWRITES:
            updated = updated.replace(old, new)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed.append(relative)
    return changed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path, default=Path("artifacts/tgap/legacy-usage-report.json"))
    parser.add_argument("--policy", type=Path, default=Path("config/tgap-legacy-audit-policy.json"))
    parser.add_argument("--migrate-safe", action="store_true")
    parser.add_argument("--fail-on-findings", action="store_true", help="Fail only on production findings")
    args = parser.parse_args()
    root = args.root.resolve()
    policy_path = args.policy if args.policy.is_absolute() else root / args.policy
    policy = load_policy(policy_path)
    migrated = migrate(root, policy) if args.migrate_safe else []
    report = audit(root, policy)
    report["migration"] = {"safe_rewrites_applied": migrated, "count": len(migrated)}
    output = args.output if args.output.is_absolute() else root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 1 if args.fail_on_findings and report["summary"]["production_findings"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
