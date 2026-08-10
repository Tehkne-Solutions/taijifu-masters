#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/modular_fighters/base_05/candidates/katana_lian_wu_pack_01"
CANDIDATES = PACK / "candidates.json"
OUTPUT = ROOT / "artifacts/base05_2/BASE05_2_KATANA_LIAN_WU_CANDIDATE_REVIEW.review-1920x1080.png"
REPORT = ROOT / "artifacts/base05_2/BASE05_2_KATANA_LIAN_WU_CANDIDATE_REVIEW.json"

STATIC_LAYERS = [
    (3, ROOT / "assets/modular_fighters/shared_equipment/sheath_lian_wu_blue/weapon_back.png"),
    (4, ROOT / "assets/modular_fighters/base_04/back_01_guardian_panel/back_accessory.png"),
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
    (60, ROOT / "assets/modular_fighters/base_04/armor_01_taijifu_guard/head_accessory.png"),
    (65, ROOT / "assets/modular_fighters/base_03/uniform_01_lian_martial/torso_outer.png"),
    (70, ROOT / "assets/modular_fighters/base_04/armor_01_taijifu_guard/shoulders.png"),
]
FACE_MASK_PATH = ROOT / "assets/modular_fighters/base_01/face_plate/neutral_face_plate_v1.png"

MIN_VISIBLE_PIXELS = 3500
MIN_EXTERIOR_PIXELS = 2200
MIN_EXTERIOR_RATIO = 0.22
MAX_FACE_OVERLAP_PIXELS = 900
MAX_BODY_OVERLAP_RATIO = 0.72
MIN_PAIRWISE_DIFF = 5000


