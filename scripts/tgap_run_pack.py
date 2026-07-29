#!/usr/bin/env python3
"""Executa o pipeline TGAP de um pack e produz relatório consolidado."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def run_step(name: str, command: list[str], cwd: Path) -> dict[str, Any]:
    started = datetime.now(timezone.utc)
    process = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
    finished = datetime.now(timezone.utc)
    return {
        "name": name,
        "command": command,
        "exit_code": process.returncode,
        "passed": process.returncode == 0,
        "skipped": False,
        "stdout": process.stdout.strip(),
        "stderr": process.stderr.strip(),
        "started_at": started.isoformat(),
        "finished_at": finished.isoformat(),
        "duration_seconds": round((finished - started).total_seconds(), 3),
    }


def skipped_step(name: str, reason: str) -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    return {
        "name": name,
        "command": [],
        "exit_code": None,
        "passed": False,
        "skipped": True,
        "skip_reason": reason,
        "stdout": "",
        "stderr": "",
        "started_at": now,
        "finished_at": now,
        "duration_seconds": 0.0,
    }


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def write_pipeline_report(pack: Path, steps: list[dict[str, Any]], reports: dict[str, Any]) -> dict[str, Any]:
    validation = pack / "validation"
    passed = all(step["passed"] for step in steps)
    consolidated = {
        "tgap_version": "1.0",
        "pack_root": str(pack),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "pipeline_passed": passed,
        "promotion_blocked": not passed,
        "steps": steps,
        "reports": reports,
    }

    json_path = validation / "pipeline-report.json"
    md_path = validation / "pipeline-report.md"
    json_path.write_text(json.dumps(consolidated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Relatório Consolidado TGAP",
        "",
        f"- Pack: `{pack.name}`",
        f"- Pipeline aprovado: **{'sim' if passed else 'não'}**",
        f"- Promoção bloqueada: **{'não' if passed else 'sim'}**",
        "",
        "## Etapas",
        "",
    ]
    for step in steps:
        if step.get("skipped"):
            lines.append(f"- **{step['name']}**: SKIP — {step.get('skip_reason', 'etapa não executada')}")
        else:
            lines.append(
                f"- **{step['name']}**: {'PASS' if step['passed'] else 'FAIL'} "
                f"(exit {step['exit_code']}, {step['duration_seconds']}s)"
            )
    failed = [step for step in steps if not step["passed"] and not step.get("skipped")]
    if failed:
        lines.extend(["", "## Falhas", ""])
        for step in failed:
            detail = step["stderr"] or step["stdout"] or "sem diagnóstico textual"
            lines.append(f"### {step['name']}\n\n```text\n{detail}\n```")
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return consolidated


def main() -> int:
    parser = argparse.ArgumentParser(description="Executa gates TGAP e consolida o status do pack.")
    parser.add_argument("pack_root", type=Path)
    parser.add_argument("--migrate", action="store_true", help="Executa migrador específico antes dos gates.")
    parser.add_argument("--migration-script", type=Path, default=Path("scripts/tgap_migrate_lian_wu.py"))
    parser.add_argument("--python", default=sys.executable)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    pack = args.pack_root if args.pack_root.is_absolute() else repo / args.pack_root
    pack = pack.resolve()
    validation = pack / "validation"
    validation.mkdir(parents=True, exist_ok=True)

    steps: list[dict[str, Any]] = []
    if args.migrate:
        migration = args.migration_script if args.migration_script.is_absolute() else repo / args.migration_script
        steps.append(run_step("migration", [args.python, str(migration)], repo))

    contract_command = [args.python, str(repo / "scripts/tgap_contract_gate.py"), str(pack)]
    contract = run_step("contract_gate", contract_command, repo)
    steps.append(contract)

    technical_steps = [
        ("inventory", [args.python, str(repo / "scripts/tgap_inventory_report.py"), str(pack), "--write-status"]),
        ("visual_gate", [args.python, str(repo / "scripts/tgap_visual_gate.py"), str(pack)]),
        ("animation_gate", [args.python, str(repo / "scripts/tgap_animation_gate.py"), str(pack)]),
        ("runtime_gate", [args.python, str(repo / "scripts/tgap_runtime_gate.py"), str(pack)]),
    ]
    if contract["passed"]:
        steps.extend(run_step(name, command, repo) for name, command in technical_steps)
    else:
        steps.extend(skipped_step(name, "contract_gate_failed") for name, _ in technical_steps)

    reports = {
        "contract": read_json(validation / "contract-gate-report.json"),
        "inventory": read_json(validation / "inventory-report.json"),
        "visual": read_json(validation / "visual-gate-report.json"),
        "animation": read_json(validation / "animation-gate-report.json"),
        "runtime": read_json(validation / "runtime-gate-report.json"),
    }

    write_pipeline_report(pack, steps, reports)

    if contract["passed"]:
        pipeline_contract = run_step(
            "pipeline_contract_gate",
            contract_command + ["--include-pipeline-report"],
            repo,
        )
        steps.append(pipeline_contract)
        reports["contract"] = read_json(validation / "contract-gate-report.json")
    else:
        steps.append(skipped_step("pipeline_contract_gate", "contract_gate_failed"))

    consolidated = write_pipeline_report(pack, steps, reports)
    passed = consolidated["pipeline_passed"]
    print(json.dumps({
        "pipeline_passed": passed,
        "promotion_blocked": not passed,
        "report": str(validation / "pipeline-report.json"),
    }, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
