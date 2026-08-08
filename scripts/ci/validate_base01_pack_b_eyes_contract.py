from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/modular_fighters/base_01/production/BASE01_PACK_B_EYES.json"
CATALOG = ROOT / "assets/modular_fighters/base_01/catalog.json"
CANONICAL_A = ROOT / "assets/modular_fighters/base_01/production/BASE01_PACK_A_FACES.canonical.json"

pack = json.loads(PACK.read_text(encoding="utf-8"))
catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
pack_a = json.loads(CANONICAL_A.read_text(encoding="utf-8"))

assert pack["pack_id"] == "BASE01-PACK-B-EYES"
assert pack["slot"] == "eyes"
assert pack["authoring"]["canvas"] == [1024, 1024]
assert pack["authoring"]["mode"] == "RGBA"
assert pack["authoring"]["pivot"] == [0.5, 0.92]
assert pack["authoring"]["preview_assembly_order"] == ["body_base","skin","face_plate","face","eyes","brows"]
assert pack["promotion_policy"] == "fail_closed"

expected = ["eyes_02_calm","eyes_03_fierce","eyes_04_narrow","eyes_05_round","eyes_06_heavy"]
assert [row["id"] for row in pack["deliverables"]] == expected

states = {row["id"]: row["status"] for row in catalog["eyes"]}
assert states["eyes_01_focused"] == "produced"
for eye_id in expected:
    assert states[eye_id] in {"planned", "produced"}, eye_id

plate = pack_a["modules"]["neutral_face_plate_v1"]
assert plate["slot"] == "face_plate"
assert (ROOT / plate["path"]).exists()

acceptance = pack["acceptance"]
assert acceptance["individual_pngs"] == 5
assert acceptance["gameplay_scale_preview_px"] == 132
assert acceptance["pairwise_visual_difference_required"] is True
assert acceptance["canonical_sha256_required"] is True
assert acceptance["runtime_import_required"] is True
assert acceptance["owner_review_required"] is True

print("BASE01_PACK_B_EYES_CONTRACT=PASS deliverables=5")
print("FACE_PLATE_DEPENDENCY=PASS")
print("SIGNATURE=Tehkné Solutions")
