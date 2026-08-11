#!/usr/bin/env python3
"""Orquestra o pipeline completo do Taijifu Asset Forge.

Etapas: init -> image processing -> validation -> Godot -> bundle.
Não cria placeholders e preserva relatórios mesmo quando o pack está bloqueado.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def display_path(path: Path) -> str:
    """Render repository paths relatively while preserving valid external test paths."""
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(ROOT.resolve()))
    except ValueError:
        return str(resolved)


def run_step(name: str, command: list[str], required_inputs: list[Path] | None = None) -> dict[str, Any]:
    missing_inputs = [display_path(path) for path in (required_inputs or []) if not path.is_file()]
    if missing_inputs:
        return {
            "name": name,
            "status": "blocked",
            "exit_code": None,
            "missing_inputs": missing_inputs,
            "command": command,
        }
    process = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    return {
        "name": name,
        "status": "passed" if process.returncode == 0 else "failed",
        "exit_code": process.returncode,
        "command": command,
        "stdout": process.stdout[-12000:],
        "stderr": process.stderr[-12000:],
    }


def orchestrate(config_path: Path, strict: bool = False) -> dict[str, Any]:
    config = load_json(config_path)
    python = sys.executable
    spec = config["pack_spec"]
    recipe = config["image_recipe"]
    godot_recipe = config["godot_recipe"]
    intake = [ROOT / item for item in config.get("required_intake", [])]

    steps: list[dict[str, Any]] = []
    steps.append(run_step("init", [python, "tools/asset_forge/forge.py", "init", spec]))
    steps.append(run_step("images", [python, "tools/asset_forge/image_ops.py", recipe], intake))
    steps.append(run_step("validate", [python, "tools/asset_forge/forge.py", "validate", spec]))
    steps.append(run_step("godot", [python, "tools/asset_forge/godot_ops.py", godot_recipe]))
    bundle_cmd = [python, "tools/asset_forge/forge.py", "bundle", spec]
    if strict:
        bundle_cmd.append("--strict")
    steps.append(run_step("bundle", bundle_cmd))

    blocking = [step for step in steps if step["status"] != "passed"]
    report = {
        "schema": "taijifu/asset-forge-orchestration/v1",
        "pack_id": config["pack_id"],
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "strict": strict,
        "ready": not blocking,
        "steps": steps,
        "summary": {
            "total": len(steps),
            "passed": sum(step["status"] == "passed" for step in steps),
            "blocked": sum(step["status"] == "blocked" for step in steps),
            "failed": sum(step["status"] == "failed" for step in steps),
        },
    }
    output = ROOT / config["report"]
    dump_json(output, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    config_path = args.config if args.config.is_absolute() else ROOT / args.config
    report = orchestrate(config_path, strict=args.strict)
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 0 if report["ready"] or not args.strict else 5


if __name__ == "__main__":
    raise SystemExit(main())
