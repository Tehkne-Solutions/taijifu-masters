#!/usr/bin/env python3
"""Generate Lian Wu ji_body_hook 6-keypose visual attack sequence.

The six PNGs are visual key poses, not a replacement for TechniqueCatalog's
logical startup/active/recovery frame timings. VM02-C3 maps the logical combat
window onto these poses.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
import sys

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as exc:
    raise SystemExit(
        "VM02_C2_BODY_HOOK6=BLOCKED missing dependency Pillow. Install with: python -m pip install Pillow"
    ) from exc

EXPECTED_SOURCE_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANVAS = (1024, 1024)
FRAME_COUNT = 6
ALPHA_THRESHOLD = 3
KEYPOSES = ["guard", "chamber", "torque", "impact", "recoil", "recover"]
ACTIVE_KEYPOSES = [4]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
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
        "torso": [p(0.12, 0.00), p(0.88, 0.00), p(0.84, 0.64), p(0.16, 0.64)],
        "arm_back": [p(0.00, 0.22), p(0.49, 0.22), p(0.48, 0.73), p(0.00, 0.76)],
        "arm_front": [p(0.51, 0.20), p(1.00, 0.20), p(1.00, 0.76), p(0.52, 0.73)],
        "pelvis": [p(0.20, 0.51), p(0.80, 0.51), p(0.80, 0.78), p(0.20, 0.78)],
        "legs": [p(0.07, 0.60), p(0.93, 0.60), p(0.96, 1.00), p(0.04, 1.00)],
    }
    return {name: polygon_mask(size, pts) for name, pts in regions.items()}


def extract_region(source, mask):
    return Image.composite(source, Image.new("RGBA", source.size, (0, 0, 0, 0)), mask)


def rotate_about(layer, degrees, pivot):
    return layer.rotate(
        degrees,
        resample=Image.Resampling.NEAREST,
        center=pivot,
        expand=False,
        fillcolor=(0, 0, 0, 0),
    )


def safe_offset(layer, dx, dy):
    if not dx and not dy:
        return layer
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (int(dx), int(dy)))
    return out


def build_pose(source, bounds, masks, preset):
    p = lambda x, y: norm_point(bounds, x, y)
    torso = extract_region(source, masks["torso"])
    arm_back = extract_region(source, masks["arm_back"])
    arm_front = extract_region(source, masks["arm_front"])
    pelvis = extract_region(source, masks["pelvis"])
    legs = extract_region(source, masks["legs"])

    torso = rotate_about(torso, preset["torso_rot"], p(0.50, 0.47))
    torso = safe_offset(torso, preset["torso_dx"], preset["torso_dy"])
    pelvis = safe_offset(pelvis, preset["pelvis_dx"], preset["pelvis_dy"])
    legs = safe_offset(legs, preset["legs_dx"], 0)

    arm_back = rotate_about(arm_back, preset["back_rot"], p(0.34, 0.34))
    arm_back = safe_offset(arm_back, preset["back_dx"], preset["back_dy"])
    arm_front = rotate_about(arm_front, preset["front_rot"], p(0.66, 0.34))
    arm_front = safe_offset(arm_front, preset["front_dx"], preset["front_dy"])

    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for layer in (legs, arm_back, torso, pelvis, arm_front):
        out.alpha_composite(layer)

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
    parser.add_argument(
        "--source",
        default="assets/characters/lian_wu/character_lock/lian_wu_neutral.png",
    )
    args = parser.parse_args()
    repo = Path(args.repo_root).resolve()
    source_path = (repo / args.source).resolve()
    if not source_path.is_file():
        print(f"VM02_C2_BODY_HOOK6=BLOCKED source_missing={source_path}")
        return 2
    source_sha = sha256(source_path)
    if source_sha != EXPECTED_SOURCE_SHA256:
        print("VM02_C2_BODY_HOOK6=BLOCKED source_hash_mismatch")
        print(f"expected={EXPECTED_SOURCE_SHA256}")
        print(f"actual={source_sha}")
        return 3

    source = Image.open(source_path).convert("RGBA")
    if source.size != CANVAS:
        print(f"VM02_C2_BODY_HOOK6=BLOCKED canvas={source.size} expected={CANVAS}")
        return 4
    bounds = alpha_bounds(source)
    if bounds == (0, 0, 0, 0):
        print("VM02_C2_BODY_HOOK6=BLOCKED empty_alpha")
        return 5

    frames_dir = repo / "assets/pack_01_characters/lian_wu/frames/attacks/ji_body_hook"
    metadata_dir = repo / "assets/pack_01_characters/lian_wu/metadata"
    frames_dir.mkdir(parents=True, exist_ok=True)
    metadata_dir.mkdir(parents=True, exist_ok=True)
    for stale in frames_dir.glob("char_lian_wu__ji_body_hook__f*.png"):
        stale.unlink()

    # Regional articulation presets: compact chamber -> torso torque -> short body hook.
    presets = [
        None,
        dict(torso_rot=2.0, torso_dx=-3, torso_dy=1, pelvis_dx=-2, pelvis_dy=1, legs_dx=0,
             back_rot=-8.0, back_dx=-1, back_dy=1, front_rot=14.0, front_dx=-7, front_dy=3),
        dict(torso_rot=-4.0, torso_dx=-1, torso_dy=0, pelvis_dx=-3, pelvis_dy=1, legs_dx=-1,
             back_rot=10.0, back_dx=2, back_dy=0, front_rot=30.0, front_dx=-3, front_dy=-2),
        dict(torso_rot=-8.0, torso_dx=7, torso_dy=-1, pelvis_dx=2, pelvis_dy=0, legs_dx=1,
             back_rot=18.0, back_dx=4, back_dy=-1, front_rot=-24.0, front_dx=24, front_dy=-7),
        dict(torso_rot=-2.0, torso_dx=3, torso_dy=0, pelvis_dx=1, pelvis_dy=0, legs_dx=0,
             back_rot=7.0, back_dx=1, back_dy=0, front_rot=-7.0, front_dx=9, front_dy=-2),
        None,
    ]

    masks = build_region_masks(source.size, bounds)
    baseline = bounds[3] - 1
    records = []
    for idx, keypose in enumerate(KEYPOSES, start=1):
        frame_path = frames_dir / f"char_lian_wu__ji_body_hook__f{idx:02d}.png"
        if presets[idx - 1] is None:
            # Preserve byte-identical neutral handoff at guard/recover.
            shutil.copyfile(source_path, frame_path)
            frame = Image.open(frame_path).convert("RGBA")
        else:
            frame = build_pose(source, bounds, masks, presets[idx - 1])
            frame.save(frame_path, format="PNG", optimize=False, compress_level=9)
        fb = alpha_bounds(frame)
        frame_baseline = fb[3] - 1 if fb != (0, 0, 0, 0) else -1
        if frame_baseline != baseline:
            print(
                f"VM02_C2_BODY_HOOK6=BLOCKED baseline_drift frame={idx} baseline={frame_baseline} source={baseline}"
            )
            return 6
        records.append(
            {
                "index": idx,
                "keypose": keypose,
                "phase_hint": "active" if idx in ACTIVE_KEYPOSES else ("startup" if idx < 4 else "recovery"),
                "file": str(frame_path.relative_to(repo)).replace("\\", "/"),
                "sha256": sha256(frame_path),
                "alpha_bounds": list(fb),
                "baseline_y": frame_baseline,
            }
        )

    # Minimum visual differentiation gates.
    unique_hashes = len({record["sha256"] for record in records})
    if unique_hashes < 5:
        print(f"VM02_C2_BODY_HOOK6=BLOCKED insufficient_pose_diversity unique_hashes={unique_hashes}")
        return 7
    if records[0]["sha256"] != source_sha or records[-1]["sha256"] != source_sha:
        print("VM02_C2_BODY_HOOK6=BLOCKED neutral_handoff_hash")
        return 8

    metadata = {
        "schema": "tehkne/taijifu-animation-metadata/v1",
        "signature": "Tehkné Solutions",
        "character_id": "lian_wu",
        "animation": "ji_body_hook",
        "status": "candidate_pending_godot_review",
        "source_character_lock": {
            "file": str(source_path.relative_to(repo)).replace("\\", "/"),
            "sha256": source_sha,
            "pivot_policy": "alpha_bounds_bottom_center",
            "source_alpha_bounds": list(bounds),
            "baseline_y": baseline,
        },
        "generation": {
            "method": "articulated_region_composite_body_hook_v1",
            "frame_count": FRAME_COUNT,
            "keyposes": KEYPOSES,
            "active_keyposes": ACTIVE_KEYPOSES,
            "logical_timing_source": "TechniqueCatalog/ji_body_hook startup=4 active=4 recovery=10 @60fps",
            "note": "visual keyposes are mapped to logical attack windows during runtime integration",
            "loop": False,
            "transparent_background": True,
        },
        "frames": records,
        "gates": {
            "identity_source_hash": "pass",
            "canvas": "pass",
            "baseline_continuity": "pass",
            "neutral_guard_handoff": "pass",
            "neutral_recover_handoff": "pass",
            "pose_diversity": "pass",
            "godot_visual_review": "pending",
            "runtime_binding": "blocked_pending_c3",
        },
    }
    metadata_path = metadata_dir / "ji_body_hook.json"
    metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("VM02_C2_BODY_HOOK6=GENERATED")
    print(f"source_sha256={source_sha}")
    print(f"source_alpha_bounds={bounds}")
    print(f"baseline_y={baseline}")
    print(f"frames={FRAME_COUNT}")
    print(f"unique_hashes={unique_hashes}")
    for record in records:
        print(
            f"FRAME_PASS {record['index']:02d} {record['keypose']} {record['sha256']} {record['file']}"
        )
    print("neutral_handoff_hash=PASS")
    print(f"metadata={metadata_path.relative_to(repo)}")
    print("VM02_C2_BODY_HOOK6_GODOT_REVIEW=PENDING")
    return 0


if __name__ == "__main__":
    sys.exit(main())
