#!/usr/bin/env python3
"""Generate Lian Wu Idle v1 from the approved Character Lock neutral sprite.

Tehkné Solutions

This tool does not redraw the character. It performs a deterministic integer-pixel
vertical breathing warp on the approved neutral PNG while keeping the feet/contact
baseline fixed. Output is intentionally a production candidate until reviewed in Godot.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit(
        "VM02_A2_IDLE6=BLOCKED missing dependency Pillow. Install with: python -m pip install Pillow"
    ) from exc

EXPECTED_SOURCE_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANVAS = (1024, 1024)
FRAME_PHASES = (0, 1, 2, 1, 0, -1)
FRAME_COUNT = len(FRAME_PHASES)
ALPHA_THRESHOLD = 1


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    return alpha.getbbox() or (0, 0, 0, 0)


def breathing_offset(y: int, phase: int, bounds: tuple[int, int, int, int]) -> int:
    """Piecewise integer-pixel breathing offset; feet remain fixed.

    Upper body receives full phase. Lower torso tapers to zero, and the final
    contact region remains untouched so the approved baseline cannot drift.
    """
    _x0, y0, _x1, y1 = bounds
    height = max(1, y1 - y0)
    upper_end = y0 + int(height * 0.58)
    taper_end = y0 + int(height * 0.86)
    if y <= upper_end:
        return -phase
    if y >= taper_end:
        return 0
    span = max(1, taper_end - upper_end)
    remain = taper_end - y
    # Integer taper, deterministic on every platform/Pillow version.
    return int(round((-phase) * (remain / span)))


def warp_idle(source: Image.Image, phase: int, bounds: tuple[int, int, int, int]) -> Image.Image:
    src = source.convert("RGBA")
    out = Image.new("RGBA", src.size, (0, 0, 0, 0))
    src_px = src.load()
    out_px = out.load()
    width, height = src.size

    # Forward map each non-transparent source pixel to a deterministic integer destination.
    # Later rows overwrite earlier rows only on the same x/y; no interpolation or color synthesis occurs.
    for y in range(height):
        dy = breathing_offset(y, phase, bounds)
        dest_y = y + dy
        if dest_y < 0 or dest_y >= height:
            continue
        for x in range(width):
            px = src_px[x, y]
            if px[3] < ALPHA_THRESHOLD:
                continue
            out_px[x, dest_y] = px

    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument(
        "--source",
        default="assets/characters/lian_wu/character_lock/lian_wu_neutral.png",
    )
    args = parser.parse_args()

    repo = Path(args.repo_root).resolve()
    source = (repo / args.source).resolve()
    if not source.is_file():
        print(f"VM02_A2_IDLE6=BLOCKED source_missing={source}")
        return 2

    actual_source_sha = sha256(source)
    if actual_source_sha != EXPECTED_SOURCE_SHA256:
        print("VM02_A2_IDLE6=BLOCKED source_hash_mismatch")
        print(f"expected={EXPECTED_SOURCE_SHA256}")
        print(f"actual={actual_source_sha}")
        return 3

    image = Image.open(source).convert("RGBA")
    if image.size != CANVAS:
        print(f"VM02_A2_IDLE6=BLOCKED canvas={image.size} expected={CANVAS}")
        return 4

    bounds = alpha_bounds(image)
    if bounds == (0, 0, 0, 0):
        print("VM02_A2_IDLE6=BLOCKED empty_alpha")
        return 5

    frames_dir = repo / "assets/pack_01_characters/lian_wu/frames/idle"
    metadata_dir = repo / "assets/pack_01_characters/lian_wu/metadata"
    frames_dir.mkdir(parents=True, exist_ok=True)
    metadata_dir.mkdir(parents=True, exist_ok=True)

    frame_records = []
    source_baseline = bounds[3] - 1
    for index, phase in enumerate(FRAME_PHASES):
        frame = warp_idle(image, phase, bounds)
        frame_name = f"char_lian_wu__idle__f{index:02d}.png"
        frame_path = frames_dir / frame_name
        frame.save(frame_path, format="PNG", optimize=False, compress_level=9)
        fb = alpha_bounds(frame)
        baseline = fb[3] - 1 if fb != (0, 0, 0, 0) else -1
        if baseline != source_baseline:
            print(
                f"VM02_A2_IDLE6=BLOCKED baseline_drift frame={index} baseline={baseline} source={source_baseline}"
            )
            return 6
        frame_records.append(
            {
                "index": index,
                "phase": phase,
                "file": str(frame_path.relative_to(repo)).replace("\\", "/"),
                "sha256": sha256(frame_path),
                "alpha_bounds": list(fb),
                "baseline_y": baseline,
            }
        )

    metadata = {
        "schema": "tehkne/taijifu-animation-metadata/v1",
        "signature": "Tehkné Solutions",
        "character_id": "lian_wu",
        "animation": "idle",
        "status": "candidate_pending_godot_review",
        "source_character_lock": {
            "file": str(source.relative_to(repo)).replace("\\", "/"),
            "sha256": actual_source_sha,
            "pivot_policy": "alpha_bounds_bottom_center",
            "source_alpha_bounds": list(bounds),
            "baseline_y": source_baseline,
        },
        "generation": {
            "method": "deterministic_integer_pixel_breathing_warp",
            "redraw": False,
            "interpolation": False,
            "frame_count": FRAME_COUNT,
            "phases": list(FRAME_PHASES),
            "loop": True,
            "fps": 8.0,
        },
        "frames": frame_records,
        "gates": {
            "identity_source_hash": "pass",
            "canvas": "pass",
            "transparent_background": "pass",
            "baseline_continuity": "pass",
            "godot_visual_review": "pending",
            "runtime_promotion": "blocked",
        },
    }
    metadata_path = metadata_dir / "idle.json"
    metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("VM02_A2_IDLE6=GENERATED")
    print(f"source_sha256={actual_source_sha}")
    print(f"source_alpha_bounds={bounds}")
    print(f"baseline_y={source_baseline}")
    print(f"frames={FRAME_COUNT}")
    for record in frame_records:
        print(f"FRAME_PASS {record['index']:02d} {record['sha256']} {record['file']}")
    print(f"metadata={metadata_path.relative_to(repo)}")
    print("VM02_A2_IDLE6_GODOT_REVIEW=PENDING")
    return 0


if __name__ == "__main__":
    sys.exit(main())
