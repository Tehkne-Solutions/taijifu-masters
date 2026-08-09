#!/usr/bin/env python3
"""C67.1 diagnostic v4: final sanitization of the Lian uniform source candidate.

Builds on v3 and removes the last two visually observed non-uniform residues:
a narrow left-side weapon fragment and all pixels at/under the historical ground
shadow baseline. Outputs remain diagnostic-only. Tehkné Solutions.
"""

from __future__ import annotations

import json

from PIL import Image

import probe_base03_lian_uniform_source as v2
import probe_base03_lian_uniform_source_v3 as v3

OUT = v2.OUT
SCHEMA = "tehkne/taijifu-c67-1-uniform-source-feasibility/v4"
EXTRA_LEFT_WEAPON = (285, 590, 340, 725)
HARD_BASELINE_CUT_Y = 943


def in_rect(x: int, y: int, rect: tuple[int, int, int, int]) -> bool:
    x0, y0, x1, y1 = rect
    return x0 <= x < x1 and y0 <= y < y1


def final_sanitize(mask: Image.Image) -> tuple[Image.Image, dict]:
    out = mask.copy()
    p = out.load()
    removed = {"extra_left_weapon": 0, "hard_baseline": 0}
    x0, y0, x1, y1 = v2.BODY_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not p[x, y]:
                continue
            if in_rect(x, y, EXTRA_LEFT_WEAPON):
                p[x, y] = 0
                removed["extra_left_weapon"] += 1
                continue
            if y >= HARD_BASELINE_CUT_Y:
                p[x, y] = 0
                removed["hard_baseline"] += 1
    return out, removed


def count_mask(mask: Image.Image) -> int:
    return sum(1 for value in mask.tobytes() if value)


def pixels_in_rect(mask: Image.Image, rect: tuple[int, int, int, int]) -> int:
    p = mask.load(); x0, y0, x1, y1 = rect
    return sum(1 for y in range(y0, y1) for x in range(x0, x1) if p[x, y])


def baseline_pixels(mask: Image.Image) -> int:
    p = mask.load(); count = 0
    for y in range(HARD_BASELINE_CUT_Y, v2.BODY_BOX[3]):
        for x in range(v2.BODY_BOX[0], v2.BODY_BOX[2]):
            if p[x, y]:
                count += 1
    return count


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
    mask_v3, removed_v3 = v3.sanitize_mask(semantic_mask, lian)
    mask_v4, removed_v4 = final_sanitize(mask_v3)
    slot_masks, unassigned_pixels = v2.partition_mask(mask_v4)
    modules = {slot: v2.rgba_from_mask(lian, mask) for slot, mask in slot_masks.items()}
    candidate_rgba = v2.rgba_from_mask(lian, mask_v4)

    nonempty = [slot for slot in v2.SLOTS if count_mask(slot_masks[slot]) > 0]
    overlaps = {}
    for i, a in enumerate(nonempty):
        for b in nonempty[i + 1 :]:
            count = v2.overlap_count(modules[a], modules[b])
            if count:
                overlaps[f"{a}:{b}"] = count

    hair_union = Image.new("RGBA", v2.CANVAS, (0, 0, 0, 0))
    hair_union.alpha_composite(hair_back)
    hair_union.alpha_composite(hair_front)

    contamination = {
        "slot_overlap": sum(overlaps.values()),
        "skin": v2.candidate_skin_pixels(candidate_rgba),
        "hair": v2.overlap_count(candidate_rgba, hair_union),
        "left_hand_weapon": pixels_in_rect(mask_v4, v3.LEFT_HAND_WEAPON),
        "right_hand": pixels_in_rect(mask_v4, v3.RIGHT_HAND),
        "collar_warm": v3.warm_collar_pixels(mask_v4, lian),
        "boot_spill": v3.feet_spill_pixels(slot_masks["feet"]),
        "baseline": baseline_pixels(slot_masks["feet"]),
        "extra_weapon": pixels_in_rect(mask_v4, EXTRA_LEFT_WEAPON),
    }

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
            "pixels": count_mask(slot_masks[slot]),
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
            "selection": "semantic_source_pixel_uniform_palette_body_matte_v4_final_sanitized",
            "changed_pixel_dependency": False,
            "source_pixel_mutation": False,
            "redraw": False,
            "resampling": False,
            "slots": metrics,
            "nonempty_slots": nonempty,
            "intentionally_empty_slots": [slot for slot in v2.SLOTS if slot not in nonempty],
            "slot_overlap_pixels": overlaps,
            "unassigned_candidate_pixels": unassigned_pixels,
            "contamination": contamination,
            "v2_rejected_pixels": rejected_v2,
            "v3_removed_pixels": removed_v3,
            "v4_removed_pixels": removed_v4,
            "hard_baseline_cut_y": HARD_BASELINE_CUT_Y,
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

    if any(contamination.values()):
        raise SystemExit(f"C67_1_UNIFORM_SOURCE_PROBE=BLOCKED contamination:{contamination}")
    if not nonempty:
        raise SystemExit("C67_1_UNIFORM_SOURCE_PROBE=BLOCKED no_candidate_pixels")

    print(f"C67_1_UNIFORM_SOURCE_PROBE=PASS method=semantic_v4 nonempty={','.join(nonempty)} improvement={improvement:.6f}")
    print("C67_1_CONTAMINATION=PASS skin=0 hair=0 hands_weapon=0 collar=0 boot_spill=0 baseline=0 extra_weapon=0")
    print(f"C67_1_HAIR_INTERACTION=MEASURED hair_front_torso_outer_overlap={hair_front_outer_overlap}")
    print("C67_1_PRODUCTION_PROMOTION=BLOCKED owner_visual_review_required")
    print(f"C67_1_OUTPUT={OUT.relative_to(v2.ROOT).as_posix()}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
