#!/usr/bin/env python3
"""Materialize Training Rival P01 (idle6 + run8) from one clean canonical master.

P01 v3 keeps the complete upper body, arms and wooden training saber as one rigid visual
block. Only two mutually-exclusive side-leg masks are articulated during run. This removes
the overlapping-region failure that duplicated/split the saber in the original C39 pass.

No contact sheet, background removal, redraw or second weapon is allowed.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

try:
    from PIL import Image, ImageChops, ImageDraw
except ImportError as exc:
    raise SystemExit("VM02_C39_P01=BLOCKED missing Pillow") from exc

CANVAS = (1024, 1024)
ALPHA_THRESHOLD = 3
IDLE_COUNT = 6
RUN_COUNT = 8
LIAN_WU_LOCK_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANONICAL_NAME = "char_training_rival__{animation}__f{frame:03d}.png"


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


def visible_mask(image: Image.Image) -> Image.Image:
    return image.convert("RGBA").getchannel("A").point(
        lambda value: 255 if value >= ALPHA_THRESHOLD else 0
    )


def norm_point(bounds, nx: float, ny: float) -> tuple[int, int]:
    x0, y0, x1, y1 = bounds
    return (
        int(round(x0 + (x1 - x0) * nx)),
        int(round(y0 + (y1 - y0) * ny)),
    )


def rectangle_region(source_mask: Image.Image, bounds, nx0, ny0, nx1, ny1) -> Image.Image:
    mask = Image.new("L", source_mask.size, 0)
    ImageDraw.Draw(mask).rectangle(
        [norm_point(bounds, nx0, ny0), norm_point(bounds, nx1, ny1)],
        fill=255,
    )
    return ImageChops.multiply(mask, source_mask)


def build_disjoint_masks(source: Image.Image, bounds):
    source_mask = visible_mask(source)
    # Full lateral coverage below the hip line. A narrow central strip remains with the
    # upper block so sash/pelvis never become detached moving fragments.
    leg_back = rectangle_region(source_mask, bounds, 0.00, 0.575, 0.485, 1.00)
    leg_front = rectangle_region(source_mask, bounds, 0.515, 0.575, 1.00, 1.00)
    leg_front = ImageChops.subtract(leg_front, leg_back)
    legs_union = ImageChops.lighter(leg_back, leg_front)
    upper_weapon = ImageChops.subtract(source_mask, legs_union)

    overlap = ImageChops.multiply(leg_back, leg_front).getbbox()
    if overlap is not None:
        raise RuntimeError(f"disjoint_mask_overlap={overlap}")
    return {
        "upper_weapon": upper_weapon,
        "leg_back": leg_back,
        "leg_front": leg_front,
    }


def extract(source: Image.Image, mask: Image.Image) -> Image.Image:
    return Image.composite(source, Image.new("RGBA", source.size, (0, 0, 0, 0)), mask)


def rotate(layer: Image.Image, degrees: float, pivot) -> Image.Image:
    return layer.rotate(
        degrees,
        resample=Image.Resampling.BICUBIC,
        center=pivot,
        expand=False,
        fillcolor=(0, 0, 0, 0),
    )


def offset(layer: Image.Image, dx: int, dy: int) -> Image.Image:
    if dx == 0 and dy == 0:
        return layer
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.alpha_composite(layer, (int(dx), int(dy)))
    return out


def baseline_lock(frame: Image.Image, source_baseline: int) -> Image.Image:
    fb = alpha_bounds(frame)
    if fb == (0, 0, 0, 0):
        return frame
    dy = source_baseline - (fb[3] - 1)
    return offset(frame, 0, dy) if dy else frame


def compose_idle(source: Image.Image, bounds, theta: float) -> Image.Image:
    # Breathing is a tiny whole-sprite transform. Weapon/body continuity is therefore exact.
    pivot = norm_point(bounds, 0.50, 0.94)
    frame = rotate(source, 0.22 * math.sin(theta), pivot)
    frame = offset(
        frame,
        int(round(0.6 * math.sin(theta))),
        -int(round(1.5 * (0.5 + 0.5 * math.sin(theta)))),
    )
    return baseline_lock(frame, bounds[3] - 1)


def compose_run(source: Image.Image, bounds, masks, theta: float) -> Image.Image:
    p = lambda x, y: norm_point(bounds, x, y)
    source_baseline = bounds[3] - 1
    upper = extract(source, masks["upper_weapon"])
    back = extract(source, masks["leg_back"])
    front = extract(source, masks["leg_front"])

    s = math.sin(theta)
    c = math.cos(theta)
    bob = -int(round(4.0 * abs(c)))

    # Upper body + both hands + saber stay rigid; only translation/bob is allowed.
    upper = offset(upper, int(round(-2.5 * s)), bob)

    back = rotate(back, -15.0 * s, p(0.36, 0.63))
    front = rotate(front, 15.0 * s, p(0.66, 0.63))
    back = offset(
        back,
        int(round(-7.0 * s)),
        bob - int(round(11.0 * max(0.0, -s))),
    )
    front = offset(
        front,
        int(round(7.0 * s)),
        bob - int(round(11.0 * max(0.0, s))),
    )

    frame = Image.new("RGBA", source.size, (0, 0, 0, 0))
    frame.alpha_composite(back)
    frame.alpha_composite(front)
    frame.alpha_composite(upper)
    return baseline_lock(frame, source_baseline)


def validate_clean_source(image: Image.Image, source_hash: str) -> tuple[bool, str]:
    if image.size != CANVAS:
        return False, f"canvas={image.size} expected={CANVAS}"
    if source_hash == LIAN_WU_LOCK_SHA256:
        return False, "source_matches_lian_wu_character_lock"
    if image.mode != "RGBA":
        return False, f"mode={image.mode} expected=RGBA"
    bounds = alpha_bounds(image)
    if bounds == (0, 0, 0, 0):
        return False, "empty_alpha"
    x0, y0, x1, y1 = bounds
    if x0 <= 1 or y0 <= 1 or x1 >= CANVAS[0] - 1 or y1 >= CANVAS[1] - 1:
        return False, "foreground_touches_canvas_edge"
    alpha = image.getchannel("A")
    for xy in ((0, 0), (1023, 0), (0, 1023), (1023, 1023)):
        if alpha.getpixel(xy) != 0:
            return False, "nontransparent_canvas_corner"
    return True, "pass"


def save_sequence(source, bounds, masks, out_root: Path, mode: str, count: int):
    dest = out_root / mode
    dest.mkdir(parents=True, exist_ok=True)
    records = []
    source_baseline = bounds[3] - 1
    for index in range(count):
        theta = 2.0 * math.pi * index / count
        frame = (
            compose_idle(source, bounds, theta)
            if mode == "idle"
            else compose_run(source, bounds, masks, theta)
        )
        filename = CANONICAL_NAME.format(animation=mode, frame=index + 1)
        path = dest / filename
        frame.save(path, "PNG", optimize=True, compress_level=9)
        fb = alpha_bounds(frame)
        baseline = fb[3] - 1 if fb != (0, 0, 0, 0) else -1
        if baseline != source_baseline:
            raise RuntimeError(
                f"baseline_drift {mode}/{filename} {baseline}!={source_baseline}"
            )
        records.append({
            "index": index + 1,
            "phase": round(math.sin(theta), 6),
            "file": str(path.relative_to(out_root)).replace("\\", "/"),
            "sha256": sha256(path),
            "alpha_bounds": list(fb),
            "baseline_y": baseline,
        })
    return records


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output-root", required=True)
    args = parser.parse_args()

    source_path = Path(args.source).resolve()
    out_root = Path(args.output_root).resolve()
    if not source_path.is_file():
        print(f"VM02_C39_P01=BLOCKED source_missing={source_path}")
        return 2

    source_hash = sha256(source_path)
    with Image.open(source_path) as opened:
        if opened.mode != "RGBA":
            print(f"VM02_C39_P01=BLOCKED source_contract=mode={opened.mode} expected=RGBA")
            return 3
        source = opened.copy()

    ok, why = validate_clean_source(source, source_hash)
    if not ok:
        print(f"VM02_C39_P01=BLOCKED source_contract={why}")
        return 3

    bounds = alpha_bounds(source)
    masks = build_disjoint_masks(source, bounds)
    idle = save_sequence(source, bounds, masks, out_root, "idle", IDLE_COUNT)
    run = save_sequence(source, bounds, masks, out_root, "run", RUN_COUNT)
    hashes = {record["sha256"] for record in idle + run}
    if len(hashes) < 8:
        print(f"VM02_C39_P01=BLOCKED insufficient_unique_frames={len(hashes)}/14")
        return 4

    manifest = {
        "schema": "tehkne/taijifu-training-rival-p01/v3",
        "signature": "Tehkné Solutions",
        "character_id": "training_rival",
        "pack": "P01",
        "version": "3.0.0-weapon-safe-candidate",
        "source": {
            "file": str(source_path),
            "sha256": source_hash,
            "alpha_bounds": list(bounds),
            "baseline_y": bounds[3] - 1,
        },
        "contract": {
            "style": "comic_manga_2_5d_martial_fantasy",
            "native_facing": "left",
            "pivot": "bottom_center",
            "weapon": "single_wooden_training_saber",
            "canonical_naming": "char_training_rival__<animation>__f<frame-3-digits>.png",
        },
        "generation": {
            "method": "disjoint_side_leg_masks_rigid_upper_weapon",
            "upper_and_weapon_are_single_rigid_block": True,
            "leg_masks_mutually_exclusive": True,
            "central_sash_owner": "upper_weapon",
            "contact_sheet_as_source": False,
            "background_removal": False,
            "idle_frames": IDLE_COUNT,
            "run_frames": RUN_COUNT,
        },
        "idle": idle,
        "run": run,
        "gates": {
            "clean_source": "pass",
            "not_lian_source": "pass",
            "transparent_background": "pass",
            "weapon_duplication_structurally_prevented": "pass",
            "detached_lower_body_fragment_structurally_prevented": "pass",
            "baseline_continuity": "pass",
            "canonical_naming": "pass",
            "unique_frame_floor": "pass",
            "visual_review": "pending",
        },
    }
    (out_root / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print("VM02_C39_P01=GENERATED")
    print(f"source_sha256={source_hash}")
    print(f"source_alpha_bounds={bounds}")
    print(f"baseline_y={bounds[3] - 1}")
    print("idle_frames=6")
    print("run_frames=8")
    print(f"unique_hashes={len(hashes)}")
    print("weapon_duplication_structurally_prevented=true")
    print("detached_lower_body_fragment_structurally_prevented=true")
    print("canonical_naming=true")
    print("VM02_C39_P01_VISUAL_REVIEW=PENDING")
    return 0


if __name__ == "__main__":
    sys.exit(main())
