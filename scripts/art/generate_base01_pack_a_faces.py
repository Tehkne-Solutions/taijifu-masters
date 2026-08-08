#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from statistics import median

from PIL import Image, ImageDraw, ImageFilter, ImageOps

SIGNATURE = "Tehkné Solutions"
CANVAS = (1024, 1024)
SOURCE_FACE_SHA256 = "d8bc0218b6104d2095e20a074fa4e0a23d428d1bf71e91fcac7139374b3504d9"
BASE00_SHA256 = "fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe"
EYES_SHA256 = "7517e6d14cef106fbe782736524321b992ea3088486498fc24e71f1e158419a9"
BROWS_SHA256 = "44fa5d30e0963582b5cf2d877b7a61a6d68f8028b9a2da19cbba9a73afc80225"

FACE_BBOXES = {
    "left_ear": (367, 304, 390, 346),
    "right_ear": (585, 302, 605, 336),
    "mouth": (458, 369, 484, 373),
}

VARIANTS = {
    "face_02_angular": {
        "intent": "more angular cheek and jaw planes; mature martial identity; preserves base silhouette",
        "filename": "face_02_angular.png",
    },
    "face_03_soft": {
        "intent": "softer cheek and jaw planes; youthful neutral identity; preserves base silhouette",
        "filename": "face_03_soft.png",
    },
    "face_04_broad": {
        "intent": "broader cheek and jaw planes; powerful grounded identity; preserves base silhouette",
        "filename": "face_04_broad.png",
    },
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bbox(image: Image.Image) -> list[int]:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise RuntimeError("generated module is fully transparent")
    x0, y0, x1, y1 = box
    return [x0, y0, x1 - 1, y1 - 1]


def transparent_corners(image: Image.Image) -> bool:
    alpha = image.getchannel("A")
    w, h = image.size
    return all(alpha.getpixel(p) == 0 for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)))


def source_accent(source: Image.Image) -> tuple[int, int, int]:
    candidates: list[tuple[int, int, int]] = []
    for r, g, b, a in source.getdata():
        if a and 80 < r < 230 and 25 < g < 145 and b < 105 and r > g:
            candidates.append((r, g, b))
    if not candidates:
        return (186, 100, 53)
    return (
        int(median(v[0] for v in candidates)),
        int(median(v[1] for v in candidates)),
        int(median(v[2] for v in candidates)),
    )


def paste_scaled(
    canvas: Image.Image,
    source: Image.Image,
    bbox: tuple[int, int, int, int],
    sx: float,
    sy: float,
    shift_x: int = 0,
    shift_y: int = 0,
) -> None:
    x0, y0, x1, y1 = bbox
    crop = source.crop(bbox)
    ow, oh = crop.size
    nw = max(1, round(ow * sx))
    nh = max(1, round(oh * sy))
    resized = crop.resize((nw, nh), Image.Resampling.BICUBIC)
    cx = (x0 + x1) / 2 + shift_x
    cy = (y0 + y1) / 2 + shift_y
    px = round(cx - nw / 2)
    py = round(cy - nh / 2)
    canvas.alpha_composite(resized, (px, py))


def make_angular(source: Image.Image, accent: tuple[int, int, int]) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    paste_scaled(out, source, FACE_BBOXES["left_ear"], 0.86, 1.00, 2, -1)
    paste_scaled(out, source, FACE_BBOXES["right_ear"], 0.86, 1.03, -2, -1)
    paste_scaled(out, source, FACE_BBOXES["mouth"], 1.12, 0.82, 0, -1)
    draw = ImageDraw.Draw(out, "RGBA")
    warm_dark = (*accent, 105)
    warm_light = (min(255, accent[0] + 35), min(255, accent[1] + 35), min(255, accent[2] + 25), 80)
    draw.line([(412, 353), (426, 359), (436, 358)], fill=warm_dark, width=2)
    draw.line([(553, 352), (542, 358), (533, 357)], fill=warm_dark, width=2)
    draw.line([(431, 373), (441, 377)], fill=warm_light, width=2)
    draw.line([(526, 373), (517, 377)], fill=warm_light, width=2)
    return out


def make_soft(source: Image.Image, accent: tuple[int, int, int]) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    paste_scaled(out, source, FACE_BBOXES["left_ear"], 1.05, 1.06, 0, 1)
    paste_scaled(out, source, FACE_BBOXES["right_ear"], 1.05, 1.07, 0, 1)
    mouth = source.crop(FACE_BBOXES["mouth"]).resize((24, 6), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(0.25))
    out.alpha_composite(mouth, (459, 368))
    draw = ImageDraw.Draw(out, "RGBA")
    soft = (min(255, accent[0] + 45), min(255, accent[1] + 45), min(255, accent[2] + 35), 65)
    draw.arc((407, 348, 431, 366), 20, 115, fill=soft, width=2)
    draw.arc((538, 347, 562, 365), 65, 160, fill=soft, width=2)
    return out


