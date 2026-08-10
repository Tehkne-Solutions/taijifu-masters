from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tests/tgap/runtime_scene_matrix_smoke.gd"


def test_scene_matrix_smoke_contract():
    text = SCRIPT.read_text(encoding="utf-8")
    required = [
        "TGAP_SCENE_MATRIX_SMOKE_OK",
        "preparation_ui",
        "arena_animation",
        "result_ui",
        "SpriteFrames",
        "generation() == 1",
        "generation() == 2",
        "reload_catalog()",
        "cache não foi invalidado por geração",
        "res://scenes/vertical_slice/first_playable_menu.tscn",
    ]
    for token in required:
        assert token in text


def test_runtime_remains_tgap_only():
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    assert 'TgapAssetLoader="*res://scripts/runtime/tgap_asset_loader.gd"' in project
    assert "AssetPackRegistry=" not in project
