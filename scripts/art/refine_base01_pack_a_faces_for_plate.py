#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from PIL import Image, ImageDraw

CANVAS = (1024, 1024)
SHADOW = (199, 115, 60)
DEEP = (126, 67, 38)
CHEEK = (250, 191, 107)


def refine_angular(img: Image.Image) -> None:
    d = ImageDraw.Draw(img, "RGBA")
    # sharper cheek planes and a more decisive lower-face read
    d.line([(407, 347), (426, 357), (443, 354)], fill=(*DEEP, 195), width=6)
    d.line([(563, 346), (544, 356), (528, 354)], fill=(*DEEP, 195), width=6)
    d.line([(425, 370), (442, 381), (452, 381)], fill=(*SHADOW, 185), width=6)
    d.line([(540, 369), (523, 380), (513, 380)], fill=(*SHADOW, 185), width=6)
    d.line([(457, 369), (470, 367), (486, 369)], fill=(*DEEP, 210), width=4)


def refine_soft(img: Image.Image) -> None:
    d = ImageDraw.Draw(img, "RGBA")
    # rounded, low-contrast cheek arcs and a softer compact mouth
    d.arc((402, 345, 442, 374), 18, 118, fill=(*CHEEK, 150), width=6)
    d.arc((528, 344, 568, 373), 62, 162, fill=(*CHEEK, 150), width=6)
    d.arc((448, 362, 493, 379), 25, 155, fill=(*SHADOW, 135), width=5)
    d.ellipse((430, 360, 438, 368), fill=(*CHEEK, 105))
    d.ellipse((535, 359, 543, 367), fill=(*CHEEK, 105))


def refine_broad(img: Image.Image) -> None:
    d = ImageDraw.Draw(img, "RGBA")
    # longer, heavier planes make the lower face read wider while keeping silhouette fixed
    d.line([(397, 351), (421, 363), (444, 362)], fill=(*SHADOW, 190), width=7)
    d.line([(572, 349), (548, 361), (526, 360)], fill=(*SHADOW, 190), width=7)
    d.line([(416, 372), (438, 383), (454, 382)], fill=(*DEEP, 175), width=7)
    d.line([(552, 371), (530, 382), (514, 381)], fill=(*DEEP, 175), width=7)
    d.line([(452, 369), (470, 371), (490, 369)], fill=(*DEEP, 215), width=5)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--faces-dir", required=True)
    ns = ap.parse_args()
    root = Path(ns.faces_dir)
    jobs = {
        "face_02_angular.png": refine_angular,
        "face_03_soft.png": refine_soft,
        "face_04_broad.png": refine_broad,
    }
    for name, fn in jobs.items():
        path = root / name
        if not path.exists():
            raise SystemExit(f"C59_2_FACE_REFINEMENT=BLOCKED missing={path}")
        img = Image.open(path).convert("RGBA")
        if img.size != CANVAS:
            raise SystemExit(f"C59_2_FACE_REFINEMENT=BLOCKED canvas={name}:{img.size}")
        fn(img)
        img.save(path)
        print(f"C59_2_FACE_REFINEMENT=PASS module={name}")
    print("C59_2_PACK_A_FACE_DIFFERENTIATION=PASS")
    print("SIGNATURE=Tehkné Solutions")

if __name__ == "__main__":
    main()
