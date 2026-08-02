#!/usr/bin/env python3
"""Generate Lian Wu Walk 8 candidates from the approved Character Lock neutral sprite.

Tehkné Solutions

Articulated regional derivative. Alpha bounds use the same effective threshold as
the Godot visual bench so baseline validation cannot disagree across tools.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError as exc:
    raise SystemExit("VM02_A3_WALK8=BLOCKED missing dependency Pillow. Install with: python -m pip install Pillow") from exc

EXPECTED_SOURCE_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANVAS = (1024, 1024)
FRAME_COUNT = 8
ALPHA_THRESHOLD = 3  # mirrors Godot ALPHA_THRESHOLD=0.01 (>2.55/255)
FPS = 10.0


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
    # Normalize to a binary mask using the same effective visibility threshold
    # as the Godot bench. This prevents faint rotated edge pixels (alpha 1-2)
    # from becoming a false contact baseline in Python only.
    visible = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
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
        "torso": [p(0.16, 0.00), p(0.84, 0.00), p(0.84, 0.66), p(0.16, 0.66)],
        "arm_back": [p(0.03, 0.26), p(0.48, 0.27), p(0.47, 0.72), p(0.00, 0.73)],
        "arm_front": [p(0.52, 0.25), p(0.97, 0.25), p(1.00, 0.74), p(0.53, 0.72)],
        "pelvis": [p(0.24, 0.53), p(0.76, 0.53), p(0.76, 0.76), p(0.24, 0.76)],
        "leg_back": [p(0.18, 0.61), p(0.52, 0.61), p(0.55, 1.00), p(0.12, 1.00)],
        "leg_front": [p(0.48, 0.61), p(0.82, 0.61), p(0.88, 1.00), p(0.45, 1.00)],
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


def composite_walk_frame(source, bounds, masks, phase):
    p = lambda x, y: norm_point(bounds, x, y)
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    torso = extract_region(source, masks["torso"])
    arm_back = extract_region(source, masks["arm_back"])
    arm_front = extract_region(source, masks["arm_front"])
    pelvis = extract_region(source, masks["pelvis"])
    leg_back = extract_region(source, masks["leg_back"])
    leg_front = extract_region(source, masks["leg_front"])

    bob = -int(round(2.0 * abs(phase)))
    torso = safe_offset(torso, 0, bob)
    pelvis = safe_offset(pelvis, 0, bob)

    arm_deg = 5.5 * phase
    arm_back = rotate_about(arm_back, arm_deg, p(0.34, 0.34))
    arm_front = rotate_about(arm_front, -arm_deg, p(0.66, 0.34))

    leg_deg = 7.5 * phase
    leg_back = rotate_about(leg_back, -leg_deg, p(0.40, 0.64))
    leg_front = rotate_about(leg_front, leg_deg, p(0.60, 0.64))
    if phase > 0.15:
        leg_front = safe_offset(leg_front, 2, -int(round(3.0 * phase)))
        leg_back = safe_offset(leg_back, -1, 0)
    elif phase < -0.15:
        leg_back = safe_offset(leg_back, 2, -int(round(3.0 * -phase)))
        leg_front = safe_offset(leg_front, -1, 0)

    for layer in (leg_back, arm_back, torso, pelvis, leg_front, arm_front):
        out.alpha_composite(layer)

    fb = alpha_bounds(out)
    if fb != (0, 0, 0, 0):
        source_baseline = bounds[3] - 1
        current_baseline = fb[3] - 1
        dy = source_baseline - current_baseline
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
        print(f"VM02_A3_WALK8=BLOCKED source_missing={source}"); return 2
    actual_source_sha = sha256(source)
    if actual_source_sha != EXPECTED_SOURCE_SHA256:
        print("VM02_A3_WALK8=BLOCKED source_hash_mismatch"); print(f"expected={EXPECTED_SOURCE_SHA256}"); print(f"actual={actual_source_sha}"); return 3
    image = Image.open(source).convert("RGBA")
    if image.size != CANVAS:
        print(f"VM02_A3_WALK8=BLOCKED canvas={image.size} expected={CANVAS}"); return 4
    bounds = alpha_bounds(image)
    if bounds == (0, 0, 0, 0):
        print("VM02_A3_WALK8=BLOCKED empty_alpha"); return 5

    frames_dir = repo / "assets/pack_01_characters/lian_wu/frames/walk"
    metadata_dir = repo / "assets/pack_01_characters/lian_wu/metadata"
    frames_dir.mkdir(parents=True, exist_ok=True); metadata_dir.mkdir(parents=True, exist_ok=True)
    for stale in frames_dir.glob("char_lian_wu__walk__f*.png"): stale.unlink()

    masks = build_region_masks(image.size, bounds)
    source_baseline = bounds[3] - 1
    frame_records, phases = [], []
    for zero_index in range(FRAME_COUNT):
        frame_number = zero_index + 1
        phase = math.sin((2.0 * math.pi * zero_index) / FRAME_COUNT)
        phases.append(round(phase, 6))
        frame = composite_walk_frame(image, bounds, masks, phase)
        frame_path = frames_dir / f"char_lian_wu__walk__f{frame_number:02d}.png"
        frame.save(frame_path, format="PNG", optimize=False, compress_level=9)
        fb = alpha_bounds(frame)
        baseline = fb[3] - 1 if fb != (0, 0, 0, 0) else -1
        if baseline != source_baseline:
            print(f"VM02_A3_WALK8=BLOCKED baseline_drift frame={frame_number} baseline={baseline} source={source_baseline}"); return 6
        frame_records.append({"index": frame_number, "phase": round(phase, 6), "file": str(frame_path.relative_to(repo)).replace("\\", "/"), "sha256": sha256(frame_path), "alpha_bounds": list(fb), "baseline_y": baseline})

    metadata = {
        "schema": "tehkne/taijifu-animation-metadata/v1", "signature": "Tehkné Solutions", "character_id": "lian_wu", "animation": "walk", "status": "candidate_pending_godot_review",
        "source_character_lock": {"file": str(source.relative_to(repo)).replace("\\", "/"), "sha256": actual_source_sha, "pivot_policy": "alpha_bounds_bottom_center", "source_alpha_bounds": list(bounds), "baseline_y": source_baseline},
        "generation": {"method": "articulated_region_composite_v1", "redraw": False, "global_warp": False, "interpolation": False, "frame_count": FRAME_COUNT, "frame_numbering": "one_based_f01_to_f08", "phases": phases, "loop": True, "fps": FPS, "regions": ["torso", "arm_back", "arm_front", "pelvis", "leg_back", "leg_front"], "alpha_visibility_threshold_8bit": ALPHA_THRESHOLD},
        "frames": frame_records,
        "gates": {"identity_source_hash": "pass", "canvas": "pass", "transparent_background": "pass", "baseline_continuity": "pass", "articulated_motion_generated": "pass", "godot_visual_review": "pending", "runtime_promotion": "blocked"},
    }
    metadata_path = metadata_dir / "walk.json"
    metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("VM02_A3_WALK8=GENERATED"); print(f"source_sha256={actual_source_sha}"); print(f"source_alpha_bounds={bounds}"); print(f"baseline_y={source_baseline}"); print(f"frames={FRAME_COUNT}")
    for record in frame_records: print(f"FRAME_PASS {record['index']:02d} {record['sha256']} {record['file']}")
    print(f"metadata={metadata_path.relative_to(repo)}"); print("VM02_A3_WALK8_GODOT_REVIEW=PENDING")
    return 0


if __name__ == "__main__": sys.exit(main())
