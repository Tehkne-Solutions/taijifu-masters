#!/usr/bin/env python3
"""C67.1 diagnostic v3: sanitize the semantic Lian uniform source matte.

This pass reuses the v2 semantic source-pixel matte, then removes spatial regions
that cannot belong to a reusable uniform module: exposed hands/weapon, warm skin
inside the open collar, inter-boot/background pixels and low-alpha baseline shadow.
No output is a production asset. Tehkné Solutions.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops

import probe_base03_lian_uniform_source as v2

ROOT = v2.ROOT
OUT = v2.OUT
SCHEMA = "tehkne/taijifu-c67-1-uniform-source-feasibility/v3"

LEFT_HAND_WEAPON = (285, 625, 370, 725)
RIGHT_HAND = (645, 610, 725, 700)
COLLAR_SKIN_ZONE = (425, 325, 545, 440)
LEFT_BOOT_ZONE = (300, 835, 495, 962)
RIGHT_BOOT_ZONE = (545, 835, 730, 962)
BASELINE_Y = 925


def in_rect(x: int, y: int, rect: tuple[int, int, int, int]) -> bool:
    x0, y0, x1, y1 = rect
    return x0 <= x < x1 and y0 <= y < y1


def is_warm_exposed_skin(r: int, g: int, b: int) -> bool:
    """Broader only inside the known open-collar region.

    The global v2 classifier is intentionally conservative. Here spatial context
    lets us reject darker skin/outline tones without treating blue/white cloth as
    skin. A few gold collar pixels may be sacrificed rather than baking skin into
    the reusable uniform module.
    """
    mean = (r + g + b) / 3.0
    return (
        r > 90
        and g > 42
        and r > g * 1.04
        and g >= b * 0.88
        and (r - b) > 24
        and mean > 66
    )


def sanitize_mask(mask: Image.Image, source: Image.Image) -> tuple[Image.Image, dict]:
    out = mask.copy()
    mp = out.load()
    sp = source.load()
    removed = {
        "left_hand_weapon": 0,
        "right_hand": 0,
        "collar_skin": 0,
        "boot_spill": 0,
        "baseline_low_alpha": 0,
    }

    x0, y0, x1, y1 = v2.BODY_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not mp[x, y]:
                continue
            r, g, b, a = sp[x, y]

            if in_rect(x, y, LEFT_HAND_WEAPON):
                mp[x, y] = 0
                removed["left_hand_weapon"] += 1
                continue
            if in_rect(x, y, RIGHT_HAND):
                mp[x, y] = 0
                removed["right_hand"] += 1
                continue
            if in_rect(x, y, COLLAR_SKIN_ZONE) and is_warm_exposed_skin(r, g, b):
                mp[x, y] = 0
                removed["collar_skin"] += 1
                continue

            if y >= 875:
                inside_boot = in_rect(x, y, LEFT_BOOT_ZONE) or in_rect(x, y, RIGHT_BOOT_ZONE)
                if not inside_boot:
                    mp[x, y] = 0
                    removed["boot_spill"] += 1
                    continue
                if y >= BASELINE_Y and a < 245:
                    mp[x, y] = 0
                    removed["baseline_low_alpha"] += 1
                    continue

    return out, removed


def rgba_from_mask(source: Image.Image, mask: Image.Image) -> Image.Image:
    return v2.rgba_from_mask(source, mask)


def mask_pixels_in_rect(mask: Image.Image, rect: tuple[int, int, int, int]) -> int:
    x0, y0, x1, y1 = rect
    p = mask.load()
    return sum(1 for y in range(y0, y1) for x in range(x0, x1) if p[x, y])


def feet_spill_pixels(mask: Image.Image) -> int:
    p = mask.load()
    count = 0
    for y in range(875, v2.BODY_BOX[3]):
        for x in range(v2.BODY_BOX[0], v2.BODY_BOX[2]):
            if not p[x, y]:
                continue
            if not (in_rect(x, y, LEFT_BOOT_ZONE) or in_rect(x, y, RIGHT_BOOT_ZONE)):
                count += 1
    return count


def low_alpha_baseline_pixels(mask: Image.Image, source: Image.Image) -> int:
    p = mask.load(); sp = source.load()
    count = 0
    for y in range(BASELINE_Y, v2.BODY_BOX[3]):
        for x in range(v2.BODY_BOX[0], v2.BODY_BOX[2]):
            if p[x, y] and sp[x, y][3] < 245:
                count += 1
    return count


def warm_collar_pixels(mask: Image.Image, source: Image.Image) -> int:
    p = mask.load(); sp = source.load()
    x0, y0, x1, y1 = COLLAR_SKIN_ZONE
    return sum(
        1
        for y in range(y0, y1)
        for x in range(x0, x1)
        if p[x, y] and is_warm_exposed_skin(*sp[x, y][:3])
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for path, expected in v2.EXPECTED.items():
        if not path.is_file() or v2.sha256(path) != expected:
            raise SystemExit(f"C67_1_UNIFORM_SOURCE_PROBE=BLOCKED source:{path.name}")

    lian = Image.open(v2.LIAN).convert("RGBA")
    base = Image.open(v2.BASE).convert("RGBA")
    hair_back = Image.open(v2.HAIR_BACK).convert("RGBA")
    hair_front = Image.open(v2.HAIR_FRONT).convert("RGBA")

    semantic_mask, rejected_v2 = v2.build_semantic_clothing_mask(lian, hair_back, hair_front)
    sanitized_mask, sanitized_removed = sanitize_mask(semantic_mask, lian)
    slot_masks, unassigned_pixels = v2.partition_mask(sanitized_mask)
    modules = {slot: rgba_from_mask(lian, mask) for slot, mask in slot_masks.items()}
    candidate_rgba = rgba_from_mask(lian, sanitized_mask)

    nonempty = [slot for slot in v2.SLOTS if v2.count_pixels(slot_masks[slot]) > 0]
    overlaps = {}
    for i, a in enumerate(nonempty):
        for b in nonempty[i + 1 :]:
            count = v2.overlap_count(modules[a], modules[b])
            if count:
                overlaps[f"{a}:{b}"] = count

    hair_union = Image.new("RGBA", v2.CANVAS, (0, 0, 0, 0))
    hair_union.alpha_composite(hair_back)
    hair_union.alpha_composite(hair_front)
    skin_pixels = v2.candidate_skin_pixels(candidate_rgba)
    hair_overlap = v2.overlap_count(candidate_rgba, hair_union)
    left_forbidden = mask_pixels_in_rect(sanitized_mask, LEFT_HAND_WEAPON)
    right_forbidden = mask_pixels_in_rect(sanitized_mask, RIGHT_HAND)
    boot_spill = feet_spill_pixels(slot_masks["feet"])
    baseline_low_alpha = low_alpha_baseline_pixels(slot_masks["feet"], lian)
    collar_warm = warm_collar_pixels(sanitized_mask, lian)

    base_hair = v2.compose_layers(base, {}, hair_back, hair_front)
    composed = v2.compose_layers(base, modules, hair_back, hair_front)
    gameplay = v2.gameplay_crop(composed)
    hair_front_outer_overlap = v2.overlap_count(hair_front, modules["torso_outer"])

    for index, slot in enumerate(v2.SLOTS, start=1):
        modules[slot].save(OUT / f"{index:02d}_{slot}_FULL_CANVAS_DIAGNOSTIC.png")
    candidate_rgba.save(OUT / "08_all_clothing_candidate_FULL_CANVAS_DIAGNOSTIC.png")
    composed.save(OUT / "09_base00_hair_uniform_composition_FULL_CANVAS_DIAGNOSTIC.png")
    v2.preview(gameplay).save(OUT / "10_base00_hair_uniform_gameplay_132px.png")

    crops = [
        v2.preview(lian.crop(v2.BODY_BOX)),
        v2.preview(base_hair.crop(v2.BODY_BOX)),
        v2.preview(candidate_rgba.crop(v2.BODY_BOX)),
        v2.preview(composed.crop(v2.BODY_BOX)),
    ]
    w, h = crops[0].size
    panel = Image.new("RGBA", (w * 4, h), (24, 24, 24, 255))
    for i, image in enumerate(crops):
        panel.paste(image, (i * w, 0))
    panel.save(OUT / "C67_1_LIAN_UNIFORM_SOURCE_FEASIBILITY.contact.png")

    slot_previews = [v2.preview(modules[slot].crop(v2.BODY_BOX)) for slot in v2.SLOTS]
    slot_panel = Image.new("RGBA", (w * 4, h * 2), (24, 24, 24, 255))
    for i, image in enumerate(slot_previews):
        slot_panel.paste(image, ((i % 4) * w, (i // 4) * h))
    slot_panel.save(OUT / "C67_1_UNIFORM_SLOT_SPLIT.contact.png")

    baseline_score = v2.body_difference_score(lian, base_hair)
    composed_score = v2.body_difference_score(lian, composed)
    improvement = 0.0 if baseline_score == 0 else 1.0 - composed_score / baseline_score

    metrics = {
        slot: {
            "pixels": v2.count_pixels(slot_masks[slot]),
            "bbox": list(modules[slot].getchannel("A").getbbox()) if modules[slot].getchannel("A").getbbox() else None,
        }
        for slot in v2.SLOTS
    }
    report = {
        "schema": SCHEMA,
        "signature": "Tehkné Solutions",
        "status": "diagnostic_owner_visual_review_required",
        "source": {
            "lian_sha256": v2.EXPECTED[v2.LIAN],
            "base00_sha256": v2.EXPECTED[v2.BASE],
            "hair_back_sha256": v2.EXPECTED[v2.HAIR_BACK],
            "hair_front_sha256": v2.EXPECTED[v2.HAIR_FRONT],
            "canvas": list(v2.CANVAS),
            "body_probe_box": list(v2.BODY_BOX),
        },
        "candidate": {
            "selection": "semantic_source_pixel_uniform_palette_body_matte_v3_spatial_sanitized",
            "changed_pixel_dependency": False,
            "source_pixel_mutation": False,
            "redraw": False,
            "resampling": False,
            "slots": metrics,
            "nonempty_slots": nonempty,
            "intentionally_empty_slots": [slot for slot in v2.SLOTS if slot not in nonempty],
            "slot_overlap_pixels": overlaps,
            "unassigned_candidate_pixels": unassigned_pixels,
            "skin_like_pixels": skin_pixels,
            "approved_hair_overlap_pixels": hair_overlap,
            "left_hand_weapon_zone_pixels": left_forbidden,
            "right_hand_zone_pixels": right_forbidden,
            "warm_collar_pixels": collar_warm,
            "feet_outside_boot_zones_pixels": boot_spill,
            "feet_low_alpha_baseline_pixels": baseline_low_alpha,
            "v2_rejected_pixels": rejected_v2,
            "v3_removed_pixels": sanitized_removed,
        },
        "composition": {
            "current_z": v2.CURRENT_Z,
            "hair_front_torso_outer_overlap_pixels": hair_front_outer_overlap,
            "body_difference_baseline_score": baseline_score,
            "body_difference_composed_score": composed_score,
            "difference_improvement_ratio": improvement,
            "gameplay_review_height_px": v2.GAMEPLAY_HEIGHT,
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

    contamination = {
        "slot_overlap": sum(overlaps.values()),
        "skin": skin_pixels,
        "hair": hair_overlap,
        "left_hand_weapon": left_forbidden,
        "right_hand": right_forbidden,
        "collar_warm": collar_warm,
        "boot_spill": boot_spill,
        "baseline_low_alpha": baseline_low_alpha,
    }
    if any(contamination.values()):
        raise SystemExit(f"C67_1_UNIFORM_SOURCE_PROBE=BLOCKED contamination:{contamination}")
    if not nonempty:
        raise SystemExit("C67_1_UNIFORM_SOURCE_PROBE=BLOCKED no_candidate_pixels")

    print(f"C67_1_UNIFORM_SOURCE_PROBE=PASS method=semantic_v3 nonempty={','.join(nonempty)} improvement={improvement:.6f}")
    print("C67_1_CONTAMINATION=PASS skin=0 hair=0 hands_weapon=0 collar=0 boot_spill=0 baseline_shadow=0")
    print(f"C67_1_HAIR_INTERACTION=MEASURED hair_front_torso_outer_overlap={hair_front_outer_overlap}")
    print("C67_1_PRODUCTION_PROMOTION=BLOCKED owner_visual_review_required")
    print(f"C67_1_OUTPUT={OUT.relative_to(ROOT).as_posix()}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
