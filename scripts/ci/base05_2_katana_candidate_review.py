#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/modular_fighters/base_05/candidates/katana_lian_wu_pack_01"
CANDIDATES = PACK / "candidates.json"
OUTPUT = ROOT / "artifacts/base05_2/BASE05_2_KATANA_LIAN_WU_CANDIDATE_REVIEW.review-1920x1080.png"
REPORT = ROOT / "artifacts/base05_2/BASE05_2_KATANA_LIAN_WU_CANDIDATE_REVIEW.json"

SHARED_MANIFEST = ROOT / "assets/modular_fighters/shared_equipment/manifest.json"
BASE04_MANIFEST = ROOT / "assets/modular_fighters/base_04/manifest.json"

STATIC_LAYERS = [
    (5, ROOT / "assets/modular_fighters/base_02/hair_01_lian_topknot/hair_01_lian_topknot_back.png"),
    (10, ROOT / "assets/modular_fighters/base_00/base_fighter_v1_master.png"),
    (11, ROOT / "assets/modular_fighters/base_03/uniform_01_lian_martial/legs.png"),
    (12, ROOT / "assets/modular_fighters/base_03/uniform_01_lian_martial/feet.png"),
    (12, ROOT / "assets/modular_fighters/base_03/uniform_01_lian_martial/arms.png"),
    (14, ROOT / "assets/modular_fighters/base_03/uniform_01_lian_martial/waist.png"),
    (15, ROOT / "assets/modular_fighters/base_01/face_plate/neutral_face_plate_v1.png"),
    (20, ROOT / "assets/modular_fighters/base_01/face/face_01_balanced.png"),
    (30, ROOT / "assets/modular_fighters/base_01/eyes/eyes_01_focused.png"),
    (40, ROOT / "assets/modular_fighters/base_01/brows/brows_01_focused.png"),
    (50, ROOT / "assets/modular_fighters/base_02/hair_01_lian_topknot/hair_01_lian_topknot_front.png"),
    (65, ROOT / "assets/modular_fighters/base_03/uniform_01_lian_martial/torso_outer.png"),
]
FACE_MASK_PATH = ROOT / "assets/modular_fighters/base_01/face_plate/neutral_face_plate_v1.png"

MIN_VISIBLE_PIXELS = 3500
MIN_EXTERIOR_PIXELS = 2200
MIN_EXTERIOR_RATIO = 0.22
MAX_FACE_OVERLAP_PIXELS = 900
MAX_BODY_OVERLAP_RATIO = 0.72
MIN_PAIRWISE_DIFF = 5000
GAMEPLAY_SIZE = (256, 256)
MIN_GAMEPLAY_VISIBLE_PIXELS = 180


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def rgba(path: Path) -> Image.Image:
    assert path.is_file(), path
    image = Image.open(path).convert("RGBA")
    image.load()
    assert image.size == (1024, 1024), (path, image.size)
    return image


