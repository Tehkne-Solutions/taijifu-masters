#!/usr/bin/env python3
"""C67.1 diagnostic only: test exact Lian clothing reuse for BASE-03.

This probe never promotes assets. It preserves source pixels under conservative
body/clothing masks, partitions them into disjoint uniform slots and composes the
result with BASE-00 + the approved BASE-02 Topknot using the current layer policy.
Tehkné Solutions.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
LIAN = ROOT / "assets/characters/lian_wu/character_lock/lian_wu_neutral.png"
BASE = ROOT / "assets/modular_fighters/base_00/base_fighter_v1_master.png"
HAIR_BACK = ROOT / "assets/modular_fighters/base_02/hair_01_lian_topknot/hair_01_lian_topknot_back.png"
HAIR_FRONT = ROOT / "assets/modular_fighters/base_02/hair_01_lian_topknot/hair_01_lian_topknot_front.png"
OUT = ROOT / "artifacts/c67_1_uniform_source_probe"

EXPECTED = {
    LIAN: "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5",
    BASE: "fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe",
    HAIR_BACK: "45198a1def4f4fc22f72c01579d4468d0dd36afbbd99fe2fcd60292e8728ce7b",
    HAIR_FRONT: "11f1bc72ecee3f78ad8b35f8f3a7be8dc82b6d1391fbda1ddf17876c03f744d4",
}
CANVAS = (1024, 1024)
BODY_BOX = (285, 325, 760, 990)
GAMEPLAY_HEIGHT = 132
SLOTS = ["torso_inner", "torso_outer", "arms", "hands", "waist", "legs", "feet"]
CURRENT_Z = {
    "hair_back": 5,
    "body_base": 10,
    "torso_inner": 11,
    "legs": 11,
    "feet": 12,
    "arms": 12,
    "hands": 13,
    "waist": 14,
    "hair_front": 50,
    "torso_outer": 65,
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checkerboard(size: tuple[int, int], cell: int = 24) -> Image.Image:
    out = Image.new("RGBA", size, (235, 235, 235, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, min(x + cell - 1, size[0]-1), min(y + cell - 1, size[1]-1)), fill=(205,205,205,255))
    return out


def preview(image: Image.Image) -> Image.Image:
    bg = checkerboard(image.size)
    bg.alpha_composite(image)
    return bg


def is_skin_like(r: int, g: int, b: int) -> bool:
    mean = (r + g + b) / 3.0
    return r > 135 and g > 75 and b > 35 and r > g > b and mean > 95 and (r - b) > 35


def is_clothing_like(r: int, g: int, b: int) -> bool:
    """Conservative Lian uniform palette classifier.

    Lian's approved neutral uses white/blue/black/gold clothing. Skin-like warm
    pixels are explicitly rejected; exact source pixels are retained unchanged.
    """
    if is_skin_like(r, g, b):
        return False
    mean = (r + g + b) / 3.0
    dark = mean < 105
    white_neutral = mean > 145 and max(r, g, b) - min(r, g, b) < 75
    blue = b > 65 and b >= r * 1.05 and b >= g * 1.02
    gold = r > 105 and g > 75 and b < 95 and r > b * 1.25
    return dark or white_neutral or blue or gold


def build_changed_clothing_mask(lian: Image.Image, base: Image.Image) -> Image.Image:
    diff = ImageChops.difference(lian, base)
    lp = lian.load(); dp = diff.load()
    mask = Image.new("L", CANVAS, 0); mp = mask.load()
    x0, y0, x1, y1 = BODY_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b, a = lp[x, y]
            if a < 16:
                continue
            dr, dg, db, da = dp[x, y]
            if max(dr, dg, db, da) < 26:
                continue
            if is_clothing_like(r, g, b):
                mp[x, y] = 255
    return mask


def partition_mask(mask: Image.Image) -> dict[str, Image.Image]:
    """Diagnostic spatial partition; disjoint by construction.

    C67.1 deliberately does not claim torso_inner/hands from a flattened source:
    those two slots remain empty in this feasibility pass because the historical
    neutral cannot prove an independent under-layer or gloves without invention.
    """
    masks = {slot: Image.new("L", CANVAS, 0) for slot in SLOTS}
    src = mask.load(); dst = {slot: image.load() for slot, image in masks.items()}
    for y in range(BODY_BOX[1], BODY_BOX[3]):
        for x in range(BODY_BOX[0], BODY_BOX[2]):
            if not src[x, y]:
                continue
            slot = None
            if y >= 900:
                slot = "feet"
            elif y >= 715:
                slot = "legs"
            elif 625 <= y < 735 and 365 <= x <= 670:
                slot = "waist"
            elif 350 <= y < 700 and (x < 425 or x > 610):
                slot = "arms"
            elif 345 <= y < 680:
                slot = "torso_outer"
            elif y >= 680:
                slot = "legs"
            if slot:
                dst[slot][x, y] = 255
    return masks


def rgba_from_mask(source: Image.Image, mask: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    out.paste(source, (0,0), mask)
    return out


def count_pixels(mask: Image.Image) -> int:
    return sum(1 for value in mask.tobytes() if value)


def overlap_count(a: Image.Image, b: Image.Image) -> int:
    return sum(1 for av, bv in zip(a.getchannel("A").tobytes(), b.getchannel("A").tobytes()) if av and bv)


def compose_layers(base: Image.Image, modules: dict[str, Image.Image], hair_back: Image.Image, hair_front: Image.Image) -> Image.Image:
    layer_images = {"body_base": base, "hair_back": hair_back, "hair_front": hair_front, **modules}
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    for name, _z in sorted(CURRENT_Z.items(), key=lambda item: (item[1], item[0])):
        image = layer_images.get(name)
        if image is not None:
            out.alpha_composite(image)
    return out


def gameplay_crop(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return Image.new("RGBA", (GAMEPLAY_HEIGHT, GAMEPLAY_HEIGHT), (0,0,0,0))
    crop = image.crop(bbox)
    scale = GAMEPLAY_HEIGHT / max(1, crop.height)
    return crop.resize((max(1, round(crop.width * scale)), GAMEPLAY_HEIGHT), Image.Resampling.NEAREST)


def body_difference_score(reference: Image.Image, candidate: Image.Image) -> int:
    diff = ImageChops.difference(reference.crop(BODY_BOX), candidate.crop(BODY_BOX)).convert("RGBA")
    return sum(max(pixel) for pixel in diff.getdata())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for path, expected in EXPECTED.items():
        if not path.is_file():
            raise SystemExit(f"C67_1_UNIFORM_SOURCE_PROBE=BLOCKED missing:{path.relative_to(ROOT)}")
        if sha256(path) != expected:
            raise SystemExit(f"C67_1_UNIFORM_SOURCE_PROBE=BLOCKED sha:{path.name}")

    lian = Image.open(LIAN).convert("RGBA")
    base = Image.open(BASE).convert("RGBA")
    hair_back = Image.open(HAIR_BACK).convert("RGBA")
    hair_front = Image.open(HAIR_FRONT).convert("RGBA")
    if any(image.size != CANVAS for image in (lian, base, hair_back, hair_front)):
        raise SystemExit("C67_1_UNIFORM_SOURCE_PROBE=BLOCKED canvas")

    candidate_mask = build_changed_clothing_mask(lian, base)
    slot_masks = partition_mask(candidate_mask)
    modules = {slot: rgba_from_mask(lian, mask) for slot, mask in slot_masks.items()}

    # Fail closed on accidental slot overlap.
    nonempty = [slot for slot in SLOTS if count_pixels(slot_masks[slot]) > 0]
    overlaps = {}
    for i, a in enumerate(nonempty):
        for b in nonempty[i+1:]:
            count = overlap_count(modules[a], modules[b])
            if count:
                overlaps[f"{a}:{b}"] = count
    if overlaps:
        raise SystemExit(f"C67_1_UNIFORM_SOURCE_PROBE=BLOCKED slot_overlap:{overlaps}")

    base_hair = compose_layers(base, {}, hair_back, hair_front)
    composed = compose_layers(base, modules, hair_back, hair_front)
    gameplay = gameplay_crop(composed)

    # Hair interaction risk is measured against the current z order. Torso outer
    # is above hair_front today; this diagnostic must quantify actual pixel overlap.
    hair_front_outer_overlap = overlap_count(hair_front, modules["torso_outer"])

    # Save diagnostic full-canvas modules. These are NOT production assets.
    for index, slot in enumerate(SLOTS, start=1):
        modules[slot].save(OUT / f"{index:02d}_{slot}_FULL_CANVAS_DIAGNOSTIC.png")
    candidate_rgba = rgba_from_mask(lian, candidate_mask)
    candidate_rgba.save(OUT / "08_all_clothing_candidate_FULL_CANVAS_DIAGNOSTIC.png")
    composed.save(OUT / "09_base00_hair_uniform_composition_FULL_CANVAS_DIAGNOSTIC.png")
    preview(gameplay).save(OUT / "10_base00_hair_uniform_gameplay_132px.png")

    # Build body-region contact sheet: Lian source | BASE00+Hair | candidate-only | composition.
    crops = [
        preview(lian.crop(BODY_BOX)),
        preview(base_hair.crop(BODY_BOX)),
        preview(candidate_rgba.crop(BODY_BOX)),
        preview(composed.crop(BODY_BOX)),
    ]
    w, h = crops[0].size
    panel = Image.new("RGBA", (w*4, h), (24,24,24,255))
    for i, image in enumerate(crops):
        panel.paste(image, (i*w, 0))
    panel.save(OUT / "C67_1_LIAN_UNIFORM_SOURCE_FEASIBILITY.contact.png")

    # Slot sheet for visual contamination review.
    slot_previews = [preview(modules[slot].crop(BODY_BOX)) for slot in SLOTS]
    slot_panel = Image.new("RGBA", (w*4, h*2), (24,24,24,255))
    for i, image in enumerate(slot_previews):
        slot_panel.paste(image, ((i % 4)*w, (i // 4)*h))
    slot_panel.save(OUT / "C67_1_UNIFORM_SLOT_SPLIT.contact.png")

    baseline_score = body_difference_score(lian, base_hair)
    composed_score = body_difference_score(lian, composed)
    improvement = 0.0 if baseline_score == 0 else 1.0 - composed_score / baseline_score

    metrics = {
        slot: {
            "pixels": count_pixels(slot_masks[slot]),
            "bbox": list(modules[slot].getchannel("A").getbbox()) if modules[slot].getchannel("A").getbbox() else None,
        }
        for slot in SLOTS
    }
    report = {
        "schema": "tehkne/taijifu-c67-1-uniform-source-feasibility/v1",
        "signature": "Tehkné Solutions",
        "status": "diagnostic_owner_visual_review_required",
        "source": {
            "lian_sha256": EXPECTED[LIAN],
            "base00_sha256": EXPECTED[BASE],
            "hair_back_sha256": EXPECTED[HAIR_BACK],
            "hair_front_sha256": EXPECTED[HAIR_FRONT],
            "canvas": list(CANVAS),
            "body_probe_box": list(BODY_BOX),
        },
        "candidate": {
            "selection": "changed_source_pixels_matching_conservative_lian_uniform_palette",
            "source_pixel_mutation": False,
            "redraw": False,
            "resampling": False,
            "slots": metrics,
            "nonempty_slots": nonempty,
            "intentionally_empty_slots": [slot for slot in SLOTS if slot not in nonempty],
            "slot_overlap_pixels": overlaps,
        },
        "composition": {
            "current_z": CURRENT_Z,
            "hair_front_torso_outer_overlap_pixels": hair_front_outer_overlap,
            "body_difference_baseline_score": baseline_score,
            "body_difference_composed_score": composed_score,
            "difference_improvement_ratio": improvement,
            "gameplay_review_height_px": GAMEPLAY_HEIGHT,
        },
        "policy": {
            "diagnostic_is_production_asset": False,
            "automatic_uniform_promotion_allowed": False,
            "hair_interaction_visual_review_required": True,
            "layer_policy_change_allowed_from_metrics_only": False,
            "production_requires_owner_visual_review": True,
            "fallback_if_contaminated": "author_new_BASE03_uniform_art",
        },
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    if not nonempty:
        raise SystemExit("C67_1_UNIFORM_SOURCE_PROBE=BLOCKED no_candidate_pixels")
    print(f"C67_1_UNIFORM_SOURCE_PROBE=PASS nonempty={','.join(nonempty)} improvement={improvement:.6f}")
    print(f"C67_1_HAIR_INTERACTION=MEASURED hair_front_torso_outer_overlap={hair_front_outer_overlap}")
    print("C67_1_PRODUCTION_PROMOTION=BLOCKED owner_visual_review_required")
    print(f"C67_1_OUTPUT={OUT.relative_to(ROOT).as_posix()}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
