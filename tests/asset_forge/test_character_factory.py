from __future__ import annotations

import importlib.util
import json
from pathlib import Path

MODULE_PATH = Path(__file__).parents[2] / "tools" / "asset_forge" / "character_factory.py"
spec = importlib.util.spec_from_file_location("character_factory", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def valid_dna() -> dict:
    return {
        "schema": "taijifu/character-dna/v1",
        "id": "test_hero",
        "name": "Test Hero",
        "pack_id": "pack_99_test_hero",
        "origin": "Test",
        "faction": "Test",
        "combat_style": ["test"],
        "movement": {"speed": "medium"},
        "palette": {"primary": ["white"]},
        "personality": ["calm"],
        "lore": "Test lore",
        "skills": ["test_skill"],
        "ultimate": "test_ultimate",
        "rarity": "common",
        "source_assets": ["master_raw.png"],
        "animations": ["idle"]
    }


def test_validate_accepts_complete_dna() -> None:
    assert module.validate(valid_dna()) == []


def test_validate_rejects_missing_fields() -> None:
    dna = valid_dna()
    del dna["source_assets"]
    errors = module.validate(dna)
    assert any("source_assets" in error for error in errors)


def test_render_contracts_generates_release_and_asset_dna() -> None:
    dna = valid_dna()
    contracts = module.render_contracts(dna)
    assert "asset-forge/release/pack_99_test_hero.json" in contracts
    assert "assets/tgap/pack_99_test_hero/character_dna.json" in contracts
    assert contracts["asset-forge/packs/pack_99_test_hero.json"]["no_placeholders"] is True


def test_write_contracts_refuses_overwrite(tmp_path: Path) -> None:
    dna = valid_dna()
    contracts = module.render_contracts(dna)
    module.write_contracts(tmp_path, contracts, force=False)
    try:
        module.write_contracts(tmp_path, contracts, force=False)
    except FileExistsError:
        pass
    else:
        raise AssertionError("expected FileExistsError")


def test_generated_files_are_valid_json(tmp_path: Path) -> None:
    dna = valid_dna()
    created = module.write_contracts(tmp_path, module.render_contracts(dna), force=False)
    for relative in created:
        json.loads((tmp_path / relative).read_text(encoding="utf-8"))
