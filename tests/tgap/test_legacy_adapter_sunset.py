from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "scripts/runtime/asset_pack_registry.gd"
POLICY = ROOT / "config/tgap-legacy-sunset.json"


def _function_body(text: str, name: str, next_name: str) -> str:
    start = text.index(f"func {name}(")
    end = text.index(f"func {next_name}(", start)
    return text[start:end]


def test_legacy_adapter_is_disabled_by_default():
    text = REGISTRY.read_text(encoding="utf-8")
    assert "@export var legacy_adapter_enabled: bool = false" in text
    assert "@export var scan_legacy_packs: bool = false" in text


def test_tgap_remains_first_resolution_path():
    text = REGISTRY.read_text(encoding="utf-8")
    get_pack = _function_body(text, "get_pack", "has_pack")
    resolve_asset = _function_body(text, "resolve_asset", "load_asset")
    assert "TgapAssetLoader.get_pack" in get_pack
    assert "TgapAssetLoader.resolve" in resolve_asset
    assert get_pack.index("TgapAssetLoader.get_pack") < get_pack.index("if not legacy_adapter_enabled")
    assert resolve_asset.index("TgapAssetLoader.resolve") < resolve_asset.index("if not legacy_adapter_enabled")


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
