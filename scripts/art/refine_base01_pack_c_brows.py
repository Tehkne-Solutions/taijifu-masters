#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
from PIL import Image, ImageOps

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


def load_generator(root: Path):
    path = root/'scripts/art/generate_base01_pack_c_brows.py'
    spec = importlib.util.spec_from_file_location('c61_gen', path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument('--repo-root',default='.'); ap.add_argument('--brows-dir',required=True); ns=ap.parse_args()
    root=Path(ns.repo_root).resolve(); brows_dir=Path(ns.brows_dir).resolve()
    source_path=root/'assets/modular_fighters/base_01/brows/brows_01_focused.png'
    if sha256(source_path)!=SOURCE_SHA: raise SystemExit('C61_BROW_REFINEMENT=BLOCKED source_sha')
    source=Image.open(source_path).convert('RGBA')
    heavy=Image.new('RGBA',CANVAS,(0,0,0,0))
    # Heavy should read as greater brow mass, not extra decorative strokes.
    place(heavy,source,LEFT,1.06,1.42,-1,-1)
    place(heavy,source,RIGHT,1.06,1.42,1,-1)
    out=brows_dir/'brows_05_heavy.png'; heavy.save(out,'PNG',optimize=False)
    box=heavy.getchannel('A').getbbox()
    if box is None: raise SystemExit('C61_BROW_REFINEMENT=BLOCKED heavy_empty')
    digest=sha256(out)

    qa_path=brows_dir/'BASE01_PACK_C_BROWS.candidate-qa.json'
    qa=json.loads(qa_path.read_text(encoding='utf-8'))
    x0,y0,x1,y1=box
    qa['modules']['brows_05_heavy']['sha256']=digest
    qa['modules']['brows_05_heavy']['alpha_bbox']=[x0,y0,x1-1,y1-1]
    qa_path.write_text(json.dumps(qa,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    order=['brows_02_neutral','brows_03_arched','brows_04_straight','brows_05_heavy','brows_06_sharp']
    (brows_dir/'checksums.sha256').write_text(''.join(f"{qa['modules'][i]['sha256']}  {qa['modules'][i]['file']}\n" for i in order),encoding='utf-8')

    # Regenerate visual evidence after refinement so the sheet matches the exact runtime bytes.
    gen=load_generator(root)
    canonical=json.loads((root/'assets/modular_fighters/base_01/production/BASE01_PACK_A_FACES.canonical.json').read_text(encoding='utf-8'))
    plate_path=root/canonical['modules']['neutral_face_plate_v1']['path']
    base=Image.open(root/'assets/modular_fighters/base_00/base_fighter_v1_master.png').convert('RGBA')
    plate=Image.open(plate_path).convert('RGBA')
    face=Image.open(root/'assets/modular_fighters/base_01/face/face_01_balanced.png').convert('RGBA')
    eyes=Image.open(root/'assets/modular_fighters/base_01/eyes/eyes_01_focused.png').convert('RGBA')
    previews={}
    for brow_id in order:
        img=Image.open(brows_dir/f'{brow_id}.png').convert('RGBA')
        assembled=gen.compose(base,plate,face,eyes,img)
        previews[brow_id]={
            'module':gen.module_preview(img),
            'authored':assembled,
            'flipped':ImageOps.mirror(assembled),
            'gameplay':gen.gameplay(assembled),
        }
    gen.contact_sheet(previews,brows_dir/'BASE01_PACK_C_BROWS.contact-sheet-1920x1080.png')

    print(f'C61_BROW_REFINEMENT=PASS module=brows_05_heavy sha256={digest}')
    print('C61_REVIEW_EVIDENCE_REGENERATED=PASS')
    print('SIGNATURE=Tehkné Solutions')
    return 0

if __name__=='__main__': raise SystemExit(main())
