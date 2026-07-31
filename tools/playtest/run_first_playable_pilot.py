#!/usr/bin/env python3
"""Canonical hardened CLI for the Taijifu Masters First Playable pilot.

The sibling `first_playable_pilot.py` contains the deterministic domain core.
This entrypoint adds operational privacy and cross-file integrity checks and is
the only CLI that should be used with real pilot data.

Signature: Tehkné Solutions
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import first_playable_pilot as core


def sanitize_intake_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    """Remove local filesystem paths while preserving hashes and source names."""
    sanitized = json.loads(json.dumps(manifest, ensure_ascii=False))
    for collection in ("accepted", "rejected"):
        for entry in sanitized.get(collection, []):
            if not isinstance(entry, dict):
                continue
            entry.pop("source_path", None)
            entry["source_reference"] = str(entry.get("source_name", ""))
    sanitized["privacy"] = "source_files_unchanged_paths_removed_manifest_only"
    return sanitized


def validate_context(
    plan: dict[str, Any],
    intake: dict[str, Any] | None = None,
    observations: dict[str, Any] | None = None,
    decisions: dict[str, Any] | None = None,
) -> None:
    pilot_id = str(plan.get("pilot_id", ""))
    build_version = str(plan.get("build_version", ""))
    if not pilot_id or not build_version:
        raise ValueError("Plano sem pilot_id ou build_version")
    for label, payload in (
        ("intake", intake),
        ("observações", observations),
        ("decisões", decisions),
    ):
        if payload is None:
            continue
        payload_pilot = str(payload.get("pilot_id", ""))
        payload_build = str(payload.get("build_version", ""))
        if payload_pilot and payload_pilot != pilot_id:
            raise ValueError(
                f"{label}: pilot_id {payload_pilot!r} não corresponde a {pilot_id!r}"
            )
        if payload_build and payload_build != build_version:
            raise ValueError(
                f"{label}: build_version {payload_build!r} não corresponde a {build_version!r}"
            )


def harden_backlog_gate(backlog: dict[str, Any]) -> dict[str, Any]:
    """Add integrity checks omitted from the deterministic core gate."""
    hardened = json.loads(json.dumps(backlog, ensure_ascii=False))
    items = [item for item in hardened.get("items", []) if isinstance(item, dict)]
    open_counts = {
        priority: sum(
            1
            for item in items
            if item.get("priority") == priority and not bool(item.get("resolved", False))
        )
        for priority in core.PRIORITY_ORDER
    }
    hardened["open_counts"] = open_counts

    checks = hardened.setdefault("completion_gate", {}).setdefault("checks", {})
    rejected_count = len(hardened.get("rejected_observations", []))
    decision_warning_count = len(hardened.get("decision_warnings", []))
    unknown_decision_count = len(hardened.get("unknown_decision_ids", []))
    checks["rejected_observations"] = {
        "required": 0,
        "actual": rejected_count,
        "passed": rejected_count == 0,
    }
    checks["decision_warnings"] = {
        "required": 0,
        "actual": decision_warning_count,
        "passed": decision_warning_count == 0,
    }
    checks["unknown_decision_ids"] = {
        "required": 0,
        "actual": unknown_decision_count,
        "passed": unknown_decision_count == 0,
    }
    if "open_p0_allowed" in checks:
        checks["open_p0_allowed"]["actual"] = open_counts["P0"]
        checks["open_p0_allowed"]["passed"] = (
            open_counts["P0"] <= int(checks["open_p0_allowed"].get("required", 0))
        )
    hardened["completion_gate"]["passed"] = all(
        bool(check.get("passed", False)) for check in checks.values()
    )
    hardened["completion_gate"]["note"] = (
        "Gate endurecido: sem P0 aberto, sem observação rejeitada e sem decisão inválida."
    )
    return hardened


def command_plan(argv: list[str]) -> int:
    return core.main(["plan", *argv])


def command_intake(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="run_first_playable_pilot.py intake")
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("pilot-control/intake"))
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args(argv)

    plan = core.load_plan(args.plan)
    manifest = sanitize_intake_manifest(core.build_intake_manifest(args.inputs, plan))
    validate_context(plan, intake=manifest)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.output_dir / "pilot-intake-manifest.json"
    markdown_path = args.output_dir / "pilot-intake-report.md"
    core.write_json(json_path, manifest)
    markdown_path.write_text(core.render_intake_markdown(manifest), encoding="utf-8")
    print(
        json.dumps(
            {
                "accepted": manifest["inputs"]["accepted_files"],
                "rejected": manifest["inputs"]["rejected_files"],
                "manifest": str(json_path),
                "local_paths_removed": True,
            },
            indent=2,
            ensure_ascii=False,
        )
    )
    return 1 if args.strict and manifest["inputs"]["rejected_files"] > 0 else 0


def command_triage(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="run_first_playable_pilot.py triage")
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--observations", type=Path, required=True)
    parser.add_argument("--intake", type=Path, required=True)
    parser.add_argument("--decisions", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("pilot-control/triage"))
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--fail-on-p0", action="store_true")
    args = parser.parse_args(argv)

    plan = core.load_plan(args.plan)
    summary = core.read_json(args.summary)
    observations = core.read_json(args.observations)
    intake = core.read_json(args.intake)
    decisions = core.read_json(args.decisions)
    validate_context(plan, intake=intake, observations=observations, decisions=decisions)
    backlog = harden_backlog_gate(
        core.build_backlog(summary, observations, plan, intake, decisions)
    )
    args.output_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.output_dir / "pilot-backlog.json"
    markdown_path = args.output_dir / "pilot-backlog.md"
    core.write_json(json_path, backlog)
    markdown_path.write_text(core.render_backlog_markdown(backlog), encoding="utf-8")
    print(
        json.dumps(
            {
                "counts": backlog["counts"],
                "open_counts": backlog["open_counts"],
                "gate_passed": backlog["completion_gate"]["passed"],
                "backlog": str(json_path),
            },
            indent=2,
            ensure_ascii=False,
        )
    )
    if args.fail_on_p0 and backlog["open_counts"]["P0"] > 0:
        return 2
    if args.strict and not backlog["completion_gate"]["passed"]:
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    if not arguments or arguments[0] not in {"plan", "intake", "triage"}:
        print(
            "Uso: run_first_playable_pilot.py {plan|intake|triage} ...",
            file=sys.stderr,
        )
        return 2
    command, remaining = arguments[0], arguments[1:]
    try:
        if command == "plan":
            return command_plan(remaining)
        if command == "intake":
            return command_intake(remaining)
        return command_triage(remaining)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        print(f"ERRO: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
