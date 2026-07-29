from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LOADER = REPO / "scripts/runtime/tgap_asset_loader.gd"
PROJECT = REPO / "project.godot"


def test_loader_is_registered_as_autoload() -> None:
    project = PROJECT.read_text(encoding="utf-8")
    assert 'TgapAssetLoader="*res://scripts/runtime/tgap_asset_loader.gd"' in project


def test_loader_implements_generation_cache_and_safe_resolution() -> None:
    source = LOADER.read_text(encoding="utf-8")
    required_fragments = [
        'class_name TgapAssetLoader',
        'tgap/install-catalog/v1',
        'func resolve(',
        'func load_resource(',
        'func poll_catalog()',
        'func invalidate_pack(',
        'CACHE_MODE_REPLACE',
        'catalog_reloaded.emit',
        'pack_invalidated.emit',
        '_is_safe_relative_path',
    ]
    for fragment in required_fragments:
        assert fragment in source


def test_loader_rejects_parent_directory_traversal() -> None:
    source = LOADER.read_text(encoding="utf-8")
    assert 'segment == ".."' in source
    assert 'value.is_absolute_path()' in source
