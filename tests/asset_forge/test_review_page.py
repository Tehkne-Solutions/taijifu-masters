from __future__ import annotations

import importlib.util
import json
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[2] / "tools" / "asset_forge" / "review_page.py"
spec = importlib.util.spec_from_file_location("review_page", MODULE_PATH)
review_page = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(review_page)


def write_config(tmp_path: Path) -> Path:
    path = tmp_path / "review.json"
    path.write_text(json.dumps({
        "pack_id": "pack_test",
        "output_dir": "artifacts/review/pack_test",
        "assets": [{"path": "assets/master.png", "label": "Master", "group": "master"}],
        "checklist": {"identity": "Identidade consistente"}
    }), encoding="utf-8")
    return path


def test_missing_asset_blocks_review(tmp_path: Path):
    result = review_page.build(tmp_path, write_config(tmp_path))
    assert result["ready_for_review"] is False
    assert result["missing"] == ["assets/master.png"]
    assert (tmp_path / "artifacts/review/pack_test/index.html").is_file()


def test_existing_asset_is_hashed_and_rendered(tmp_path: Path):
    asset = tmp_path / "assets/master.png"
    asset.parent.mkdir(parents=True)
    asset.write_bytes(b"physical-image-evidence")
    result = review_page.build(tmp_path, write_config(tmp_path))
    assert result["ready_for_review"] is True
    assert len(result["assets"][0]["sha256"]) == 64
    html = (tmp_path / "artifacts/review/pack_test/index.html").read_text(encoding="utf-8")
    assert "approval-draft.json" in html
    assert "Alternar fundo" in html
