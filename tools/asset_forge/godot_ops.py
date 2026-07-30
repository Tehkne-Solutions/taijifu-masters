#!/usr/bin/env python3
from __future__ import annotations
import argparse, json
from pathlib import Path


def load(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def dump(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def generate(repo: Path, recipe_path: Path) -> dict:
    recipe = load(recipe_path)
    pack_root = repo / recipe['pack_root']
    runtime = pack_root / 'runtime'
    validation = pack_root / 'validation'
    runtime.mkdir(parents=True, exist_ok=True)
    validation.mkdir(parents=True, exist_ok=True)

    required = [pack_root / p for p in recipe.get('required_assets', [])]
    missing = [p.relative_to(pack_root).as_posix() for p in required if not p.is_file()]
    ready = not missing

    manifest = {
        'schema': 'taijifu/asset-forge-godot-runtime/v1',
        'pack_id': recipe['pack_id'],
        'subject_id': recipe['subject_id'],
        'ready': ready,
        'missing': missing,
        'resources': recipe.get('resources', {}),
        'semantic_aliases': recipe.get('semantic_aliases', {}),
    }
    dump(runtime / 'asset_forge_runtime_manifest.json', manifest)

    scene_path = validation / 'asset_forge_validation.tscn'
    script_path = validation / 'asset_forge_validation.gd'
    scene_path.write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource path="res://%s" type="Script" id="1"]\n\n[node name="AssetForgeValidation" type="Node"]\nscript = ExtResource("1")\n' % script_path.relative_to(repo).as_posix(), encoding='utf-8')
    script_path.write_text('extends Node\n\nfunc _ready() -> void:\n\tvar manifest_path = "res://%s"\n\tif not FileAccess.file_exists(manifest_path):\n\t\tpush_error("asset_forge_manifest_missing")\n\t\tget_tree().quit(2)\n\t\treturn\n\tvar parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))\n\tif typeof(parsed) != TYPE_DICTIONARY:\n\t\tpush_error("asset_forge_manifest_invalid")\n\t\tget_tree().quit(3)\n\t\treturn\n\tif not bool(parsed.get("ready", false)):\n\t\tprint("ASSET_FORGE_BLOCKED:", parsed.get("missing", []))\n\t\tget_tree().quit(4)\n\t\treturn\n\tprint("ASSET_FORGE_OK:%s")\n\tget_tree().quit(0)\n' % ((runtime / 'asset_forge_runtime_manifest.json').relative_to(repo).as_posix(), recipe['pack_id']), encoding='utf-8')

    report = {'schema': 'taijifu/asset-forge-godot-report/v1', 'pack_id': recipe['pack_id'], 'ready': ready, 'missing': missing, 'scene': scene_path.relative_to(repo).as_posix()}
    dump(repo / 'artifacts/asset-forge' / f"{recipe['pack_id']}__godot.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('recipe', type=Path)
    parser.add_argument('--strict', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    recipe = args.recipe if args.recipe.is_absolute() else repo / args.recipe
    report = generate(repo, recipe)
    print(json.dumps(report, ensure_ascii=False))
    return 1 if args.strict and not report['ready'] else 0

if __name__ == '__main__':
    raise SystemExit(main())
