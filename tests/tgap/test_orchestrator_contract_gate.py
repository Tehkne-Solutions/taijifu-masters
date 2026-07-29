from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RUNNER = REPO / "scripts" / "tgap_run_pack.py"


def run(pack: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(RUNNER), str(pack)],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )


def test_orchestrator_stops_after_invalid_contract(tmp_path: Path) -> None:
    pack = tmp_path / "pack_invalid_contract"
    pack.mkdir()
    (pack / "manifest.json").write_text(
        json.dumps({
            "schema": "tgap/v1",
            "pack_id": "INVALID PACK ID",
            "asset_class": "character",
            "version": "latest",
            "state": "approved",
        }),
        encoding="utf-8",
    )
    (pack / "expected-assets.json").write_text(
        json.dumps({
            "schema": "tgap/expected-assets/v1",
            "pack_id": "pack_invalid_contract",
            "assets": [{"path": "frames/idle/missing.png", "quality": "final"}],
        }),
        encoding="utf-8",
    )

    result = run(pack)
    report = json.loads((pack / "validation/pipeline-report.json").read_text(encoding="utf-8"))

    assert result.returncode == 1
    assert report["pipeline_passed"] is False
    assert report["promotion_blocked"] is True
    assert report["steps"][0]["name"] == "contract_gate"
    assert report["steps"][0]["passed"] is False

    skipped = {step["name"]: step for step in report["steps"][1:]}
    for name in ("inventory", "visual_gate", "animation_gate", "runtime_gate", "pipeline_contract_gate"):
        assert skipped[name]["skipped"] is True
        assert skipped[name]["skip_reason"] == "contract_gate_failed"

    assert not (pack / "validation/inventory-report.json").exists()
    assert not (pack / "validation/visual-gate-report.json").exists()
    assert not (pack / "validation/animation-gate-report.json").exists()
    assert not (pack / "validation/runtime-gate-report.json").exists()
