#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCHEMA = "taijifu/asset-forge-approval/v1"
REQUIRED_CHECKS = (
    "identity_consistent",
    "background_clean",
    "no_cropped_content",
    "turnaround_consistent",
    "portraits_consistent",
    "icons_legible",
    "technical_quality_approved",
)


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_payload(data: dict[str, Any]) -> bytes:
    signed = {k: v for k, v in data.items() if k not in {"signature", "verified"}}
    return json.dumps(signed, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def digest(data: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_payload(data)).hexdigest()


def create_approval(pack_id: str, reviewer: str, checks: dict[str, bool], notes: str = "") -> dict[str, Any]:
    result = {
        "schema": SCHEMA,
        "pack_id": pack_id,
        "reviewer": reviewer.strip(),
        "reviewed_at": datetime.now(timezone.utc).isoformat(),
        "decision": "approved" if all(checks.get(k) is True for k in REQUIRED_CHECKS) else "rejected",
        "checks": {k: bool(checks.get(k, False)) for k in REQUIRED_CHECKS},
        "notes": notes,
    }
    result["signature"] = digest(result)
    return result


def verify(path: Path, pack_id: str | None = None) -> dict[str, Any]:
    data = load(path)
    errors: list[str] = []
    if data.get("schema") != SCHEMA:
        errors.append("invalid_schema")
    if pack_id and data.get("pack_id") != pack_id:
        errors.append("pack_mismatch")
    if not str(data.get("reviewer", "")).strip():
        errors.append("missing_reviewer")
    if data.get("decision") != "approved":
        errors.append("not_approved")
    checks = data.get("checks", {})
    for name in REQUIRED_CHECKS:
        if checks.get(name) is not True:
            errors.append(f"check_failed:{name}")
    if data.get("signature") != digest(data):
        errors.append("invalid_signature")
    return {"verified": not errors, "errors": errors, "approval": data}


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    make = sub.add_parser("create")
    make.add_argument("output", type=Path)
    make.add_argument("--pack", required=True)
    make.add_argument("--reviewer", required=True)
    make.add_argument("--notes", default="")
    make.add_argument("--approve-all", action="store_true")
    check = sub.add_parser("verify")
    check.add_argument("approval", type=Path)
    check.add_argument("--pack")
    check.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    if args.command == "create":
        checks = {name: args.approve_all for name in REQUIRED_CHECKS}
        data = create_approval(args.pack, args.reviewer, checks, args.notes)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(data, ensure_ascii=False))
        return 0

    result = verify(args.approval, args.pack)
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["verified"] or not args.strict else 6


if __name__ == "__main__":
    raise SystemExit(main())
