from pathlib import Path
import importlib.util

MODULE_PATH = Path(__file__).parents[2] / "scripts" / "tgap_audit_legacy_usage.py"
spec = importlib.util.spec_from_file_location("legacy_audit", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


def test_audit_classifies_legacy_references(tmp_path: Path):
    script = tmp_path / "scripts" / "consumer.gd"
    script.parent.mkdir(parents=True)
    script.write_text(
        'var item = AssetPackRegistry.load_asset("lian_wu", "spriteframes")\n'
        'var path = "res://assets/packs/pack_01/file.png"\n',
        encoding="utf-8",
    )
    report = module.audit(tmp_path)
    assert report["schema"] == "tgap/legacy-audit/v3"
    assert report["summary"]["total_findings"] == 2
    assert report["summary"]["production_findings"] == 2
    assert report["summary"]["by_kind"]["legacy_registry"] == 1
    assert report["summary"]["by_kind"]["legacy_pack_root"] == 1


def test_safe_migration_rewrites_supported_calls(tmp_path: Path):
    script = tmp_path / "scripts" / "consumer.gd"
    script.parent.mkdir(parents=True)
    script.write_text(
        'var a = AssetPackRegistry.load_asset("lian_wu", "spriteframes")\n'
        'var b = AssetPackRegistry.resolve_asset("lian_wu", "atlas_png")\n',
        encoding="utf-8",
    )
    changed = module.migrate(tmp_path)
    migrated = script.read_text(encoding="utf-8")
    assert changed == ["scripts/consumer.gd"]
    assert "TgapAssetLoader.load_resource(" in migrated
    assert "TgapAssetLoader.resolve(" in migrated
    assert "AssetPackRegistry" not in migrated


def test_registry_adapter_is_not_rewritten(tmp_path: Path):
    adapter = tmp_path / "scripts" / "runtime" / "asset_pack_registry.gd"
    adapter.parent.mkdir(parents=True)
    adapter.write_text("AssetPackRegistry.load_asset()\n", encoding="utf-8")
    assert module.migrate(tmp_path) == []


def test_ci_scripts_are_infrastructure_not_production(tmp_path: Path):
    script = tmp_path / "scripts" / "ci" / "legacy_smoke.gd"
    script.parent.mkdir(parents=True)
    script.write_text('var path = "res://assets/packs/pack_99/file.png"\n', encoding="utf-8")
    report = module.audit(tmp_path)
    assert report["summary"]["production_findings"] == 0
    assert report["summary"]["by_scope"]["allowed_infrastructure"] == 1


def test_retired_runtime_is_reported_without_consuming_production_budget(tmp_path: Path):
    script = tmp_path / "scripts" / "runtime" / "pack_99_battle_visual_runtime.gd"
    script.parent.mkdir(parents=True)
    script.write_text('var path = "res://assets/packs/pack_99/file.png"\n', encoding="utf-8")
    report = module.audit(tmp_path)
    assert report["summary"]["production_findings"] == 0
    assert report["summary"]["retired_findings"] == 1
    assert report["findings"][0]["scope"] == "retired_legacy"
    assert report["findings"][0]["severity"] == "retired"
