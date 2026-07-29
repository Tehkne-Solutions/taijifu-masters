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
    expected = {
        "schema": "tgap/expected-assets/v1",
        "pack_id": "pack_test",
        "animations": {"idle": 2, "attack": 1},
    }
    (pack / "expected-assets.json").write_text(json.dumps(expected), encoding="utf-8")
    (pack / "atlases" / "char_lian_wu__atlas.png").write_bytes(b"png-placeholder")
    frame_names = [
        "char_lian_wu__idle__f00",
        "char_lian_wu__idle__f01",
        "char_lian_wu__attack__f00",
    ]
    atlas = {"frames": {f"{name}.png": {"frame": {"x": 0, "y": 0, "w": 1, "h": 1}} for name in frame_names}}
    (pack / "atlases" / "char_lian_wu__atlas.json").write_text(json.dumps(atlas), encoding="utf-8")
    tres = "[gd_resource type=\"SpriteFrames\" format=3]\n" + "\n".join(frame_names)
    (pack / "runtime" / "lian_wu_spriteframes.tres").write_text(tres, encoding="utf-8")
    manifest = {
        "pack_id": "pack_test",
        "character_id": "lian_wu",
        "atlas": "atlases/char_lian_wu__atlas.png",
        "spriteframes": "runtime/lian_wu_spriteframes.tres",
        "animations": {"idle": {"frame_count": 2}, "attack": 1},
    }
    (pack / "runtime" / "lian_wu_runtime_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    return pack


def read_report(pack: Path) -> dict:
    return json.loads((pack / "validation" / "runtime-gate-report.json").read_text(encoding="utf-8"))


def test_runtime_gate_accepts_consistent_pack(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)

    result = run_gate(pack)
    report = read_report(pack)

    assert result.returncode == 0, result.stderr or result.stdout
    assert report["runtime_gate_passed"] is True
    assert report["promotion_blocked"] is False
    assert report["errors"] == []
    assert report["checks"]["atlas_consistency"]["expected_frames"] == 3
    assert report["checks"]["spriteframes_consistency"]["declared_frames"] == 3


def test_runtime_gate_blocks_missing_atlas_frame(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    atlas_path = pack / "atlases" / "char_lian_wu__atlas.json"
    atlas = json.loads(atlas_path.read_text(encoding="utf-8"))
    atlas["frames"].pop("char_lian_wu__idle__f01.png")
    atlas_path.write_text(json.dumps(atlas), encoding="utf-8")

    result = run_gate(pack)
    report = read_report(pack)

    assert result.returncode == 1
    assert report["promotion_blocked"] is True
    assert report["checks"]["atlas_consistency"]["missing"] == ["char_lian_wu__idle__f01"]


def test_runtime_gate_blocks_missing_spriteframe_and_manifest_divergence(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    sprite_path = pack / "runtime" / "lian_wu_spriteframes.tres"
    sprite_path.write_text(
        sprite_path.read_text(encoding="utf-8").replace("char_lian_wu__attack__f00", ""),
        encoding="utf-8",
    )
    manifest_path = pack / "runtime" / "lian_wu_runtime_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["animations"]["idle"]["frame_count"] = 99
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    result = run_gate(pack)
    report = read_report(pack)

    assert result.returncode == 1
    assert "char_lian_wu__attack__f00" in report["checks"]["spriteframes_consistency"]["missing"]
    assert any("manifesto divergente em idle" in error for error in report["errors"])


def test_runtime_gate_blocks_broken_res_reference(tmp_path: Path) -> None:
    pack = build_runtime_pack(tmp_path)
    sprite_path = pack / "runtime" / "lian_wu_spriteframes.tres"
    sprite_path.write_text(
        sprite_path.read_text(encoding="utf-8") + '\npath = "res://missing/texture.png"\n',
        encoding="utf-8",
    )

    result = run_gate(pack)
    report = read_report(pack)

    assert result.returncode == 1
    assert report["checks"]["spriteframes_consistency"]["broken_references"] == ["res://missing/texture.png"]
