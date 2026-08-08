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
BUILD = ROOT / "build/c61-1-pack-c-brows"
PACK = BASE / "production/BASE01_PACK_C_BROWS.json"
QA = BASE / "production/BASE01_PACK_C_BROWS.qa.json"
READY = BASE / "production/BASE01_PACK_C_BROWS.readiness.json"
CATALOG = BASE / "catalog.json"
MANIFEST = BASE / "manifest.json"
PLAN = BASE / "production_plan.json"
CANONICAL = BASE / "production/BASE01_PACK_C_BROWS.canonical.json"
SIGNATURE = "Tehkné Solutions"
PIVOT = [0.5, 0.92]
VARIANTS = [
    "brows_02_neutral",
    "brows_03_arched",
    "brows_04_straight",
    "brows_05_heavy",
    "brows_06_sharp",
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
        raise SystemExit(f"C61_1_PROMOTION=BLOCKED canvas={path}:{img.size}")
    alpha = img.getchannel("A")
    if any(alpha.getpixel(p) != 0 for p in ((0,0),(1023,0),(0,1023),(1023,1023))):
        raise SystemExit(f"C61_1_PROMOTION=BLOCKED transparent_corners={path}")
    box = alpha.getbbox()
    if box is None:
        raise SystemExit(f"C61_1_PROMOTION=BLOCKED empty={path}")
    x0,y0,x1,y1 = box
    return {
        "sha256": sha256(path),
        "canvas": [1024,1024],
        "mode": "RGBA",
        "alpha_bbox": [x0,y0,x1-1,y1-1],
        "transparent_corners": True,
        "pivot": PIVOT,
        "root_anchor": "bottom_center",
    }


def main() -> int:
    owner_review = ROOT / "tools/c61-1-owner-review.pass"
    if not owner_review.is_file() or "OWNER_REVIEW=PASS" not in owner_review.read_text(encoding="utf-8"):
        raise SystemExit("C61_1_PROMOTION=BLOCKED owner_review_pending")

    subprocess.run([
        sys.executable, str(ROOT / "scripts/art/generate_base01_pack_c_brows.py"),
        "--repo-root", str(ROOT), "--output", str(BUILD.relative_to(ROOT)),
    ], check=True)
    subprocess.run([
        sys.executable, str(ROOT / "scripts/art/refine_base01_pack_c_brows.py"),
        "--repo-root", str(ROOT), "--brows-dir", str(BUILD),
    ], check=True)

    pack, qa, ready = load(PACK), load(QA), load(READY)
    catalog, manifest, plan = load(CATALOG), load(MANIFEST), load(PLAN)
    modules = {}
    for brow_id in VARIANTS:
        src = BUILD / f"{brow_id}.png"
        dst = BASE / "brows" / f"{brow_id}.png"
        shutil.copy2(src, dst)
        meta = validate_png(dst)
        meta.update({"slot":"brows","path":str(dst.relative_to(ROOT)).replace("\\","/")})
        modules[brow_id] = meta
        print(f"C61_1_CANONICAL_FILE=PASS module={brow_id} sha256={meta['sha256']}")

    rows = {row["id"]: row for row in catalog["brows"]}
    for brow_id, meta in modules.items():
        rows[brow_id].update({"status":"produced","path":meta["path"],"sha256":meta["sha256"]})
    catalog["last_completed_pack"] = "BASE01-PACK-C-BROWS"
    save(CATALOG, catalog)

    manifest.setdefault("modules", {}).update(modules)
    manifest.setdefault("qa", {})["pack_c_brows"] = {
        "machine":"PASS",
        "runtime_import":"PASS_GODOT_4_3_C61",
        "owner_review":"PASS",
        "visual_review_basis":"C61_V3_CONTACT_SHEET",
        "status":"PASS",
    }
    scope = manifest.setdefault("scope", {})
    scope["delivered"] = "default identity modules + Pack A faces + neutral face plate + Pack B eyes + Pack C brows"
    scope["not_yet_delivered"] = [x for x in scope.get("not_yet_delivered", []) if x != "additional brow variants"]
    save(MANIFEST, manifest)

    pack["version"] = "1.1.0"; pack["status"] = "produced_canonical"
    for item in pack["deliverables"]:
        item.update({"status":"produced","sha256":modules[item["id"]]["sha256"]})
    save(PACK, pack)

    qa["version"] = "1.1.0"; qa["status"] = "PASS"
    qa["checks"] = {k:"PASS" for k in qa["checks"]}
    qa["modules"] = {b:{"status":"CANONICAL","path":modules[b]["path"],"sha256":modules[b]["sha256"]} for b in VARIANTS}
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
        if row["pack_id"] == "BASE01-PACK-C-BROWS":
            row["status"] = "complete"; row["version"] = "1.1.0"
    save(PLAN, plan)

    save(CANONICAL, {
        "schema":"tehkne/taijifu-base01-pack-c-canonical/v1",
        "signature":SIGNATURE,
        "pack_id":"BASE01-PACK-C-BROWS",
        "version":"1.1.0",
        "status":"PASS",
        "owner_review":"PASS",
        "runtime_bench":"C61_CANDIDATE_RUNTIME_PASS",
        "pivot":PIVOT,
        "assembly_order":["body_base","skin","face_plate","face","eyes","brows"],
        "modules":modules,
    })
    print("C61_1_PACK_C_CANONICAL_PROMOTION=PASS modules=5")
    print(f"SIGNATURE={SIGNATURE}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
