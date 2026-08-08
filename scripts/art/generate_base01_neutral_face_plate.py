#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

BASE_PATH = Path("assets/modular_fighters/base_00/base_fighter_v1_master.png")
PALETTE_PATH = Path("assets/modular_fighters/base_01/palettes/skin_tone_03_warm.json")
EYES_PATH = Path("assets/modular_fighters/base_01/eyes/eyes_01_focused.png")
BROWS_PATH = Path("assets/modular_fighters/base_01/brows/brows_01_focused.png")
EXPECTED = {
    "base": "fd07d14d744e3433ad1f13877e333650e5ce26a4d41d4b14d7646b6bcd47e3fe",
    "eyes": "7517e6d14cef106fbe782736524321b992ea3088486498fc24e71f1e158419a9",
    "brows": "44fa5d30e0963582b5cf2d877b7a61a6d68f8028b9a2da19cbba9a73afc80225",
}
FACES = ["face_02_angular.png", "face_03_soft.png", "face_04_broad.png"]
SIGNATURE = "Tehkné Solutions"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fail(msg: str) -> None:
    raise SystemExit(f"C59_2_NEUTRAL_FACE_PLATE=BLOCKED {msg}")


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] * (1.0 - t) + b[i] * t) for i in range(3))


def checker(size: tuple[int, int], cell: int = 18) -> Image.Image:
    out = Image.new("RGB", size, (238, 238, 238))
    d = ImageDraw.Draw(out)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if ((x // cell) + (y // cell)) % 2:
                d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=(205, 205, 205))
    return out


def build_plate(base: Image.Image, palette: dict) -> tuple[Image.Image, Image.Image]:
    w, h = base.size
    alpha = base.getchannel("A")
    silhouette = alpha.point(lambda p: 255 if p > 8 else 0)

    # Protect the external silhouette/ink while wiping only internal identity-bearing regions.
    expanded = silhouette.filter(ImageFilter.MaxFilter(9))
    contracted = silhouette.filter(ImageFilter.MinFilter(9))
    edge = Image.eval(ImageChopsSubtract(expanded, contracted), lambda p: 255 if p else 0)
    protected_edge = edge.filter(ImageFilter.MaxFilter(9))

    region = Image.new("L", (w, h), 0)
    rd = ImageDraw.Draw(region)
    rd.ellipse((365, 245, 610, 395), fill=255)   # brows + eyes + nose + mouth + cheek planes
    rd.ellipse((350, 282, 425, 370), fill=255)   # authored ear interior
    rd.ellipse((555, 282, 632, 370), fill=255)   # opposite ear interior
    region = region.filter(ImageFilter.GaussianBlur(2.0))

    # Hard interior core avoids any ghost of the BASE-00 default identity.
    core = region.point(lambda p: 255 if p >= 32 else 0)
    final_mask = Image.new("L", (w, h), 0)
    fm = final_mask.load(); c = core.load(); s = silhouette.load(); e = protected_edge.load()
    for y in range(230, 405):
        for x in range(335, 650):
            if c[x, y] and s[x, y] and not e[x, y]:
                fm[x, y] = 255

    base_c = hex_rgb(palette["channels"]["skin_base"])
    shadow = hex_rgb(palette["channels"]["skin_shadow"])
    hi = hex_rgb(palette["channels"]["skin_highlight"])
    cheek = hex_rgb(palette["channels"]["cheek_tint"])

    plate = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = plate.load(); m = final_mask.load()
    for y in range(230, 405):
        fy = (y - 245.0) / 150.0
        for x in range(335, 650):
            if not m[x, y]:
                continue
            fx = (x - 365.0) / 245.0
            color = base_c
            # left-side cel shadow, matching the canonical lighting direction
            shadow_t = max(0.0, (0.28 - fx) / 0.28) * 0.42
            color = mix(color, shadow, shadow_t)
            # soft upper-center highlight
            dx = (fx - 0.58) / 0.55
            dy = (fy - 0.18) / 0.65
            radial = max(0.0, 1.0 - (dx * dx + dy * dy))
            color = mix(color, hi, radial * 0.22)
            # subtle cheek warmth low in the face
            cheek_t = max(0.0, min(1.0, (fy - 0.52) / 0.48)) * 0.14
            color = mix(color, cheek, cheek_t)
            px[x, y] = (*color, 255)

    neutralized = Image.alpha_composite(base, plate)
    return plate, neutralized


def ImageChopsSubtract(a: Image.Image, b: Image.Image) -> Image.Image:
    # local helper avoids importing a wider surface than needed
    import PIL.ImageChops
    return PIL.ImageChops.subtract(a, b)


def compose(base: Image.Image, *layers: Image.Image) -> Image.Image:
    out = base.copy()
    for layer in layers:
        out = Image.alpha_composite(out, layer)
    return out


def alpha_bbox(img: Image.Image):
    return img.getchannel("A").getbbox()


def changed_pixels(a: Image.Image, b: Image.Image) -> int:
    import numpy as np
    aa = np.asarray(a, dtype=np.int16)
    bb = np.asarray(b, dtype=np.int16)
    return int(np.any(aa != bb, axis=2).sum())


def make_contact(out: Path, plate: Image.Image, base: Image.Image, neutral: Image.Image,
                 faces: list[Image.Image], eyes: Image.Image, brows: Image.Image) -> None:
    canvas = Image.new("RGB", (1920, 1080), (13, 20, 29))
    d = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    gold = (245, 184, 54)
    green = (80, 220, 156)
    muted = (188, 200, 216)
    d.text((48, 35), "TAIJIFU MASTERS — C59.2 NEUTRAL FACE PLATE PROTOTYPE", fill=gold, font=font)
    d.text((48, 58), "candidate artifact only • BASE-00 identity neutralization before non-default face swap", fill=muted, font=font)

    # top row: plate, neutralized base, three assemblies
    boxes = [(45, 105, 330, 390), (365, 105, 650, 390), (690, 105, 975, 390),
             (1010, 105, 1295, 390), (1330, 105, 1615, 390)]
    labels = ["FACE PLATE", "NEUTRALIZED BASE", "ANGULAR", "SOFT", "BROAD"]
    visuals = [plate, neutral] + [compose(base, plate, f, eyes, brows) for f in faces]
    for box, label, visual in zip(boxes, labels, visuals):
        x1,y1,x2,y2=box
        d.rounded_rectangle(box, radius=12, outline=(85,113,142), width=2, fill=(25,34,45))
        d.text((x1+12,y1+12), label, fill=(235,240,245), font=font)
        thumb = visual.copy()
        if label == "FACE PLATE":
            bg = checker((1024,1024))
            bg = Image.merge("RGBA", (*bg.split(), Image.new("L", bg.size, 255)))
            thumb = Image.alpha_composite(bg, thumb)
        thumb.thumbnail((235,235), Image.Resampling.LANCZOS)
        canvas.paste(thumb.convert("RGB"), (x1+25, y1+40))

    # gameplay row: compare 132 px silhouettes/readability
    d.text((48, 440), "GAMEPLAY READABILITY — 132 px", fill=green, font=font)
    assemblies = [compose(base, plate, f, eyes, brows) for f in faces]
    for i,(label,visual) in enumerate(zip(["ANGULAR","SOFT","BROAD"], assemblies)):
        x = 170 + i*520
        bg = checker((330,330), 15)
        thumb = visual.copy(); thumb.thumbnail((132,132), Image.Resampling.LANCZOS)
        bg.paste(thumb.convert("RGB"), ((330-thumb.width)//2, (330-thumb.height)//2))
        canvas.paste(bg, (x, 500))
        d.text((x+130, 845), label, fill=(235,240,245), font=font)

    d.text((48, 1015), "Promotion blocked until visual review + official face_plate slot contract.", fill=muted, font=font)
    d.text((48, 1040), SIGNATURE, fill=gold, font=font)
    canvas.save(out / "BASE01_NEUTRAL_FACE_PLATE.contact-sheet-1920x1080.png")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--faces-dir", required=True)
    ap.add_argument("--output", required=True)
    ns = ap.parse_args()
    repo = Path(ns.repo_root)
    faces_dir = Path(ns.faces_dir)
    out = Path(ns.output); out.mkdir(parents=True, exist_ok=True)

    paths = {"base": repo/BASE_PATH, "eyes": repo/EYES_PATH, "brows": repo/BROWS_PATH}
    for key,path in paths.items():
        got = sha256(path)
        if got != EXPECTED[key]: fail(f"source_sha_mismatch key={key} actual={got}")
        print(f"C59_2_SOURCE_SHA=PASS key={key} sha256={got}")

    base = Image.open(paths["base"]).convert("RGBA")
    eyes = Image.open(paths["eyes"]).convert("RGBA")
    brows = Image.open(paths["brows"]).convert("RGBA")
    if base.size != (1024,1024): fail(f"base_canvas={base.size}")

    palette = json.loads((repo/PALETTE_PATH).read_text(encoding="utf-8"))
    plate, neutral = build_plate(base, palette)
    plate_path = out/"neutral_face_plate_v1.png"
    plate.save(plate_path)
    neutral.save(out/"neutralized_base_preview.png")
    bbox = alpha_bbox(plate)
    if bbox is None: fail("plate_empty")
    changed = changed_pixels(base, neutral)
    if changed < 12000: fail(f"neutralization_too_small changed_pixels={changed}")

    face_imgs=[]
    for name in FACES:
        p=faces_dir/name
        if not p.exists(): fail(f"face_candidate_missing={name}")
        face_imgs.append(Image.open(p).convert("RGBA"))

    make_contact(out, plate, base, neutral, face_imgs, eyes, brows)
    qa = {
        "schema":"tehkne/taijifu-base01-neutral-face-plate-candidate/v1",
        "signature":SIGNATURE,
        "status":"candidate_review_pending",
        "plate":{"file":plate_path.name,"sha256":sha256(plate_path),"canvas":[1024,1024],"mode":"RGBA","alpha_bbox":list(bbox)},
        "neutralization":{"changed_pixels":changed,"default_identity_removed_before_swap":True},
        "assembly_order_candidate":["body_base","skin","face_plate","face","eyes","brows"],
        "default_face_uses_plate":False,
        "non_default_face_uses_plate":True,
        "owner_review":"PENDING",
        "standard_slot_promotion":"PENDING",
    }
    (out/"BASE01_NEUTRAL_FACE_PLATE.candidate-qa.json").write_text(json.dumps(qa,indent=2),encoding="utf-8")
    print(f"C59_2_NEUTRAL_FACE_PLATE=PASS sha256={qa['plate']['sha256']} bbox={bbox} changed_pixels={changed}")
    print("OWNER_REVIEW=PENDING")
    print("STANDARD_SLOT_PROMOTION=PENDING")
    print(f"SIGNATURE={SIGNATURE}")

if __name__ == "__main__":
    main()
