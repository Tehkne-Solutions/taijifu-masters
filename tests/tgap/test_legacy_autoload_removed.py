from pathlib import Path


def test_project_uses_tgap_loader_without_legacy_autoload() -> None:
    project = Path("project.godot").read_text(encoding="utf-8")
    assert 'TgapAssetLoader="*res://scripts/runtime/tgap_asset_loader.gd"' in project
    assert 'AssetPackRegistry="*res://scripts/runtime/asset_pack_registry.gd"' not in project


def test_legacy_adapter_remains_non_autoloaded_for_emergency_imports() -> None:
    adapter = Path("scripts/runtime/asset_pack_registry.gd")
    assert adapter.exists()
    content = adapter.read_text(encoding="utf-8")
    assert "legacy_adapter_enabled" in content
    assert "TgapAssetLoader" in content


def test_production_gate_remains_zero_budget() -> None:
    policy = Path("config/tgap-legacy-sunset.json").read_text(encoding="utf-8")
    assert '"production_budget": 0' in policy
