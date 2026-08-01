#!/usr/bin/env python3
"""Executa os gates canônicos do First Playable.

Assinatura: Tehkné Solutions
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class GateResult:
    name: str
    command: list[str]
    status: str
    returncode: int
    output: str


def run_gate(name: str, command: list[str]) -> GateResult:
    executable = shutil.which(command[0])
    if executable is None:
        return GateResult(name, command, "blocked", 127, f"Executável ausente: {command[0]}")
    process = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    return GateResult(
        name=name,
        command=command,
        status="passed" if process.returncode == 0 else "failed",
        returncode=process.returncode,
        output=process.stdout[-12000:],
    )


def art_report_gate(report_path: Path, strict: bool) -> GateResult:
    command = [
        sys.executable,
        "tools/release/validate_art_preflight_report.py",
        str(report_path),
    ]
    if strict:
        command.append("--strict")
    if report_path.exists():
        return run_gate("art_production_report", command)
    if strict:
        return GateResult(
            "art_production_report",
            command,
            "failed",
            2,
            f"Relatório artístico obrigatório ausente: {report_path}",
        )
    return GateResult(
        "art_production_report",
        command,
        "passed",
        0,
        f"Relatório artístico não fornecido no modo informativo: {report_path}",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict-assets", action="store_true", help="Exige os lotes reais e bloqueia fallbacks procedurais.")
    parser.add_argument(
        "--art-report",
        default="artifacts/first-playable-art-preflight.json",
        help="Relatório produzido pelo repositório taijifu-masters-assets.",
    )
    parser.add_argument("--report", default="artifacts/first-playable-release-gate.json")
    args = parser.parse_args()

    gates: list[tuple[str, list[str]]] = [
        ("visual_policy", ["godot", "--headless", "--path", ".", "--script", "tests/first_playable_visual_policy_contract.gd"]),
        ("arena_final", ["godot", "--headless", "--path", ".", "--script", "tests/first_playable_arena_final_contract.gd"]),
        ("hud_final", ["godot", "--headless", "--path", ".", "--script", "tests/first_playable_hud_final_contract.gd"]),
        ("combat_feedback", ["godot", "--headless", "--path", ".", "--script", "tests/first_playable_combat_feedback_contract.gd"]),
        ("real_art_handoff", ["godot", "--headless", "--path", ".", "--script", "tests/first_playable_real_art_handoff_contract.gd"]),
        ("lian_wu_lot01_presenter", ["godot", "--headless", "--path", ".", "--script", "tests/first_playable_lot01_presenter_contract.gd"]),
        ("lian_wu_lot01_importer", [sys.executable, "-m", "pytest", "-q", "tests/test_first_playable_lot01_importer.py"]),
        ("training_rival_lot01_presenter", ["godot", "--headless", "--path", ".", "--script", "tests/training_rival_lot01_presenter_contract.gd"]),
        ("training_rival_lot01_importer", [sys.executable, "-m", "pytest", "-q", "tests/test_training_rival_lot01_importer.py"]),
    ]

    visual_command = [sys.executable, "tools/asset_forge/audit_first_playable_visuals.py"]
    if args.strict_assets:
        visual_command.append("--strict")
    gates.append(("visual_assets", visual_command))

    results = [run_gate(name, command) for name, command in gates]
    art_report_path = Path(args.art_report)
    if not art_report_path.is_absolute():
        art_report_path = ROOT / art_report_path
    results.append(art_report_gate(art_report_path, args.strict_assets))

    summary = {
        "gate_id": "taijifu-first-playable-release-v3",
        "strict_assets": args.strict_assets,
        "art_report": str(art_report_path),
        "required_real_fighters": ["lian_wu", "training_rival"],
        "signature": "Tehkné Solutions",
        "passed": all(result.status == "passed" for result in results),
        "results": [asdict(result) for result in results],
    }

    report_path = ROOT / args.report
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for result in results:
        print(f"[{result.status.upper():7}] {result.name}")
        if result.status != "passed" or result.output:
            print(result.output)

    print(f"Relatório: {report_path.relative_to(ROOT)}")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
