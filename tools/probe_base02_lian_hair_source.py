#!/usr/bin/env python3
"""C66.1 diagnostic only: test exact Lian Hair reuse without redrawing.

The probe never promotes assets. It preserves exact source pixels and produces
front/back full-canvas diagnostic modules plus a BASE-00 composition for owner
visual review. Tehkné Solutions.
"""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
LIAN = ROOT / "assets/characters/lian_wu/character_lock/lian_wu_neutral.png"
BASE = ROOT / "assets/modular_fighters/base_00/base_fighter_v1_master.png"
OUT = ROOT / "artifacts/c66_1_hair_source_probe"
EXPECTED_LIAN_SHA = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
EXPECTED_BASE_SHA = "fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe"
HEAD_BOX = (250, 40, 780, 430)
CANVAS = (1024, 1024)
GAMEPLAY_HEIGHT = 132


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def used_bbox(image: Image.Image):
    return image.getchannel("A").getbbox()


def checkerboard(size: tuple[int, int], cell: int = 24) -> Image.Image:
    out = Image.new("RGBA", size, (235, 235, 235, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle(
                    (x, y, min(x + cell - 1, size[0] - 1), min(y + cell - 1, size[1] - 1)),
                    fill=(205, 205, 205, 255),
                )
    return out


def alpha_preview(image: Image.Image) -> Image.Image:
    bg = checkerboard(image.size)
    bg.alpha_composite(image)
    return bg


def binary_bbox(mask: Image.Image):
    return mask.getbbox()


def connected_components(mask: Image.Image, min_pixels: int = 8):
    w, h = mask.size
    pixels = mask.load()
    seen = bytearray(w * h)
    components = []
    for y in range(h):
        for x in range(w):
            idx = y * w + x
            if seen[idx] or pixels[x, y] == 0:
                continue
            q = deque([(x, y)])
            seen[idx] = 1
            points = []
            minx = maxx = x
            miny = maxy = y
            while q:
                cx, cy = q.popleft()
                points.append((cx, cy))
                minx, maxx = min(minx, cx), max(maxx, cx)
                miny, maxy = min(miny, cy), max(maxy, cy)
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    nidx = ny * w + nx
                    if seen[nidx] or pixels[nx, ny] == 0:
                        continue
                    seen[nidx] = 1
                    q.append((nx, ny))
            if len(points) >= min_pixels:
                components.append({
                    "pixels": len(points),
                    "bbox": [minx, miny, maxx + 1, maxy + 1],
                    "points": points,
                })
    components.sort(key=lambda item: item["pixels"], reverse=True)
    return components


def keep_components(mask: Image.Image, min_pixels: int = 15) -> tuple[Image.Image, list[dict]]:
    components = connected_components(mask, min_pixels=min_pixels)
    out = Image.new("L", mask.size, 0)
    target = out.load()
    for component in components:
        for point in component["points"]:
            target[point] = 255
    clean = [
        {"pixels": item["pixels"], "bbox": item["bbox"]}
        for item in components
    ]
    return out, clean


def subtract_mask(a: Image.Image, b: Image.Image) -> Image.Image:
    raw = bytes(max(0, av - bv) for av, bv in zip(a.tobytes(), b.tobytes()))
    return Image.frombytes("L", a.size, raw)


def is_hair_color(r: int, g: int, b: int) -> bool:
    """Conservative palette classifier used only inside fixed Hair spatial zones.

    It intentionally rejects warm skin pixels. Dark ink/hair, brown hair shading
    and the approved blue ribbon remain eligible. Exact source pixels are kept;
    this function only decides alpha membership.
    """
    mean = (r + g + b) / 3.0
    skin_like = r > 145 and g > 90 and b > 50 and r > g > b and mean > 115
    blue_ribbon = b > 70 and b > r * 1.25 and b > g * 1.15
    dark_hair = mean < 115
    brown_hair = mean < 150 and r < 180 and g < 155 and b < 120 and not skin_like
    return (dark_hair or brown_hair or blue_ribbon) and not skin_like


def build_semantic_split(lian_head: Image.Image, base_head: Image.Image) -> tuple[Image.Image, Image.Image, dict]:
    """Return disjoint diagnostic hair_back and hair_front masks.

    Hair back starts from silhouette pixels that Lian adds outside BASE-00. Hair
    front comes from conservative hair-color pixels in fixed head/bang/side-lock
    zones where it must render above the face. The rules are intentionally frozen
    in source coordinates and are not a generic background-removal algorithm.
    """
    w, h = lian_head.size
    la = lian_head.getchannel("A")
    ba = base_head.getchannel("A")
    lp = lian_head.load()
    lap = la.load()
    bap = ba.load()

    back = Image.new("L", (w, h), 0)
    bp = back.load()
    for y in range(h):
        for x in range(w):
            if lap[x, y] < 16:
                continue
            # High-confidence pixels outside the bald BASE-00 silhouette.
            if y < 322 and bap[x, y] < 16:
                # Reject shoulder/garment fragments at the bottom of the crop.
                if y > 305 and (x < 330 or x > 445):
                    continue
                bp[x, y] = 255

    front = Image.new("L", (w, h), 0)
    fp = front.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = lp[x, y]
            if a < 16:
                continue
            # Main cap / bangs plus the left hanging lock. The right ribbon is
            # intentionally left to hair_back because it sits behind the head.
            spatial = 120 <= x <= 385 and 85 <= y <= 240
            spatial = spatial or (125 <= x <= 220 and 200 <= y <= 320)
            spatial = spatial or (300 <= x <= 355 and 150 <= y <= 235)
            if spatial and is_hair_color(r, g, b):
                fp[x, y] = 255

    front, front_components = keep_components(front, min_pixels=15)
    # Front wins where masks overlap; production composition requires disjoint modules.
    back = subtract_mask(back, front)
    back, back_components = keep_components(back, min_pixels=8)

    metrics = {
        "hair_back_pixels": sum(item["pixels"] for item in back_components),
        "hair_back_bbox_local": back.getbbox(),
        "hair_back_components": back_components[:20],
        "hair_front_pixels": sum(item["pixels"] for item in front_components),
        "hair_front_bbox_local": front.getbbox(),
        "hair_front_components": front_components[:20],
        "front_back_overlap_pixels": sum(1 for av, bv in zip(back.tobytes(), front.tobytes()) if av and bv),
        "spatial_policy": {
            "back_exclusive_alpha_max_y": 321,
            "front_main_zone": [120, 85, 385, 240],
            "front_left_lock_zone": [125, 200, 220, 320],
            "front_right_temple_zone": [300, 150, 355, 235],
        },
    }
    return back, front, metrics


def rgba_from_mask(source: Image.Image, mask: Image.Image) -> Image.Image:
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    out.paste(source, (0, 0), mask)
    return out


def embed_full_canvas(crop_rgba: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    out.alpha_composite(crop_rgba, (HEAD_BOX[0], HEAD_BOX[1]))
    return out


def gameplay_crop(image: Image.Image, bbox, target_height: int = GAMEPLAY_HEIGHT) -> Image.Image:
    if bbox is None:
        return Image.new("RGBA", (target_height, target_height), (0, 0, 0, 0))
    crop = image.crop(bbox)
    scale = target_height / max(1, crop.height)
    target_width = max(1, round(crop.width * scale))
    return crop.resize((target_width, target_height), Image.Resampling.NEAREST)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if not LIAN.is_file() or not BASE.is_file():
        raise SystemExit("C66_1_HAIR_SOURCE_PROBE=BLOCKED source_missing")
    if sha256(LIAN) != EXPECTED_LIAN_SHA:
        raise SystemExit("C66_1_HAIR_SOURCE_PROBE=BLOCKED lian_sha_mismatch")
    if sha256(BASE) != EXPECTED_BASE_SHA:
        raise SystemExit("C66_1_HAIR_SOURCE_PROBE=BLOCKED base00_sha_mismatch")

    lian = Image.open(LIAN).convert("RGBA")
    base = Image.open(BASE).convert("RGBA")
    if lian.size != CANVAS or base.size != CANVAS:
        raise SystemExit(f"C66_1_HAIR_SOURCE_PROBE=BLOCKED canvas lian={lian.size} base={base.size}")

    lian_head = lian.crop(HEAD_BOX)
    base_head = base.crop(HEAD_BOX)
    w, h = lian_head.size

    # Baseline diagnostics retained from the first probe.
    la = lian_head.getchannel("A")
    ba = base_head.getchannel("A")
    exclusive = Image.new("L", (w, h), 0)
    ex = exclusive.load(); lp = la.load(); bp = ba.load()
    exclusive_count = 0
    for y in range(h):
        for x in range(w):
            if lp[x, y] >= 16 and bp[x, y] < 16:
                ex[x, y] = 255
                exclusive_count += 1

    diff = ImageChops.difference(lian_head, base_head)
    changed = Image.new("L", (w, h), 0)
    cp = changed.load(); dp = diff.load()
    changed_count = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = dp[x, y]
            if max(r, g, b, a) >= 32 and lp[x, y] >= 16:
                cp[x, y] = 255
                changed_count += 1

    exclusive_rgba = rgba_from_mask(lian_head, exclusive)
    changed_rgba = rgba_from_mask(lian_head, changed)

    # C66.1 v2 diagnostic: deterministic front/back Hair split.
    back_mask, front_mask, split_metrics = build_semantic_split(lian_head, base_head)
    back_crop = rgba_from_mask(lian_head, back_mask)
    front_crop = rgba_from_mask(lian_head, front_mask)
    combined_crop = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    combined_crop.alpha_composite(back_crop)
    combined_crop.alpha_composite(front_crop)

    hair_back_full = embed_full_canvas(back_crop)
    hair_front_full = embed_full_canvas(front_crop)
    combined_full = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    combined_full.alpha_composite(hair_back_full)
    combined_full.alpha_composite(hair_front_full)

    # Real modular composition order from C66.0: back -> BASE-00 -> front.
    composed_full = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    composed_full.alpha_composite(hair_back_full)
    composed_full.alpha_composite(base)
    composed_full.alpha_composite(hair_front_full)

    # Head-crop composition and gameplay-scale evidence.
    composed_head = composed_full.crop(HEAD_BOX)
    composed_bbox = used_bbox(composed_full)
    gameplay = gameplay_crop(composed_full, composed_bbox, GAMEPLAY_HEIGHT)

    lian_head.save(OUT / "01_lian_head_source.png")
    base_head.save(OUT / "02_base00_head_source.png")
    alpha_preview(exclusive_rgba).save(OUT / "03_exclusive_alpha_preview.png")
    exclusive_rgba.save(OUT / "04_exclusive_alpha_rgba.png")
    alpha_preview(changed_rgba).save(OUT / "05_changed_pixels_preview.png")
    changed_rgba.save(OUT / "06_changed_pixels_rgba.png")
    diff.save(OUT / "07_raw_rgba_difference.png")

    # Split diagnostics are full-canvas and retain canonical 0.5/0.92 authoring space.
    hair_back_full.save(OUT / "08_hair_back_candidate_FULL_CANVAS_DIAGNOSTIC.png")
    hair_front_full.save(OUT / "09_hair_front_candidate_FULL_CANVAS_DIAGNOSTIC.png")
    composed_full.save(OUT / "10_base00_hair_composition_FULL_CANVAS_DIAGNOSTIC.png")
    alpha_preview(back_crop).save(OUT / "11_hair_back_checker.png")
    alpha_preview(front_crop).save(OUT / "12_hair_front_checker.png")
    alpha_preview(combined_crop).save(OUT / "13_combined_hair_checker.png")
    alpha_preview(composed_head).save(OUT / "14_base00_hair_composition_head.png")
    alpha_preview(gameplay).save(OUT / "15_base00_hair_gameplay_132px.png")

    first_panel = Image.new("RGBA", (w * 4, h), (24, 24, 24, 255))
    first_panel.paste(alpha_preview(lian_head), (0, 0))
    first_panel.paste(alpha_preview(base_head), (w, 0))
    first_panel.paste(alpha_preview(exclusive_rgba), (w * 2, 0))
    first_panel.paste(alpha_preview(changed_rgba), (w * 3, 0))
    first_panel.save(OUT / "C66_1_LIAN_HAIR_SOURCE_FEASIBILITY.contact.png")

    split_panel = Image.new("RGBA", (w * 4, h), (24, 24, 24, 255))
    split_panel.paste(alpha_preview(back_crop), (0, 0))
    split_panel.paste(alpha_preview(front_crop), (w, 0))
    split_panel.paste(alpha_preview(combined_crop), (w * 2, 0))
    split_panel.paste(alpha_preview(composed_head), (w * 3, 0))
    split_panel.save(OUT / "C66_1_HAIR_FRONT_BACK_SPLIT.contact.png")

    exclusive_components = connected_components(exclusive)
    changed_components = connected_components(changed)
    report = {
        "schema": "tehkne/taijifu-c66-1-hair-source-feasibility/v2",
        "signature": "Tehkné Solutions",
        "status": "diagnostic_owner_visual_review_required",
        "source": {
            "lian_path": str(LIAN.relative_to(ROOT)).replace("\\", "/"),
            "lian_sha256": sha256(LIAN),
            "lian_alpha_bbox": used_bbox(lian),
            "base00_path": str(BASE.relative_to(ROOT)).replace("\\", "/"),
            "base00_sha256": sha256(BASE),
            "base00_alpha_bbox": used_bbox(base),
            "canvas": list(lian.size),
            "head_probe_box": list(HEAD_BOX),
            "canonical_pivot": [0.5, 0.92],
        },
        "baseline_diagnostics": {
            "exclusive_alpha_pixels": exclusive_count,
            "exclusive_alpha_bbox_local": binary_bbox(exclusive),
            "exclusive_components": [
                {"pixels": item["pixels"], "bbox": item["bbox"]}
                for item in exclusive_components[:20]
            ],
            "changed_pixels": changed_count,
            "changed_bbox_local": binary_bbox(changed),
            "changed_components": [
                {"pixels": item["pixels"], "bbox": item["bbox"]}
                for item in changed_components[:20]
            ],
        },
        "semantic_split_diagnostic": {
            **split_metrics,
            "full_canvas": True,
            "resampling": False,
            "source_pixel_mutation": False,
            "composition_order": ["hair_back", "base_fighter_v1", "hair_front"],
            "composed_alpha_bbox": composed_bbox,
            "gameplay_review_height_px": GAMEPLAY_HEIGHT,
        },
        "policy": {
            "diagnostic_is_production_asset": False,
            "automatic_hair_promotion_allowed": False,
            "front_back_outputs_are_candidates_only": True,
            "pixel_reuse_only_if_visual_review_proves_clean_hair_separation": True,
            "production_requires_disjoint_front_back_modules": True,
            "production_requires_owner_visual_review": True,
            "fallback_if_contaminated": "author_new_BASE02_hair_art",
        },
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    if split_metrics["front_back_overlap_pixels"] != 0:
        raise SystemExit("C66_1_HAIR_SOURCE_PROBE=BLOCKED front_back_overlap")
    if not split_metrics["hair_back_pixels"] or not split_metrics["hair_front_pixels"]:
        raise SystemExit("C66_1_HAIR_SOURCE_PROBE=BLOCKED empty_split")

    print(
        "C66_1_HAIR_SOURCE_PROBE=PASS "
        f"exclusive={exclusive_count} changed={changed_count} "
        f"back={split_metrics['hair_back_pixels']} front={split_metrics['hair_front_pixels']}"
    )
    print("C66_1_HAIR_SPLIT=PASS overlap=0 full_canvas=true source_pixels_only=true")
    print("C66_1_PRODUCTION_PROMOTION=BLOCKED owner_visual_review_required")
    print(f"C66_1_OUTPUT={OUT.relative_to(ROOT).as_posix()}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
