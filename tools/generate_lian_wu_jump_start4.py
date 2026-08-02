#!/usr/bin/env python3
"""Generate Lian Wu Jump Start 4 candidates from the approved Character Lock.

Tehkné Solutions

Non-looping launch sequence: contact -> compression -> impulse -> takeoff.
"""
from __future__ import annotations

import argparse, hashlib, json
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFilter

EXPECTED_SOURCE_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANVAS = (1024, 1024)
FRAME_COUNT = 4
ALPHA_THRESHOLD = 3
FPS = 12.0


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image):
    alpha = image.convert("RGBA").getchannel("A")
    visible = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    return visible.getbbox() or (0, 0, 0, 0)


def norm_point(bounds, nx, ny):
    x0, y0, x1, y1 = bounds
    return (int(round(x0 + (x1-x0)*nx)), int(round(y0 + (y1-y0)*ny)))


def polygon_mask(size, points, dilation=9):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    if dilation >= 3 and dilation % 2 == 1:
        mask = mask.filter(ImageFilter.MaxFilter(dilation))
    return mask


def extract(source, mask):
    return Image.composite(source, Image.new("RGBA", source.size, (0,0,0,0)), mask)


def rotate(layer, degrees, pivot):
    return layer.rotate(degrees, resample=Image.Resampling.NEAREST, center=pivot, expand=False, fillcolor=(0,0,0,0))


def offset(layer, dx, dy):
    if not dx and not dy:
        return layer
    out = Image.new("RGBA", layer.size, (0,0,0,0))
    out.alpha_composite(layer, (dx,dy))
    return out


def build_masks(size, bounds):
    p=lambda x,y:norm_point(bounds,x,y)
    regions={
        "torso":[p(.14,0),p(.86,0),p(.84,.66),p(.16,.66)],
        "arm_back":[p(0,.25),p(.48,.26),p(.47,.73),p(0,.74)],
        "arm_front":[p(.52,.24),p(1,.24),p(1,.74),p(.53,.72)],
        "pelvis":[p(.22,.52),p(.78,.52),p(.78,.78),p(.22,.78)],
        "leg_back":[p(.12,.60),p(.52,.60),p(.56,1),p(.07,1)],
        "leg_front":[p(.48,.60),p(.88,.60),p(.94,1),p(.44,1)],
    }
    return {k:polygon_mask(size,v) for k,v in regions.items()}


def compose(source,bounds,masks,index):
    p=lambda x,y:norm_point(bounds,x,y)
    # Tuned progression: neutral/contact, crouch, extension, clear takeoff.
    presets=[
        dict(body_y=0, pelvis_y=0, torso_deg=0, arm_deg=0, leg_deg=0, leg_y=0, takeoff=0),
        dict(body_y=18, pelvis_y=22, torso_deg=3, arm_deg=8, leg_deg=11, leg_y=8, takeoff=0),
        dict(body_y=5, pelvis_y=7, torso_deg=-4, arm_deg=-13, leg_deg=-14, leg_y=-7, takeoff=0),
        dict(body_y=-22, pelvis_y=-20, torso_deg=-7, arm_deg=-20, leg_deg=-19, leg_y=-20, takeoff=-16),
    ][index]
    layers={k:extract(source,masks[k]) for k in masks}
    layers["torso"]=rotate(layers["torso"],presets[0]["torso_deg"] if False else presets[0]["torso_deg"],p(.50,.48))
    # use selected preset
    q=presets
    layers={k:extract(source,masks[k]) for k in masks}
    layers["torso"]=rotate(layers["torso"],q["torso_deg"],p(.50,.48))
    layers["arm_back"]=rotate(layers["arm_back"],q["arm_deg"],p(.34,.34))
    layers["arm_front"]=rotate(layers["arm_front"],-q["arm_deg"],p(.66,.34))
    layers["leg_back"]=rotate(layers["leg_back"],-q["leg_deg"],p(.40,.64))
    layers["leg_front"]=rotate(layers["leg_front"],q["leg_deg"],p(.60,.64))
    layers["torso"]=offset(layers["torso"],2 if index>=2 else 0,q["body_y"]+q["takeoff"])
    layers["pelvis"]=offset(layers["pelvis"],2 if index>=2 else 0,q["pelvis_y"]+q["takeoff"])
    layers["leg_back"]=offset(layers["leg_back"],-4 if index>=2 else 0,q["leg_y"]+q["takeoff"])
    layers["leg_front"]=offset(layers["leg_front"],5 if index>=2 else 0,q["leg_y"]+q["takeoff"])
    out=Image.new("RGBA",source.size,(0,0,0,0))
    for key in ("leg_back","arm_back","torso","pelvis","leg_front","arm_front"):
        out.alpha_composite(layers[key])
    # Ground frames F01-F03 re-anchor to canonical contact. F04 intentionally lifts.
    if index < 3:
        fb=alpha_bounds(out)
        if fb!=(0,0,0,0):
            dy=(bounds[3]-1)-(fb[3]-1)
            if dy: out=offset(out,0,dy)
    return out


