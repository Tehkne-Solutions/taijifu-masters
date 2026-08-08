from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROMOTER = ROOT / "scripts/art/promote_base01_pack_c_brows.py"
GENERATOR = ROOT / "scripts/art/generate_base01_pack_c_brows.py"
REFINER = ROOT / "scripts/art/refine_base01_pack_c_brows.py"

text = PROMOTER.read_text(encoding="utf-8")
assert GENERATOR.is_file()
assert REFINER.is_file()
assert 'tools/c61-1-owner-review.pass' in text
assert 'OWNER_REVIEW=PASS' in text
assert 'owner_review_pending' in text
assert 'BASE01_PACK_C_BROWS.canonical.json' in text
assert 'C61_1_PACK_C_CANONICAL_PROMOTION=PASS modules=5' in text
assert not (ROOT / 'tools/c61-1-owner-review.pass').exists(), 'owner approval must not be pre-created in readiness PR'

print('C61_1_CANONICAL_READINESS=PASS')
print('OWNER_REVIEW=PENDING')
print('PROMOTION=FAIL_CLOSED')
print('SIGNATURE=Tehkné Solutions')
