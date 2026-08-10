from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def test_smoke_harness_uses_tgap_exclusively():
    text = (ROOT / "tests/tgap/runtime_smoke_test.gd").read_text(encoding="utf-8")
    assert 'get_node_or_null("TgapAssetLoader")' in text
    assert 'get_node_or_null("AssetPackRegistry") == null' in text
    assert "load_catalog(true)" in text
    assert "load_resource(PACK_ID, RESOURCE_PATH, VERSION)" in text
    assert "ResourceLoader.exists(scene_path)" in text
    assert "packed.instantiate()" in text


def test_main_scene_is_covered():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    smoke = (ROOT / "tests/tgap/runtime_smoke_test.gd").read_text(encoding="utf-8")
    assert 'run/main_scene="res://scenes/vertical_slice/first_playable_menu.tscn"' in project
    assert '"res://scenes/vertical_slice/first_playable_menu.tscn"' in smoke


def test_legacy_autoload_remains_absent():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'TgapAssetLoader="*res://scripts/runtime/tgap_asset_loader.gd"' in project
    assert 'AssetPackRegistry="*res://scripts/runtime/asset_pack_registry.gd"' not in project