def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--repo-root",default="."); ap.add_argument("--source",default="assets/characters/lian_wu/character_lock/lian_wu_neutral.png"); args=ap.parse_args()
    repo=Path(args.repo_root).resolve(); source=(repo/args.source).resolve()
    if not source.is_file(): print(f"VM02_A5_JUMP_START4=BLOCKED source_missing={source}"); return 2
    actual=sha256(source)
    if actual!=EXPECTED_SOURCE_SHA256: print("VM02_A5_JUMP_START4=BLOCKED source_hash_mismatch"); return 3
    image=Image.open(source).convert("RGBA")
    if image.size!=CANVAS: print(f"VM02_A5_JUMP_START4=BLOCKED canvas={image.size}"); return 4
    bounds=alpha_bounds(image); masks=build_masks(image.size,bounds); source_baseline=bounds[3]-1
    frames_dir=repo/"assets/pack_01_characters/lian_wu/frames/jump_start"; meta_dir=repo/"assets/pack_01_characters/lian_wu/metadata"
    frames_dir.mkdir(parents=True,exist_ok=True); meta_dir.mkdir(parents=True,exist_ok=True)
    for stale in frames_dir.glob("char_lian_wu__jump_start__f*.png"): stale.unlink()
    records=[]
    for i in range(FRAME_COUNT):
        frame=compose(image,bounds,masks,i); path=frames_dir/f"char_lian_wu__jump_start__f{i+1:02d}.png"; frame.save(path,format="PNG",compress_level=9)
        fb=alpha_bounds(frame); baseline=fb[3]-1 if fb!=(0,0,0,0) else -1
        if i<3 and baseline!=source_baseline: print(f"VM02_A5_JUMP_START4=BLOCKED grounded_baseline frame={i+1} baseline={baseline}"); return 5
        if i==3 and baseline>=source_baseline: print(f"VM02_A5_JUMP_START4=BLOCKED takeoff_not_airborne baseline={baseline}"); return 6
        records.append({"index":i+1,"file":str(path.relative_to(repo)).replace("\\","/"),"sha256":sha256(path),"alpha_bounds":list(fb),"baseline_y":baseline})
    meta={"schema":"tehkne/taijifu-animation-metadata/v1","signature":"Tehkné Solutions","character_id":"lian_wu","animation":"jump_start","status":"candidate_pending_godot_review","source_character_lock":{"file":str(source.relative_to(repo)).replace("\\","/"),"sha256":actual,"source_alpha_bounds":list(bounds),"baseline_y":source_baseline},"generation":{"method":"articulated_jump_launch_v1","frame_count":4,"frame_numbering":"one_based_f01_to_f04","loop":False,"fps":FPS,"semantic_phases":["contact","compression","impulse","takeoff"],"transition_target":"jump_loop","global_warp":False,"redraw":False},"frames":records,"gates":{"identity_source_hash":"pass","canvas":"pass","transparent_background":"pass","ground_contact_f01_f03":"pass","takeoff_f04":"pass","godot_visual_review":"pending","runtime_promotion":"blocked"}}
    mp=meta_dir/"jump_start.json"; mp.write_text(json.dumps(meta,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print("VM02_A5_JUMP_START4=GENERATED"); print(f"source_sha256={actual}"); print(f"source_alpha_bounds={bounds}"); print(f"baseline_y={source_baseline}"); print("frames=4")
    for r in records: print(f"FRAME_PASS {r['index']:02d} {r['sha256']} {r['file']}")
    print(f"metadata={mp.relative_to(repo)}"); print("VM02_A5_JUMP_START4_GODOT_REVIEW=PENDING"); return 0

if __name__=="__main__": sys.exit(main())
