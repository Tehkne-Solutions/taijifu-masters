#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

SIGNATURE = "Tehkné Solutions"
CANVAS = (1024, 1024)
SOURCE_SHA = "44fa5d30e0963582b5cf2d877b7a61a6d68f8028b9a2da19cbba9a73afc80225"
LEFT = (376, 260, 464, 307)
RIGHT = (470, 260, 556, 307)
VARIANTS = [
    ("brows_02_neutral", "brows_02_neutral.png"),
    ("brows_03_arched", "brows_03_arched.png"),
    ("brows_04_straight", "brows_04_straight.png"),
    ("brows_05_heavy", "brows_05_heavy.png"),
    ("brows_06_sharp", "brows_06_sharp.png"),
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


def place(canvas: Image.Image, source: Image.Image, bbox: tuple[int,int,int,int], sx: float=1.0, sy: float=1.0, dx: int=0, dy: int=0, angle: float=0.0) -> None:
    x0,y0,x1,y1 = bbox
    crop = source.crop(bbox)
    nw = max(1, round(crop.width * sx)); nh = max(1, round(crop.height * sy))
    crop = crop.resize((nw,nh), Image.Resampling.LANCZOS)
    if angle:
        crop = crop.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    cx = (x0+x1)/2 + dx; cy = (y0+y1)/2 + dy
    canvas.alpha_composite(crop, (round(cx-crop.width/2), round(cy-crop.height/2)))


def neutral(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    place(out, source, LEFT, 1.0, 0.90, 0, 3, -2.0)
    place(out, source, RIGHT, 1.0, 0.90, 0, 3, 2.0)
    return out


def arched(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    place(out, source, LEFT, 0.98, 1.02, 0, -2, -9.0)
    place(out, source, RIGHT, 0.98, 1.02, 0, -2, 9.0)
    return out


def straight(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    place(out, source, LEFT, 1.04, 0.72, 1, 5, -1.0)
    place(out, source, RIGHT, 1.04, 0.72, -1, 5, 1.0)
    return out


def heavy(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    place(out, source, LEFT, 1.05, 1.28, -1, -1, -2.0)
    place(out, source, RIGHT, 1.05, 1.28, 1, -1, 2.0)
    d = ImageDraw.Draw(out, "RGBA")
    d.line([(385,287),(420,279),(454,287)], fill=(30,22,17,125), width=5)
    d.line([(480,287),(516,278),(548,286)], fill=(30,22,17,125), width=5)
    return out


def sharp(source: Image.Image) -> Image.Image:
    out = Image.new("RGBA", CANVAS, (0,0,0,0))
    place(out, source, LEFT, 1.00, 0.94, 1, 1, 8.0)
    place(out, source, RIGHT, 1.00, 0.94, -1, 1, -8.0)
    d = ImageDraw.Draw(out, "RGBA")
    d.line([(445,292),(458,299)], fill=(28,20,16,230), width=6)
    d.line([(477,299),(490,291)], fill=(28,20,16,230), width=6)
    return out


def checker(size: tuple[int,int], cell: int=16) -> Image.Image:
    bg = Image.new("RGBA", size, (235,235,235,255)); d = ImageDraw.Draw(bg)
    for y in range(0,size[1],cell):
        for x in range(0,size[0],cell):
            if ((x//cell)+(y//cell))%2:
                d.rectangle((x,y,x+cell-1,y+cell-1), fill=(205,205,205,255))
    return bg


def compose(base: Image.Image, plate: Image.Image, face: Image.Image, eyes: Image.Image, brows: Image.Image) -> Image.Image:
    out = base.copy()
    for layer in (plate, face, eyes, brows): out = Image.alpha_composite(out, layer)
    return out


def crop_character(img: Image.Image, pad: int=5) -> Image.Image:
    box = img.getchannel("A").getbbox(); x0,y0,x1,y1 = box
    return img.crop((max(0,x0-pad),max(0,y0-pad),min(img.width,x1+pad),min(img.height,y1+pad)))


def gameplay(img: Image.Image, height: int=132) -> Image.Image:
    char = crop_character(img); w = max(1, round(char.width*height/char.height))
    char = char.resize((w,height), Image.Resampling.LANCZOS)
    stage = checker((190,160),12); stage.alpha_composite(char, ((190-char.width)//2,160-char.height-8))
    return stage


def module_preview(img: Image.Image) -> Image.Image:
    box=img.getchannel("A").getbbox(); x0,y0,x1,y1=box
    crop=img.crop((max(0,x0-15),max(0,y0-15),min(1024,x1+15),min(1024,y1+15)))
    crop.thumbnail((300,145), Image.Resampling.LANCZOS)
    bg=checker((320,165),12); bg.alpha_composite(crop,((320-crop.width)//2,(165-crop.height)//2)); return bg


def contact_sheet(rows: dict[str,dict[str,Image.Image]], out: Path) -> None:
    canvas=Image.new("RGBA",(1920,1080),(14,20,28,255)); d=ImageDraw.Draw(canvas)
    d.text((45,28),"TAIJIFU MASTERS — BASE01 PACK C BROWS — CANDIDATE REVIEW",fill=(244,188,72,255))
    d.text((45,52),"face_plate path enabled • canonical face_01 + eyes_01 • preview only",fill=(205,215,228,255))
    for i,(brow_id,pre) in enumerate(rows.items()):
        x=30+i*378
        d.rounded_rectangle((x,90,x+350,1020),radius=16,fill=(24,32,42,255),outline=(90,115,145,255),width=2)
        d.text((x+16,110),brow_id,fill=(255,255,255,255)); canvas.alpha_composite(pre["module"],(x+15,145))
        d.text((x+16,330),"AUTHORED",fill=(83,220,155,255)); auth=crop_character(pre["authored"]); auth.thumbnail((145,360),Image.Resampling.LANCZOS); canvas.alpha_composite(auth,(x+18,360))
        d.text((x+185,330),"FLIPPED",fill=(83,220,155,255)); flip=crop_character(pre["flipped"]); flip.thumbnail((145,360),Image.Resampling.LANCZOS); canvas.alpha_composite(flip,(x+185,360))
        d.text((x+16,760),"GAMEPLAY 132px",fill=(205,215,228,255)); canvas.alpha_composite(pre["gameplay"],(x+80,795))
    d.text((45,1040),SIGNATURE,fill=(244,188,72,255)); canvas.convert("RGB").save(out,"PNG")


def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument("--repo-root",default="."); ap.add_argument("--output",default="build/base01-pack-c-brows"); ns=ap.parse_args()
    root=Path(ns.repo_root).resolve(); out=(root/ns.output).resolve(); out.mkdir(parents=True,exist_ok=True)
    source_path=root/"assets/modular_fighters/base_01/brows/brows_01_focused.png"
    if sha256(source_path)!=SOURCE_SHA: raise SystemExit("C61_SOURCE_SHA=BLOCKED brows_01_focused")
    canonical=json.loads((root/"assets/modular_fighters/base_01/production/BASE01_PACK_A_FACES.canonical.json").read_text(encoding="utf-8"))
    plate_item=canonical["modules"]["neutral_face_plate_v1"]; plate_path=root/plate_item["path"]
    if sha256(plate_path)!=plate_item["sha256"]: raise SystemExit("C61_FACE_PLATE_SHA=BLOCKED")
    base=Image.open(root/"assets/modular_fighters/base_00/base_fighter_v1_master.png").convert("RGBA")
    plate=Image.open(plate_path).convert("RGBA"); face=Image.open(root/"assets/modular_fighters/base_01/face/face_01_balanced.png").convert("RGBA")
    eyes=Image.open(root/"assets/modular_fighters/base_01/eyes/eyes_01_focused.png").convert("RGBA"); source=Image.open(source_path).convert("RGBA")
    generated={"brows_02_neutral":neutral(source),"brows_03_arched":arched(source),"brows_04_straight":straight(source),"brows_05_heavy":heavy(source),"brows_06_sharp":sharp(source)}
    qa={"schema":"tehkne/taijifu-base01-pack-c-candidate-qa/v1","signature":SIGNATURE,"pack_id":"BASE01-PACK-C-BROWS","status":"CANDIDATE_REVIEW_REQUIRED","source_sha256":SOURCE_SHA,"face_plate_sha256":plate_item["sha256"],"pivot":[0.5,0.92],"owner_review":"PENDING","runtime_import":"PENDING","promotion":"BLOCKED_REVIEW_AND_RUNTIME","modules":{}}
    previews={}; hashes=set()
    for brow_id,filename in VARIANTS:
        img=generated[brow_id]
        if img.size!=CANVAS or img.mode!="RGBA" or not transparent_corners(img): raise SystemExit(f"C61_CANDIDATE=BLOCKED contract={brow_id}")
        path=out/filename; img.save(path,"PNG",optimize=False); digest=sha256(path)
        if digest==SOURCE_SHA or digest in hashes: raise SystemExit(f"C61_CANDIDATE=BLOCKED uniqueness={brow_id}")
        hashes.add(digest); assembled=compose(base,plate,face,eyes,img)
        previews[brow_id]={"module":module_preview(img),"authored":assembled,"flipped":ImageOps.mirror(assembled),"gameplay":gameplay(assembled)}
        qa["modules"][brow_id]={"file":filename,"sha256":digest,"canvas":[1024,1024],"mode":"RGBA","alpha_bbox":alpha_bbox(img),"transparent_corners":True,"authored_review":"PENDING_OWNER_REVIEW","flipped_review":"PENDING_OWNER_REVIEW","gameplay_scale_132px":"PENDING_OWNER_REVIEW"}
        print(f"C61_CANDIDATE=PASS module={brow_id} sha256={digest} bbox={qa['modules'][brow_id]['alpha_bbox']}")
    contact_sheet(previews,out/"BASE01_PACK_C_BROWS.contact-sheet-1920x1080.png")
    (out/"BASE01_PACK_C_BROWS.candidate-qa.json").write_text(json.dumps(qa,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    (out/"checksums.sha256").write_text("".join(f"{qa['modules'][i]['sha256']}  {qa['modules'][i]['file']}\n" for i,_ in VARIANTS),encoding="utf-8")
    print("C61_PACK_C_BROWS_CANDIDATE_GENERATION=PASS candidates=5"); print("OWNER_REVIEW=PENDING"); print(f"SIGNATURE={SIGNATURE}"); return 0

if __name__=="__main__": raise SystemExit(main())