def make_broad(source: Image.Image, accent: tuple[int, int, int]) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    paste_scaled(out, source, FACE_BBOXES["left_ear"], 1.13, 1.03, -3, 0)
    paste_scaled(out, source, FACE_BBOXES["right_ear"], 1.13, 1.04, 3, 0)
    paste_scaled(out, source, FACE_BBOXES["mouth"], 1.28, 0.95, -1, 0)
    draw = ImageDraw.Draw(out, "RGBA")
    warm = (*accent, 88)
    warm_dark = (max(0, accent[0] - 20), max(0, accent[1] - 18), max(0, accent[2] - 12), 95)
    draw.line([(404, 357), (423, 363), (437, 362)], fill=warm, width=2)
    draw.line([(561, 355), (545, 362), (532, 361)], fill=warm, width=2)
    draw.line([(426, 376), (442, 380)], fill=warm_dark, width=2)
    draw.line([(532, 376), (516, 380)], fill=warm_dark, width=2)
    return out


def checkerboard(size: tuple[int, int], cell: int = 24) -> Image.Image:
    bg = Image.new("RGBA", size, (240, 240, 240, 255))
    draw = ImageDraw.Draw(bg)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2 == 0:
                draw.rectangle((x, y, min(size[0], x + cell), min(size[1], y + cell)), fill=(205, 205, 205, 255))
    return bg


def assembled(base: Image.Image, face: Image.Image, eyes: Image.Image, brows: Image.Image) -> Image.Image:
    out = base.copy()
    out.alpha_composite(face)
    out.alpha_composite(eyes)
    out.alpha_composite(brows)
    return out


def character_crop(image: Image.Image, padding: int = 14) -> Image.Image:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise RuntimeError("assembled character is empty")
    x0, y0, x1, y1 = box
    x0 = max(0, x0 - padding)
    y0 = max(0, y0 - padding)
    x1 = min(image.width, x1 + padding)
    y1 = min(image.height, y1 + padding)
    return image.crop((x0, y0, x1, y1))


