#!/usr/bin/env python3
"""C66.1 diagnostic only: compare exact Lian Character Lock vs BASE-00 for Hair reuse feasibility."""

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
HEAD_BOX = (250, 40, 780, 430)


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
                draw.rectangle((x, y, min(x + cell - 1, size[0] - 1), min(y + cell - 1, size[1] - 1)), fill=(205, 205, 205, 255))
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
            count = 0
            minx = maxx = x
            miny = maxy = y
            while q:
                cx, cy = q.popleft()
                count += 1
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
            if count >= min_pixels:
                components.append({"pixels": count, "bbox": [minx, miny, maxx + 1, maxy + 1]})
    components.sort(key=lambda item: item["pixels"], reverse=True)
    return components


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if not LIAN.is_file() or not BASE.is_file():
        raise SystemExit("C66_1_HAIR_SOURCE_PROBE=BLOCKED source_missing")
    if sha256(LIAN) != EXPECTED_LIAN_SHA:
        raise SystemExit("C66_1_HAIR_SOURCE_PROBE=BLOCKED lian_sha_mismatch")

    lian = Image.open(LIAN).convert("RGBA")
    base = Image.open(BASE).convert("RGBA")
    if lian.size != (1024, 1024) or base.size != (1024, 1024):
        raise SystemExit(f"C66_1_HAIR_SOURCE_PROBE=BLOCKED canvas lian={lian.size} base={base.size}")

    lian_head = lian.crop(HEAD_BOX)
    base_head = base.crop(HEAD_BOX)
    w, h = lian_head.size

    # 1) High-confidence silhouette addition: Lian is opaque where BASE-00 is transparent.
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

    # 2) Broad changed-pixel mask: useful diagnostic, not a production extraction.
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

    # Diagnostic RGBA candidates retain exact Lian pixels under each mask.
    exclusive_rgba = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    exclusive_rgba.paste(lian_head, (0, 0), exclusive)
    changed_rgba = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    changed_rgba.paste(lian_head, (0, 0), changed)

    lian_head.save(OUT / "01_lian_head_source.png")
    base_head.save(OUT / "02_base00_head_source.png")
    alpha_preview(exclusive_rgba).save(OUT / "03_exclusive_alpha_preview.png")
    exclusive_rgba.save(OUT / "04_exclusive_alpha_rgba.png")
    alpha_preview(changed_rgba).save(OUT / "05_changed_pixels_preview.png")
    changed_rgba.save(OUT / "06_changed_pixels_rgba.png")
    diff.save(OUT / "07_raw_rgba_difference.png")

    # Side-by-side visual evidence, no resampling.
    panel = Image.new("RGBA", (w * 4, h), (24, 24, 24, 255))
    panel.paste(alpha_preview(lian_head), (0, 0))
    panel.paste(alpha_preview(base_head), (w, 0))
    panel.paste(alpha_preview(exclusive_rgba), (w * 2, 0))
    panel.paste(alpha_preview(changed_rgba), (w * 3, 0))
    panel.save(OUT / "C66_1_LIAN_HAIR_SOURCE_FEASIBILITY.contact.png")

    exclusive_components = connected_components(exclusive)
    changed_components = connected_components(changed)
    report = {
        "schema": "tehkne/taijifu-c66-1-hair-source-feasibility/v1",
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
        },
        "diagnostics": {
            "exclusive_alpha_pixels": exclusive_count,
            "exclusive_alpha_bbox_local": binary_bbox(exclusive),
            "exclusive_components": exclusive_components[:20],
            "changed_pixels": changed_count,
            "changed_bbox_local": binary_bbox(changed),
            "changed_components": changed_components[:20],
        },
        "policy": {
            "diagnostic_is_production_asset": False,
            "automatic_hair_promotion_allowed": False,
            "pixel_reuse_only_if_visual_review_proves_clean_hair_separation": True,
            "fallback_if_contaminated": "author_new_BASE02_hair_art",
        },
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"C66_1_HAIR_SOURCE_PROBE=PASS exclusive={exclusive_count} changed={changed_count}")
    print("C66_1_PRODUCTION_PROMOTION=BLOCKED owner_visual_review_required")
    print(f"C66_1_OUTPUT={OUT.relative_to(ROOT).as_posix()}")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
