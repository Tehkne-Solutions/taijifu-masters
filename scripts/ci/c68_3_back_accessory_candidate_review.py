#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / "assets/modular_fighters/base_04/candidates/back_accessory_pack_01/candidates.json"
OUTPUT = ROOT / "artifacts/c68_3/C68_3_BACK_ACCESSORY_CANDIDATES.review-1920x1080.png"

BASE = ROOT / "assets/modular_fighters/base_00/base_fighter_v1_master.png"
LAYERS = [
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


def rgba(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != (1024, 1024):
        raise AssertionError(f"invalid canvas: {path} -> {image.size}")
    return image


def connected_components(image: Image.Image) -> int:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return 0
    crop = alpha.crop(bbox)
    w, h = crop.size
    px = crop.load()
    seen = bytearray(w * h)
    components = 0
    for y in range(h):
        for x in range(w):
            idx = y * w + x
            if seen[idx] or px[x, y] == 0:
                continue
            components += 1
            q = deque([(x, y)])
            seen[idx] = 1
            while q:
                cx, cy = q.popleft()
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    nidx = ny * w + nx
                    if not seen[nidx] and px[nx, ny] != 0:
                        seen[nidx] = 1
                        q.append((nx, ny))
    return components


def visible_pixels(image: Image.Image) -> int:
    hist = image.getchannel("A").histogram()
    return sum(hist[1:])


def compose(candidate: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    canvas.alpha_composite(candidate)
    for _z, path in sorted(LAYERS, key=lambda item: item[0]):
        canvas.alpha_composite(rgba(path))
    return canvas


def main() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert contract["stage"] == "C68.3"
    assert contract["runtime_activation"] is False
    assert contract["creator_exposure"] is False
    assert contract["constraints"]["candidate_count"] == 3
    assert contract["selection"]["selected_candidate"] is None

    composites: list[tuple[str, str, Image.Image]] = []
    for candidate_id, spec in contract["candidates"].items():
        path = ROOT / spec["path"]
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == spec["sha256"], candidate_id
        image = rgba(path)
        bbox = image.getchannel("A").getbbox()
        assert list(bbox) == spec["alpha_bbox"], (candidate_id, bbox)
        assert visible_pixels(image) == spec["visible_pixels"], candidate_id
        assert connected_components(image) == 1, candidate_id
        assert spec["connected_components"] == 1, candidate_id
        assert bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 1024 and bbox[3] < 1024, candidate_id
        assert bbox[3] <= contract["constraints"]["max_bottom_y"], candidate_id
        composites.append((candidate_id, spec["label"], compose(image)))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (1920, 1080), (24, 28, 35))
    draw = ImageDraw.Draw(sheet)
    panel_w = 620
    x0 = 20
    for index, (candidate_id, label, composite) in enumerate(composites):
        x = x0 + index * 635
        authored = composite.resize((520, 520), Image.Resampling.NEAREST)
        flipped = composite.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize((360, 360), Image.Resampling.NEAREST)
        sheet.paste(authored.convert("RGB"), (x + 50, 70))
        sheet.paste(flipped.convert("RGB"), (x + 130, 630))
        draw.text((x + 18, 20), f"{candidate_id} — {label}", fill=(240, 240, 240))
        draw.text((x + 238, 600), "FLIPPED / GAMEPLAY CHECK", fill=(220, 220, 220))
        if index < 2:
            draw.line((x + panel_w, 0, x + panel_w, 1080), fill=(80, 86, 96), width=2)
    draw.text((20, 1048), "C68.3 • Hair Topknot + Traje Marcial + Guarda Marcial • runtime=false • Creator=false • Tehkné Solutions", fill=(220, 220, 220))
    sheet.save(OUTPUT)

    print("C68_3_CANDIDATE_BINARIES=PASS count=3 rgba=1024x1024 connected=1")
    print("C68_3_COMPOSITION_MATRIX=PASS authored=true flipped=true gameplay_scale=true")
    print("C68_3_PROMOTION_STATE=PASS runtime=false creator=false selected=null")
    print(f"C68_3_VISUAL_OUTPUT={OUTPUT.relative_to(ROOT)}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
