#!/usr/bin/env python3
import argparse, hashlib, json
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "taijifu/asset-forge-approval/v1"
REQUIRED = ["identity_consistent","clean_background","no_clipping","turnaround_consistent","portraits_consistent","icons_legible","technical_quality"]

def canonical(data):
    return json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()

def promote(draft_path: Path, output: Path, perceptual: Path | None = None) -> int:
    draft = json.loads(draft_path.read_text(encoding="utf-8"))
    checks = draft.get("checks", {})
    errors = []
    if not draft.get("pack_id"): errors.append("pack_id ausente")
    if not draft.get("reviewer"): errors.append("reviewer ausente")
    if any(checks.get(k) is not True for k in REQUIRED): errors.append("checklist incompleto")
    if draft.get("decision") != "approved": errors.append("decisão não aprovada")
    perceptual_sha = None
    if perceptual:
        report = json.loads(perceptual.read_text(encoding="utf-8"))
        if not report.get("ready"): errors.append("gate perceptual bloqueado")
        if report.get("pack_id") != draft.get("pack_id"): errors.append("pack_id perceptual divergente")
        perceptual_sha = hashlib.sha256(perceptual.read_bytes()).hexdigest()
    if errors:
        print(json.dumps({"promoted": False, "errors": errors}, ensure_ascii=False)); return 10
    payload = {"schema": SCHEMA,"pack_id": draft["pack_id"],"reviewer": draft["reviewer"],"reviewed_at": datetime.now(timezone.utc).isoformat(),"decision": "approved","checks": {k: True for k in REQUIRED},"notes": draft.get("notes", ""),"review_manifest_sha256": draft.get("review_manifest_sha256"),"perceptual_report_sha256": perceptual_sha}
    payload["signature_sha256"] = hashlib.sha256(canonical(payload)).hexdigest()
    output.parent.mkdir(parents=True, exist_ok=True); output.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"promoted": True, "output": str(output), "signature": payload["signature_sha256"]}, ensure_ascii=False)); return 0

if __name__ == "__main__":
    ap=argparse.ArgumentParser(); ap.add_argument("draft", type=Path); ap.add_argument("output", type=Path); ap.add_argument("--perceptual", type=Path)
    a=ap.parse_args(); raise SystemExit(promote(a.draft,a.output,a.perceptual))
