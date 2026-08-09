#!/usr/bin/env python3
"""Generate Lian Wu Jump Loop 3 candidates from the approved Character Lock.

Tehkné Solutions

Three airborne poses bridging Jump Start takeoff to the later Fall sequence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

from lian_wu_canonical_identity import validate_source
from PIL import Image, ImageDraw, ImageFilter

CANVAS = (1024, 1024)
FRAME_COUNT = 3
ALPHA_THRESHOLD = 3
FPS = 9.0


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image):
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


def extract(source, mask):
    return Image.composite(source, Image.new("RGBA", source.size, (0, 0, 0, 0)), mask)


def rotate(layer, degrees, pivot):
    return layer.rotate(
        degrees,
        resample=Image.Resampling.NEAREST,
        center=pivot,
        expand=False,
        fillcolor=(0, 0, 0, 0),
    )


def offset(layer, dx, dy):
    if not dx and not dy:
        return layer
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (dx, dy))
    return out


def build_masks(size, bounds):
    p = lambda x, y: norm_point(bounds, x, y)
    regions = {
        "torso": [p(.14, 0), p(.86, 0), p(.84, .66), p(.16, .66)],
        "arm_back": [p(0, .25), p(.48, .26), p(.47, .73), p(0, .74)],
        "arm_front": [p(.52, .24), p(1, .24), p(1, .74), p(.53, .72)],
        "pelvis": [p(.22, .52), p(.78, .52), p(.78, .78), p(.22, .78)],
        "leg_back": [p(.12, .60), p(.52, .60), p(.56, 1), p(.07, 1)],
        "leg_front": [p(.48, .60), p(.88, .60), p(.94, 1), p(.44, 1)],
    }
    return {k: polygon_mask(size, v) for k, v in regions.items()}


def compose(source, bounds, masks, index):
    p = lambda x, y: norm_point(bounds, x, y)
    # rise -> apex -> settle. Every pose remains clearly airborne.
    presets = [
        dict(body_y=-34, pelvis_y=-31, torso_deg=-7, arm_deg=-21, leg_back_deg=-18, leg_front_deg=20, leg_back_xy=(-6, -24), leg_front_xy=(7, -22)),
        dict(body_y=-43, pelvis_y=-40, torso_deg=-3, arm_deg=-12, leg_back_deg=-10, leg_front_deg=12, leg_back_xy=(-4, -30), leg_front_xy=(5, -28)),
        dict(body_y=-36, pelvis_y=-34, torso_deg=2, arm_deg=-6, leg_back_deg=-5, leg_front_deg=7, leg_back_xy=(-2, -25), leg_front_xy=(4, -24)),
    ]
    q = presets[index]
    layers = {k: extract(source, masks[k]) for k in masks}

    layers["torso"] = rotate(layers["torso"], q["torso_deg"], p(.50, .48))
    layers["arm_back"] = rotate(layers["arm_back"], q["arm_deg"], p(.34, .34))
    layers["arm_front"] = rotate(layers["arm_front"], -q["arm_deg"], p(.66, .34))
    layers["leg_back"] = rotate(layers["leg_back"], q["leg_back_deg"], p(.40, .64))
    layers["leg_front"] = rotate(layers["leg_front"], q["leg_front_deg"], p(.60, .64))

    layers["torso"] = offset(layers["torso"], 3, q["body_y"])
    layers["pelvis"] = offset(layers["pelvis"], 3, q["pelvis_y"])
    layers["leg_back"] = offset(layers["leg_back"], q["leg_back_xy"][0], q["leg_back_xy"][1])
    layers["leg_front"] = offset(layers["leg_front"], q["leg_front_xy"][0], q["leg_front_xy"][1])
    layers["arm_back"] = offset(layers["arm_back"], 2, q["body_y"] + 2)
    layers["arm_front"] = offset(layers["arm_front"], 4, q["body_y"] + 1)

    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for key in ("leg_back", "arm_back", "torso", "pelvis", "leg_front", "arm_front"):
        out.alpha_composite(layers[key])
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--source", default="assets/characters/lian_wu/character_lock/lian_wu_neutral.png")
    args = ap.parse_args()

    repo = Path(args.repo_root).resolve()
    source = (repo / args.source).resolve()
    if not source.is_file():
        print(f"VM02_A6_JUMP_LOOP3=BLOCKED source_missing={source}")
        return 2
    try:
        canonical_identity = validate_source(source)
    except (OSError, ValueError) as exc:
        print(f"VM02_A6_JUMP_LOOP3=BLOCKED canonical_visual_identity={exc}"); return 3
    actual = str(canonical_identity["file_sha256"])
    image = Image.open(source).convert("RGBA")
    if image.size != CANVAS:
        print(f"VM02_A6_JUMP_LOOP3=BLOCKED canvas={image.size} expected={CANVAS}")
        return 4

    bounds = alpha_bounds(image)
    source_baseline = bounds[3] - 1
    masks = build_masks(image.size, bounds)
    frames_dir = repo / "assets/pack_01_characters/lian_wu/frames/jump_loop"
    meta_dir = repo / "assets/pack_01_characters/lian_wu/metadata"
    frames_dir.mkdir(parents=True, exist_ok=True)
    meta_dir.mkdir(parents=True, exist_ok=True)
    for stale in frames_dir.glob("char_lian_wu__jump_loop__f*.png"):
        stale.unlink()

    records = []
    for i in range(FRAME_COUNT):
        frame = compose(image, bounds, masks, i)
        path = frames_dir / f"char_lian_wu__jump_loop__f{i+1:02d}.png"
        frame.save(path, format="PNG", compress_level=9)
        fb = alpha_bounds(frame)
        baseline = fb[3] - 1 if fb != (0, 0, 0, 0) else -1
        if baseline < 0 or baseline >= source_baseline:
            print(f"VM02_A6_JUMP_LOOP3=BLOCKED frame_not_airborne frame={i+1} baseline={baseline} source={source_baseline}")
            return 5
        records.append({
            "index": i + 1,
            "file": str(path.relative_to(repo)).replace("\\", "/"),
            "sha256": sha256(path),
            "alpha_bounds": list(fb),
            "baseline_y": baseline,
            "air_gap_px": source_baseline - baseline,
        })

    if len({r["sha256"] for r in records}) != FRAME_COUNT:
        print("VM02_A6_JUMP_LOOP3=BLOCKED duplicate_frames")
        return 6

    meta = {
        "schema": "tehkne/taijifu-animation-metadata/v1",
        "signature": "Tehkné Solutions",
        "character_id": "lian_wu",
        "animation": "jump_loop",
        "status": "candidate_pending_godot_review",
        "source_character_lock": {
            "file": str(source.relative_to(repo)).replace("\\", "/"),
            "sha256": actual,
            "source_alpha_bounds": list(bounds),
            "baseline_y": source_baseline,
        },
        "generation": {
            "method": "articulated_airborne_hold_v1",
            "frame_count": FRAME_COUNT,
            "frame_numbering": "one_based_f01_to_f03",
            "loop": True,
            "fps": FPS,
            "semantic_phases": ["rise_hold", "apex_hold", "settle_hold"],
            "transition_source": "jump_start:f04",
            "transition_target": "fall:f01",
            "global_warp": False,
            "redraw": False,
        },
        "frames": records,
        "gates": {
            "identity_source_hash": "pass",
            "canvas": "pass",
            "transparent_background": "pass",
            "all_frames_airborne": "pass",
            "distinct_frames": "pass",
            "godot_visual_review": "pending",
            "runtime_promotion": "blocked",
        },
    }
    mp = meta_dir / "jump_loop.json"
    mp.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("VM02_A6_JUMP_LOOP3=GENERATED")
    print(f"source_sha256={actual}")
    print(f"source_alpha_bounds={bounds}")
    print(f"baseline_y={source_baseline}")
    print(f"frames={FRAME_COUNT}")
    for r in records:
        print(f"FRAME_PASS {r['index']:02d} {r['sha256']} gap={r['air_gap_px']} {r['file']}")
    print(f"metadata={mp.relative_to(repo)}")
    print("VM02_A6_JUMP_LOOP3_GODOT_REVIEW=PENDING")
    return 0


if __name__ == "__main__":
    sys.exit(main())
