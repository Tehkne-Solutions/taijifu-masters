from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
RUNNER = REPO / "scripts" / "tgap_run_pack.py"
RELEASER = REPO / "scripts" / "tgap_release_pack.py"


def write_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_rgba(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((40, 24, 88, 120), fill=(30, 120, 220, 255))
    image.save(path)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def build_canonical_pack(root: Path) -> Path:
    pack = root / "pack_00_e2e_canonical"
    frame_name = "char_lian_wu__idle__f00"

    write_rgba(pack / "frames/idle" / f"{frame_name}.png")
    write_rgba(pack / "atlases/char_lian_wu__atlas.png")

    write_json(pack / "metadata/idle.json", {
        "animation": "idle",
        "fps": 12,
        "loop": True,
        "frame_count": 1,
    })
    write_json(pack / "atlases/char_lian_wu__atlas.json", {
        "frames": {
            f"{frame_name}.png": {
                "frame": {"x": 0, "y": 0, "w": 128, "h": 128}
            }
        }
    })
    (pack / "runtime").mkdir(parents=True, exist_ok=True)
    (pack / "runtime/lian_wu_spriteframes.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        '[resource]\n'
        f'resource_name = "{frame_name}"\n',
        encoding="utf-8",
    )
    write_json(pack / "runtime/lian_wu_runtime_manifest.json", {
        "pack_id": "pack_00_e2e_canonical",
        "character_id": "lian_wu",
        "atlas": "atlases/char_lian_wu__atlas.json",
        "spriteframes": "runtime/lian_wu_spriteframes.tres",
        "animations": {"idle": {"frame_count": 1}},
    })
    write_json(pack / "manifest.json", {
        "schema": "tgap/manifest/v1",
        "pack_id": "pack_00_e2e_canonical",
        "name": "TGAP Canonical E2E Pack",
        "version": "1.0.0",
        "lifecycle": "approved",
    })
    write_json(pack / "production-status.json", {
        "pack_id": "pack_00_e2e_canonical",
        "state": "approved",
    })

    assets = [
        "manifest.json",
        "production-status.json",
        "frames/idle/char_lian_wu__idle__f00.png",
        "metadata/idle.json",
        "atlases/char_lian_wu__atlas.png",
        "atlases/char_lian_wu__atlas.json",
        "runtime/lian_wu_spriteframes.tres",
        "runtime/lian_wu_runtime_manifest.json",
    ]
    write_json(pack / "expected-assets.json", {
        "schema": "tgap/expected-assets/v1",
        "pack_id": "pack_00_e2e_canonical",
        "closed_inventory": True,
        "animations": {"idle": 1},
        "assets": [{"path": path, "quality": "final"} for path in assets],
    })
    return pack


def run(*args: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *(str(arg) for arg in args)],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )


def test_canonical_pack_crosses_full_pipeline_and_release(tmp_path: Path) -> None:
    pack = build_canonical_pack(tmp_path)

    pipeline = run(RUNNER, pack)
    assert pipeline.returncode == 0, pipeline.stdout + pipeline.stderr

    report = json.loads((pack / "validation/pipeline-report.json").read_text(encoding="utf-8"))
    assert report["pipeline_passed"] is True
    assert report["promotion_blocked"] is False
    assert [step["name"] for step in report["steps"]] == [
        "inventory",
        "visual_gate",
        "animation_gate",
        "runtime_gate",
    ]
    assert all(step["passed"] for step in report["steps"])

    output_a = tmp_path / "release-a"
    output_b = tmp_path / "release-b"
    first = run(RELEASER, pack, "--version", "1.0.0", "--output-dir", output_a)
    second = run(RELEASER, pack, "--version", "1.0.0", "--output-dir", output_b)
    assert first.returncode == 0, first.stdout + first.stderr
    assert second.returncode == 0, second.stdout + second.stderr

    zip_a = output_a / "pack_00_e2e_canonical-1.0.0.zip"
    zip_b = output_b / "pack_00_e2e_canonical-1.0.0.zip"
    assert zip_a.is_file() and zip_b.is_file()
    assert sha256(zip_a) == sha256(zip_b)

    distribution = json.loads(
        (output_a / "pack_00_e2e_canonical-1.0.0.manifest.json").read_text(encoding="utf-8")
    )
    assert distribution["pipeline_approved"] is True
    assert distribution["forced"] is False
    assert distribution["archive"]["sha256"] == sha256(zip_a)
    assert distribution["file_count"] > 0
