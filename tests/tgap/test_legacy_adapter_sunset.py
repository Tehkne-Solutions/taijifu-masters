from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "scripts/runtime/asset_pack_registry.gd"
POLICY = ROOT / "config/tgap-legacy-sunset.json"


def test_legacy_adapter_is_disabled_by_default():
    text = REGISTRY.read_text(encoding="utf-8")
    assert "@export var legacy_adapter_enabled: bool = false" in text
    assert "@export var scan_legacy_packs: bool = false" in text


def test_tgap_remains_first_resolution_path():
    text = REGISTRY.read_text(encoding="utf-8")
    assert "TgapAssetLoader.get_pack" in text
    assert "TgapAssetLoader.resolve" in text
    assert text.index("TgapAssetLoader.resolve") < text.index("if not legacy_adapter_enabled")


def test_legacy_usage_is_observable():
    text = REGISTRY.read_text(encoding="utf-8")
    assert "signal legacy_api_used" in text
    assert "func usage_snapshot()" in text
    assert "push_warning" in text


def test_sunset_policy_has_zero_production_budget():
    policy = json.loads(POLICY.read_text(encoding="utf-8"))
    assert policy["schema"] == "tgap/legacy-sunset/v1"
    assert policy["production_budget"] == 0
    assert policy["default_enabled"] is False
    assert policy["removal_conditions"]["production_findings"] == 0
