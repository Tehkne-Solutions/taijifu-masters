#!/usr/bin/env python3
"""Generate Lian Wu ji_sweep 6-keypose visual sequence.

Tehkné Solutions
"""
from __future__ import annotations
import argparse, hashlib, json, shutil, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

EXPECTED_SOURCE_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANVAS=(1024,1024); FRAME_COUNT=6; ALPHA_THRESHOLD=3
KEYPOSES=["guard","drop_load","chamber","sweep_active","follow_through","recover"]
ACTIVE_KEYPOSES=[4]

def sha256(p:Path)->str:
    h=hashlib.sha256();
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest()

def alpha_bounds(im:Image.Image):
    a=im.convert('RGBA').getchannel('A')
    return a.point(lambda v:255 if v>=ALPHA_THRESHOLD else 0).getbbox() or (0,0,0,0)

def norm(bounds,nx,ny):
    x0,y0,x1,y1=bounds; return (round(x0+(x1-x0)*nx),round(y0+(y1-y0)*ny))

def mask(size,pts):
    m=Image.new('L',size,0); ImageDraw.Draw(m).polygon(pts,fill=255); return m.filter(ImageFilter.MaxFilter(9))

def region(src,m): return Image.composite(src,Image.new('RGBA',src.size,(0,0,0,0)),m)
def rotate(layer,degrees,pivot): return layer.rotate(degrees,resample=Image.Resampling.NEAREST,center=pivot,expand=False,fillcolor=(0,0,0,0))
def offset(layer,dx,dy):
    if not dx and not dy:return layer
    out=Image.new('RGBA',layer.size,(0,0,0,0)); out.alpha_composite(layer,(int(dx),int(dy))); return out

def build_masks(size,b):
    p=lambda x,y:norm(b,x,y)
    return {
      'torso':mask(size,[p(.12,.0),p(.88,.0),p(.84,.62),p(.16,.62)]),
      'arms':mask(size,[p(.0,.18),p(1,.18),p(.96,.73),p(.04,.73)]),
      'pelvis':mask(size,[p(.18,.50),p(.82,.50),p(.82,.78),p(.18,.78)]),
      'leg_back':mask(size,[p(.05,.60),p(.55,.58),p(.55,1),p(.02,1)]),
      'leg_front':mask(size,[p(.45,.58),p(.95,.60),p(.98,1),p(.45,1)]),
    }

