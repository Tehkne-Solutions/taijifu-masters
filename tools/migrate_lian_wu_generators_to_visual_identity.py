#!/usr/bin/env python3
"""Migrate Lian Wu generators from encoded-PNG SHA locks to canonical RGBA identity.

This migration is deliberately mechanical: it replaces only the source identity
preflight in the ten known generators. Animation construction, frame counts,
FPS, bounds, baseline rules, naming and review gates remain untouched.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

OLD_BINARY_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
IMPORT_LINE = "from lian_wu_canonical_identity import validate_source"
SIGNATURE = "Tehkné Solutions"

TARGETS = (
    "tools/generate_lian_wu_body_hook6.py",
    "tools/generate_lian_wu_fall3.py",
    "tools/generate_lian_wu_idle6.py",
    "tools/generate_lian_wu_ji_sweep6.py",
    "tools/generate_lian_wu_jump_loop3.py",
    "tools/generate_lian_wu_jump_start4.py",
    "tools/generate_lian_wu_land4.py",
    "tools/generate_lian_wu_riposte6.py",
    "tools/generate_lian_wu_run8.py",
    "tools/generate_lian_wu_walk8.py",
)

HASH_CONSTANT_RE = re.compile(
    r'^EXPECTED_SOURCE_SHA256\s*=\s*["\']'
    + re.escape(OLD_BINARY_SHA256)
    + r'["\']\s*\n',
    re.MULTILINE,
)

# The historical scripts have two equivalent naming shapes:
# locomotion: actual_source_sha = sha256(source); image = Image.open(source)...
# combat:     source_sha = sha256(source_path); source = Image.open(source_path)...
# Capture those variable names rather than changing animation-specific code.
LEGACY_PREFLIGHT_RE = re.compile(
    r'(?P<indent>^[ \t]*)'
    r'(?P<hashvar>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*sha256\('
    r'(?P<pathvar>[A-Za-z_][A-Za-z0-9_]*)\)\s*\n'
    r'(?P<body>.*?)'
    r'(?P=indent)(?P<imgvar>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*Image\.open\('
    r'(?P=pathvar)\)\.convert\(["\']RGBA["\']\)',
    re.MULTILINE | re.DOTALL,
)
# Stage names are stable; the human-readable reason varied historically
# (source_hash_mismatch vs source_hash=<sha>). The candidate itself is already
# constrained to the EXPECTED_SOURCE_SHA256 comparison, so capture only the
# stage prefix here rather than depending on wording after BLOCKED.
MARKER_RE = re.compile(r'([A-Z][A-Z0-9_]+)=BLOCKED\b')


def _inject_import(text: str, path: Path) -> str:
    if IMPORT_LINE in text:
        return text
    guarded = re.search(r'^try:\s*\n[ \t]+from PIL\b', text, re.MULTILINE)
    if guarded is not None:
        return text[: guarded.start()] + IMPORT_LINE + "\n\n" + text[guarded.start() :]
    direct = re.search(r'^from PIL\b', text, re.MULTILINE)
    if direct is not None:
        return text[: direct.start()] + IMPORT_LINE + "\n" + text[direct.start() :]
    raise ValueError(f"{path}: Pillow import anchor not found")


def _replace_preflight(text: str, path: Path) -> tuple[str, str, str]:
    matches = list(LEGACY_PREFLIGHT_RE.finditer(text))
    candidates = []
    for match in matches:
        if "EXPECTED_SOURCE_SHA256" in match.group("body"):
            candidates.append(match)
    if len(candidates) != 1:
        raise ValueError(
            f"{path}: expected one legacy hash preflight, found {len(candidates)} "
            f"among {len(matches)} sha256-to-RGBA candidates"
        )
    match = candidates[0]
    body = match.group("body")
    marker_match = MARKER_RE.search(body)
    if marker_match is None:
        raise ValueError(f"{path}: legacy BLOCKED marker not found in hash preflight")
    marker = marker_match.group(1)
    indent = match.group("indent")
    hashvar = match.group("hashvar")
    pathvar = match.group("pathvar")
    imgvar = match.group("imgvar")
    replacement = (
        f"{indent}try:\n"
        f"{indent}    canonical_identity = validate_source({pathvar})\n"
        f"{indent}except (OSError, ValueError) as exc:\n"
        f"{indent}    print(f\"{marker}=BLOCKED canonical_visual_identity={{exc}}\"); return 3\n"
        f"{indent}{hashvar} = str(canonical_identity[\"file_sha256\"])\n"
        f"{indent}{imgvar} = Image.open({pathvar}).convert(\"RGBA\")"
    )
    return text[: match.start()] + replacement + text[match.end() :], marker, pathvar


def migrate_one(path: Path, apply: bool) -> dict:
    if not path.is_file():
        raise ValueError(f"target_missing={path}")
    original = path.read_text(encoding="utf-8")

    # Already migrated is valid and makes the tool idempotent.
    if OLD_BINARY_SHA256 not in original:
        if IMPORT_LINE not in original or "canonical_identity = validate_source(" not in original:
            raise ValueError(f"{path}: old binary lock absent but canonical validator wiring is incomplete")
        return {
            "path": path.as_posix(),
            "state": "already_migrated",
            "changed": False,
        }

    migrated = _inject_import(original, path)
    migrated, marker, source_variable = _replace_preflight(migrated, path)
    migrated, removed = HASH_CONSTANT_RE.subn("", migrated, count=1)
    if removed != 1:
        raise ValueError(f"{path}: expected one historical hash constant, removed {removed}")
    if OLD_BINARY_SHA256 in migrated:
        raise ValueError(f"{path}: historical binary SHA remains after migration")

    # Guard against broad accidental rewrites: one import + one preflight + one
    # constant are the only intended semantic edits.
    if migrated.count(IMPORT_LINE) != 1:
        raise ValueError(f"{path}: canonical validator import count is not one")
    if migrated.count("canonical_identity = validate_source(") != 1:
        raise ValueError(f"{path}: canonical validator call count is not one")

    if apply:
        path.write_text(migrated, encoding="utf-8")
    return {
        "path": path.as_posix(),
        "state": "migrated" if apply else "migration_required",
        "changed": True,
        "block_marker": marker,
        "source_variable": source_variable,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    root = args.repo_root.resolve()
    records = []
    try:
        for relative in TARGETS:
            records.append(migrate_one(root / relative, args.apply))
    except (OSError, ValueError) as exc:
        print(f"C63_3_GENERATOR_MIGRATION=BLOCKED {exc}", file=sys.stderr)
        return 2

    changed = sum(1 for item in records if item["changed"])
    already = sum(1 for item in records if item["state"] == "already_migrated")
    report = {
        "schema": "tehkne/c63-3-lian-generator-identity-migration/v1",
        "signature": SIGNATURE,
        "apply": args.apply,
        "target_count": len(TARGETS),
        "changed_count": changed,
        "already_migrated_count": already,
        "historical_binary_sha256": OLD_BINARY_SHA256,
        "canonical_identity_validator": "tools/lian_wu_canonical_identity.py",
        "animation_semantics_changed": False,
        "records": records,
    }
    if args.report:
        report_path = args.report if args.report.is_absolute() else root / args.report
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    mode = "APPLIED" if args.apply else "PLANNED"
    print(
        f"C63_3_GENERATOR_MIGRATION={mode} targets={len(TARGETS)} "
        f"changed={changed} already={already}"
    )
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
