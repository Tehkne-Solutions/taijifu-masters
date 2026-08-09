#!/usr/bin/env python3
"""Generate Lian Wu Fall 3 candidates from the approved Character Lock.

Tehkné Solutions

Non-looping descending sequence: fall entry -> descent -> pre-impact.
"""
from __future__ import annotations
import argparse, hashlib, json, sys
from pathlib import Path
from lian_wu_canonical_identity import validate_source
from PIL import Image, ImageDraw, ImageFilter

CANVAS=(1024,1024); FRAME_COUNT=3; ALPHA_THRESHOLD=3; FPS=12.0

def sha256(path:Path)->str:
    h=hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda:fh.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def alpha_bounds(image:Image.Image):
    a=image.convert('RGBA').getchannel('A')
    return a.point(lambda v:255 if v>=ALPHA_THRESHOLD else 0).getbbox() or (0,0,0,0)

def norm(bounds,nx,ny):
    x0,y0,x1,y1=bounds; return (round(x0+(x1-x0)*nx),round(y0+(y1-y0)*ny))

def mask(size,pts,d=9):
    m=Image.new('L',size,0); ImageDraw.Draw(m).polygon(pts,fill=255)
    return m.filter(ImageFilter.MaxFilter(d)) if d>=3 and d%2==1 else m

def extract(src,m): return Image.composite(src,Image.new('RGBA',src.size,(0,0,0,0)),m)
def rotate(layer,deg,pivot): return layer.rotate(deg,resample=Image.Resampling.NEAREST,center=pivot,expand=False,fillcolor=(0,0,0,0))
def offset(layer,dx,dy):
    out=Image.new('RGBA',layer.size,(0,0,0,0)); out.alpha_composite(layer,(dx,dy)); return out

def build_masks(size,b):
    p=lambda x,y:norm(b,x,y)
    regs={
      'torso':[p(.14,0),p(.86,0),p(.84,.66),p(.16,.66)],
      'arm_back':[p(0,.25),p(.48,.26),p(.47,.73),p(0,.74)],
      'arm_front':[p(.52,.24),p(1,.24),p(1,.74),p(.53,.72)],
      'pelvis':[p(.22,.52),p(.78,.52),p(.78,.78),p(.22,.78)],
      'leg_back':[p(.12,.60),p(.52,.60),p(.56,1),p(.07,1)],
      'leg_front':[p(.48,.60),p(.88,.60),p(.94,1),p(.44,1)],
    }
    return {k:mask(size,v) for k,v in regs.items()}

def compose(src,b,masks,index):
    p=lambda x,y:norm(b,x,y)
    presets=[
      dict(y=-28,torso=3,arm=8,leg=6,front=3,back=-2),
      dict(y=-20,torso=7,arm=15,leg=11,front=5,back=-4),
      dict(y=-10,torso=10,arm=20,leg=17,front=8,back=-6),
    ]
    q=presets[index]; layers={k:extract(src,masks[k]) for k in masks}
    layers['torso']=rotate(layers['torso'],q['torso'],p(.50,.48))
    layers['arm_back']=rotate(layers['arm_back'],-q['arm'],p(.34,.34))
    layers['arm_front']=rotate(layers['arm_front'],q['arm'],p(.66,.34))
    layers['leg_back']=rotate(layers['leg_back'],-q['leg'],p(.40,.64))
    layers['leg_front']=rotate(layers['leg_front'],q['leg'],p(.60,.64))
    layers['torso']=offset(layers['torso'],2,q['y'])
    layers['pelvis']=offset(layers['pelvis'],2,q['y']+2)
    layers['leg_back']=offset(layers['leg_back'],q['back'],q['y']+3)
    layers['leg_front']=offset(layers['leg_front'],q['front'],q['y']+3)
    out=Image.new('RGBA',src.size,(0,0,0,0))
    for key in ('leg_back','arm_back','torso','pelvis','leg_front','arm_front'): out.alpha_composite(layers[key])
    return out

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--repo-root',default='.'); ap.add_argument('--source',default='assets/characters/lian_wu/character_lock/lian_wu_neutral.png'); args=ap.parse_args()
    repo=Path(args.repo_root).resolve(); source=(repo/args.source).resolve()
    if not source.is_file(): print(f'VM02_A7_FALL3=BLOCKED source_missing={source}'); return 2
    try:
        canonical_identity = validate_source(source)
    except (OSError, ValueError) as exc:
        print(f"VM02_A7_FALL3=BLOCKED canonical_visual_identity={exc}"); return 3
    actual = str(canonical_identity["file_sha256"])
    image = Image.open(source).convert("RGBA")
    if image.size!=CANVAS: print(f'VM02_A7_FALL3=BLOCKED canvas={image.size}'); return 4
    b=alpha_bounds(image); base=b[3]-1; masks=build_masks(image.size,b)
    frames_dir=repo/'assets/pack_01_characters/lian_wu/frames/fall'; meta_dir=repo/'assets/pack_01_characters/lian_wu/metadata'; frames_dir.mkdir(parents=True,exist_ok=True); meta_dir.mkdir(parents=True,exist_ok=True)
    for stale in frames_dir.glob('char_lian_wu__fall__f*.png'): stale.unlink()
    records=[]; gaps=[]
    for i in range(FRAME_COUNT):
        frame=compose(image,b,masks,i); path=frames_dir/f'char_lian_wu__fall__f{i+1:02d}.png'; frame.save(path,format='PNG',compress_level=9)
        fb=alpha_bounds(frame); baseline=fb[3]-1 if fb!=(0,0,0,0) else -1; gap=base-baseline
        if gap<=0: print(f'VM02_A7_FALL3=BLOCKED frame_not_airborne={i+1} gap={gap}'); return 5
        gaps.append(gap); records.append({'index':i+1,'file':str(path.relative_to(repo)).replace('\\','/'),'sha256':sha256(path),'alpha_bounds':list(fb),'baseline_y':baseline,'ground_gap_px':gap})
    if not (gaps[0]>gaps[1]>gaps[2]): print(f'VM02_A7_FALL3=BLOCKED non_descending_gaps={gaps}'); return 6
    meta={'schema':'tehkne/taijifu-animation-metadata/v1','signature':'Tehkné Solutions','character_id':'lian_wu','animation':'fall','status':'candidate_pending_godot_review','source_character_lock':{'file':str(source.relative_to(repo)).replace('\\','/'),'sha256':actual,'source_alpha_bounds':list(b),'baseline_y':base},'generation':{'method':'articulated_fall_descent_v1','frame_count':3,'frame_numbering':'one_based_f01_to_f03','loop':False,'fps':FPS,'semantic_phases':['fall_entry','descent','pre_impact'],'transition_source':'jump_loop','transition_target':'land','global_warp':False,'redraw':False},'frames':records,'gates':{'identity_source_hash':'pass','canvas':'pass','transparent_background':'pass','airborne_all_frames':'pass','descending_gap_order':'pass','godot_visual_review':'pending','runtime_promotion':'blocked'}}
    mp=meta_dir/'fall.json'; mp.write_text(json.dumps(meta,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('VM02_A7_FALL3=GENERATED'); print(f'source_sha256={actual}'); print(f'source_alpha_bounds={b}'); print(f'baseline_y={base}'); print('frames=3')
    for r in records: print(f"FRAME_PASS {r['index']:02d} {r['sha256']} gap={r['ground_gap_px']} {r['file']}")
    print(f'metadata={mp.relative_to(repo)}'); print('VM02_A7_FALL3_GODOT_REVIEW=PENDING'); return 0

if __name__=='__main__': sys.exit(main())
