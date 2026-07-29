from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GATE = REPO / "scripts" / "tgap_semantic_gate.py"


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf-8")


def build_pack(tmp_path: Path) -> Path:
    pack = tmp_path / "pack_semantic"
    write_json(pack / "manifest.json", {
        "schema": "tgap/v1", "pack_id": "pack_semantic", "display_name": "Semantic",
        "asset_class": "character", "version": "1.0.0", "state": "approved",
        "runtime": {
            "entity_id": "hero", "frame_prefix": "char_hero",
            "atlas_png": "atlases/hero.png", "atlas_json": "atlases/hero.json",
            "spriteframes": "runtime/hero.tres", "manifest": "runtime/hero.json",
        },
    })
    assets = ["atlases/hero.png", "atlases/hero.json", "runtime/hero.tres", "runtime/hero.json"]
    write_json(pack / "expected-assets.json", {
        "schema": "tgap/expected-assets/v1", "pack_id": "pack_semantic",
        "closed_inventory": True, "animations": {"idle": 2},
        "assets": [{"path": path, "quality": "final"} for path in assets],
    })
    write_json(pack / "production-status.json", {"pack_id": "pack_semantic", "state": "approved"})
    write_json(pack / "runtime/hero.json", {
        "pack_id": "pack_semantic", "entity_id": "hero",
        "atlas": "atlases/hero.json", "spriteframes": "runtime/hero.tres",
        "animations": {"idle": {"frame_count": 2}},
    })
    return pack


def run(pack: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(GATE), str(pack), *args], cwd=REPO, text=True, capture_output=True, check=False)


def report(pack: Path) -> dict:
    return json.loads((pack / "validation/semantic-gate-report.json").read_text(encoding="utf-8"))


def test_accepts_coherent_documents(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    result = run(pack)
    assert result.returncode == 0, result.stdout + result.stderr
    assert report(pack)["semantic_gate_passed"] is True


def test_blocks_pack_id_divergence(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    expected = json.loads((pack / "expected-assets.json").read_text(encoding="utf-8"))
    expected["pack_id"] = "pack_other"
    write_json(pack / "expected-assets.json", expected)
    assert run(pack).returncode == 1
    assert any("pack_id_manifest_expected" in error for error in report(pack)["errors"])


def test_blocks_runtime_animation_divergence(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    runtime = json.loads((pack / "runtime/hero.json").read_text(encoding="utf-8"))
    runtime["animations"]["idle"]["frame_count"] = 99
    write_json(pack / "runtime/hero.json", runtime)
    assert run(pack).returncode == 1
    assert any("runtime_animation_counts" in error for error in report(pack)["errors"])


def test_blocks_advanced_state_with_non_final_asset(tmp_path: Path) -> None:
    pack = build_pack(tmp_path)
    expected = json.loads((pack / "expected-assets.json").read_text(encoding="utf-8"))
    expected["assets"][0]["quality"] = "prototype"
    write_json(pack / "expected-assets.json", expected)
    assert run(pack).returncode == 1
    assert any("advanced_state_final_assets" in error for error in report(pack)["errors"])