def pose(src,b,m,preset):
    P=lambda x,y:norm(b,x,y)
    torso=offset(rotate(region(src,m['torso']),preset['torso_rot'],P(.5,.46)),preset['torso_dx'],preset['torso_dy'])
    arms=offset(rotate(region(src,m['arms']),preset['arms_rot'],P(.5,.34)),preset['arms_dx'],preset['arms_dy'])
    pelvis=offset(region(src,m['pelvis']),preset['pelvis_dx'],preset['pelvis_dy'])
    lb=offset(rotate(region(src,m['leg_back']),preset['back_rot'],P(.34,.72)),preset['back_dx'],preset['back_dy'])
    lf=offset(rotate(region(src,m['leg_front']),preset['front_rot'],P(.66,.72)),preset['front_dx'],preset['front_dy'])
    out=Image.new('RGBA',src.size,(0,0,0,0))
    for layer in (lb,lf,arms,torso,pelvis): out.alpha_composite(layer)
    fb=alpha_bounds(out)
    if fb!=(0,0,0,0):
        dy=(b[3]-1)-(fb[3]-1)
        if dy: out=offset(out,0,dy)
    return out

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--repo-root',default='.'); ap.add_argument('--source',default='assets/characters/lian_wu/character_lock/lian_wu_neutral.png'); args=ap.parse_args()
    repo=Path(args.repo_root).resolve(); sp=(repo/args.source).resolve()
    if not sp.is_file(): print(f'VM02_C6_JI_SWEEP6=BLOCKED source_missing={sp}'); return 2
    sh=sha256(sp)
    if sh!=EXPECTED_SOURCE_SHA256: print('VM02_C6_JI_SWEEP6=BLOCKED source_hash_mismatch'); return 3
    src=Image.open(sp).convert('RGBA'); b=alpha_bounds(src); baseline=b[3]-1
    frames=repo/'assets/pack_01_characters/lian_wu/frames/attacks/ji_sweep'; meta_dir=repo/'assets/pack_01_characters/lian_wu/metadata'; frames.mkdir(parents=True,exist_ok=True); meta_dir.mkdir(parents=True,exist_ok=True)
    for s in frames.glob('char_lian_wu__ji_sweep__f*.png'): s.unlink()
    presets=[None,
      dict(torso_rot=4,torso_dx=-2,torso_dy=10,arms_rot=8,arms_dx=-2,arms_dy=5,pelvis_dx=-2,pelvis_dy=10,back_rot=-8,back_dx=-5,back_dy=7,front_rot=10,front_dx=4,front_dy=5),
      dict(torso_rot=-6,torso_dx=-4,torso_dy=8,arms_rot=18,arms_dx=-5,arms_dy=4,pelvis_dx=-4,pelvis_dy=8,back_rot=-16,back_dx=-8,back_dy=3,front_rot=18,front_dx=8,front_dy=1),
      dict(torso_rot=-12,torso_dx=10,torso_dy=6,arms_rot=-14,arms_dx=8,arms_dy=2,pelvis_dx=5,pelvis_dy=6,back_rot=-30,back_dx=-10,back_dy=-2,front_rot=38,front_dx=26,front_dy=-8),
      dict(torso_rot=-5,torso_dx=7,torso_dy=4,arms_rot=-6,arms_dx=6,arms_dy=2,pelvis_dx=3,pelvis_dy=4,back_rot=-12,back_dx=-4,back_dy=0,front_rot=22,front_dx=15,front_dy=-4),
      None]
    masks=build_masks(src.size,b); records=[]
    for idx,k in enumerate(KEYPOSES,1):
        fp=frames/f'char_lian_wu__ji_sweep__f{idx:02d}.png'
        if presets[idx-1] is None: shutil.copyfile(sp,fp); fr=Image.open(fp).convert('RGBA')
        else: fr=pose(src,b,masks,presets[idx-1]); fr.save(fp,format='PNG',optimize=False,compress_level=9)
        fb=alpha_bounds(fr); fbase=fb[3]-1 if fb!=(0,0,0,0) else -1
        if fbase!=baseline: print(f'VM02_C6_JI_SWEEP6=BLOCKED baseline_drift frame={idx}'); return 4
        records.append({'index':idx,'keypose':k,'phase_hint':'active' if idx in ACTIVE_KEYPOSES else ('startup' if idx<4 else 'recovery'),'file':str(fp.relative_to(repo)).replace('\\','/'),'sha256':sha256(fp),'alpha_bounds':list(fb),'baseline_y':fbase})
    unique=len({r['sha256'] for r in records})
    if unique<5: print(f'VM02_C6_JI_SWEEP6=BLOCKED insufficient_pose_diversity unique_hashes={unique}'); return 5
    if records[0]['sha256']!=sh or records[-1]['sha256']!=sh: print('VM02_C6_JI_SWEEP6=BLOCKED neutral_handoff_hash'); return 6
    meta={'schema':'tehkne/taijifu-animation-metadata/v1','signature':'Tehkné Solutions','character_id':'lian_wu','animation':'ji_sweep','status':'candidate_pending_godot_review','source_character_lock':{'file':str(sp.relative_to(repo)).replace('\\','/'),'sha256':sh,'pivot_policy':'alpha_bounds_bottom_center','source_alpha_bounds':list(b),'baseline_y':baseline},'generation':{'method':'articulated_region_composite_ji_sweep_v1','frame_count':FRAME_COUNT,'keyposes':KEYPOSES,'active_keyposes':ACTIVE_KEYPOSES,'logical_timing_source':'TechniqueCatalog/ji_sweep startup=8 active=6 recovery=16 @60fps','loop':False,'transparent_background':True},'frames':records,'gates':{'identity_source_hash':'pass','baseline_continuity':'pass','neutral_guard_handoff':'pass','neutral_recover_handoff':'pass','pose_diversity':'pass','godot_visual_review':'pending','runtime_binding':'blocked_pending_c6_integration'}}
    mp=meta_dir/'ji_sweep.json'; mp.write_text(json.dumps(meta,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('VM02_C6_JI_SWEEP6=GENERATED'); print(f'source_sha256={sh}'); print(f'baseline_y={baseline}'); print(f'frames={FRAME_COUNT}'); print(f'unique_hashes={unique}')
    for r in records: print(f"FRAME_PASS {r['index']:02d} {r['keypose']} {r['sha256']} {r['file']}")
    print('neutral_handoff_hash=PASS'); print(f'metadata={mp.relative_to(repo)}'); print('VM02_C6_JI_SWEEP6_GODOT_REVIEW=PENDING'); return 0
if __name__=='__main__': sys.exit(main())
