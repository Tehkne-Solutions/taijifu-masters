from __future__ import annotations
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/modular_fighters/base_01/production/BASE01_PACK_A_FACES.json"
CATALOG = ROOT / "assets/modular_fighters/base_01/catalog.json"

pack = json.loads(PACK.read_text(encoding="utf-8"))
catalog = json.loads(CATALOG.read_text(encoding="utf-8"))

assert pack["pack_id"] == "BASE01-PACK-A-FACES"
assert pack["slot"] == "face"
assert pack["authoring"]["canvas"] == [1024, 1024]
assert pack["authoring"]["mode"] == "RGBA"
assert pack["authoring"]["pivot"] == [0.5, 0.92]
assert pack["authoring"]["root_anchor"] == "bottom_center"
assert pack["promotion_policy"] == "fail_closed"

expected = ["face_02_angular", "face_03_soft", "face_04_broad"]
actual = [item["id"] for item in pack["deliverables"]]
assert actual == expected, (actual, expected)

catalog_faces = {item["id"]: item["status"] for item in catalog["faces"]}
assert catalog_faces.get("face_01_balanced") == "produced"
for face_id in expected:
    assert catalog_faces.get(face_id) in {"planned", "produced"}, face_id

for item in pack["deliverables"]:
    assert item["path"].endswith(f"/{item['id']}.png")
    assert item["intent"].strip()
    if catalog_faces[item["id"]] == "produced":
        path = ROOT / item["path"]
        assert path.exists(), path
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert item.get("sha256") == digest, (item["id"], item.get("sha256"), digest)
        assert item.get("status") == "produced"

acceptance = pack["acceptance"]
assert acceptance["individual_pngs"] == 3
assert acceptance["authored_review"] == "required"
assert acceptance["flipped_review"] == "required"
assert acceptance["gameplay_scale_preview_px"] == 132
assert acceptance["canonical_sha256_required"] is True
assert acceptance["owner_review_required"] is True
assert acceptance["runtime_import_required"] is True

print("BASE01_PACK_A_FACES_CONTRACT=PASS deliverables=3")
print("SIGNATURE=Tehkné Solutions")
