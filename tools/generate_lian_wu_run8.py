#!/usr/bin/env python3
"""Generate Lian Wu Run 8 candidates from the approved Character Lock neutral sprite.

Tehkné Solutions

Run is not a sped-up walk. This generator uses the approved regional rig lineage with
stronger stride, forward body drive, shorter contact, explicit flight phases and larger
arm counter-swing while preserving identity, canvas and canonical contact baseline.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from lian_wu_canonical_identity import validate_source

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as exc:
    raise SystemExit("VM02_A4_RUN8=BLOCKED missing dependency Pillow. Install with: python -m pip install Pillow") from exc

CANVAS = (1024, 1024)
FRAME_COUNT = 8
ALPHA_THRESHOLD = 3
FPS = 14.0


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
    visible = alpha.point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0)
    return visible.getbbox() or (0, 0, 0, 0)


def norm_point(bounds, nx, ny):
    x0, y0, x1, y1 = bounds
    return (int(round(x0 + (x1 - x0) * nx)), int(round(y0 + (y1 - y0) * ny)))


def polygon_mask(size, points, dilation=9):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    if dilation >= 3 and dilation % 2 == 1:
        mask = mask.filter(ImageFilter.MaxFilter(dilation))
    return mask


def build_region_masks(size, bounds):
    p = lambda x, y: norm_point(bounds, x, y)
    regions = {
        "torso": [p(0.14, 0.00), p(0.86, 0.00), p(0.84, 0.65), p(0.16, 0.65)],
        "arm_back": [p(0.00, 0.24), p(0.48, 0.25), p(0.47, 0.72), p(0.00, 0.74)],
        "arm_front": [p(0.52, 0.23), p(1.00, 0.23), p(1.00, 0.74), p(0.53, 0.72)],
        "pelvis": [p(0.22, 0.52), p(0.78, 0.52), p(0.78, 0.77), p(0.22, 0.77)],
        "leg_back": [p(0.13, 0.59), p(0.52, 0.59), p(0.55, 1.00), p(0.06, 1.00)],
        "leg_front": [p(0.48, 0.59), p(0.87, 0.59), p(0.94, 1.00), p(0.45, 1.00)],
    }
    return {name: polygon_mask(size, pts) for name, pts in regions.items()}


def extract_region(source, mask):
    return Image.composite(source, Image.new("RGBA", source.size, (0, 0, 0, 0)), mask)


def rotate_about(layer, degrees, pivot):
    return layer.rotate(degrees, resample=Image.Resampling.NEAREST, center=pivot, expand=False, fillcolor=(0, 0, 0, 0))


def safe_offset(layer, dx, dy):
    if not dx and not dy:
        return layer
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (dx, dy))
    return out


def composite_run_frame(source, bounds, masks, theta):
    p = lambda x, y: norm_point(bounds, x, y)
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    stride = math.sin(theta)
    cycle = math.cos(theta)
    lift_front = max(0.0, math.sin(theta + math.pi * 0.5))
    lift_back = max(0.0, math.sin(theta - math.pi * 0.5))
    flight = max(0.0, -math.cos(2.0 * theta))

    torso = extract_region(source, masks["torso"])
    arm_back = extract_region(source, masks["arm_back"])
    arm_front = extract_region(source, masks["arm_front"])
    pelvis = extract_region(source, masks["pelvis"])
    leg_back = extract_region(source, masks["leg_back"])
    leg_front = extract_region(source, masks["leg_front"])

    # Forward drive and stronger vertical compression/flight than walk.
    torso = rotate_about(torso, -3.0, p(0.50, 0.56))
    torso = safe_offset(torso, 5 + int(round(2.0 * stride)), -int(round(6.0 * flight)))
    pelvis = safe_offset(pelvis, 4 + int(round(3.0 * stride)), -int(round(5.0 * flight)))

    arm_deg = 18.0 * stride
    arm_back = rotate_about(arm_back, arm_deg, p(0.34, 0.34))
    arm_front = rotate_about(arm_front, -arm_deg, p(0.66, 0.34))

    leg_deg = 24.0 * stride
    leg_back = rotate_about(leg_back, -leg_deg, p(0.40, 0.64))
    leg_front = rotate_about(leg_front, leg_deg, p(0.60, 0.64))
    leg_front = safe_offset(leg_front, int(round(11.0 * stride)), -int(round(16.0 * lift_front + 5.0 * flight)))
    leg_back = safe_offset(leg_back, -int(round(11.0 * stride)), -int(round(16.0 * lift_back + 5.0 * flight)))

    for layer in (leg_back, arm_back, torso, pelvis, leg_front, arm_front):
        out.alpha_composite(layer)

    # Preserve canonical alpha-bounds contact baseline. Flight is encoded in limb/body
    # pose rather than moving the whole sprite root, keeping runtime pivot deterministic.
    fb = alpha_bounds(out)
    if fb != (0, 0, 0, 0):
        source_baseline = bounds[3] - 1
        dy = source_baseline - (fb[3] - 1)
        if dy:
            out = safe_offset(out, 0, dy)
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--source", default="assets/characters/lian_wu/character_lock/lian_wu_neutral.png")
    args = parser.parse_args()
    repo = Path(args.repo_root).resolve()
    source = (repo / args.source).resolve()
    if not source.is_file():
        print(f"VM02_A4_RUN8=BLOCKED source_missing={source}"); return 2
    try:
        canonical_identity = validate_source(source)
    except (OSError, ValueError) as exc:
        print(f"VM02_A4_RUN8=BLOCKED canonical_visual_identity={exc}"); return 3
    actual_source_sha = str(canonical_identity["file_sha256"])
    image = Image.open(source).convert("RGBA")
    if image.size != CANVAS:
        print(f"VM02_A4_RUN8=BLOCKED canvas={image.size} expected={CANVAS}"); return 4
    bounds = alpha_bounds(image)
    if bounds == (0, 0, 0, 0):
        print("VM02_A4_RUN8=BLOCKED empty_alpha"); return 5

    frames_dir = repo / "assets/pack_01_characters/lian_wu/frames/run"
    metadata_dir = repo / "assets/pack_01_characters/lian_wu/metadata"
    frames_dir.mkdir(parents=True, exist_ok=True); metadata_dir.mkdir(parents=True, exist_ok=True)
    for stale in frames_dir.glob("char_lian_wu__run__f*.png"):
        stale.unlink()

    masks = build_region_masks(image.size, bounds)
    source_baseline = bounds[3] - 1
    records, phases = [], []
    for zero_index in range(FRAME_COUNT):
        n = zero_index + 1
        theta = (2.0 * math.pi * zero_index) / FRAME_COUNT
        phase = math.sin(theta)
        phases.append(round(phase, 6))
        frame = composite_run_frame(image, bounds, masks, theta)
        path = frames_dir / f"char_lian_wu__run__f{n:02d}.png"
        frame.save(path, format="PNG", optimize=False, compress_level=9)
        fb = alpha_bounds(frame)
        baseline = fb[3] - 1 if fb != (0, 0, 0, 0) else -1
        if baseline != source_baseline:
            print(f"VM02_A4_RUN8=BLOCKED baseline_drift frame={n} baseline={baseline} source={source_baseline}"); return 6
        records.append({"index": n, "phase": round(phase, 6), "file": str(path.relative_to(repo)).replace("\\", "/"), "sha256": sha256(path), "alpha_bounds": list(fb), "baseline_y": baseline})

    metadata = {
        "schema": "tehkne/taijifu-animation-metadata/v1", "signature": "Tehkné Solutions", "character_id": "lian_wu", "animation": "run", "status": "candidate_pending_godot_review",
        "source_character_lock": {"file": str(source.relative_to(repo)).replace("\\", "/"), "sha256": actual_source_sha, "pivot_policy": "alpha_bounds_bottom_center", "source_alpha_bounds": list(bounds), "baseline_y": source_baseline},
        "generation": {"method": "articulated_region_composite_run_v1", "redraw": False, "global_warp": False, "interpolation": False, "frame_count": FRAME_COUNT, "frame_numbering": "one_based_f01_to_f08", "phases": phases, "loop": True, "fps": FPS, "alpha_visibility_threshold_8bit": ALPHA_THRESHOLD, "visual_review_target": "forward_drive_long_stride_short_contact_flight_readability"},
        "frames": records,
        "gates": {"identity_source_hash": "pass", "canvas": "pass", "transparent_background": "pass", "baseline_continuity": "pass", "articulated_motion_generated": "pass", "godot_visual_review": "pending", "runtime_promotion": "blocked"},
    }
    metadata_path = metadata_dir / "run.json"
    metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("VM02_A4_RUN8=GENERATED"); print(f"source_sha256={actual_source_sha}"); print(f"source_alpha_bounds={bounds}"); print(f"baseline_y={source_baseline}"); print(f"frames={FRAME_COUNT}")
    for r in records: print(f"FRAME_PASS {r['index']:02d} {r['sha256']} {r['file']}")
    print(f"metadata={metadata_path.relative_to(repo)}"); print("VM02_A4_RUN8_GODOT_REVIEW=PENDING")
    return 0


if __name__ == "__main__": sys.exit(main())
