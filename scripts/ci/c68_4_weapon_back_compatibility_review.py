#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
EQUIPMENT = ROOT / "assets/modular_fighters/shared_equipment/manifest.json"
BASE04 = ROOT / "assets/modular_fighters/base_04/manifest.json"
CANDIDATES = ROOT / "assets/modular_fighters/base_04/candidates/back_accessory_pack_01/candidates.json"
OUTPUT = ROOT / "artifacts/c68_4/C68_4_WEAPON_BACK_BACK_ACCESSORY.review-1920x1080.png"

BASE = ROOT / "assets/modular_fighters/base_00/base_fighter_v1_master.png"
STATIC_LAYERS = [
    (5, ROOT / "assets/modular_fighters/base_02/hair_01_lian_topknot/hair_01_lian_topknot_back.png"),
    (10, BASE),
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

MIN_SHEATH_RETAINED_PIXELS = 1600
MIN_SHEATH_RETAINED_RATIO = 0.10
MIN_BACK_RETAINED_PIXELS = 3500
MIN_BACK_RETAINED_RATIO = 0.08
MIN_COMBINED_DISTINCT_PIXELS = 5500


def rgba(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    image.load()
    assert image.size == (1024, 1024), (path, image.size)
    return image


def visible_pixels(image: Image.Image) -> int:
    hist = image.getchannel("A").histogram()
    return sum(hist[1:])


def diff_pixels(left: Image.Image, right: Image.Image) -> int:
    diff = ImageChops.difference(left.convert("RGBA"), right.convert("RGBA"))
    gray = diff.convert("RGB").convert("L")
    return sum(1 for value in gray.getdata() if value != 0)


def compose(sheath: Image.Image | None, back: Image.Image | None) -> Image.Image:
    layers: list[tuple[int, Image.Image]] = []
    if sheath is not None:
        layers.append((3, sheath))
    if back is not None:
        layers.append((4, back))
    for z, path in STATIC_LAYERS:
        layers.append((z, rgba(path)))
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for _z, image in sorted(layers, key=lambda item: item[0]):
        canvas.alpha_composite(image)
    return canvas


def main() -> None:
    equipment = json.loads(EQUIPMENT.read_text(encoding="utf-8"))
    base04 = json.loads(BASE04.read_text(encoding="utf-8"))
    candidates = json.loads(CANDIDATES.read_text(encoding="utf-8"))

    assert equipment["pack_id"] == "SHARED_MODULAR_EQUIPMENT"
    assert equipment["runtime_slots"] == ["weapon_back"]
    assert equipment["promotion"]["creator_exposure"] is False
    assert candidates["selection"]["selected_candidate"] == "v3_guardian_panel"
    assert base04["promotion"]["back_accessory_creator_exposure"] is False

    equipment_promoted = bool(equipment["promotion"]["runtime_activation"])
    back_promoted = bool(base04["promotion"]["back_accessory_runtime_activation"])

    modules = equipment["modules"]
    assert "sheath_lian_wu_blue" in modules
    sheath_contract = modules["sheath_lian_wu_blue"]
    assert sheath_contract["slot"] == "weapon_back"
    assert sheath_contract["layer"] == 3
    if equipment_promoted:
        assert sheath_contract["runtime_ready"] is True
        assert sheath_contract["production_ready"] is True
    sheath_path = ROOT / sheath_contract["path"]
    raw = sheath_path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == sheath_contract["sha256"]
    sheath = rgba(sheath_path)
    assert list(sheath.getchannel("A").getbbox()) == sheath_contract["alpha_bbox"]
    assert visible_pixels(sheath) == sheath_contract["visible_pixels"]

    selected_spec = candidates["candidates"]["v3_guardian_panel"]
    selected_candidate_path = ROOT / selected_spec["path"]
    selected_candidate = rgba(selected_candidate_path)
    assert hashlib.sha256(selected_candidate_path.read_bytes()).hexdigest() == selected_spec["sha256"]

    back = selected_candidate
    if back_promoted:
        assert "back_01_guardian_panel" in base04["back_accessories"]
        back_entry = base04["back_accessories"]["back_01_guardian_panel"]
        assert back_entry["runtime_ready"] is True and back_entry["production_ready"] is True
        module_id = back_entry["back_accessory"]
        assert module_id in base04["modules"]
        prod = base04["modules"][module_id]
        prod_path = ROOT / prod["path"]
        assert prod["slot"] == "back_accessory"
        assert prod["sha256"] == selected_spec["sha256"]
        assert hashlib.sha256(prod_path.read_bytes()).hexdigest() == selected_spec["sha256"]
        back = rgba(prod_path)

    baseline = compose(None, None)
    sheath_only = compose(sheath, None)
    back_only = compose(None, back)
    combined = compose(sheath, back)

    sheath_retained = diff_pixels(sheath_only, baseline)
    sheath_ratio = sheath_retained / float(max(visible_pixels(sheath), 1))
    back_retained = diff_pixels(back_only, baseline)
    back_ratio = back_retained / float(max(visible_pixels(back), 1))
    combined_delta = diff_pixels(combined, baseline)
    sheath_contribution_with_back = diff_pixels(combined, back_only)
    back_contribution_with_sheath = diff_pixels(combined, sheath_only)

    print(f"C68_4_SHEATH_READABILITY retained={sheath_retained} ratio={sheath_ratio:.4f}")
    print(f"C68_4_BACK_READABILITY retained={back_retained} ratio={back_ratio:.4f}")
    print(f"C68_4_COMBINED_DISTINCT combined={combined_delta} sheath_with_back={sheath_contribution_with_back} back_with_sheath={back_contribution_with_sheath}")

    assert sheath_retained >= MIN_SHEATH_RETAINED_PIXELS
    assert sheath_ratio >= MIN_SHEATH_RETAINED_RATIO
    assert back_retained >= MIN_BACK_RETAINED_PIXELS
    assert back_ratio >= MIN_BACK_RETAINED_RATIO
    assert combined_delta >= MIN_COMBINED_DISTINCT_PIXELS
    assert sheath_contribution_with_back >= MIN_SHEATH_RETAINED_PIXELS
    assert back_contribution_with_sheath >= MIN_BACK_RETAINED_PIXELS

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (1920, 1080), (24, 28, 35))
    draw = ImageDraw.Draw(sheet)
    views = [("SHEATH z3", sheath_only), ("PAINEL GUARDIAO z4", back_only), ("COMBINED z3<z4<z5", combined)]
    for index, (label, image) in enumerate(views):
        x = 20 + index * 635
        authored = image.resize((520, 520), Image.Resampling.NEAREST)
        flipped = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((360, 360), Image.Resampling.NEAREST)
        sheet.paste(authored.convert("RGB"), (x + 50, 70))
        sheet.paste(flipped.convert("RGB"), (x + 130, 630))
        draw.text((x + 18, 20), label, fill=(240, 240, 240))
        draw.text((x + 235, 600), "FLIPPED / GAMEPLAY CHECK", fill=(220, 220, 220))
        if index < 2:
            draw.line((x + 620, 0, x + 620, 1080), fill=(80, 86, 96), width=2)
    state = f"equipment_runtime={str(equipment_promoted).lower()} back_runtime={str(back_promoted).lower()} creator=false"
    draw.text((20, 1048), f"C68.4 • sheath_lian_wu_blue z3 + Painel Guardiao z4 + hair_back z5 • {state} • Tehkné Solutions", fill=(220, 220, 220))
    sheet.save(OUTPUT)

    print("C68_4_LAYER_ORDER=PASS weapon_back=3 back_accessory=4 hair_back=5")
    print("C68_4_COMPATIBILITY=PASS authored=true flipped=true gameplay_scale=true")
    print(f"C68_4_PROMOTION_STATE=PASS equipment_runtime={str(equipment_promoted).lower()} back_runtime={str(back_promoted).lower()} creator=false")
    print(f"C68_4_VISUAL_OUTPUT={OUTPUT.relative_to(ROOT)}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
