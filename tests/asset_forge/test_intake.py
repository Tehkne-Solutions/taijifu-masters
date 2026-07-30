from __future__ import annotations

import importlib.util
import json
import zipfile
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[2] / "tools" / "asset_forge" / "intake.py"
spec = importlib.util.spec_from_file_location("intake", MODULE_PATH)
intake = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(intake)


def write_config(root: Path) -> Path:
    p = root / "config.json"
    p.write_text(json.dumps({
        "pack_id": "pack_test",
        "staging_root": "artifacts/staging",
        "intake_root": "asset-forge/intake/pack_test",
        "review_root": "artifacts/review/pack_test",
        "report": "artifacts/intake.json",
        "max_files": 8,
        "max_bytes": 100000,
        "allowed_extensions": [".png"],
        "expected": ["a.png", "b.png"]
    }), encoding="utf-8")
    return p


def test_directory_intake_accepts_closed_inventory(tmp_path: Path):
    cfg = write_config(tmp_path)
    source = tmp_path / "source"
    source.mkdir()
    (source / "a.png").write_bytes(b"a")
    (source / "b.png").write_bytes(b"b")
    report = intake.run(tmp_path, cfg, source)
    assert report["ready_for_processing"] is True
    assert len(report["accepted"]) == 2
    assert (tmp_path / "artifacts/review/pack_test/CHECKLIST.md").is_file()


def test_missing_file_blocks_intake(tmp_path: Path):
    cfg = write_config(tmp_path)
    source = tmp_path / "source"
    source.mkdir()
    (source / "a.png").write_bytes(b"a")
    report = intake.run(tmp_path, cfg, source)
    assert report["ready_for_processing"] is False
    assert report["missing"] == ["b.png"]


def test_zip_slip_is_rejected(tmp_path: Path):
    cfg = write_config(tmp_path)
    archive = tmp_path / "bad.zip"
    with zipfile.ZipFile(archive, "w") as zf:
        zf.writestr("../a.png", b"x")
    try:
        intake.run(tmp_path, cfg, archive)
    except ValueError as exc:
        assert "unsafe_path" in str(exc)
    else:
        raise AssertionError("zip slip must be rejected")


def test_extras_are_reported_but_not_promoted(tmp_path: Path):
    cfg = write_config(tmp_path)
    source = tmp_path / "source"
    source.mkdir()
    (source / "a.png").write_bytes(b"a")
    (source / "b.png").write_bytes(b"b")
    (source / "extra.jpg").write_bytes(b"x")
    report = intake.run(tmp_path, cfg, source)
    assert report["ready_for_processing"] is True
    assert report["extras"] == ["extra.jpg"]
    assert not (tmp_path / "asset-forge/intake/pack_test/extra.jpg").exists()
