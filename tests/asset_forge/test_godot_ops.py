from __future__ import annotations
import importlib.util, json
from pathlib import Path

MODULE = Path(__file__).resolve().parents[2] / 'tools' / 'asset_forge' / 'godot_ops.py'
spec = importlib.util.spec_from_file_location('godot_ops', MODULE)
mod = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(mod)


def test_generate_reports_missing_without_fabricating_assets(tmp_path: Path):
    recipe = tmp_path / 'recipe.json'
    recipe.write_text(json.dumps({
        'pack_id': 'pack_test',
        'subject_id': 'char_test',
        'pack_root': 'assets/tgap/pack_test',
        'required_assets': ['source/master.png'],
        'resources': {'master': 'res://assets/tgap/pack_test/source/master.png'},
        'semantic_aliases': {'character.test.master': 'master'}
    }), encoding='utf-8')
    report = mod.generate(tmp_path, recipe)
    assert report['ready'] is False
    assert report['missing'] == ['source/master.png']
    assert not (tmp_path / 'assets/tgap/pack_test/source/master.png').exists()
    assert (tmp_path / report['scene']).is_file()


def test_generate_ready_when_real_asset_exists(tmp_path: Path):
    root = tmp_path / 'assets/tgap/pack_test/source'
    root.mkdir(parents=True)
    (root / 'master.png').write_bytes(b'real')
    recipe = tmp_path / 'recipe.json'
    recipe.write_text(json.dumps({
        'pack_id': 'pack_test', 'subject_id': 'char_test',
        'pack_root': 'assets/tgap/pack_test',
        'required_assets': ['source/master.png']
    }), encoding='utf-8')
    assert mod.generate(tmp_path, recipe)['ready'] is True
