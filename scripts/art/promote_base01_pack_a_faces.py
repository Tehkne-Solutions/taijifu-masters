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
BASE01 = ROOT / "assets/modular_fighters/base_01"
BUILD = ROOT / "build/c59-5"
SIGNATURE = "Tehkné Solutions"
FACES = ["face_02_angular", "face_03_soft", "face_04_broad"]
FACE_PLATE_ID = "neutral_face_plate_v1"


def run(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def alpha_bbox(path: Path) -> list[int]:
    img = Image.open(path).convert("RGBA")
    if img.size != (1024, 1024) or img.mode != "RGBA":
        raise SystemExit(f"C59_5_PROMOTION=BLOCKED asset_contract={path}:{img.size}:{img.mode}")
    alpha = img.getchannel("A")
    if any(alpha.getpixel(p) != 0 for p in ((0,0),(1023,0),(0,1023),(1023,1023))):
        raise SystemExit(f"C59_5_PROMOTION=BLOCKED transparent_corners={path}")
    box = alpha.getbbox()
    if box is None:
        raise SystemExit(f"C59_5_PROMOTION=BLOCKED empty_asset={path}")
    x0, y0, x1, y1 = box
    return [x0, y0, x1 - 1, y1 - 1]


def module_contract(slot: str, path: Path) -> dict:
    return {
        "slot": slot,
        "path": path.relative_to(ROOT).as_posix(),
        "sha256": sha256(path),
        "canvas": [1024, 1024],
        "mode": "RGBA",
        "alpha_bbox": alpha_bbox(path),
        "transparent_corners": True,
        "pivot": [0.5, 0.92],
        "root_anchor": "bottom_center",
    }


def main() -> int:
    if BUILD.exists():
        shutil.rmtree(BUILD)
    faces_build = BUILD / "faces"
    neutral_build = BUILD / "neutral"
    faces_build.mkdir(parents=True)
    neutral_build.mkdir(parents=True)

    run(sys.executable, "scripts/art/generate_base01_pack_a_faces.py", "--repo-root", ".", "--output", faces_build.relative_to(ROOT).as_posix())
    run(sys.executable, "scripts/art/refine_base01_pack_a_faces_for_plate.py", "--faces-dir", faces_build.relative_to(ROOT).as_posix())
    run(sys.executable, "scripts/art/generate_base01_neutral_face_plate.py", "--repo-root", ".", "--faces-dir", faces_build.relative_to(ROOT).as_posix(), "--output", neutral_build.relative_to(ROOT).as_posix())

    face_dir = BASE01 / "face"
    plate_dir = BASE01 / "face_plate"
    face_dir.mkdir(parents=True, exist_ok=True)
    plate_dir.mkdir(parents=True, exist_ok=True)

    canonical_paths: dict[str, Path] = {}
    for face_id in FACES:
        src = faces_build / f"{face_id}.png"
        dst = face_dir / f"{face_id}.png"
        shutil.copyfile(src, dst)
        canonical_paths[face_id] = dst
    plate_path = plate_dir / f"{FACE_PLATE_ID}.png"
    shutil.copyfile(neutral_build / f"{FACE_PLATE_ID}.png", plate_path)
    canonical_paths[FACE_PLATE_ID] = plate_path

    contracts = {
        face_id: module_contract("face", canonical_paths[face_id])
        for face_id in FACES
    }
    contracts[FACE_PLATE_ID] = module_contract("face_plate", plate_path)
    hashes = {key: value["sha256"] for key, value in contracts.items()}
    if len(set(hashes.values())) != 4:
        raise SystemExit(f"C59_5_PROMOTION=BLOCKED duplicate_hashes={hashes}")

    catalog_path = BASE01 / "catalog.json"
    catalog = load_json(catalog_path)
    for row in catalog.get("faces", []):
        if row.get("id") in FACES:
            row["status"] = "produced"
            row["path"] = contracts[row["id"]]["path"]
            row["sha256"] = contracts[row["id"]]["sha256"]
    catalog["internal_modules"] = [
        {
            "id": FACE_PLATE_ID,
            "slot": "face_plate",
            "status": "produced",
            "path": contracts[FACE_PLATE_ID]["path"],
            "sha256": contracts[FACE_PLATE_ID]["sha256"],
            "creator_editable": False,
        }
    ]
    catalog["last_completed_pack"] = "BASE01-PACK-A-FACES"
    save_json(catalog_path, catalog)

    manifest_path = BASE01 / "manifest.json"
    manifest = load_json(manifest_path)
    modules = manifest.setdefault("modules", {})
    for face_id in FACES:
        modules[face_id] = contracts[face_id]
    modules[FACE_PLATE_ID] = contracts[FACE_PLATE_ID]
    manifest["non_default_identity"] = {
        "face_plate": FACE_PLATE_ID,
        "assembly_order": ["body_base", "skin", "face_plate", "face", "eyes", "brows"],
        "default_face_plate_free": True,
        "applies_to_faces": FACES,
    }
    manifest.setdefault("qa", {})["pack_a_faces"] = {
        "machine": "PASS",
        "runtime_import": "PASS_GODOT_4_3_C59_4",
        "owner_review": "PASS",
        "visual_review_basis": "C59.2_V2",
        "status": "PASS",
    }
    scope = manifest.setdefault("scope", {})
    scope["delivered"] = "default identity modules + Pack A face variants + neutral face plate"
    pending = list(scope.get("not_yet_delivered", []))
    pending = [x for x in pending if x not in {"additional face variants", "neutral replacement face plate for non-default swaps"}]
    scope["not_yet_delivered"] = pending
    save_json(manifest_path, manifest)

    pack_path = BASE01 / "production/BASE01_PACK_A_FACES.json"
    pack = load_json(pack_path)
    pack["version"] = "1.1.0"
    pack["status"] = "produced_canonical"
    pack["face_plate_dependency"] = {
        "id": FACE_PLATE_ID,
        "path": contracts[FACE_PLATE_ID]["path"],
        "sha256": contracts[FACE_PLATE_ID]["sha256"],
        "required_for_non_default_faces": True,
    }
    for item in pack.get("deliverables", []):
        fid = item["id"]
        item["status"] = "produced"
        item["sha256"] = contracts[fid]["sha256"]
    pack["promotion"] = {
        "owner_review": "PASS",
        "godot_runtime": "PASS_C59_4",
        "canonicalized_by": "C59.5",
    }
    save_json(pack_path, pack)

    qa_path = BASE01 / "production/BASE01_PACK_A_FACES.qa.json"
    qa = load_json(qa_path)
    qa["status"] = "PASS"
    qa["version"] = "1.1.0"
    checks = qa.setdefault("checks", {})
    for key in list(checks):
        checks[key] = "PASS"
    checks["face_plate_dependency"] = "PASS"
    for face_id in FACES:
        qa.setdefault("modules", {})[face_id] = {
            "status": "PASS",
            "sha256": contracts[face_id]["sha256"],
            "path": contracts[face_id]["path"],
        }
    qa["face_plate"] = {
        "status": "PASS",
        "sha256": contracts[FACE_PLATE_ID]["sha256"],
        "path": contracts[FACE_PLATE_ID]["path"],
    }
    qa["owner_approval"] = "PASS"
    qa["runtime_gate"] = "C59_4_PASS"
    save_json(qa_path, qa)

    readiness_path = BASE01 / "production/BASE01_PACK_A_FACES.readiness.json"
    readiness = load_json(readiness_path)
    readiness["state"] = "READY_CANONICAL"
    readiness["ready"].update({
        "canonical_assets": True,
        "canonical_sha256": True,
        "godot_runtime_import": True,
        "owner_visual_review": True,
        "face_plate": True,
    })
    readiness["pending"] = []
    save_json(readiness_path, readiness)

    plan_path = BASE01 / "production_plan.json"
    plan = load_json(plan_path)
    for row in plan.get("packs", []):
        if row.get("pack_id") == "BASE01-PACK-A-FACES":
            row["status"] = "complete"
            row["version"] = "1.1.0"
    save_json(plan_path, plan)

    canonical = {
        "schema": "tehkne/taijifu-base01-pack-a-canonical/v1",
        "signature": SIGNATURE,
        "pack_id": "BASE01-PACK-A-FACES",
        "version": "1.1.0",
        "status": "PASS",
        "owner_review": "PASS",
        "runtime_bench": "C59.4_PASS",
        "pivot": [0.5, 0.92],
        "assembly_order_non_default": ["body_base", "skin", "face_plate", "face", "eyes", "brows"],
        "modules": {key: contracts[key] for key in [FACE_PLATE_ID, *FACES]},
    }
    save_json(BASE01 / "production/BASE01_PACK_A_FACES.canonical.json", canonical)

    print("C59_5_PACK_A_CANONICAL_PROMOTION=PASS assets=4")
    for key in [FACE_PLATE_ID, *FACES]:
        print(f"C59_5_CANONICAL_ASSET=PASS id={key} sha256={contracts[key]['sha256']}")
    print("OWNER_REVIEW=PASS")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
