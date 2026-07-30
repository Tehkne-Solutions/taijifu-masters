#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(command: list[str], allow_failure: bool = False) -> dict:
    process = subprocess.run(command, text=True, capture_output=True)
    result = {
        "command": command,
        "exit_code": process.returncode,
        "stdout": process.stdout[-8000:],
        "stderr": process.stderr[-8000:],
        "ok": process.returncode == 0,
    }
    if process.returncode and not allow_failure:
        raise RuntimeError(json.dumps(result, ensure_ascii=False))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Taijifu Asset Forge release pipeline")
    parser.add_argument("config", type=Path)
    parser.add_argument("--source", type=Path, help="ZIP ou diretório de intake")
    parser.add_argument("--approval", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
    report = {
        "schema": "taijifu/asset-forge-release-pipeline/v1",
        "pack_id": config["pack_id"],
        "steps": [],
        "ready": False,
    }

    if args.source:
        command = [sys.executable, "tools/asset_forge/intake.py", config["intake_config"], str(args.source), "--clean"]
        if args.strict:
            command.append("--strict")
        report["steps"].append(run(command, allow_failure=not args.strict))

    orchestration = [sys.executable, "tools/asset_forge/orchestrator.py", config["orchestration_config"]]
    report["steps"].append(run(orchestration, allow_failure=True))

    approval_ok = False
    if args.approval:
        gate = [sys.executable, "tools/asset_forge/approval_gate.py", "verify", str(args.approval), "--pack", config["pack_id"]]
        if args.strict:
            gate.append("--strict")
        gate_result = run(gate, allow_failure=not args.strict)
        report["steps"].append(gate_result)
        approval_ok = gate_result["ok"]
    else:
        report["steps"].append({"step": "approval", "ok": False, "reason": "approval_missing"})

    technical_ok = bool(report["steps"][-2].get("ok")) if args.approval else bool(report["steps"][-2].get("ok"))
    report["ready"] = technical_ok and approval_ok

    if report["ready"]:
        bundle = [sys.executable, "tools/asset_forge/forge.py", "bundle", config["pack_spec"], "--strict"]
        report["steps"].append(run(bundle))

    output = Path(config["report"])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["ready"] or not args.strict else 7


if __name__ == "__main__":
    raise SystemExit(main())
