#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps

SIGNATURE = "Tehkné Solutions"
CANVAS = (1024, 1024)
SOURCE_SHA = "7517e6d14cef106fbe782736524321b992ea3088486498fc24e71f1e158419a9"
LEFT = (392, 288, 459, 351)
RIGHT = (500, 286, 569, 349)
VARIANTS = [
    ("eyes_02_calm", "eyes_02_calm.png"),
    ("eyes_03_fierce", "eyes_03_fierce.png"),
    ("eyes_04_narrow", "eyes_04_narrow.png"),
    ("eyes_05_round", "eyes_05_round.png"),
    ("eyes_06_heavy", "eyes_06_heavy.png"),
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_bbox(img: Image.Image) -> list[int]:
    box = img.getchannel("A").getbbox()
    if box is None:
        raise RuntimeError("empty image")
    x0,y0,x1,y1 = box
    return [x0,y0,x1-1,y1-1]


def transparent_corners(img: Image.Image) -> bool:
    a = img.getchannel("A")
    return all(a.getpixel(p) == 0 for p in ((0,0),(1023,0),(0,1023),(1023,1023)))


def paste_eye(canvas: Image.Image, source: Image.Image, bbox: tuple[int,int,int,int], sx: float, sy: float, dx: int=0, dy: int=0) -> None:
    x0,y0,x1,y1 = bbox
    crop = source.crop(bbox)
    nw = max(1, round(crop.width * sx))
    nh = max(1, round(crop.height * sy))
    crop = crop.resize((nw,nh), Image.Resampling.LANCZOS)
    cx = (x0+x1)/2 + dx
    cy = (y0+y1)/2 + dy
    canvas.alpha_composite(crop, (round(cx-nw/2), round(cy-nh/2)))


def calm(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    paste_eye(out, source, LEFT, 1.00, 0.88, 0, 3)
    paste_eye(out, source, RIGHT, 1.00, 0.88, 0, 3)
    return out


def fierce(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    paste_eye(out, source, LEFT, 1.01, 0.82, 0, 2)
    paste_eye(out, source, RIGHT, 1.01, 0.82, 0, 2)
    d = ImageDraw.Draw(out, "RGBA")
    d.line([(395,296),(430,299),(457,309)], fill=(35,24,18,235), width=6)
    d.line([(503,308),(534,299),(566,294)], fill=(35,24,18,235), width=6)
    return out


def narrow(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    paste_eye(out, source, LEFT, 1.04, 0.62, 0, 7)
    paste_eye(out, source, RIGHT, 1.04, 0.62, 0, 7)
    return out


def round_eye(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    paste_eye(out, source, LEFT, 0.94, 1.18, -1, -2)
    paste_eye(out, source, RIGHT, 0.94, 1.18, 1, -2)
    return out


def heavy(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    paste_eye(out, source, LEFT, 1.03, 0.94, 0, 3)
    paste_eye(out, source, RIGHT, 1.03, 0.94, 0, 3)
    d = ImageDraw.Draw(out, "RGBA")
    d.line([(394,296),(426,292),(458,301)], fill=(30,22,17,245), width=8)
    d.line([(501,300),(535,291),(568,294)], fill=(30,22,17,245), width=8)
    d.line([(402,340),(430,345),(452,342)], fill=(141,77,44,120), width=3)
    d.line([(507,341),(536,345),(561,338)], fill=(141,77,44,120), width=3)
    return out


def checker(size: tuple[int,int], cell: int=16) -> Image.Image:
    bg = Image.new("RGBA", size, (235,235,235,255))
    d = ImageDraw.Draw(bg)
    for y in range(0,size[1],cell):
        for x in range(0,size[0],cell):
            if ((x//cell)+(y//cell))%2:
                d.rectangle((x,y,x+cell-1,y+cell-1), fill=(205,205,205,255))
    return bg


def compose(base: Image.Image, plate: Image.Image, face: Image.Image, eyes: Image.Image, brows: Image.Image) -> Image.Image:
    out = base.copy()
    for layer in (plate, face, eyes, brows):
        out = Image.alpha_composite(out, layer)
    return out


def crop_character(img: Image.Image, pad: int=5) -> Image.Image:
    box = img.getchannel("A").getbbox()
    x0,y0,x1,y1 = box
    return img.crop((max(0,x0-pad),max(0,y0-pad),min(img.width,x1+pad),min(img.height,y1+pad)))


def gameplay(img: Image.Image, height: int=132) -> Image.Image:
    char = crop_character(img)
    w = max(1, round(char.width * height / char.height))
    char = char.resize((w,height), Image.Resampling.LANCZOS)
    stage = checker((190,160), 12)
    stage.alpha_composite(char, ((190-char.width)//2, 160-char.height-8))
    return stage


def module_preview(img: Image.Image) -> Image.Image:
    box = img.getchannel("A").getbbox()
    x0,y0,x1,y1 = box
    crop = img.crop((max(0,x0-15),max(0,y0-15),min(1024,x1+15),min(1024,y1+15)))
    crop.thumbnail((300,145), Image.Resampling.LANCZOS)
    bg = checker((320,165), 12)
    bg.alpha_composite(crop, ((320-crop.width)//2,(165-crop.height)//2))
    return bg


def contact_sheet(rows: dict[str,dict[str,Image.Image]], out: Path) -> None:
    canvas = Image.new("RGBA", (1920,1080), (14,20,28,255))
    d = ImageDraw.Draw(canvas)
    d.text((45,28), "TAIJIFU MASTERS — BASE01 PACK B EYES — CANDIDATE REVIEW", fill=(244,188,72,255))
    d.text((45,52), "face_plate path enabled • canonical face_01 + brows_01 • preview only", fill=(205,215,228,255))
    card_w = 360
    for i,(eye_id,pre) in enumerate(rows.items()):
        x = 30 + i*378
        d.rounded_rectangle((x,90,x+350,1020), radius=16, fill=(24,32,42,255), outline=(90,115,145,255), width=2)
        d.text((x+16,110), eye_id, fill=(255,255,255,255))
        canvas.alpha_composite(pre["module"], (x+15,145))
        d.text((x+16,330), "AUTHORED", fill=(83,220,155,255))
        auth = crop_character(pre["authored"]); auth.thumbnail((145,360), Image.Resampling.LANCZOS)
        canvas.alpha_composite(auth, (x+18,360))
        d.text((x+185,330), "FLIPPED", fill=(83,220,155,255))
        flip = crop_character(pre["flipped"]); flip.thumbnail((145,360), Image.Resampling.LANCZOS)
        canvas.alpha_composite(flip, (x+185,360))
        d.text((x+16,760), "GAMEPLAY 132px", fill=(205,215,228,255))
        canvas.alpha_composite(pre["gameplay"], (x+80,795))
    d.text((45,1040), SIGNATURE, fill=(244,188,72,255))
    canvas.convert("RGB").save(out, "PNG")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--output", default="build/base01-pack-b-eyes")
    ns = ap.parse_args()
    root = Path(ns.repo_root).resolve()
    out = (root / ns.output).resolve(); out.mkdir(parents=True, exist_ok=True)

    source_path = root / "assets/modular_fighters/base_01/eyes/eyes_01_focused.png"
    if sha256(source_path) != SOURCE_SHA:
        raise SystemExit("C60_SOURCE_SHA=BLOCKED eyes_01_focused")
    canonical = json.loads((root/"assets/modular_fighters/base_01/production/BASE01_PACK_A_FACES.canonical.json").read_text(encoding="utf-8"))
    plate_item = canonical["modules"]["neutral_face_plate_v1"]
    plate_path = root / plate_item["path"]
    if sha256(plate_path) != plate_item["sha256"]:
        raise SystemExit("C60_FACE_PLATE_SHA=BLOCKED")

    base = Image.open(root/"assets/modular_fighters/base_00/base_fighter_v1_master.png").convert("RGBA")
    plate = Image.open(plate_path).convert("RGBA")
    face = Image.open(root/"assets/modular_fighters/base_01/face/face_01_balanced.png").convert("RGBA")
    brows = Image.open(root/"assets/modular_fighters/base_01/brows/brows_01_focused.png").convert("RGBA")
    source = Image.open(source_path).convert("RGBA")

    generated = {
        "eyes_02_calm": calm(source),
        "eyes_03_fierce": fierce(source),
        "eyes_04_narrow": narrow(source),
        "eyes_05_round": round_eye(source),
        "eyes_06_heavy": heavy(source),
    }
    qa = {
        "schema":"tehkne/taijifu-base01-pack-b-candidate-qa/v1",
        "signature":SIGNATURE,
        "pack_id":"BASE01-PACK-B-EYES",
        "status":"CANDIDATE_REVIEW_REQUIRED",
        "source_sha256":SOURCE_SHA,
        "face_plate_sha256":plate_item["sha256"],
        "pivot":[0.5,0.92],
        "owner_review":"PENDING",
        "runtime_import":"PENDING",
        "promotion":"BLOCKED_REVIEW_AND_RUNTIME",
        "modules":{},
    }
    previews = {}
    hashes = set()
    for eye_id, filename in VARIANTS:
        img = generated[eye_id]
        if img.size != CANVAS or img.mode != "RGBA" or not transparent_corners(img):
            raise SystemExit(f"C60_CANDIDATE=BLOCKED contract={eye_id}")
        path = out/filename
        img.save(path, "PNG", optimize=False)
        digest = sha256(path)
        if digest == SOURCE_SHA or digest in hashes:
            raise SystemExit(f"C60_CANDIDATE=BLOCKED uniqueness={eye_id}")
        hashes.add(digest)
        assembled = compose(base, plate, face, img, brows)
        previews[eye_id] = {
            "module":module_preview(img),
            "authored":assembled,
            "flipped":ImageOps.mirror(assembled),
            "gameplay":gameplay(assembled),
        }
        qa["modules"][eye_id] = {
            "file":filename,
            "sha256":digest,
            "canvas":[1024,1024],
            "mode":"RGBA",
            "alpha_bbox":alpha_bbox(img),
            "transparent_corners":True,
            "authored_review":"PENDING_OWNER_REVIEW",
            "flipped_review":"PENDING_OWNER_REVIEW",
            "gameplay_scale_132px":"PENDING_OWNER_REVIEW",
        }
        print(f"C60_CANDIDATE=PASS module={eye_id} sha256={digest} bbox={qa['modules'][eye_id]['alpha_bbox']}")

    contact_sheet(previews, out/"BASE01_PACK_B_EYES.contact-sheet-1920x1080.png")
    (out/"BASE01_PACK_B_EYES.candidate-qa.json").write_text(json.dumps(qa,indent=2,ensure_ascii=False)+"\n", encoding="utf-8")
    (out/"checksums.sha256").write_text("".join(f"{qa['modules'][i]['sha256']}  {qa['modules'][i]['file']}\n" for i,_ in VARIANTS),encoding="utf-8")
    print("C60_PACK_B_EYES_CANDIDATE_GENERATION=PASS candidates=5")
    print("OWNER_REVIEW=PENDING")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
