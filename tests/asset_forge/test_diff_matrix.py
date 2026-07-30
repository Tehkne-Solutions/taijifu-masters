from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image


def test_diff_matrix_generates_artifact(tmp_path: Path) -> None:
    left = tmp_path / "left.png"
    right = tmp_path / "right.png"
    Image.new("RGBA", (32, 32), (255, 0, 0, 255)).save(left)
    Image.new("RGBA", (32, 32), (0, 0, 255, 255)).save(right)
    config = tmp_path / "config.json"
    output = tmp_path / "matrix.png"
    report = tmp_path / "report.json"
    config.write_text(json.dumps({
        "pack_id": "test_pack",
        "cell_size": [64, 64],
        "comparisons": [{"id": "a_vs_b", "left": str(left), "right": str(right)}],
        "output": str(output),
        "report": str(report),
    }), encoding="utf-8")

    result = subprocess.run([sys.executable, "tools/asset_forge/diff_matrix.py", str(config), "--strict"])
    assert result.returncode == 0
    assert output.exists()
    assert json.loads(report.read_text(encoding="utf-8"))["ready"] is True


def test_diff_matrix_strict_blocks_missing_asset(tmp_path: Path) -> None:
    config = tmp_path / "config.json"
    config.write_text(json.dumps({
        "pack_id": "test_pack",
        "comparisons": [{"id": "missing", "left": str(tmp_path / "a.png"), "right": str(tmp_path / "b.png")}],
        "output": str(tmp_path / "matrix.png"),
        "report": str(tmp_path / "report.json"),
    }), encoding="utf-8")
    result = subprocess.run([sys.executable, "tools/asset_forge/diff_matrix.py", str(config), "--strict"])
    assert result.returncode == 12