def fit(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(max_size, Image.Resampling.LANCZOS)
    return copy


def gameplay_preview(image: Image.Image, height: int = 132) -> Image.Image:
    char = character_crop(image, 4)
    width = max(1, round(char.width * (height / char.height)))
    char = char.resize((width, height), Image.Resampling.LANCZOS)
    stage = checkerboard((220, 170), 14)
    x = (stage.width - char.width) // 2
    y = stage.height - char.height - 10
    stage.alpha_composite(char, (x, y))
    draw = ImageDraw.Draw(stage)
    draw.line((15, stage.height - 10, stage.width - 15, stage.height - 10), fill=(50, 210, 135, 255), width=2)
    return stage


def module_preview(image: Image.Image) -> Image.Image:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise RuntimeError("module preview source empty")
    x0, y0, x1, y1 = box
    pad = 26
    crop = image.crop((max(0, x0 - pad), max(0, y0 - pad), min(image.width, x1 + pad), min(image.height, y1 + pad)))
    crop = fit(crop, (420, 220))
    bg = checkerboard((440, 240), 18)
    bg.alpha_composite(crop, ((bg.width - crop.width) // 2, (bg.height - crop.height) // 2))
    return bg


def build_contact_sheet(rows: dict[str, dict[str, Image.Image]], output: Path) -> None:
    sheet = Image.new("RGBA", (1920, 1080), (15, 20, 27, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((56, 34), "TAIJIFU MASTERS — BASE01 PACK A FACES — CANDIDATE REVIEW", fill=(244, 188, 72, 255))
    draw.text((56, 62), "Generated deterministically from canonical face_01_balanced; preview only; not runtime source", fill=(210, 218, 228, 255))
    columns = [(40, 100, 620, 1010), (670, 100, 1250, 1010), (1300, 100, 1880, 1010)]
    for (variant_id, previews), col in zip(rows.items(), columns):
        x0, y0, x1, y1 = col
        draw.rounded_rectangle(col, radius=18, outline=(100, 120, 145, 255), width=2, fill=(25, 31, 40, 255))
        draw.text((x0 + 22, y0 + 18), variant_id, fill=(255, 255, 255, 255))
        module = previews["module"]
        sheet.alpha_composite(module, (x0 + (580 - module.width) // 2, y0 + 54))
        draw.text((x0 + 22, y0 + 306), "AUTHORED", fill=(91, 220, 154, 255))
        auth = fit(character_crop(previews["authored"]), (230, 420))
        sheet.alpha_composite(auth, (x0 + 42, y0 + 340))
        draw.text((x0 + 302, y0 + 306), "FLIPPED", fill=(91, 220, 154, 255))
        flip = fit(character_crop(previews["flipped"]), (230, 420))
        sheet.alpha_composite(flip, (x0 + 302, y0 + 340))
        draw.text((x0 + 22, y0 + 785), "GAMEPLAY 132px", fill=(210, 218, 228, 255))
        game = previews["gameplay"]
        sheet.alpha_composite(game, (x0 + 180, y0 + 750))
    draw.text((56, 1040), SIGNATURE, fill=(244, 188, 72, 255))
    sheet.convert("RGB").save(output, "PNG")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    parser.add_argument("--output", default="build/base01-pack-a-faces")
    args = parser.parse_args()

    root = Path(args.repo_root).resolve()
    output = (root / args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)

    paths = {
        "base": root / "assets/modular_fighters/base_00/base_fighter_v1_master.png",
        "face": root / "assets/modular_fighters/base_01/face/face_01_balanced.png",
        "eyes": root / "assets/modular_fighters/base_01/eyes/eyes_01_focused.png",
        "brows": root / "assets/modular_fighters/base_01/brows/brows_01_focused.png",
    }
    expected = {"base": BASE00_SHA256, "face": SOURCE_FACE_SHA256, "eyes": EYES_SHA256, "brows": BROWS_SHA256}
    for key, path in paths.items():
        if not path.exists():
            raise SystemExit(f"C59_1_SOURCE_MISSING key={key} path={path}")
        actual = sha256(path)
        if actual != expected[key]:
            raise SystemExit(f"C59_1_SOURCE_SHA_BLOCKED key={key} expected={expected[key]} actual={actual}")
        print(f"C59_1_SOURCE_SHA=PASS key={key} sha256={actual}")

    base = Image.open(paths["base"]).convert("RGBA")
    source = Image.open(paths["face"]).convert("RGBA")
    eyes = Image.open(paths["eyes"]).convert("RGBA")
    brows = Image.open(paths["brows"]).convert("RGBA")
    for name, image in (("base", base), ("face", source), ("eyes", eyes), ("brows", brows)):
        if image.size != CANVAS or image.mode != "RGBA":
            raise SystemExit(f"C59_1_SOURCE_CONTRACT_BLOCKED key={name} size={image.size} mode={image.mode}")

    accent = source_accent(source)
    generated = {
        "face_02_angular": make_angular(source, accent),
        "face_03_soft": make_soft(source, accent),
        "face_04_broad": make_broad(source, accent),
    }

    qa = {
        "schema": "tehkne/taijifu-base01-pack-a-candidate-qa/v1",
        "signature": SIGNATURE,
        "pack_id": "BASE01-PACK-A-FACES",
        "status": "CANDIDATE_REVIEW_REQUIRED",
        "source_sha256": SOURCE_FACE_SHA256,
        "pivot": [0.5, 0.92],
        "root_anchor": "bottom_center",
        "owner_review": "PENDING",
        "runtime_import": "PENDING",
        "promotion": "BLOCKED_REVIEW_AND_RUNTIME",
        "modules": {},
    }
    preview_rows: dict[str, dict[str, Image.Image]] = {}
    hashes: set[str] = set()

    for variant_id, image in generated.items():
        if image.size != CANVAS or image.mode != "RGBA":
            raise SystemExit(f"C59_1_GENERATED_CONTRACT_BLOCKED module={variant_id}")
        if not transparent_corners(image):
            raise SystemExit(f"C59_1_TRANSPARENT_CORNERS_BLOCKED module={variant_id}")
        path = output / VARIANTS[variant_id]["filename"]
        image.save(path, "PNG", optimize=False)
        digest = sha256(path)
        if digest == SOURCE_FACE_SHA256 or digest in hashes:
            raise SystemExit(f"C59_1_UNIQUENESS_BLOCKED module={variant_id} sha256={digest}")
        hashes.add(digest)
        bbox = alpha_bbox(image)
        qa["modules"][variant_id] = {
            "path": path.name,
            "intent": VARIANTS[variant_id]["intent"],
            "sha256": digest,
            "canvas": [1024, 1024],
            "mode": "RGBA",
            "alpha_bbox": bbox,
            "transparent_corners": True,
            "authored_review": "PENDING_OWNER_REVIEW",
            "flipped_review": "PENDING_OWNER_REVIEW",
            "gameplay_scale_132px": "PENDING_OWNER_REVIEW",
        }
        character = assembled(base, image, eyes, brows)
        preview_rows[variant_id] = {
            "module": module_preview(image),
            "authored": character,
            "flipped": ImageOps.mirror(character),
            "gameplay": gameplay_preview(character, 132),
        }
        print(f"C59_1_CANDIDATE=PASS module={variant_id} sha256={digest} bbox={bbox}")

    build_contact_sheet(preview_rows, output / "BASE01_PACK_A_FACES.contact-sheet-1920x1080.png")
    (output / "BASE01_PACK_A_FACES.candidate-qa.json").write_text(json.dumps(qa, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (output / "checksums.sha256").write_text(
        "".join(f"{entry['sha256']}  {entry['path']}\n" for entry in qa["modules"].values()), encoding="utf-8"
    )
    print("C59_1_PACK_A_FACES_CANDIDATE_GENERATION=PASS")
    print("OWNER_REVIEW=PENDING")
    print("RUNTIME_IMPORT=PENDING")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
