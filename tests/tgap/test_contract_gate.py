from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "tgap_contract_gate.py"


def run_gate(pack: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), str(pack), *extra], cwd=REPO, text=True, capture_output=True, check=False)


def build_pack(tmp_path: Path) -> Path:
    pack = tmp_path / "pack_contract"
    (pack / "runtime").mkdir(parents=True)
    (pack / "manifest.json").write_text(json.dumps({
        "schema": "tgap/v1",
        "pack_id": "pack_contract",
        "asset_class": "character",
        "version": "1.0.0",
        "state": "validation",
        "runtime": {
            "entity_id": "contract_hero",
            "frame_prefix": "char_contract_hero",
            "atlas_png": "atlases/hero.png",
            "atlas_json": "atlases/hero.json",
            "spriteframes": "runtime/hero.tres",
            "manifest": "runtime/hero.json",
        },
    }), encoding="utf-8")
    (pack / "expected-assets.json").write_text(json.dumps({
        "schema": "tgap/expected-assets/v1",
        "pack_id": "pack_contract",
        "assets": [{"path": "frames/idle.png", "quality": "final"}],
        "animations": {"idle": 1},
    }), encoding="utf-8")
    (pack / "runtime" / "hero.json").write_text(json.dumps({
        "pack_id": "pack_contract",
        "entity_id": "contract_hero",
        "atlas": "atlases/hero.png",
        "spriteframes": "runtime/hero.tres",
        "animations": {"idle": {"frame_count": 1, "fps": 12, "loop": True}},
    }), encoding="utf-8")
    return pack


def report(pack: Path) -> dict:
    return json.loads((pack / "validation" / "contract-gate-report.json").read_text(encoding="utf-8"))


def test_contract_gate_accepts_valid_documents(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    result = run_gate(pack)
    data = report(pack)
    assert result.returncode == 0, result.stdout + result.stderr
    assert data["contract_gate_passed"] is True
    assert data["promotion_blocked"] is False
    assert data["documents_checked"] == 3


def test_contract_gate_blocks_invalid_pack_id_and_version(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    path = pack / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["pack_id"] = "INVALID PACK"
    manifest["version"] = "latest"
    path.write_text(json.dumps(manifest), encoding="utf-8")
    result = run_gate(pack)
    data = report(pack)
    assert result.returncode == 1
    assert data["promotion_blocked"] is True
    assert any("pack_id" in error for error in data["errors"])
    assert any("version" in error for error in data["errors"])


def test_contract_gate_blocks_incomplete_runtime_config(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    path = pack / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest["runtime"].pop("spriteframes")
    path.write_text(json.dumps(manifest), encoding="utf-8")
    result = run_gate(pack)
    assert result.returncode == 1
    assert any("spriteframes" in error for error in report(pack)["errors"])


def test_pipeline_report_schema_rejects_contradiction(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    validation = pack / "validation"
    validation.mkdir(exist_ok=True)
    (validation / "pipeline-report.json").write_text(json.dumps({
        "tgap_version": "1.0",
        "pipeline_passed": True,
        "promotion_blocked": True,
        "steps": [{"name": "inventory", "passed": True}],
    }), encoding="utf-8")
    result = run_gate(pack, "--include-pipeline-report")
    assert result.returncode == 1
    assert any("pipeline_report" in error for error in report(pack)["errors"])
