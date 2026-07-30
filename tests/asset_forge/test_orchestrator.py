from __future__ import annotations

import importlib.util
import json
from pathlib import Path

MODULE = Path(__file__).resolve().parents[2] / "tools" / "asset_forge" / "orchestrator.py"
spec = importlib.util.spec_from_file_location("asset_forge_orchestrator", MODULE)
module = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(module)


def test_run_step_blocks_when_input_is_missing(tmp_path: Path):
    result = module.run_step("images", ["python", "missing.py"], [tmp_path / "raw.png"])
    assert result["status"] == "blocked"
    assert result["exit_code"] is None
    assert result["missing_inputs"]


def test_orchestration_config_declares_four_real_inputs():
    path = Path(__file__).resolve().parents[2] / "asset-forge" / "orchestration" / "pack_01_lian_wu_base.json"
    config = json.loads(path.read_text(encoding="utf-8"))
    assert config["schema"] == "taijifu/asset-forge-orchestration-config/v1"
    assert len(config["required_intake"]) == 4
    assert all(item.endswith(".png") for item in config["required_intake"])
