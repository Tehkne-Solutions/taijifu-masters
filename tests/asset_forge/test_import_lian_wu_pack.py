from pathlib import Path


def test_importer_declares_required_pack_sources() -> None:
    source = Path("tools/asset_forge/import_lian_wu_pack.py").read_text(encoding="utf-8")
    for required in (
        "source/char_lian_wu__master_raw.png",
        "source/turnaround_raw.png",
        "source/portraits_raw.png",
        "source/icons_raw.png",
        "manifest.json",
    ):
        assert required in source


def test_importer_preserves_release_gates() -> None:
    source = Path("tools/asset_forge/import_lian_wu_pack.py").read_text(encoding="utf-8")
    assert "tools/asset_forge/release_pipeline.py" in source
    assert "asset-forge/releases/pack_01_lian_wu_base.json" in source
    assert "--strict" in source


def test_importer_validates_pack_identity_and_checksums() -> None:
    source = Path("tools/asset_forge/import_lian_wu_pack.py").read_text(encoding="utf-8")
    assert 'manifest.get("pack_id") != "pack_01_lian_wu_base"' in source
    assert "sha256(path) == item.get(\"sha256\")" in source
