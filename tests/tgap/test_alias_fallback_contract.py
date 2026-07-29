from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]


def test_alias_catalog_contract():
    data = json.loads((ROOT / "assets/tgap/aliases.json").read_text(encoding="utf-8"))
    assert data["schema"] == "tgap/aliases/v1"
    assert data["aliases"]["lian_wu"]["pack_id"] == "pack_01_lian_wu"
    assert data["path_aliases"]["pack_01_lian_wu"]["spriteframes"].endswith(".tres")


def test_loader_exposes_alias_and_fallback_api():
    source = (ROOT / "scripts/runtime/tgap_asset_loader.gd").read_text(encoding="utf-8")
    for token in (
        "canonical_pack_id",
        "resolve_path_alias",
        "_resolve_fallback",
        "deprecated_alias_used",
        "fallback_used",
        "allowed_states",
    ):
        assert token in source


def test_legacy_registry_delegates_to_tgap():
    source = (ROOT / "scripts/runtime/asset_pack_registry.gd").read_text(encoding="utf-8")
    assert "prefer_tgap" in source
    assert "TgapAssetLoader.get_pack" in source
    assert "TgapAssetLoader.resolve" in source
    assert "source\": \"tgap" in source


def test_fallbacks_never_allowed_in_approved_states():
    data = json.loads((ROOT / "assets/tgap/aliases.json").read_text(encoding="utf-8"))
    forbidden = {"approved", "integrated", "released"}
    for fallback in data.get("fallbacks", {}).values():
        assert forbidden.isdisjoint(set(fallback.get("allowed_states", [])))
