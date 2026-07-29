#!/usr/bin/env python3
"""Gera inventário TGAP por classe, com qualidade, hashes e bloqueios."""
from __future__ import annotations
import argparse, hashlib, json
from collections import Counter
from pathlib import Path
from typing import Any
from tgap_asset_profiles import resolve_profile

FINAL_STATES={"final","approved","integrated","released"}
PROTOTYPE_MARKERS=("prototype","keypose","placeholder","preview","concept","mockup")

def sha256(path:Path)->str:
    d=hashlib.sha256()
    with path.open("rb") as h:
        for chunk in iter(lambda:h.read(1024*1024),b""): d.update(chunk)
    return d.hexdigest()

def classify(path:str, quality:str|None=None)->str:
    q=(quality or "").lower(); lower=path.lower()
    if q in FINAL_STATES:return "final"
    if q=="prototype" or any(m in lower for m in PROTOTYPE_MARKERS):return "prototype"
    return "unverified"

def expand_entries(root:Path, expected:dict[str,Any], profile:dict[str,Any])->list[dict[str,Any]]:
    entries=[]
    for item in expected.get("assets",[]): entries.append({"path":item} if isinstance(item,str) else dict(item))
    for group in expected.get("groups",[]):
        pattern=group.get("glob"); required=int(group.get("required",0)); quality=group.get("quality")
        matches=sorted(root.glob(pattern)) if pattern else []
        for p in matches: entries.append({"path":p.relative_to(root).as_posix(),"quality":quality,"group":group.get("id")})
        for i in range(max(0,required-len(matches))): entries.append({"path":f"<missing:{group.get('id','group')}:{i+1}>","quality":quality,"virtual_missing":True})
    return entries

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument("pack_root",type=Path); ap.add_argument("--write-status",action="store_true"); a=ap.parse_args()
    root=a.pack_root.resolve(); expected=json.loads((root/"expected-assets.json").read_text(encoding="utf-8")); manifest=json.loads((root/"manifest.json").read_text(encoding="utf-8")); profile=resolve_profile(manifest)
    results=[]
    for item in expand_entries(root,expected,profile):
        rel=item["path"]; target=root/rel; present=not item.get("virtual_missing") and target.is_file(); e={"path":rel,"present":present,"classification":"missing","group":item.get("group")}
        if present:e.update(size_bytes=target.stat().st_size,sha256=sha256(target),classification=classify(rel,item.get("quality")))
        results.append(e)
    counts=Counter(x["classification"] for x in results); total=len(results); present=sum(x["present"] for x in results); final=counts["final"]; blocked=total==0 or present!=total or final!=total
    report={"tgap_version":"1.0","asset_class":profile["asset_class"],"pack_root":str(root),"expected":total,"present":present,"missing":total-present,"final":final,"prototype":counts["prototype"],"unverified":counts["unverified"],"progress_physical":round(present/total,6) if total else 0,"progress_final":round(final/total,6) if total else 0,"promotion_blocked":blocked,"assets":results}
    v=root/"validation"; v.mkdir(parents=True,exist_ok=True); (v/"inventory-report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8"); (v/"inventory-report.md").write_text(f"# Inventário TGAP\n\n- Classe: **{profile['asset_class']}**\n- Presentes: **{present}/{total}**\n- Finais: **{final}/{total}**\n- Promoção bloqueada: **{'sim' if blocked else 'não'}**\n",encoding="utf-8")
    if a.write_status:
        s=root/"production-status.json"; current=json.loads(s.read_text(encoding="utf-8")) if s.exists() else {}; current.update({k:report[k] for k in ("expected","present","missing","final","prototype","unverified","progress_physical","progress_final","promotion_blocked")}); s.write_text(json.dumps(current,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:report[k] for k in ("asset_class","expected","present","missing","final","promotion_blocked")},ensure_ascii=False)); return 1 if blocked else 0
if __name__=="__main__": raise SystemExit(main())
