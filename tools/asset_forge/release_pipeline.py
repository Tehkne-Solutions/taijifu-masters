#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(command: list[str], allow_failure: bool = False, step: str | None = None) -> dict:
    process = subprocess.run(command, text=True, capture_output=True)
    result = {
        "step": step or Path(command[1]).stem if len(command) > 1 else command[0],
        "command": command,
        "exit_code": process.returncode,
        "stdout": process.stdout[-8000:],
        "stderr": process.stderr[-8000:],
        "ok": process.returncode == 0,
    }
    if process.returncode and not allow_failure:
        raise RuntimeError(json.dumps(result, ensure_ascii=False))
    return result


def append_step(report: dict, command: list[str], strict: bool, step: str) -> dict:
    result = run(command, allow_failure=not strict, step=step)
    report["steps"].append(result)
    return result


def append_governance_steps(report: dict, config: dict, strict: bool) -> None:
    dna = config.get("character_dna")
    if not dna:
        report["steps"].append({"step": "production_governance", "ok": False, "reason": "character_dna_not_configured"})
        return

    budget_command = [sys.executable, "tools/asset_forge/asset_budget.py", dna]
    if config.get("pack_root"):
        budget_command += ["--root", config["pack_root"]]
    if strict:
        budget_command.append("--strict")
    append_step(report, budget_command, strict, "asset_budget")

    board_command = [sys.executable, "tools/asset_forge/production_board.py", dna]
    append_step(report, board_command, False, "production_board")

    append_step(
        report,
        [sys.executable, "tools/asset_forge/character_index.py"],
        False,
        "character_index",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Taijifu Asset Forge release pipeline")
    parser.add_argument("config", type=Path)
    parser.add_argument("--source", type=Path, help="ZIP ou diretório de intake")
    parser.add_argument("--draft", type=Path, help="approval-draft.json exportado pela revisão")
    parser.add_argument("--approval", type=Path, help="aprovação já assinada")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
    report = {
        "schema": "taijifu/asset-forge-release-pipeline/v3",
        "pack_id": config["pack_id"],
        "steps": [],
        "ready": False,
        "bundle_promoted": False,
    }

    try:
        if args.source:
            intake = [sys.executable, "tools/asset_forge/intake.py", config["intake_config"], str(args.source), "--clean"]
            if args.strict:
                intake.append("--strict")
            append_step(report, intake, args.strict, "intake")

        orchestration = append_step(
            report,
            [sys.executable, "tools/asset_forge/orchestrator.py", config["orchestration_config"]],
            False,
            "orchestration",
        )

        perceptual = append_step(
            report,
            [sys.executable, "tools/asset_forge/perceptual_gate.py", config["perceptual_config"]] + (["--strict"] if args.strict else []),
            args.strict,
            "perceptual_gate",
        )

        append_step(
            report,
            [sys.executable, "tools/asset_forge/diff_matrix.py", config["diff_matrix_config"]] + (["--strict"] if args.strict else []),
            args.strict,
            "diff_matrix",
        )

        approval_path = args.approval or Path(config["approval"])
        if args.draft:
            promotion = [
                sys.executable,
                "tools/asset_forge/promote_approval.py",
                str(args.draft),
                str(approval_path),
                "--perceptual",
                config["perceptual_report"],
            ]
            append_step(report, promotion, args.strict, "promote_approval")

        approval_ok = False
        if approval_path.exists():
            gate = [sys.executable, "tools/asset_forge/approval_gate.py", "verify", str(approval_path), "--pack", config["pack_id"]]
            if args.strict:
                gate.append("--strict")
            approval_result = append_step(report, gate, args.strict, "approval_gate")
            approval_ok = approval_result["ok"]
        else:
            report["steps"].append({"step": "approval_gate", "ok": False, "reason": "approval_missing"})

        report["ready"] = orchestration["ok"] and perceptual["ok"] and approval_ok
        if report["ready"]:
            bundle = append_step(
                report,
                [sys.executable, "tools/asset_forge/forge.py", "bundle", config["pack_spec"], "--strict"],
                True,
                "bundle",
            )
            report["bundle_promoted"] = bundle["ok"]
            report["ready"] = report["ready"] and bundle["ok"]
    except RuntimeError as exc:
        report["fatal_error"] = str(exc)
        report["ready"] = False
    finally:
        append_governance_steps(report, config, args.strict)
        output = Path(config["report"])
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False))

    return 0 if report["ready"] or not args.strict else 11


if __name__ == "__main__":
    raise SystemExit(main())
