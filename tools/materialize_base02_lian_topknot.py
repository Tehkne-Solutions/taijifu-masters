#!/usr/bin/env python3
"""Materialize BASE-02 Hair 01 from the exact approved Lian Character Lock.

Authoring-time only. The output preserves exact source RGB/A pixels under a
frozen semantic/spatial matte; no redraw, inpainting or resampling is allowed.
Tehkné Solutions.
"""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LIAN = ROOT / "assets/characters/lian_wu/character_lock/lian_wu_neutral.png"
BASE = ROOT / "assets/modular_fighters/base_00/base_fighter_v1_master.png"
MANIFEST = ROOT / "assets/modular_fighters/base_02/manifest.json"
CONTRACT = ROOT / "assets/modular_fighters/base_02/production/BASE02_HAIR_PACK_01_LIAN_TOPKNOT.json"
OUTPUT_ROOT = ROOT / "assets/modular_fighters/base_02/hair_01_lian_topknot"
BACK_PATH = OUTPUT_ROOT / "hair_01_lian_topknot_back.png"
FRONT_PATH = OUTPUT_ROOT / "hair_01_lian_topknot_front.png"

EXPECTED_LIAN_SHA = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
EXPECTED_BASE_SHA = "fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe"
CANVAS = (1024, 1024)
PIVOT = [0.5, 0.92]
HEAD_BOX = (250, 40, 780, 430)
STYLE_ID = "hair_01_lian_topknot"
BACK_ID = "hair_01_lian_topknot_back"
FRONT_ID = "hair_01_lian_topknot_front"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


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
            while q:
                cx, cy = q.popleft()
                points.append((cx, cy))
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    nidx = ny * w + nx
                    if seen[nidx] or pixels[nx, ny] == 0:
                        continue
                    seen[nidx] = 1
                    q.append((nx, ny))
            if len(points) >= min_pixels:
                components.append(points)
    components.sort(key=len, reverse=True)
    return components


def keep_components(mask: Image.Image, min_pixels: int) -> Image.Image:
    out = Image.new("L", mask.size, 0)
    target = out.load()
    for component in connected_components(mask, min_pixels=min_pixels):
        for point in component:
            target[point] = 255
    return out


def subtract_mask(a: Image.Image, b: Image.Image) -> Image.Image:
    raw = bytes(max(0, av - bv) for av, bv in zip(a.tobytes(), b.tobytes()))
    return Image.frombytes("L", a.size, raw)


def is_hair_color(r: int, g: int, b: int) -> bool:
    mean = (r + g + b) / 3.0
    skin_like = r > 145 and g > 90 and b > 50 and r > g > b and mean > 115
    blue_ribbon = b > 70 and b > r * 1.25 and b > g * 1.15
    dark_hair = mean < 115
    brown_hair = mean < 150 and r < 180 and g < 155 and b < 120 and not skin_like
    return (dark_hair or brown_hair or blue_ribbon) and not skin_like


def build_split(lian_head: Image.Image, base_head: Image.Image) -> tuple[Image.Image, Image.Image]:
    w, h = lian_head.size
    la = lian_head.getchannel("A")
    ba = base_head.getchannel("A")
    lp = lian_head.load(); lap = la.load(); bap = ba.load()

    back = Image.new("L", (w, h), 0)
    backp = back.load()
    for y in range(h):
        for x in range(w):
            if lap[x, y] < 16:
                continue
            if y < 322 and bap[x, y] < 16:
                if y > 305 and (x < 330 or x > 445):
                    continue
                backp[x, y] = 255

    front = Image.new("L", (w, h), 0)
    frontp = front.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = lp[x, y]
            if a < 16:
                continue
            spatial = 120 <= x <= 385 and 85 <= y <= 240
            spatial = spatial or (125 <= x <= 220 and 200 <= y <= 320)
            spatial = spatial or (300 <= x <= 355 and 150 <= y <= 235)
            if spatial and is_hair_color(r, g, b):
                frontp[x, y] = 255

    front = keep_components(front, 15)
    back = keep_components(subtract_mask(back, front), 8)
    if sum(1 for av, bv in zip(back.tobytes(), front.tobytes()) if av and bv) != 0:
        raise RuntimeError("front_back_overlap")
    if back.getbbox() is None or front.getbbox() is None:
        raise RuntimeError("empty_hair_split")
    return back, front


def full_canvas_from_crop(source_crop: Image.Image, mask: Image.Image) -> Image.Image:
    crop = Image.new("RGBA", source_crop.size, (0, 0, 0, 0))
    crop.paste(source_crop, (0, 0), mask)
    full = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    full.alpha_composite(crop, (HEAD_BOX[0], HEAD_BOX[1]))
    return full


def assert_exact_source_pixels(output: Image.Image, source: Image.Image) -> None:
    op = output.load(); sp = source.load()
    for y in range(CANVAS[1]):
        for x in range(CANVAS[0]):
            pixel = op[x, y]
            if pixel[3] and pixel != sp[x, y]:
                raise RuntimeError(f"source_pixel_mutation:{x},{y}")


def module_contract(module_id: str, slot: str, path: Path, image: Image.Image) -> dict:
    return {
        "slot": slot,
        "path": rel(path),
        "sha256": sha256(path),
        "canvas": list(CANVAS),
        "mode": "RGBA",
        "alpha_bbox": list(image.getchannel("A").getbbox()),
        "pivot": PIVOT,
        "root_anchor": "bottom_center",
        "source": {
            "method": "exact_character_lock_source_pixel_matte_v1",
            "lian_character_lock_sha256": EXPECTED_LIAN_SHA,
            "base00_reference_sha256": EXPECTED_BASE_SHA,
            "resampling": False,
            "redraw": False,
            "source_pixel_mutation": False,
        },
    }


