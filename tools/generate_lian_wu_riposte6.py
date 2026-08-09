#!/usr/bin/env python3
"""Generate Lian Wu ji_riposte 6-keypose visual sequence.

Visual-only keyposes for VM02-C20. Combat timing/damage remain owned by the
validated C19 riposte contract.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

from lian_wu_canonical_identity import validate_source

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as exc:
    raise SystemExit("VM02_C20_RIPOSTE6=BLOCKED missing Pillow") from exc

CANVAS = (1024, 1024)
FRAME_COUNT = 6
ALPHA_THRESHOLD = 3
KEYPOSES = ["guard", "slip", "chamber", "riposte_active", "recoil", "recover"]
ACTIVE_KEYPOSES = [4]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image):
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


def build_masks(size, bounds):
    p = lambda x, y: norm_point(bounds, x, y)
    regions = {
        "torso": [p(0.12, 0.00), p(0.88, 0.00), p(0.84, 0.64), p(0.16, 0.64)],
        "back": [p(0.00, 0.20), p(0.50, 0.20), p(0.49, 0.74), p(0.00, 0.77)],
        "front": [p(0.50, 0.18), p(1.00, 0.18), p(1.00, 0.77), p(0.51, 0.74)],
        "pelvis": [p(0.18, 0.50), p(0.82, 0.50), p(0.82, 0.79), p(0.18, 0.79)],
        "legs": [p(0.04, 0.60), p(0.96, 0.60), p(0.98, 1.00), p(0.02, 1.00)],
    }
    return {name: polygon_mask(size, pts) for name, pts in regions.items()}


def extract(source, mask):
    return Image.composite(source, Image.new("RGBA", source.size, (0, 0, 0, 0)), mask)


def rotate(layer, degrees, pivot):
    return layer.rotate(degrees, resample=Image.Resampling.NEAREST, center=pivot, expand=False, fillcolor=(0, 0, 0, 0))


def offset(layer, dx, dy):
    if not dx and not dy:
        return layer
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (int(dx), int(dy)))
    return out


def pose(source, bounds, masks, preset):
    p = lambda x, y: norm_point(bounds, x, y)
    torso = offset(rotate(extract(source, masks["torso"]), preset["torso_rot"], p(0.50, 0.46)), preset["torso_dx"], preset["torso_dy"])
    back = offset(rotate(extract(source, masks["back"]), preset["back_rot"], p(0.34, 0.34)), preset["back_dx"], preset["back_dy"])
    front = offset(rotate(extract(source, masks["front"]), preset["front_rot"], p(0.66, 0.34)), preset["front_dx"], preset["front_dy"])
    pelvis = offset(extract(source, masks["pelvis"]), preset["pelvis_dx"], preset["pelvis_dy"])
    legs = offset(extract(source, masks["legs"]), preset["legs_dx"], 0)
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for layer in (legs, back, torso, pelvis, front):
        out.alpha_composite(layer)
    fb = alpha_bounds(out)
    if fb != (0, 0, 0, 0):
        dy = (bounds[3] - 1) - (fb[3] - 1)
        if dy:
            out = offset(out, 0, dy)
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--source", default="assets/characters/lian_wu/character_lock/lian_wu_neutral.png")
    args = parser.parse_args()
    repo = Path(args.repo_root).resolve()
    source_path = (repo / args.source).resolve()
    if not source_path.is_file():
        print(f"VM02_C20_RIPOSTE6=BLOCKED source_missing={source_path}")
        return 2
    try:
        canonical_identity = validate_source(source_path)
    except (OSError, ValueError) as exc:
        print(f"VM02_C20_RIPOSTE6=BLOCKED canonical_visual_identity={exc}"); return 3
    source_sha = str(canonical_identity["file_sha256"])
    source = Image.open(source_path).convert("RGBA")
    if source.size != CANVAS:
        print(f"VM02_C20_RIPOSTE6=BLOCKED canvas={source.size}")
        return 4
    bounds = alpha_bounds(source)
    baseline = bounds[3] - 1
    frames_dir = repo / "assets/pack_01_characters/lian_wu/frames/attacks/ji_riposte"
    metadata_dir = repo / "assets/pack_01_characters/lian_wu/metadata"
    frames_dir.mkdir(parents=True, exist_ok=True)
    metadata_dir.mkdir(parents=True, exist_ok=True)
    for stale in frames_dir.glob("char_lian_wu__ji_riposte__f*.png"):
        stale.unlink()

    # Defensive slip -> compressed chamber -> fast linear counter -> recoil.
    presets = [
        None,
        dict(torso_rot=7.0, torso_dx=-8, torso_dy=1, pelvis_dx=-5, pelvis_dy=1, legs_dx=-4, back_rot=-18.0, back_dx=-4, back_dy=1, front_rot=18.0, front_dx=-8, front_dy=0),
        dict(torso_rot=-7.0, torso_dx=-3, torso_dy=0, pelvis_dx=-4, pelvis_dy=1, legs_dx=-2, back_rot=20.0, back_dx=5, back_dy=-2, front_rot=34.0, front_dx=-4, front_dy=-5),
        dict(torso_rot=-12.0, torso_dx=13, torso_dy=-2, pelvis_dx=4, pelvis_dy=0, legs_dx=2, back_rot=24.0, back_dx=7, back_dy=-3, front_rot=-38.0, front_dx=38, front_dy=-12),
        dict(torso_rot=-3.0, torso_dx=7, torso_dy=0, pelvis_dx=2, pelvis_dy=0, legs_dx=1, back_rot=8.0, back_dx=2, back_dy=0, front_rot=-12.0, front_dx=15, front_dy=-4),
        None,
    ]
    masks = build_masks(source.size, bounds)
    records = []
    for idx, keypose in enumerate(KEYPOSES, 1):
        path = frames_dir / f"char_lian_wu__ji_riposte__f{idx:02d}.png"
        if presets[idx - 1] is None:
            shutil.copyfile(source_path, path)
            frame = Image.open(path).convert("RGBA")
        else:
            frame = pose(source, bounds, masks, presets[idx - 1])
            frame.save(path, format="PNG", optimize=False, compress_level=9)
        fb = alpha_bounds(frame)
        frame_baseline = fb[3] - 1 if fb != (0, 0, 0, 0) else -1
        if frame_baseline != baseline:
            print(f"VM02_C20_RIPOSTE6=BLOCKED baseline frame={idx} actual={frame_baseline} expected={baseline}")
            return 5
        records.append({"index": idx, "keypose": keypose, "file": str(path.relative_to(repo)).replace("\\", "/"), "sha256": sha256(path), "baseline_y": frame_baseline})
    unique_hashes = len({r["sha256"] for r in records})
    if unique_hashes < 5:
        print(f"VM02_C20_RIPOSTE6=BLOCKED diversity={unique_hashes}")
        return 6
    if records[0]["sha256"] != source_sha or records[-1]["sha256"] != source_sha:
        print("VM02_C20_RIPOSTE6=BLOCKED neutral_handoff")
        return 7
    metadata = {
        "schema": "tehkne/taijifu-animation-metadata/v1",
        "signature": "Tehkné Solutions",
        "character_id": "lian_wu",
        "animation": "ji_riposte",
        "status": "candidate_pending_runtime_review",
        "source_character_lock": {"file": str(source_path.relative_to(repo)).replace("\\", "/"), "sha256": source_sha, "baseline_y": baseline},
        "generation": {"method": "articulated_region_composite_riposte_v1", "frame_count": FRAME_COUNT, "keyposes": KEYPOSES, "active_keyposes": ACTIVE_KEYPOSES, "combat_contract": "VM02-C19 ji_riposte", "transparent_background": True},
        "frames": records,
    }
    meta = metadata_dir / "ji_riposte.json"
    meta.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("VM02_C20_RIPOSTE6=GENERATED")
    print(f"source_sha256={source_sha}")
    print(f"baseline_y={baseline}")
    print(f"frames={FRAME_COUNT}")
    print(f"unique_hashes={unique_hashes}")
    for record in records:
        print(f"FRAME_PASS {record['index']:02d} {record['keypose']} {record['sha256']} {record['file']}")
    print("neutral_handoff_hash=PASS")
    print(f"metadata={meta.relative_to(repo)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
