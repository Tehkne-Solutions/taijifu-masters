from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "tgap_visual_gate.py"


def run_gate(pack: Path) -> subprocess.CompletedProcess[str]:
    if not (pack / "manifest.json").is_file():
        (pack / "manifest.json").write_text(
            json.dumps({
                "schema": "tgap/v1",
                "pack_id": "pack_visual_fixture",
                "asset_class": "character",
                "version": "1.0.0",
                "state": "validation",
            }),
            encoding="utf-8",
        )
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(pack)],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )


def write_rgba(path: Path, *, transparent: bool = True, size: tuple[int, int] = (128, 128)) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    background = (0, 0, 0, 0) if transparent else (20, 30, 40, 255)
    image = Image.new("RGBA", size, background)
    draw = ImageDraw.Draw(image)
    draw.rectangle((40, 24, 88, 120), fill=(180, 210, 230, 255))
    image.save(path)


def read_report(pack: Path) -> dict:
    return json.loads((pack / "validation" / "visual-gate-report.json").read_text(encoding="utf-8"))


def test_visual_gate_accepts_rgba_with_real_transparency(tmp_path: Path) -> None:
    pack = tmp_path / "pack"
    write_rgba(pack / "frames" / "idle" / "char_lian_wu__idle__f00.png")

    result = run_gate(pack)
    report = read_report(pack)

    assert result.returncode == 0, result.stderr or result.stdout
    assert report["promotion_blocked"] is False
    assert report["images_checked"] == 1
    assert report["failed"] == 0
    assert report["results"][0]["mode"] == "RGBA"
    assert report["results"][0]["has_alpha"] is True


def test_visual_gate_blocks_opaque_png(tmp_path: Path) -> None:
    pack = tmp_path / "pack"
    write_rgba(pack / "frames" / "idle" / "char_lian_wu__idle__f00.png", transparent=False)

    result = run_gate(pack)
    report = read_report(pack)

    assert result.returncode == 1
    assert report["promotion_blocked"] is True
    assert "transparency_missing" in report["results"][0]["errors"]


def test_visual_gate_blocks_wrong_canvas_and_empty_frame(tmp_path: Path) -> None:
    pack = tmp_path / "pack"
    path = pack / "frames" / "idle" / "char_lian_wu__idle__f00.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGBA", (64, 64), (0, 0, 0, 0)).save(path)

    result = run_gate(pack)
    report = read_report(pack)
    errors = report["results"][0]["errors"]

    assert result.returncode == 1
    assert "frame_empty" in errors
    assert any(error.startswith("size_invalid:64x64") for error in errors)


def test_visual_gate_reports_pivot_drift_by_animation(tmp_path: Path) -> None:
    pack = tmp_path / "pack"
    first = pack / "frames" / "idle" / "char_lian_wu__idle__f00.png"
    second = pack / "frames" / "idle" / "char_lian_wu__idle__f01.png"
    for path, x in ((first, 20), (second, 60)):
        path.parent.mkdir(parents=True, exist_ok=True)
        image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        ImageDraw.Draw(image).rectangle((x, 50, x + 20, 120), fill=(255, 255, 255, 255))
        image.save(path)

    result = run_gate(pack)
    report = read_report(pack)

    assert result.returncode == 1
    assert report["pivot_drift"]["idle"]["x"] == 40
    assert any("pivot_drift_exceeded:idle" in error for error in report["errors"])
