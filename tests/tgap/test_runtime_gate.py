from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "tgap_runtime_gate.py"


def run_gate(pack: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(pack)],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )


def build_runtime_pack(tmp_path: Path) -> Path:
    pack = tmp_path / "pack"
    (pack / "atlases").mkdir(parents=True)
    (pack / "runtime").mkdir(parents=True)
    runtime_config = {
        "entity_id": "kaori_nami",
        "frame_prefix": "fighter_kaori_nami",
        "atlas_png": "atlases/kaori_runtime.png",
        "atlas_json": "atlases/kaori_runtime.json",
        "spriteframes": "runtime/kaori_frames.tres",
        "manifest": "runtime/kaori_runtime.json",
    }
    (pack / "manifest.json").write_text(json.dumps({"schema": "tgap/v1", "pack_id": "pack_test", "runtime": runtime_config}), encoding="utf-8")
    expected = {"schema": "tgap/expected-assets/v1", "pack_id": "pack_test", "animations": {"idle": 2, "attack": 1}}
    (pack / "expected-assets.json").write_text(json.dumps(expected), encoding="utf-8")
    (pack / runtime_config["atlas_png"]).write_bytes(b"png-placeholder")
    frame_names = ["fighter_kaori_nami__idle__f00", "fighter_kaori_nami__idle__f01", "fighter_kaori_nami__attack__f00"]
    atlas = {"frames": {f"{name}.png": {"frame": {"x": 0, "y": 0, "w": 1, "h": 1}} for name in frame_names}}
    (pack / runtime_config["atlas_json"]).write_text(json.dumps(atlas), encoding="utf-8")
    tres = "[gd_resource type=\"SpriteFrames\" format=3]\n" + "\n".join(frame_names)
    (pack / runtime_config["spriteframes"]).write_text(tres, encoding="utf-8")
    runtime_manifest = {
        "pack_id": "pack_test",
        "entity_id": "kaori_nami",
        "atlas": runtime_config["atlas_png"],
        "spriteframes": runtime_config["spriteframes"],
        "animations": {"idle": {"frame_count": 2}, "attack": 1},
    }
    (pack / runtime_config["manifest"]).write_text(json.dumps(runtime_manifest), encoding="utf-8")
    return pack


def read_report(pack: Path) -> dict:
    return json.loads((pack / "validation" / "runtime-gate-report.json").read_text(encoding="utf-8"))


def test_runtime_gate_accepts_consistent_generic_pack(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    result = run_gate(pack)
    report = read_report(pack)
    assert result.returncode == 0, result.stderr or result.stdout
    assert report["runtime_gate_passed"] is True
    assert report["promotion_blocked"] is False
    assert report["errors"] == []
    assert report["checks"]["configuration"]["entity_id"] == "kaori_nami"
    assert report["checks"]["configuration"]["frame_prefix"] == "fighter_kaori_nami"
    assert report["checks"]["atlas_consistency"]["expected_frames"] == 3
    assert report["checks"]["spriteframes_consistency"]["declared_frames"] == 3


def test_runtime_gate_blocks_missing_atlas_frame(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    atlas_path = pack / "atlases/kaori_runtime.json"
    atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
    atlas["frames"].pop("fighter_kaori_nami__idle__f01.png")
    atlas_path.write_text(json.dumps(atlas), encoding="utf-8")
    result = run_gate(pack)
    report = read_report(pack)
    assert result.returncode == 1
    assert report["checks"]["atlas_consistency"]["missing"] == ["fighter_kaori_nami__idle__f01"]


def test_runtime_gate_blocks_missing_spriteframe_and_manifest_divergence(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    sprite_path = pack / "runtime/kaori_frames.tres"
    sprite_path.write_text(sprite_path.read_text(encoding="utf-8").replace("fighter_kaori_nami__attack__f00", ""), encoding="utf-8")
    manifest_path = pack / "runtime/kaori_runtime.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["animations"]["idle"]["frame_count"] = 99
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    result = run_gate(pack)
    report = read_report(pack)
    assert result.returncode == 1
    assert "fighter_kaori_nami__attack__f00" in report["checks"]["spriteframes_consistency"]["missing"]
    assert any("manifesto divergente em idle" in error for error in report["errors"])


def test_runtime_gate_blocks_entity_id_divergence(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    manifest_path = pack / "runtime/kaori_runtime.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["entity_id"] = "outra_entidade"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    result = run_gate(pack)
    report = read_report(pack)
    assert result.returncode == 1
    assert any("entity_id divergente" in error for error in report["errors"])


def test_runtime_gate_blocks_broken_res_reference(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    sprite_path = pack / "runtime/kaori_frames.tres"
    sprite_path.write_text(sprite_path.read_text(encoding="utf-8") + '\npath = "res://missing/texture.png"\n', encoding="utf-8")
    result = run_gate(pack)
    report = read_report(pack)
    assert result.returncode == 1
    assert report["checks"]["spriteframes_consistency"]["broken_references"] == ["res://missing/texture.png"]


def test_runtime_gate_blocks_incomplete_runtime_configuration(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    manifest_path = pack / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["runtime"].pop("frame_prefix")
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    result = run_gate(pack)
    report = read_report(pack)
    assert result.returncode == 1
    assert any("configuração runtime incompleta" in error for error in report["errors"])
