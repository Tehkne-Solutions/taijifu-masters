#!/usr/bin/env python3
"""Valida imagens TGAP conforme o perfil visual da classe de asset."""
from __future__ import annotations
import argparse, json
from pathlib import Path
from typing import Any
from PIL import Image
from tgap_asset_profiles import resolve_profile

IMAGE_EXTENSIONS={".png",".webp"}

def load_json(path:Path)->dict[str,Any]: return json.loads(path.read_text(encoding="utf-8"))

def pivot_for(mode:str,bbox:tuple[int,int,int,int]|None)->list[int]|None:
    if not bbox or mode=="none": return None
    l,t,r,b=bbox
    if mode=="center": return [round((l+r)/2),round((t+b)/2)]
    return [round((l+r)/2),b]

def inspect(path:Path,rules:dict[str,Any])->dict[str,Any]:
    errors=[]; warnings=[]
    try:
        image=Image.open(path); image.load()
    except Exception as exc:
        return {"path":str(path),"passed":False,"errors":[f"decode_error: {exc}"],"warnings":[]}
    mode=image.mode; size=image.size; bands=image.getbands(); has_alpha="A" in bands
    rgba=image.convert("RGBA"); alpha=rgba.getchannel("A"); alpha_min,alpha_max=alpha.getextrema(); bbox=alpha.getbbox()
    alpha_rule=rules.get("alpha","required")
    if path.suffix.lower()==".png" and alpha_rule=="required" and mode!="RGBA": errors.append(f"mode_invalid:{mode}; expected RGBA")
    if alpha_rule=="required" and not has_alpha: errors.append("alpha_missing")
    if alpha_rule=="required" and alpha_min==255: errors.append("transparency_missing")
    if alpha_max==0 or bbox is None: errors.append("frame_empty")
    canvas=rules.get("canvas")
    if canvas and list(size)!=list(canvas): errors.append(f"size_invalid:{size[0]}x{size[1]}; expected {canvas[0]}x{canvas[1]}")
    margins=None
    if bbox:
        l,t,r,b=bbox; margins={"left":l,"top":t,"right":size[0]-r,"bottom":size[1]-b}
        if min(margins.values())<int(rules.get("min_margin",0)): warnings.append("content_near_canvas_edge")
        baseline=rules.get("baseline_min_ratio")
        if isinstance(baseline,(int,float)) and b<int(size[1]*baseline): warnings.append("subject_floating_above_baseline")
    return {"path":str(path),"passed":not errors,"format":image.format,"mode":mode,"size":list(size),"has_alpha":has_alpha,"alpha_range":[alpha_min,alpha_max],"content_bbox":list(bbox) if bbox else None,"margins":margins,"pivot_candidate":pivot_for(str(rules.get("pivot","bottom_center")),bbox),"errors":errors,"warnings":warnings}

def main()->int:
    parser=argparse.ArgumentParser(); parser.add_argument("pack_root",type=Path); args=parser.parse_args()
    root=args.pack_root.resolve(); manifest=load_json(root/"manifest.json"); profile=resolve_profile(manifest); rules=profile.get("visual",{})
    report_dir=root/"validation"; report_dir.mkdir(parents=True,exist_ok=True)
    candidates=sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS and "preview" not in p.parts and "validation" not in p.parts)
    results=[inspect(p,rules) for p in candidates]; passed=sum(i["passed"] for i in results); failed=len(results)-passed
    groups:{}={}
    for item in results:
        if item.get("pivot_candidate"):
            rel=Path(item["path"]).relative_to(root); group=rel.parts[1] if len(rel.parts)>2 and rel.parts[0] in {"frames","vfx_frames"} else rel.parts[0]
            groups.setdefault(group,[]).append(item["pivot_candidate"])
    drift={g:{"x":max(p[0] for p in ps)-min(p[0] for p in ps),"y":max(p[1] for p in ps)-min(p[1] for p in ps)} for g,ps in groups.items()}
    limit=rules.get("pivot_drift_limit"); drift_errors=[]
    if isinstance(limit,(int,float)):
        for g,d in drift.items():
            if max(d.values())>limit: drift_errors.append(f"pivot_drift_exceeded:{g}:{d}")
    blocked=failed>0 or not results or bool(drift_errors)
    report={"tgap_version":"1.0","gate":"visual","asset_class":profile.get("asset_class"),"rules":rules,"images_checked":len(results),"passed":passed,"failed":failed,"warnings":sum(len(i["warnings"]) for i in results),"pivot_drift":drift,"errors":drift_errors,"promotion_blocked":blocked,"results":results}
    (report_dir/"visual-gate-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (report_dir/"visual-gate-report.md").write_text(f"# Gate Visual TGAP\n\n- Classe: **{report['asset_class']}**\n- Imagens: **{len(results)}**\n- Falhas: **{failed}**\n- Promoção bloqueada: **{'sim' if blocked else 'não'}**\n",encoding="utf-8")
    print(json.dumps({k:report[k] for k in ("asset_class","images_checked","passed","failed","promotion_blocked")},ensure_ascii=False)); return 1 if blocked else 0
if __name__=="__main__": raise SystemExit(main())
