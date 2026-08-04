#!/usr/bin/env python3
"""Materialize Training Rival P01 (idle6 + run8) from one clean canonical master.

This intentionally mirrors the proven Lian Wu articulated-region workflow while keeping
Training Rival identity locked to its own clean source. It does not use contact sheets as
runtime sources and never removes a painted background: source alpha must already be clean.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError as exc:
    raise SystemExit("VM02_C39_P01=BLOCKED missing Pillow") from exc

CANVAS = (1024, 1024)
ALPHA_THRESHOLD = 3
IDLE_COUNT = 6
RUN_COUNT = 8
LIAN_WU_LOCK_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
    visible = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    return visible.getbbox() or (0, 0, 0, 0)


def norm_point(bounds, nx, ny):
    x0, y0, x1, y1 = bounds
    return (int(round(x0 + (x1 - x0) * nx)), int(round(y0 + (y1 - y0) * ny)))


def polygon_mask(size, points, dilation=7):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    if dilation >= 3 and dilation % 2 == 1:
        mask = mask.filter(ImageFilter.MaxFilter(dilation))
    return mask


def build_masks(size, bounds):
    p = lambda x, y: norm_point(bounds, x, y)
    regions = {
        "head": [p(.18,.00),p(.82,.00),p(.82,.34),p(.18,.34)],
        "torso": [p(.16,.20),p(.84,.20),p(.82,.66),p(.18,.66)],
        "arm_back": [p(.00,.27),p(.48,.25),p(.48,.72),p(.00,.76)],
        "arm_front": [p(.52,.25),p(1.00,.27),p(1.00,.76),p(.52,.72)],
        "pelvis": [p(.22,.53),p(.78,.53),p(.80,.77),p(.20,.77)],
        "leg_back": [p(.10,.62),p(.52,.60),p(.55,1.00),p(.05,1.00)],
        "leg_front": [p(.48,.60),p(.90,.62),p(.95,1.00),p(.45,1.00)],
    }
    return {name: polygon_mask(size, pts) for name, pts in regions.items()}


def extract(source, mask):
    return Image.composite(source, Image.new("RGBA", source.size, (0,0,0,0)), mask)


def rotate(layer, degrees, pivot):
    return layer.rotate(degrees, resample=Image.Resampling.NEAREST, center=pivot,
                        expand=False, fillcolor=(0,0,0,0))


def offset(layer, dx, dy):
    if dx == 0 and dy == 0:
        return layer
    out = Image.new("RGBA", layer.size, (0,0,0,0))
    out.alpha_composite(layer, (dx,dy))
    return out


def baseline_lock(frame, source_baseline):
    fb = alpha_bounds(frame)
    if fb == (0,0,0,0):
        return frame
    dy = source_baseline - (fb[3] - 1)
    return offset(frame, 0, dy) if dy else frame


def compose(source, bounds, masks, mode: str, theta: float):
    p = lambda x, y: norm_point(bounds, x, y)
    out = Image.new("RGBA", source.size, (0,0,0,0))
    source_baseline = bounds[3] - 1

    layers = {k: extract(source, m) for k,m in masks.items()}
    s = math.sin(theta)
    c = math.cos(theta)

    if mode == "idle":
        breath = math.sin(theta)
        settle = abs(math.cos(theta))
        layers["head"] = offset(layers["head"], int(round(1.5*breath)), -int(round(1.0*settle)))
        layers["torso"] = offset(layers["torso"], 0, -int(round(2.0*breath)))
        layers["arm_front"] = rotate(layers["arm_front"], 2.2*breath, p(.69,.35))
        layers["arm_back"] = rotate(layers["arm_back"], -1.8*breath, p(.31,.35))
        layers["pelvis"] = offset(layers["pelvis"], 0, -int(round(1.0*breath)))
    elif mode == "run":
        lift_front = max(0.0, math.sin(theta + math.pi/2))
        lift_back = max(0.0, math.sin(theta - math.pi/2))
        bob = -int(round(7.0 * abs(c)))
        layers["head"] = offset(layers["head"], int(round(-4.0*s)), bob-2)
        layers["torso"] = rotate(layers["torso"], -5.0, p(.50,.48))
        layers["torso"] = offset(layers["torso"], int(round(-3.0*s)), bob)
        layers["pelvis"] = offset(layers["pelvis"], int(round(-2.0*s)), bob+2)
        layers["arm_front"] = rotate(layers["arm_front"], -24.0*s, p(.68,.35))
        layers["arm_back"] = rotate(layers["arm_back"], 24.0*s, p(.32,.35))
        layers["leg_front"] = rotate(layers["leg_front"], 28.0*s, p(.60,.65))
        layers["leg_back"] = rotate(layers["leg_back"], -28.0*s, p(.40,.65))
        layers["leg_front"] = offset(layers["leg_front"], int(round(12.0*s)), -int(round(18.0*lift_front)))
        layers["leg_back"] = offset(layers["leg_back"], -int(round(12.0*s)), -int(round(18.0*lift_back)))
    else:
        raise ValueError(mode)

    for name in ("leg_back","arm_back","torso","head","pelvis","leg_front","arm_front"):
        out.alpha_composite(layers[name])
    return baseline_lock(out, source_baseline)


def validate_clean_source(image: Image.Image, source_hash: str) -> tuple[bool,str]:
    if image.size != CANVAS:
        return False, f"canvas={image.size} expected={CANVAS}"
    if source_hash == LIAN_WU_LOCK_SHA256:
        return False, "source_matches_lian_wu_character_lock"
    if image.mode != "RGBA":
        return False, f"mode={image.mode} expected=RGBA"
    bounds = alpha_bounds(image)
    if bounds == (0,0,0,0):
        return False, "empty_alpha"
    alpha = image.getchannel("A")
    opaque_bbox = alpha_bounds(image)
    x0,y0,x1,y1 = opaque_bbox
    if x0 <= 1 or y0 <= 1 or x1 >= CANVAS[0]-1 or y1 >= CANVAS[1]-1:
        return False, "foreground_touches_canvas_edge"
    # Native-transparent source: corners must be transparent.
    for xy in ((0,0),(1023,0),(0,1023),(1023,1023)):
        if alpha.getpixel(xy) != 0:
            return False, "nontransparent_canvas_corner"
    return True, "pass"


def save_sequence(source, bounds, masks, out_root: Path, mode: str, count: int):
    dest = out_root / mode
    dest.mkdir(parents=True, exist_ok=True)
    records=[]
    source_baseline = bounds[3]-1
    for i in range(count):
        theta = 2.0*math.pi*i/count
        frame = compose(source,bounds,masks,mode,theta)
        path = dest / f"f{i+1:03d}.png"
        frame.save(path, "PNG", optimize=False, compress_level=9)
        fb=alpha_bounds(frame)
        baseline=fb[3]-1 if fb!=(0,0,0,0) else -1
        if baseline != source_baseline:
            raise RuntimeError(f"baseline_drift {mode}/f{i+1:03d} {baseline}!={source_baseline}")
        records.append({
            "index":i+1,"phase":round(math.sin(theta),6),
            "file":str(path.relative_to(out_root)).replace('\\','/'),
            "sha256":sha256(path),"alpha_bounds":list(fb),"baseline_y":baseline
        })
    return records


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--output-root", required=True)
    args=ap.parse_args()
    source_path=Path(args.source).resolve()
    out_root=Path(args.output_root).resolve()
    if not source_path.is_file():
        print(f"VM02_C39_P01=BLOCKED source_missing={source_path}"); return 2
    source_hash=sha256(source_path)
    image=Image.open(source_path).convert("RGBA")
    ok,why=validate_clean_source(image,source_hash)
    if not ok:
        print(f"VM02_C39_P01=BLOCKED source_contract={why}"); return 3
    bounds=alpha_bounds(image)
    masks=build_masks(image.size,bounds)
    idle=save_sequence(image,bounds,masks,out_root,"idle",IDLE_COUNT)
    run=save_sequence(image,bounds,masks,out_root,"run",RUN_COUNT)
    hashes={r['sha256'] for r in idle+run}
    if len(hashes) < 8:
        print(f"VM02_C39_P01=BLOCKED insufficient_unique_frames={len(hashes)}/14"); return 4
    manifest={
        "schema":"tehkne/taijifu-training-rival-p01/v1",
        "signature":"Tehkné Solutions",
        "character_id":"training_rival",
        "pack":"P01","version":"1.0.2-candidate",
        "source":{"file":str(source_path),"sha256":source_hash,"alpha_bounds":list(bounds),"baseline_y":bounds[3]-1},
        "contract":{"style":"chibi_manga_comic","native_facing":"left","pivot":"alpha_bounds_bottom_center","weapon":"single_wooden_training_saber"},
        "generation":{"method":"articulated_region_composite","contact_sheet_as_source":False,"background_removal":False,"idle_frames":IDLE_COUNT,"run_frames":RUN_COUNT},
        "idle":idle,"run":run,
        "gates":{"clean_source":"pass","not_lian_source":"pass","transparent_background":"pass","baseline_continuity":"pass","unique_frame_floor":"pass","visual_review":"pending"}
    }
    (out_root/"manifest.json").write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print("VM02_C39_P01=GENERATED")
    print(f"source_sha256={source_hash}")
    print(f"source_alpha_bounds={bounds}")
    print(f"baseline_y={bounds[3]-1}")
    print("idle_frames=6")
    print("run_frames=8")
    print(f"unique_hashes={len(hashes)}")
    print("VM02_C39_P01_VISUAL_REVIEW=PENDING")
    return 0


if __name__ == "__main__":
    sys.exit(main())
