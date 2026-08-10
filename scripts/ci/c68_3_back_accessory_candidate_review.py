#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

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

MIN_RETAINED_PIXELS = 3500
MIN_RETAINED_RATIO = 0.08
MIN_PAIRWISE_DIFFERENCE = 3000


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


def compose(candidate: Image.Image | None) -> Image.Image:
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    if candidate is not None:
        canvas.alpha_composite(candidate)
    for _z, path in sorted(LAYERS, key=lambda item: item[0]):
        canvas.alpha_composite(rgba(path))
    return canvas


def difference_pixels(left: Image.Image, right: Image.Image) -> int:
    diff = ImageChops.difference(left.convert("RGBA"), right.convert("RGBA"))
    alpha = diff.convert("RGB").convert("L")
    return sum(1 for value in alpha.getdata() if value != 0)


def main() -> None:
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert contract["stage"] == "C68.3"
    assert contract["runtime_activation"] is False
    assert contract["creator_exposure"] is False
    assert contract["constraints"]["candidate_count"] == 3
    assert contract["selection"]["selected_candidate"] is None

    baseline = compose(None)
    composites: list[tuple[str, str, Image.Image]] = []
    readability: dict[str, tuple[int, float]] = {}
    failures: list[str] = []

    for candidate_id, spec in contract["candidates"].items():
        path = ROOT / spec["path"]
        raw = path.read_bytes()
        assert hashlib.sha256(raw).hexdigest() == spec["sha256"], candidate_id
        image = rgba(path)
        bbox = image.getchannel("A").getbbox()
        assert list(bbox) == spec["alpha_bbox"], (candidate_id, bbox)
        total_visible = visible_pixels(image)
        assert total_visible == spec["visible_pixels"], candidate_id
        assert connected_components(image) == 1, candidate_id
        assert spec["connected_components"] == 1, candidate_id
        assert bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 1024 and bbox[3] < 1024, candidate_id
        assert bbox[3] <= contract["constraints"]["max_bottom_y"], candidate_id

        composed = compose(image)
        retained = difference_pixels(composed, baseline)
        ratio = retained / float(max(total_visible, 1))
        readability[candidate_id] = (retained, ratio)
        print(f"C68_3_READABILITY candidate={candidate_id} retained_pixels={retained} retained_ratio={ratio:.4f}")
        if retained < MIN_RETAINED_PIXELS:
            failures.append(f"{candidate_id}:retained_pixels:{retained}<{MIN_RETAINED_PIXELS}")
        if ratio < MIN_RETAINED_RATIO:
            failures.append(f"{candidate_id}:retained_ratio:{ratio:.4f}<{MIN_RETAINED_RATIO:.4f}")
        composites.append((candidate_id, spec["label"], composed))

    for left_index in range(len(composites)):
        for right_index in range(left_index + 1, len(composites)):
            left_id, _, left = composites[left_index]
            right_id, _, right = composites[right_index]
            pair_diff = difference_pixels(left, right)
            print(f"C68_3_DISTINCTNESS pair={left_id}:{right_id} pixels={pair_diff}")
            if pair_diff < MIN_PAIRWISE_DIFFERENCE:
                failures.append(f"{left_id}:{right_id}:pair_diff:{pair_diff}<{MIN_PAIRWISE_DIFFERENCE}")

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
        retained, ratio = readability[candidate_id]
        draw.text((x + 18, 20), f"{candidate_id} — {label}", fill=(240, 240, 240))
        draw.text((x + 18, 44), f"retained={retained} ({ratio:.1%})", fill=(220, 220, 220))
        draw.text((x + 238, 600), "FLIPPED / GAMEPLAY CHECK", fill=(220, 220, 220))
        if index < 2:
            draw.line((x + panel_w, 0, x + panel_w, 1080), fill=(80, 86, 96), width=2)
    draw.text((20, 1048), "C68.3 • Hair Topknot + Traje Marcial + Guarda Marcial • runtime=false • Creator=false • Tehkné Solutions", fill=(220, 220, 220))
    sheet.save(OUTPUT)

    if failures:
        print("C68_3_GAMEPLAY_READABILITY=BLOCKED " + " | ".join(failures))
        raise AssertionError("candidate silhouettes are not sufficiently readable/distinct in canonical z-order")

    print("C68_3_CANDIDATE_BINARIES=PASS count=3 rgba=1024x1024 connected=1")
    print("C68_3_GAMEPLAY_READABILITY=PASS canonical_z_order=true")
    print("C68_3_COMPOSITION_MATRIX=PASS authored=true flipped=true gameplay_scale=true")
    print("C68_3_PROMOTION_STATE=PASS runtime=false creator=false selected=null")
    print(f"C68_3_VISUAL_OUTPUT={OUTPUT.relative_to(ROOT)}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