def main() -> None:
    if not LIAN.is_file() or not BASE.is_file() or not MANIFEST.is_file():
        raise SystemExit("C66_1_MATERIALIZE=BLOCKED source_or_manifest_missing")
    if sha256(LIAN) != EXPECTED_LIAN_SHA:
        raise SystemExit("C66_1_MATERIALIZE=BLOCKED lian_sha_mismatch")
    if sha256(BASE) != EXPECTED_BASE_SHA:
        raise SystemExit("C66_1_MATERIALIZE=BLOCKED base00_sha_mismatch")

    lian = Image.open(LIAN).convert("RGBA")
    base = Image.open(BASE).convert("RGBA")
    if lian.size != CANVAS or base.size != CANVAS:
        raise SystemExit("C66_1_MATERIALIZE=BLOCKED canvas")

    lian_head = lian.crop(HEAD_BOX)
    base_head = base.crop(HEAD_BOX)
    back_mask, front_mask = build_split(lian_head, base_head)
    hair_back = full_canvas_from_crop(lian_head, back_mask)
    hair_front = full_canvas_from_crop(lian_head, front_mask)
    assert_exact_source_pixels(hair_back, lian)
    assert_exact_source_pixels(hair_front, lian)

    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    hair_back.save(BACK_PATH, format="PNG")
    hair_front.save(FRONT_PATH, format="PNG")

    # Re-open encoded outputs and fail closed on authoring contract.
    back_disk = Image.open(BACK_PATH).convert("RGBA")
    front_disk = Image.open(FRONT_PATH).convert("RGBA")
    if back_disk.size != CANVAS or front_disk.size != CANVAS:
        raise SystemExit("C66_1_MATERIALIZE=BLOCKED output_canvas")
    if back_disk.getchannel("A").getbbox() is None or front_disk.getchannel("A").getbbox() is None:
        raise SystemExit("C66_1_MATERIALIZE=BLOCKED output_empty")
    assert_exact_source_pixels(back_disk, lian)
    assert_exact_source_pixels(front_disk, lian)

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    manifest["version"] = "1.0.0-candidate"
    manifest["status"] = "production_candidate_runtime_validation_pending"
    manifest["styles"][STYLE_ID] = {
        "label": "Topknot Lian",
        "hair_back": BACK_ID,
        "hair_front": FRONT_ID,
        "requires_art_assets": True,
        "production_ready": False,
        "source_lineage": "exact_historical_lian_character_lock",
    }
    manifest["modules"] = {
        BACK_ID: module_contract(BACK_ID, "hair_back", BACK_PATH, back_disk),
        FRONT_ID: module_contract(FRONT_ID, "hair_front", FRONT_PATH, front_disk),
    }
    manifest["promotion"] = {
        "art_pack_required": True,
        "art_assets_present": True,
        "creator_exposure": False,
        "battle_activation": False,
        "owner_visual_review": "diagnostic_split_pass_runtime_pending",
    }
    manifest["next_stage"] = "C66_1_RUNTIME_AND_BATTLE_VALIDATION"
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    contract = {
        "schema": "tehkne/taijifu-base02-hair-pack/v1",
        "signature": "Tehkné Solutions",
        "component_id": "BASE02_HAIR_PACK_01_LIAN_TOPKNOT",
        "stage": "C66.1",
        "status": "production_candidate_runtime_validation_pending",
        "style_id": STYLE_ID,
        "modules": {"hair_back": BACK_ID, "hair_front": FRONT_ID},
        "source": {
            "character_lock_sha256": EXPECTED_LIAN_SHA,
            "base00_reference_sha256": EXPECTED_BASE_SHA,
            "derivation": "exact_character_lock_source_pixel_matte_v1",
            "diagnostic_artifact": {
                "workflow_run": 31330055231,
                "artifact_id": 9042650886,
                "artifact_sha256": "98048b44188dc044418b273749aedff0b57f8d6eb6e4a768e905398b9c54a697",
            },
        },
        "authoring": {
            "canvas": list(CANVAS),
            "mode": "RGBA",
            "pivot": PIVOT,
            "root_anchor": "bottom_center",
            "redraw": False,
            "resampling": False,
            "source_pixel_mutation": False,
        },
        "promotion": {
            "binary_materialized": True,
            "runtime_validation": "pending",
            "battle_visual_review": "pending",
            "creator_exposure": False,
            "creator_control_stage": "C66.2",
        },
        "signature_note": "Tehkné Solutions",
    }
    CONTRACT.parent.mkdir(parents=True, exist_ok=True)
    CONTRACT.write_text(json.dumps(contract, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"C66_1_MATERIALIZE=PASS style={STYLE_ID}")
    print(f"C66_1_HAIR_BACK_SHA256={sha256(BACK_PATH)}")
    print(f"C66_1_HAIR_FRONT_SHA256={sha256(FRONT_PATH)}")
    print("C66_1_SOURCE_PIXELS=PASS redraw=false resampling=false mutation=false")
    print("C66_1_RUNTIME_VALIDATION=PENDING")
    print("C66_1_CREATOR_EXPOSURE=BLOCKED stage=C66.2")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