def rgba(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    image.load()
    assert image.size == (1024, 1024), (path, image.size)
    return image


def visible_pixels(image: Image.Image) -> int:
    hist = image.getchannel("A").histogram()
    return sum(hist[1:])


def binary_alpha(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(lambda a: 255 if a > 0 else 0)


def count_mask(mask: Image.Image) -> int:
    hist = mask.histogram()
    return sum(hist[1:])


def mask_and(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.multiply(a.convert("L"), b.convert("L"))


def mask_not(a: Image.Image) -> Image.Image:
    return Image.eval(a.convert("L"), lambda p: 255 - p)


def diff_pixels(left: Image.Image, right: Image.Image) -> int:
    diff = ImageChops.difference(left.convert("RGBA"), right.convert("RGBA"))
    gray = diff.convert("RGB").convert("L")
    return sum(1 for value in gray.getdata() if value != 0)


def compose_base() -> Image.Image:
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for _z, path in sorted(STATIC_LAYERS, key=lambda item: item[0]):
        assert path.is_file(), path
        canvas.alpha_composite(rgba(path))
    return canvas


def compose_with_weapon(base: Image.Image, weapon: Image.Image) -> Image.Image:
    # weapon_main is z80, above current clothing/armor layers.
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
    return {
        "visible_pixels": visible,
        "exterior_pixels": exterior,
        "exterior_ratio": round(exterior_ratio, 6),
        "body_overlap_pixels": overlap,
        "body_overlap_ratio": round(overlap_ratio, 6),
        "face_overlap_pixels": face_overlap,
        "readability_pass": visible >= MIN_VISIBLE_PIXELS and exterior >= MIN_EXTERIOR_PIXELS and exterior_ratio >= MIN_EXTERIOR_RATIO,
        "occlusion_pass": overlap_ratio <= MAX_BODY_OVERLAP_RATIO and face_overlap <= MAX_FACE_OVERLAP_PIXELS,
    }


def fit_panel(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    panel = Image.new("RGBA", size, (0, 0, 0, 0))
    panel.alpha_composite(copy, ((size[0] - copy.width) // 2, (size[1] - copy.height) // 2))
    return panel


def main() -> None:
    data = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    assert data["status"] == "materialized_candidate_review_pending"
    assert data["selected_candidate"] is None
    assert data["runtime_promotion"] is False
    assert data["creator_exposure"] is False
    assert len(data["candidates"]) == 3

    base = compose_base()
    face_mask = rgba(FACE_MASK_PATH)
    report = {
        "schema": "tehkne/taijifu-base05-katana-candidate-review/v1",
        "signature": "Tehkné Solutions",
        "stage": "BASE-05.2",
        "status": "candidate_review_measured_selection_pending",
        "runtime_promotion": False,
        "creator_exposure": False,
        "thresholds": {
            "min_visible_pixels": MIN_VISIBLE_PIXELS,
            "min_exterior_pixels": MIN_EXTERIOR_PIXELS,
            "min_exterior_ratio": MIN_EXTERIOR_RATIO,
            "max_face_overlap_pixels": MAX_FACE_OVERLAP_PIXELS,
            "max_body_overlap_ratio": MAX_BODY_OVERLAP_RATIO,
            "min_pairwise_diff": MIN_PAIRWISE_DIFF,
        },
        "candidates": {},
        "pairwise_diff": {},
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
        metrics = candidate_metrics(base, face_mask, image)
        metrics.update({
            "sha256": spec["sha256"],
            "alpha_bbox": spec["alpha_bbox"],
            "brief": spec["brief"],
            "authored_facing": "measured",
            "flipped_facing": "measured",
            "gameplay_scale": "measured",
        })
        report["candidates"][cid] = metrics
        images[cid] = image
        composites[cid] = compose_with_weapon(base, image)
        print(
            f"BASE05_2_METRIC id={cid} visible={metrics['visible_pixels']} exterior={metrics['exterior_pixels']} "
            f"exterior_ratio={metrics['exterior_ratio']:.4f} body_overlap_ratio={metrics['body_overlap_ratio']:.4f} "
            f"face_overlap={metrics['face_overlap_pixels']} readability={str(metrics['readability_pass']).lower()} occlusion={str(metrics['occlusion_pass']).lower()}"
        )
        assert metrics["readability_pass"], f"{cid}:readability"
        assert metrics["occlusion_pass"], f"{cid}:occlusion"

    ids = list(images)
    for i, left in enumerate(ids):
        for right in ids[i + 1:]:
            delta = diff_pixels(images[left], images[right])
            report["pairwise_diff"][f"{left}__{right}"] = delta
            print(f"BASE05_2_PAIRWISE left={left} right={right} diff={delta}")
            assert delta >= MIN_PAIRWISE_DIFF, (left, right, delta)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (1920, 1080), (25, 29, 35))
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "BASE-05.2 • Katana Lian Wu Candidate Review • authored / flipped / gameplay", fill=(242, 242, 242))
    panel_w = 620
    for index, cid in enumerate(ids):
        x = 20 + index * 635
        comp = composites[cid]
        authored = fit_panel(comp, (560, 560)).convert("RGB")
        flipped = fit_panel(comp.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (310, 310)).convert("RGB")
        gameplay = fit_panel(comp, (190, 190)).convert("RGB")
        sheet.paste(authored, (x + 28, 70))
        sheet.paste(flipped, (x + 22, 680))
        sheet.paste(gameplay, (x + 385, 740))
        metrics = report["candidates"][cid]
        draw.text((x + 22, 650), cid, fill=(238, 212, 143))
        draw.text((x + 22, 1000), f"ext={metrics['exterior_ratio']:.2f} overlap={metrics['body_overlap_ratio']:.2f} face={metrics['face_overlap_pixels']}", fill=(220, 220, 220))
        if index < 2:
            draw.line((x + panel_w, 55, x + panel_w, 1040), fill=(78, 84, 94), width=2)
    draw.text((24, 1052), "selection=pending • runtime=false • creator=false • weapon_main z80 • Tehkné Solutions", fill=(210, 210, 210))
    sheet.save(OUTPUT)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("BASE05_2_CANDIDATE_REVIEW=PASS candidates=3 selection=pending runtime=false creator=false")
    print(f"BASE05_2_VISUAL_OUTPUT={OUTPUT.relative_to(ROOT)}")
    print(f"BASE05_2_REPORT={REPORT.relative_to(ROOT)}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
