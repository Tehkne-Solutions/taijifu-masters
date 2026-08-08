#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
from PIL import Image

SOURCE_SHA = "44fa5d30e0963582b5cf2d877b7a61a6d68f8028b9a2da19cbba9a73afc80225"
LEFT = (376, 260, 464, 307)
RIGHT = (470, 260, 556, 307)
CANVAS = (1024, 1024)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def place(canvas: Image.Image, source: Image.Image, bbox: tuple[int,int,int,int], sx: float, sy: float, dx: int, dy: int) -> None:
    x0,y0,x1,y1 = bbox
    crop = source.crop(bbox)
    crop = crop.resize((round(crop.width*sx), round(crop.height*sy)), Image.Resampling.LANCZOS)
    cx=(x0+x1)/2+dx; cy=(y0+y1)/2+dy
    canvas.alpha_composite(crop,(round(cx-crop.width/2),round(cy-crop.height/2)))


def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument('--repo-root',default='.'); ap.add_argument('--brows-dir',required=True); ns=ap.parse_args()
    root=Path(ns.repo_root).resolve(); brows_dir=Path(ns.brows_dir).resolve()
    source_path=root/'assets/modular_fighters/base_01/brows/brows_01_focused.png'
    if sha256(source_path)!=SOURCE_SHA: raise SystemExit('C61_BROW_REFINEMENT=BLOCKED source_sha')
    source=Image.open(source_path).convert('RGBA')
    heavy=Image.new('RGBA',CANVAS,(0,0,0,0))
    # Heavy should read as greater brow mass, not extra decorative strokes.
    # Preserve the canonical authored shapes and increase only vertical mass.
    place(heavy,source,LEFT,1.06,1.42,-1,-1)
    place(heavy,source,RIGHT,1.06,1.42,1,-1)
    out=brows_dir/'brows_05_heavy.png'; heavy.save(out,'PNG',optimize=False)
    if heavy.getchannel('A').getbbox() is None: raise SystemExit('C61_BROW_REFINEMENT=BLOCKED heavy_empty')
    print(f'C61_BROW_REFINEMENT=PASS module=brows_05_heavy sha256={sha256(out)}')
    print('SIGNATURE=Tehkné Solutions')
    return 0

if __name__=='__main__': raise SystemExit(main())
