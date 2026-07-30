from __future__ import annotations

import importlib.util
import json
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[2] / "tools" / "asset_forge" / "forge.py"
spec = importlib.util.spec_from_file_location("forge", MODULE_PATH)
forge = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(forge)


def write_spec(tmp_path: Path) -> Path:
    path = tmp_path / "pack.json"
    path.write_text(json.dumps({
        "schema": "taijifu/asset-forge-spec/v1",
        "pack_id": "pack_test",
        "subject_id": "char_test",
        "output_root": "assets/tgap/pack_test",
        "assets": [
            {"path": "source/master.png", "width": 1, "height": 1, "alpha": True},
            {"path": "metadata/info.json"}
        ],
        "animations": []
    }), encoding="utf-8")
    return path


def test_expected_files_preserves_closed_inventory(tmp_path: Path):
    spec_path = write_spec(tmp_path)
    items = forge.expected_files(forge.load_json(spec_path))
    assert [item["path"] for item in items] == ["source/master.png", "metadata/info.json"]


def test_init_creates_structure_without_placeholders(tmp_path: Path):
    spec_path = write_spec(tmp_path)
    result = forge.init_pack(tmp_path, spec_path)
    root = tmp_path / result["pack_root"]
    assert (root / "manifest.json").is_file()
    assert (root / "source").is_dir()
    assert not (root / "source/master.png").exists()


def test_validate_reports_real_missing_files(tmp_path: Path):
    spec_path = write_spec(tmp_path)
    forge.init_pack(tmp_path, spec_path)
    report = forge.validate(tmp_path, spec_path)
    assert report["expected_total"] == 2
    assert report["present_total"] == 0
    assert report["missing_total"] == 2
    assert report["ready"] is False


def test_bundle_non_strict_creates_auditable_zip(tmp_path: Path):
    spec_path = write_spec(tmp_path)
    forge.init_pack(tmp_path, spec_path)
    result = forge.bundle(tmp_path, spec_path, strict=False)
    assert result["ready"] is False
    assert (tmp_path / result["zip"]).is_file()


def test_bundle_strict_blocks_incomplete_pack(tmp_path: Path):
    spec_path = write_spec(tmp_path)
    forge.init_pack(tmp_path, spec_path)
    try:
        forge.bundle(tmp_path, spec_path, strict=True)
    except RuntimeError as exc:
        assert "pack_not_ready" in str(exc)
    else:
        raise AssertionError("strict bundle must block incomplete packs")
