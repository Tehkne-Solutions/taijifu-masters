from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def run_gate(pack: Path) -> subprocess.CompletedProcess[str]:
    repo = Path(__file__).resolve().parents[2]
    return subprocess.run(
        [sys.executable, str(repo / "scripts/tgap_animation_gate.py"), str(pack)],
        text=True,
        capture_output=True,
        check=False,
    )


def make_pack(tmp_path: Path, *, missing_frame: bool = False, bad_metadata: bool = False) -> Path:
    pack = tmp_path / "pack_fixture"
    (pack / "frames" / "idle").mkdir(parents=True)
    (pack / "metadata").mkdir()
    (pack / "validation").mkdir()
    (pack / "manifest.json").write_text(
        json.dumps({
            "schema": "tgap/v1",
            "pack_id": "pack_fixture",
            "asset_class": "character",
            "version": "1.0.0",
            "state": "validation",
            "runtime": {
                "entity_id": "fixture",
                "frame_prefix": "char_fixture",
                "atlas_png": "atlases/fixture.png",
                "atlas_json": "atlases/fixture.json",
                "spriteframes": "runtime/fixture.tres",
                "manifest": "runtime/fixture.json",
            },
        }),
        encoding="utf-8",
    )
    (pack / "expected-assets.json").write_text(
        json.dumps({"schema": "tgap/expected-assets/v1", "pack_id": "pack_fixture", "animations": {"idle": 2}}),
        encoding="utf-8",
    )
    (pack / "frames" / "idle" / "char_fixture__idle__f00.png").write_bytes(b"fixture")
    if not missing_frame:
        (pack / "frames" / "idle" / "char_fixture__idle__f01.png").write_bytes(b"fixture")
    metadata = {"animation": "idle", "fps": 12, "loop": True, "frame_count": 2}
    if bad_metadata:
        metadata["fps"] = 0
        metadata.pop("loop")
    (pack / "metadata" / "idle.json").write_text(json.dumps(metadata), encoding="utf-8")
    return pack


def test_animation_gate_accepts_complete_sequence(tmp_path: Path) -> None:
    pack = make_pack(tmp_path)
    result = run_gate(pack)
    report = json.loads((pack / "validation/animation-gate-report.json").read_text(encoding="utf-8"))
    assert result.returncode == 0, result.stderr or result.stdout
    assert report["promotion_blocked"] is False
    assert report["animations_passed"] == 1


def test_animation_gate_blocks_missing_frame(tmp_path: Path) -> None:
    pack = make_pack(tmp_path, missing_frame=True)
    result = run_gate(pack)
    report = json.loads((pack / "validation/animation-gate-report.json").read_text(encoding="utf-8"))
    assert result.returncode == 1
    assert report["promotion_blocked"] is True
    assert any("frames ausentes" in error for error in report["animations"][0]["errors"])


def test_animation_gate_blocks_invalid_metadata(tmp_path: Path) -> None:
    pack = make_pack(tmp_path, bad_metadata=True)
    result = run_gate(pack)
    report = json.loads((pack / "validation/animation-gate-report.json").read_text(encoding="utf-8"))
    assert result.returncode == 1
    errors = report["animations"][0]["errors"]
    assert any("fps" in error for error in errors)
    assert any("loop" in error for error in errors)
