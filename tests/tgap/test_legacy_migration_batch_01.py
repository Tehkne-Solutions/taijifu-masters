import importlib.util
from pathlib import Path

MODULE_PATH = Path(__file__).parents[2] / "scripts" / "tgap_audit_legacy_usage.py"
spec = importlib.util.spec_from_file_location("legacy_audit", MODULE_PATH)
legacy_audit = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(legacy_audit)


def test_adapter_is_allowed_infrastructure():
    policy = legacy_audit.DEFAULT_POLICY
    assert legacy_audit.classify("scripts/runtime/asset_pack_registry.gd", policy) == "allowed_infrastructure"


def test_runtime_consumer_is_production():
    policy = legacy_audit.DEFAULT_POLICY
    assert legacy_audit.classify("scripts/runtime/fighter_runtime.gd", policy) == "production"


def test_audit_separates_production_from_documentation(tmp_path: Path):
    (tmp_path / "scripts/runtime").mkdir(parents=True)
    (tmp_path / "docs").mkdir()
    (tmp_path / "scripts/runtime/consumer.gd").write_text(
        'var asset = AssetPackRegistry.load_asset("lian_wu", "spriteframes")\n',
        encoding="utf-8",
    )
    (tmp_path / "docs/migration.md").write_text("AssetPackRegistry", encoding="utf-8")
    report = legacy_audit.audit(tmp_path, legacy_audit.DEFAULT_POLICY)
    assert report["schema"] == "tgap/legacy-audit/v3"
    assert report["summary"]["production_findings"] == 1
    assert report["summary"]["by_scope"]["allowed_infrastructure"] == 1


def test_safe_migration_only_changes_production(tmp_path: Path):
    (tmp_path / "scripts/runtime").mkdir(parents=True)
    (tmp_path / "docs").mkdir()
    consumer = tmp_path / "scripts/runtime/consumer.gd"
    documentation = tmp_path / "docs/example.md"
    consumer.write_text("AssetPackRegistry.load_asset(\"pack\", \"asset\")", encoding="utf-8")
    documentation.write_text("AssetPackRegistry.load_asset(\"pack\", \"asset\")", encoding="utf-8")
    changed = legacy_audit.migrate(tmp_path, legacy_audit.DEFAULT_POLICY)
    assert changed == ["scripts/runtime/consumer.gd"]
    assert "TgapAssetLoader.load_resource" in consumer.read_text(encoding="utf-8")
    assert "AssetPackRegistry.load_asset" in documentation.read_text(encoding="utf-8")