def binary_alpha(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(lambda a: 255 if a > 0 else 0)


def count_mask(mask: Image.Image) -> int:
    hist = mask.histogram()
    return sum(hist[1:])


def visible_pixels(image: Image.Image) -> int:
    return count_mask(binary_alpha(image))


def mask_and(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.multiply(a.convert("L"), b.convert("L"))


def mask_not(a: Image.Image) -> Image.Image:
    return Image.eval(a.convert("L"), lambda p: 255 - p)


def diff_pixels(left: Image.Image, right: Image.Image) -> int:
    diff = ImageChops.difference(left.convert("RGBA"), right.convert("RGBA"))
    gray = diff.convert("RGB").convert("L")
    return sum(1 for value in gray.getdata() if value != 0)


def production_dynamic_layers() -> list[tuple[int, Path]]:
    shared = load_json(SHARED_MANIFEST)
    base04 = load_json(BASE04_MANIFEST)
    sheath = shared["modules"]["sheath_lian_wu_blue"]
    back = base04["modules"]["back_01_guardian_panel_back_accessory"]
    head = base04["modules"]["armor_01_taijifu_guard_head_accessory"]
    shoulders = base04["modules"]["armor_01_taijifu_guard_shoulders"]
    assert sheath["production_ready"] is True and sheath["runtime_ready"] is True
    assert back["path"] and head["path"] and shoulders["path"]
    return [
        (int(sheath["layer"]), ROOT / sheath["path"]),
        (4, ROOT / back["path"]),
        (60, ROOT / head["path"]),
        (70, ROOT / shoulders["path"]),
    ]


def compose_base() -> Image.Image:
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    layers = STATIC_LAYERS + production_dynamic_layers()
    for _z, path in sorted(layers, key=lambda item: item[0]):
        canvas.alpha_composite(rgba(path))
    return canvas


def compose_with_weapon(base: Image.Image, weapon: Image.Image) -> Image.Image:
    result = base.copy()
    result.alpha_composite(weapon)
    return result


def candidate_metrics(base: Image.Image, face_mask: Image.Image, weapon: Image.Image) -> dict:
    weapon_mask = binary_alpha(weapon)
    base_mask = binary_alpha(base)
    face = binary_alpha(face_mask)
    visible = count_mask(weapon_mask)
    exterior = count_mask(mask_and(weapon_mask, mask_not(base_mask)))
    overlap = count_mask(mask_and(weapon_mask, base_mask))
    face_overlap = count_mask(mask_and(weapon_mask, face))
    exterior_ratio = exterior / float(max(visible, 1))
    overlap_ratio = overlap / float(max(visible, 1))
    gameplay_weapon = weapon.resize(GAMEPLAY_SIZE, Image.Resampling.LANCZOS)
    gameplay_visible = visible_pixels(gameplay_weapon)
    return {
        "visible_pixels": visible,
        "exterior_pixels": exterior,
        "exterior_ratio": round(exterior_ratio, 6),
        "body_overlap_pixels": overlap,
        "body_overlap_ratio": round(overlap_ratio, 6),
        "face_overlap_pixels": face_overlap,
        "gameplay_visible_pixels": gameplay_visible,
        "readability_pass": visible >= MIN_VISIBLE_PIXELS and exterior >= MIN_EXTERIOR_PIXELS and exterior_ratio >= MIN_EXTERIOR_RATIO,
        "occlusion_pass": overlap_ratio <= MAX_BODY_OVERLAP_RATIO and face_overlap <= MAX_FACE_OVERLAP_PIXELS,
        "gameplay_scale_pass": gameplay_visible >= MIN_GAMEPLAY_VISIBLE_PIXELS,
    }


def mirrored_metrics(base: Image.Image, face: Image.Image, weapon: Image.Image) -> dict:
    return candidate_metrics(
        base.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
        face.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
        weapon.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
    )


def flip_equivalent(authored: dict, flipped: dict) -> bool:
    keys = (
        "visible_pixels",
        "exterior_pixels",
        "body_overlap_pixels",
        "face_overlap_pixels",
        "gameplay_visible_pixels",
        "exterior_ratio",
        "body_overlap_ratio",
    )
    return all(authored[key] == flipped[key] for key in keys)


def fit_panel(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    panel = Image.new("RGBA", size, (0, 0, 0, 0))
    panel.alpha_composite(copy, ((size[0] - copy.width) // 2, (size[1] - copy.height) // 2))
    return panel


def score(metrics: dict) -> float:
    return round(
        metrics["exterior_ratio"] * 100.0
        - metrics["body_overlap_ratio"] * 45.0
        - metrics["face_overlap_pixels"] * 0.02
        + min(metrics["gameplay_visible_pixels"], 1200) * 0.01,
        4,
    )


def main() -> None:
    data = load_json(CANDIDATES)
    assert data["status"] == "materialized_candidate_review_pending"
    assert data["selected_candidate"] is None
    assert data["runtime_promotion"] is False
    assert data["creator_exposure"] is False
    assert len(data["candidates"]) == 3

    base = compose_base()
    face_mask = rgba(FACE_MASK_PATH)
    report = {
        "schema": "tehkne/taijifu-base05-katana-candidate-review/v3",
        "signature": "Tehkné Solutions",
        "stage": "BASE-05.2",
        "status": "candidate_review_measured_selection_pending",
        "runtime_promotion": False,
        "creator_exposure": False,
        "neutral_visibility_contract": {"weapon_main": False, "weapon_back": True},
        "combat_visibility_contract": {"weapon_main": "state_aware", "combat_behavior_owner": "WeaponKitCatalog"},
        "thresholds": {
            "min_visible_pixels": MIN_VISIBLE_PIXELS,
            "min_exterior_pixels": MIN_EXTERIOR_PIXELS,
            "min_exterior_ratio": MIN_EXTERIOR_RATIO,
            "max_face_overlap_pixels": MAX_FACE_OVERLAP_PIXELS,
            "max_body_overlap_ratio": MAX_BODY_OVERLAP_RATIO,
            "min_pairwise_diff": MIN_PAIRWISE_DIFF,
            "gameplay_size": list(GAMEPLAY_SIZE),
            "min_gameplay_visible_pixels": MIN_GAMEPLAY_VISIBLE_PIXELS,
        },
        "candidates": {},
        "pairwise_diff": {},
        "ranking": [],
        "viable_candidates": [],
        "rejected_candidates": [],
        "selection": None,
    }

    images: dict[str, Image.Image] = {}
    composites: dict[str, Image.Image] = {}
    for cid, spec in data["candidates"].items():
        path = ROOT / spec["path"]
        assert path.is_file(), path
        assert hashlib.sha256(path.read_bytes()).hexdigest() == spec["sha256"]
        image = rgba(path)
        assert list(image.getchannel("A").getbbox()) == spec["alpha_bbox"]
        assert visible_pixels(image) == spec["visible_pixels"]

        authored = candidate_metrics(base, face_mask, image)
        flipped = mirrored_metrics(base, face_mask, image)
        mirror_pass = flip_equivalent(authored, flipped)
        authored_facing_pass = authored["readability_pass"] and authored["occlusion_pass"]
        flipped_facing_pass = flipped["readability_pass"] and flipped["occlusion_pass"] and mirror_pass
        candidate_pass = authored_facing_pass and flipped_facing_pass and authored["gameplay_scale_pass"]
        verdict = "viable" if candidate_pass else "rejected"
        rejection_reasons = []
        if not authored["readability_pass"]:
            rejection_reasons.append("authored_readability")
        if not authored["occlusion_pass"]:
            rejection_reasons.append("authored_occlusion")
        if not flipped["readability_pass"]:
            rejection_reasons.append("flipped_readability")
        if not flipped["occlusion_pass"]:
            rejection_reasons.append("flipped_occlusion")
        if not mirror_pass:
            rejection_reasons.append("flip_metric_equivalence")
        if not authored["gameplay_scale_pass"]:
            rejection_reasons.append("gameplay_scale")

        authored.update(
            {
                "sha256": spec["sha256"],
                "alpha_bbox": spec["alpha_bbox"],
                "brief": spec["brief"],
                "authored_facing_pass": authored_facing_pass,
                "flipped_facing_pass": flipped_facing_pass,
                "flip_metric_equivalence_pass": mirror_pass,
                "review_score": score(authored),
                "candidate_pass": candidate_pass,
                "verdict": verdict,
                "rejection_reasons": rejection_reasons,
            }
        )
        report["candidates"][cid] = {"authored": authored, "flipped": flipped}
        if candidate_pass:
            report["viable_candidates"].append(cid)
        else:
            report["rejected_candidates"].append({"candidate": cid, "reasons": rejection_reasons})

        images[cid] = image
        composites[cid] = compose_with_weapon(base, image)
        print(
            f"BASE05_2_METRIC id={cid} verdict={verdict} exterior_ratio={authored['exterior_ratio']:.4f} "
            f"body_overlap_ratio={authored['body_overlap_ratio']:.4f} face_overlap={authored['face_overlap_pixels']} "
            f"gameplay_visible={authored['gameplay_visible_pixels']} authored={str(authored_facing_pass).lower()} "
            f"flipped={str(flipped_facing_pass).lower()} gameplay={str(authored['gameplay_scale_pass']).lower()} "
            f"score={authored['review_score']:.4f} reasons={','.join(rejection_reasons) if rejection_reasons else 'none'}"
        )

    ids = list(images)
    pairwise_pass = True
    for i, left in enumerate(ids):
        for right in ids[i + 1 :]:
            delta = diff_pixels(images[left], images[right])
            passed = delta >= MIN_PAIRWISE_DIFF
            pairwise_pass = pairwise_pass and passed
            report["pairwise_diff"][f"{left}__{right}"] = {"pixels": delta, "pass": passed}
            print(f"BASE05_2_PAIRWISE left={left} right={right} diff={delta} pass={str(passed).lower()}")

    report["ranking"] = sorted(
        (
            {
                "candidate": cid,
                "score": report["candidates"][cid]["authored"]["review_score"],
                "viable": report["candidates"][cid]["authored"]["candidate_pass"],
            }
            for cid in ids
        ),
        key=lambda item: (item["viable"], item["score"]),
        reverse=True,
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (1920, 1080), (25, 29, 35))
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "BASE-05.2 • Katana Lian Wu Candidate Review • authored / flipped / gameplay", fill=(242, 242, 242))
    panel_w = 620
    for index, cid in enumerate(ids):
        x = 20 + index * 635
        comp = composites[cid]
        sheet.paste(fit_panel(comp, (560, 560)).convert("RGB"), (x + 28, 70))
        sheet.paste(fit_panel(comp.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (310, 310)).convert("RGB"), (x + 22, 680))
        sheet.paste(fit_panel(comp, (190, 190)).convert("RGB"), (x + 385, 740))
        m = report["candidates"][cid]["authored"]
        draw.text((x + 22, 650), f"{cid} • {m['verdict'].upper()}", fill=(238, 212, 143))
        draw.text(
            (x + 22, 1000),
            f"ext={m['exterior_ratio']:.2f} overlap={m['body_overlap_ratio']:.2f} face={m['face_overlap_pixels']} gp={m['gameplay_visible_pixels']} score={m['review_score']:.2f}",
            fill=(220, 220, 220),
        )
        if index < 2:
            draw.line((x + panel_w, 55, x + panel_w, 1040), fill=(78, 84, 94), width=2)

    review_pass = bool(report["viable_candidates"]) and pairwise_pass
    report["status"] = "candidate_review_pass_selection_pending" if review_pass else "candidate_review_no_viable_selection_blocked"
    draw.text(
        (24, 1052),
        f"viable={len(report['viable_candidates'])} • selection=pending • runtime=false • creator=false • neutral weapon_main=false • Tehkné Solutions",
        fill=(210, 210, 210),
    )
    sheet.save(OUTPUT)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"BASE05_2_VIABLE={','.join(report['viable_candidates']) if report['viable_candidates'] else 'none'}")
    print(f"BASE05_2_REJECTED={','.join(item['candidate'] for item in report['rejected_candidates']) if report['rejected_candidates'] else 'none'}")
    print(f"BASE05_2_RANKING={json.dumps(report['ranking'], separators=(',', ':'))}")
    print(f"BASE05_2_VISUAL_OUTPUT={OUTPUT.relative_to(ROOT)}")
    print(f"BASE05_2_REPORT={REPORT.relative_to(ROOT)}")
    print("SIGNATURE=Tehkné Solutions")

    if review_pass:
        print("BASE05_2_CANDIDATE_REVIEW=PASS candidates=3 selection=pending runtime=false creator=false")
        return

    print("BASE05_2_CANDIDATE_REVIEW=BLOCKED candidates=3 selection=null runtime=false creator=false")
    sys.exit(1)


if __name__ == "__main__":
    main()
