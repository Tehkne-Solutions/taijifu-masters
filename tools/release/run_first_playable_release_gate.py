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
DEFAULT_GATE_TIMEOUT_SECONDS = 120
SCRIPT_FAILURE_MARKERS = (
    "SCRIPT ERROR:",
    "Parse Error",
    "Assertion failed",
    "Failed to load script",
)


@dataclass
class GateResult:
    name: str
    command: list[str]
    status: str
    returncode: int
    output: str


def run_gate(
    name: str,
    command: list[str],
    timeout_seconds: int = DEFAULT_GATE_TIMEOUT_SECONDS,
) -> GateResult:
    executable = shutil.which(command[0])
    if executable is None:
        return GateResult(name, command, "blocked", 127, f"Executável ausente: {command[0]}")
    try:
        process = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return GateResult(
            name=name,
            command=command,
            status="failed",
            returncode=124,
            output=(
                f"Subgate excedeu {timeout_seconds}s e foi encerrado: {name}\n"
                f"{output[-12000:]}"
            ),
        )

    output = process.stdout or ""
    script_failure = any(marker in output for marker in SCRIPT_FAILURE_MARKERS)
    returncode = process.returncode if process.returncode != 0 else (2 if script_failure else 0)
    return GateResult(
        name=name,
        command=command,
        status="passed" if returncode == 0 else "failed",
        returncode=returncode,
        output=output[-12000:],
    )


def godot_contract(path: str) -> list[str]:
    # Contract scripts execute assertions from SceneTree._init(). If an assert
    # aborts before their explicit quit(), --quit-after prevents a zombie
    # headless process while run_gate still marks SCRIPT ERROR/Assertion failed.
    return [
        "godot",
        "--headless",
        "--path",
        ".",
        "--quit-after",
        "5",
        "--script",
        path,
    ]


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
        ("visual_policy", godot_contract("tests/first_playable_visual_policy_contract.gd")),
        ("arena_final", godot_contract("tests/first_playable_arena_final_contract.gd")),
        ("hud_final", godot_contract("tests/first_playable_hud_final_contract.gd")),
        ("combat_feedback", godot_contract("tests/first_playable_combat_feedback_contract.gd")),
        ("real_art_handoff", godot_contract("tests/first_playable_real_art_handoff_contract.gd")),
        ("lian_wu_lot01_presenter", godot_contract("tests/first_playable_lot01_presenter_contract.gd")),
        ("lian_wu_lot01_importer", [sys.executable, "-m", "pytest", "-q", "tests/test_first_playable_lot01_importer.py"]),
        ("training_rival_lot01_presenter", godot_contract("tests/training_rival_lot01_presenter_contract.gd")),
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
        "subgate_timeout_seconds": DEFAULT_GATE_TIMEOUT_SECONDS,
        "script_failure_markers": list(SCRIPT_FAILURE_MARKERS),
        "godot_contract_quit_after_frames": 5,
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
