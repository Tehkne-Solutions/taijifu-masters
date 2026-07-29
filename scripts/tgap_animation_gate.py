#!/usr/bin/env python3
"""Valida sequências TGAP conforme o perfil da classe de asset."""
from __future__ import annotations
import argparse,json,re
from pathlib import Path
from typing import Any
from tgap_asset_profiles import resolve_profile

def load(path:Path)->dict[str,Any]: return json.loads(path.read_text(encoding="utf-8"))

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument("pack_root",type=Path); ap.add_argument("--pivot-drift-limit",type=float,default=12.0); a=ap.parse_args()
    root=a.pack_root.resolve(); expected=load(root/"expected-assets.json"); manifest=load(root/"manifest.json"); profile=resolve_profile(manifest); animated=bool(profile.get("animated")); animations=expected.get("animations",{})
    results=[]; total_errors=0; skipped=False
    if not animated:
        skipped=True
    else:
        prefix=profile.get("frame_prefix") or manifest.get("runtime",{}).get("frame_prefix") or manifest.get("pack_id","asset")
        digits=int(profile.get("frame_digits",2)); frame_re=re.compile(rf"^{re.escape(prefix)}__(?P<animation>[a-z0-9_]+)__f(?P<index>\d{{{digits}}})\.png$")
        frames_root=root/profile.get("frames_root","frames"); metadata_root=root/profile.get("metadata_root","metadata"); default_fps=float(profile.get("default_fps",12.0))
        visual_path=root/"validation"/"visual-gate-report.json"; visual=load(visual_path) if visual_path.is_file() else {}; drift_map=visual.get("pivot_drift",{})
        for name,count_raw in animations.items():
            count=int(count_raw); files=sorted((frames_root/name).glob("*.png")) if (frames_root/name).is_dir() else []; indices=[]; errors=[]
            for file in files:
                m=frame_re.match(file.name)
                if not m or m.group("animation")!=name: errors.append(f"nome não canônico: {file.name}")
                else: indices.append(int(m.group("index")))
            missing=sorted(set(range(count))-set(indices)); extra=sorted(set(indices)-set(range(count)))
            if len(files)!=count: errors.append(f"quantidade física={len(files)}, esperada={count}")
            if missing: errors.append(f"frames ausentes: {missing}")
            if extra: errors.append(f"frames extras: {extra}")
            meta_path=metadata_root/f"{name}.json"; meta={}
            if not meta_path.is_file(): errors.append(f"metadata ausente: {meta_path.name}")
            else:
                try: meta=load(meta_path)
                except Exception as exc: errors.append(f"metadata inválido: {exc}")
            fps=meta.get("fps",default_fps)
            if not isinstance(fps,(int,float)) or fps<=0 or fps>60: errors.append("fps deve estar entre 0 e 60")
            if not isinstance(meta.get("loop"),bool): errors.append("loop booleano obrigatório")
            if meta.get("frame_count",len(files))!=len(files): errors.append("frame_count divergente")
            drift=drift_map.get(name,{}); drift_value=max(drift.values()) if isinstance(drift,dict) and drift else None
            if isinstance(drift_value,(int,float)) and drift_value>a.pivot_drift_limit: errors.append("deriva de pivô acima do limite")
            total_errors+=len(errors); results.append({"animation":name,"expected_frames":count,"present_frames":len(files),"fps":fps,"loop":meta.get("loop"),"passed":not errors,"errors":errors})
    blocked=(animated and (not animations or total_errors>0))
    report={"tgap_version":"1.0","asset_class":profile["asset_class"],"animated":animated,"skipped":skipped,"animations_expected":len(animations),"animations_passed":sum(x["passed"] for x in results),"animations_failed":sum(not x["passed"] for x in results),"total_errors":total_errors,"promotion_blocked":blocked,"animations":results}
    v=root/"validation"; v.mkdir(parents=True,exist_ok=True); (v/"animation-gate-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8"); (v/"animation-gate-report.md").write_text(f"# Gate de Animação TGAP\n\n- Classe: **{profile['asset_class']}**\n- Animado: **{'sim' if animated else 'não'}**\n- Ignorado: **{'sim' if skipped else 'não'}**\n- Promoção bloqueada: **{'sim' if blocked else 'não'}**\n",encoding="utf-8")
    print(json.dumps({k:report[k] for k in ("asset_class","animated","skipped","animations_expected","animations_failed","promotion_blocked")},ensure_ascii=False)); return 1 if blocked else 0
if __name__=="__main__": raise SystemExit(main())
