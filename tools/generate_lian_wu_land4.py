#!/usr/bin/env python3
"""Generate Lian Wu Land 4 candidates from the approved Character Lock.

Tehkné Solutions

Non-looping landing sequence: impact -> deep compression -> recovery -> neutral.
"""
from __future__ import annotations
import argparse, hashlib, json, shutil, sys
from pathlib import Path
from lian_wu_canonical_identity import validate_source
from PIL import Image, ImageDraw, ImageFilter

CANVAS=(1024,1024); FRAME_COUNT=4; ALPHA_THRESHOLD=3; FPS=12.0

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
    if not dx and not dy: return layer
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
    if index == 3:
        return src.copy()

    p=lambda x,y:norm(b,x,y)
    presets=[
      dict(body_y=8,pelvis_y=10,torso=8,arm=16,leg=13,front=5,back=-4),
      dict(body_y=24,pelvis_y=29,torso=12,arm=22,leg=21,front=8,back=-7),
      dict(body_y=11,pelvis_y=14,torso=5,arm=10,leg=9,front=4,back=-3),
    ]
    q=presets[index]; layers={k:extract(src,masks[k]) for k in masks}
    layers['torso']=rotate(layers['torso'],q['torso'],p(.50,.48))
    layers['arm_back']=rotate(layers['arm_back'],-q['arm'],p(.34,.34))
    layers['arm_front']=rotate(layers['arm_front'],q['arm'],p(.66,.34))
    layers['leg_back']=rotate(layers['leg_back'],-q['leg'],p(.40,.64))
    layers['leg_front']=rotate(layers['leg_front'],q['leg'],p(.60,.64))
    layers['torso']=offset(layers['torso'],1,q['body_y'])
    layers['pelvis']=offset(layers['pelvis'],1,q['pelvis_y'])
    layers['leg_back']=offset(layers['leg_back'],q['back'],q['pelvis_y']-2)
    layers['leg_front']=offset(layers['leg_front'],q['front'],q['pelvis_y']-2)
    out=Image.new('RGBA',src.size,(0,0,0,0))
    for key in ('leg_back','arm_back','torso','pelvis','leg_front','arm_front'): out.alpha_composite(layers[key])
    fb=alpha_bounds(out)
    if fb!=(0,0,0,0):
        dy=(b[3]-1)-(fb[3]-1)
        if dy: out=offset(out,0,dy)
    return out

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--repo-root',default='.'); ap.add_argument('--source',default='assets/characters/lian_wu/character_lock/lian_wu_neutral.png'); args=ap.parse_args()
    repo=Path(args.repo_root).resolve(); source=(repo/args.source).resolve()
    if not source.is_file(): print(f'VM02_A8_LAND4=BLOCKED source_missing={source}'); return 2
    try:
        canonical_identity = validate_source(source)
    except (OSError, ValueError) as exc:
        print(f"VM02_A8_LAND4=BLOCKED canonical_visual_identity={exc}"); return 3
    actual = str(canonical_identity["file_sha256"])
    image = Image.open(source).convert("RGBA")
    if image.size!=CANVAS: print(f'VM02_A8_LAND4=BLOCKED canvas={image.size}'); return 4
    b=alpha_bounds(image); base=b[3]-1; masks=build_masks(image.size,b)
    frames_dir=repo/'assets/pack_01_characters/lian_wu/frames/land'; meta_dir=repo/'assets/pack_01_characters/lian_wu/metadata'; frames_dir.mkdir(parents=True,exist_ok=True); meta_dir.mkdir(parents=True,exist_ok=True)
    for stale in frames_dir.glob('char_lian_wu__land__f*.png'): stale.unlink()
    records=[]; heights=[]
    for i in range(FRAME_COUNT):
        frame=compose(image,b,masks,i); path=frames_dir/f'char_lian_wu__land__f{i+1:02d}.png'
        if i == 3:
            # Preserve the canonical PNG byte-for-byte. Saving via Pillow would
            # re-encode the same pixels and legitimately change the file hash.
            shutil.copyfile(source, path)
            with Image.open(path) as copied:
                frame = copied.convert('RGBA')
        else:
            frame.save(path,format='PNG',compress_level=9)
        fb=alpha_bounds(frame); baseline=fb[3]-1 if fb!=(0,0,0,0) else -1
        if baseline!=base: print(f'VM02_A8_LAND4=BLOCKED baseline_drift frame={i+1} baseline={baseline} source={base}'); return 5
        height=fb[3]-fb[1]; heights.append(height)
        records.append({'index':i+1,'file':str(path.relative_to(repo)).replace('\\','/'),'sha256':sha256(path),'alpha_bounds':list(fb),'baseline_y':baseline,'silhouette_height_px':height})
    if not (heights[1] < heights[0] and heights[1] < heights[2] and heights[3] >= heights[2]):
        print(f'VM02_A8_LAND4=BLOCKED compression_profile={heights}'); return 6
    if records[3]['sha256'] != actual:
        print(f"VM02_A8_LAND4=BLOCKED neutral_hash_mismatch frame4={records[3]['sha256']} source={actual}"); return 7
    meta={'schema':'tehkne/taijifu-animation-metadata/v1','signature':'Tehkné Solutions','character_id':'lian_wu','animation':'land','status':'candidate_pending_godot_review','source_character_lock':{'file':str(source.relative_to(repo)).replace('\\','/'),'sha256':actual,'source_alpha_bounds':list(b),'baseline_y':base},'generation':{'method':'articulated_land_recovery_v3','frame_count':4,'frame_numbering':'one_based_f01_to_f04','loop':False,'fps':FPS,'semantic_phases':['impact','deep_compression','recovery','neutral'],'transition_source':'fall','transition_target':'idle_or_locomotion','f04_exact_character_lock_bytes':True,'global_warp':False,'redraw':False},'frames':records,'gates':{'identity_source_hash':'pass','canvas':'pass','transparent_background':'pass','grounded_all_frames':'pass','compression_profile':'pass','neutral_handoff_hash':'pass','godot_visual_review':'pending','runtime_promotion':'blocked'}}
    mp=meta_dir/'land.json'; mp.write_text(json.dumps(meta,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('VM02_A8_LAND4=GENERATED'); print(f'source_sha256={actual}'); print(f'source_alpha_bounds={b}'); print(f'baseline_y={base}'); print('frames=4')
    for r in records: print(f"FRAME_PASS {r['index']:02d} {r['sha256']} height={r['silhouette_height_px']} {r['file']}")
    print(f'compression_profile={heights}'); print('neutral_handoff_hash=PASS'); print(f'metadata={mp.relative_to(repo)}'); print('VM02_A8_LAND4_GODOT_REVIEW=PENDING'); return 0

if __name__=='__main__': sys.exit(main())
