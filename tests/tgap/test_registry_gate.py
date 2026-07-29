from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GATE = REPO / "scripts/tgap_registry_gate.py"


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def run(registry: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(GATE), "--registry", str(registry)], cwd=REPO, text=True, capture_output=True, check=False)


def manifest(pack: Path, pack_id: str, version: str = "1.0.0") -> None:
    write_json(pack / "manifest.json", {
        "schema": "tgap/v1", "pack_id": pack_id, "display_name": pack_id,
        "asset_class": "prop", "project_id": "taijifu-masters", "version": version,
        "state": "specified", "root": str(pack), "runtime_target": "godot"
    })


def registry_entry(pack: Path, pack_id: str, order: int, version: str = "1.0.0", dependencies: list[dict] | None = None) -> dict:
    return {
        "pack_id": pack_id, "root": str(pack), "version": version, "asset_class": "prop",
        "integration_order": order, "enabled": True, "dependencies": dependencies or [],
        "compatibility": {"tgap": ">=1.0.0", "runtime": "godot", "project": "taijifu-masters"}
    }


def test_registry_accepts_ordered_dependencies(tmp_path: Path) -> None:
    base = tmp_path / "assets/tgap/pack_base"
    child = tmp_path / "assets/tgap/pack_child"
    manifest(base, "pack_base")
    manifest(child, "pack_child")
    registry = tmp_path / "registry.json"
    write_json(registry, {
        "schema": "tgap/registry/v1", "project_id": "taijifu-masters", "registry_version": "1.0.0",
        "packs": [registry_entry(base, "pack_base", 10), registry_entry(child, "pack_child", 20, dependencies=[{"pack_id": "pack_base", "version": ">=1.0.0", "optional": False}])]
    })
    result = run(registry)
    assert result.returncode == 0, result.stdout + result.stderr


def test_registry_blocks_cycle_and_bad_order(tmp_path: Path) -> None:
    one = tmp_path / "assets/tgap/pack_one"
    two = tmp_path / "assets/tgap/pack_two"
    manifest(one, "pack_one")
    manifest(two, "pack_two")
    registry = tmp_path / "registry.json"
    write_json(registry, {
        "schema": "tgap/registry/v1", "project_id": "taijifu-masters", "registry_version": "1.0.0",
        "packs": [
            registry_entry(one, "pack_one", 20, dependencies=[{"pack_id": "pack_two", "version": ">=1.0.0"}]),
            registry_entry(two, "pack_two", 10, dependencies=[{"pack_id": "pack_one", "version": ">=1.0.0"}])
        ]
    })
    result = run(registry)
    assert result.returncode != 0
    report = json.loads((REPO / "artifacts/tgap/registry-gate-report.json").read_text(encoding="utf-8"))
    assert any(error.startswith("dependency_cycle:") for error in report["errors"])


def test_registry_blocks_manifest_version_mismatch(tmp_path: Path) -> None:
    pack = tmp_path / "assets/tgap/pack_demo"
    manifest(pack, "pack_demo", "1.0.0")
    registry = tmp_path / "registry.json"
    write_json(registry, {
        "schema": "tgap/registry/v1", "project_id": "taijifu-masters", "registry_version": "1.0.0",
        "packs": [registry_entry(pack, "pack_demo", 10, "2.0.0")]
    })
    result = run(registry)
    assert result.returncode != 0
