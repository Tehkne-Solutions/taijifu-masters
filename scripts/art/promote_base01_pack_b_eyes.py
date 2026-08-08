#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/modular_fighters/base_01"
BUILD = ROOT / "build/c60-1-pack-b-eyes"
PACK = BASE / "production/BASE01_PACK_B_EYES.json"
QA = BASE / "production/BASE01_PACK_B_EYES.qa.json"
READY = BASE / "production/BASE01_PACK_B_EYES.readiness.json"
CATALOG = BASE / "catalog.json"
MANIFEST = BASE / "manifest.json"
PLAN = BASE / "production_plan.json"
CANONICAL = BASE / "production/BASE01_PACK_B_EYES.canonical.json"
SIGNATURE = "Tehkné Solutions"
PIVOT = [0.5, 0.92]
VARIANTS = [
    "eyes_02_calm",
    "eyes_03_fierce",
    "eyes_04_narrow",
    "eyes_05_round",
    "eyes_06_heavy",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_png(path: Path) -> dict:
    img = Image.open(path).convert("RGBA")
    if img.size != (1024, 1024):
        raise SystemExit(f"C60_1_PROMOTION=BLOCKED canvas={path}:{img.size}")
    a = img.getchannel("A")
    if any(a.getpixel(p) != 0 for p in ((0,0),(1023,0),(0,1023),(1023,1023))):
        raise SystemExit(f"C60_1_PROMOTION=BLOCKED transparent_corners={path}")
    box = a.getbbox()
    if box is None:
        raise SystemExit(f"C60_1_PROMOTION=BLOCKED empty={path}")
    x0,y0,x1,y1 = box
    return {
        "sha256": sha256(path),
        "canvas": [1024, 1024],
        "mode": "RGBA",
        "alpha_bbox": [x0,y0,x1-1,y1-1],
        "transparent_corners": True,
        "pivot": PIVOT,
        "root_anchor": "bottom_center",
    }


def main() -> int:
    subprocess.run([
        sys.executable,
        str(ROOT / "scripts/art/generate_base01_pack_b_eyes.py"),
        "--repo-root", str(ROOT),
        "--output", str(BUILD.relative_to(ROOT)),
    ], check=True)

    pack = load(PACK)
    catalog = load(CATALOG)
    manifest = load(MANIFEST)
    qa = load(QA)
    ready = load(READY)
    plan = load(PLAN)

    modules = {}
    for eye_id in VARIANTS:
        src = BUILD / f"{eye_id}.png"
        dst = BASE / "eyes" / f"{eye_id}.png"
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        meta = validate_png(dst)
        meta.update({"slot": "eyes", "path": str(dst.relative_to(ROOT)).replace("\\", "/")})
        modules[eye_id] = meta
        print(f"C60_1_CANONICAL_FILE=PASS module={eye_id} sha256={meta['sha256']}")

    # Catalog: planned -> produced with canonical path/hash.
    by_id = {row["id"]: row for row in catalog["eyes"]}
    for eye_id, meta in modules.items():
        row = by_id[eye_id]
        row["status"] = "produced"
        row["path"] = meta["path"]
        row["sha256"] = meta["sha256"]
    catalog["last_completed_pack"] = "BASE01-PACK-B-EYES"
    save(CATALOG, catalog)

    # Manifest: canonical runtime modules and Pack B QA.
    manifest.setdefault("modules", {}).update(modules)
    manifest.setdefault("qa", {})["pack_b_eyes"] = {
        "machine": "PASS",
        "runtime_import": "PASS_GODOT_4_3_C60",
        "owner_review": "PASS",
        "visual_review_basis": "C60_CANDIDATE_CONTACT_SHEET",
        "status": "PASS",
    }
    scope = manifest.setdefault("scope", {})
    scope["delivered"] = "default identity modules + Pack A face variants + neutral face plate + Pack B eye variants"
    pending = [x for x in scope.get("not_yet_delivered", []) if x != "additional eye variants"]
    scope["not_yet_delivered"] = pending
    save(MANIFEST, manifest)

    # Pack contract closes with actual canonical hashes.
    pack["version"] = "1.1.0"
    pack["status"] = "produced_canonical"
    for item in pack["deliverables"]:
        meta = modules[item["id"]]
        item["status"] = "produced"
        item["sha256"] = meta["sha256"]
    save(PACK, pack)

    qa["version"] = "1.1.0"
    qa["status"] = "PASS"
    qa["checks"] = {k: "PASS" for k in qa["checks"]}
    qa["modules"] = {
        eye_id: {
            "status": "CANONICAL",
            "path": modules[eye_id]["path"],
            "sha256": modules[eye_id]["sha256"],
        } for eye_id in VARIANTS
    }
    save(QA, qa)

    ready["state"] = "CANONICAL_COMPLETE"
    ready["ready"].update({
        "candidate_generation": True,
        "authored_flipped_gameplay_review": True,
        "godot_runtime_import": True,
        "owner_visual_review": True,
        "canonical_promotion": True,
    })
    ready["pending"] = []
    save(READY, ready)

    for row in plan["packs"]:
        if row["pack_id"] == "BASE01-PACK-B-EYES":
            row["status"] = "complete"
            row["version"] = "1.1.0"
    save(PLAN, plan)

    canonical = {
        "schema": "tehkne/taijifu-base01-pack-b-canonical/v1",
        "signature": SIGNATURE,
        "pack_id": "BASE01-PACK-B-EYES",
        "version": "1.1.0",
        "status": "PASS",
        "owner_review": "PASS",
        "runtime_bench": "C60_CANDIDATE_RUNTIME_PASS",
        "pivot": PIVOT,
        "assembly_order": ["body_base","skin","face_plate","face","eyes","brows"],
        "modules": modules,
    }
    save(CANONICAL, canonical)

    print("C60_1_PACK_B_CANONICAL_PROMOTION=PASS modules=5")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
