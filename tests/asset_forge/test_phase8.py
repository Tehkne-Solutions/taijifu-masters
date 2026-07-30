import json
from pathlib import Path
from PIL import Image
from tools.asset_forge.perceptual_gate import ahash, distance
from tools.asset_forge.promote_approval import promote

def test_perceptual_hash_identical(tmp_path):
    p=tmp_path/'a.png'; Image.new('RGBA',(16,16),(255,255,255,255)).save(p)
    assert distance(ahash(p),ahash(p)) == 0

def test_promotion_rejects_incomplete_checklist(tmp_path):
    draft=tmp_path/'draft.json'; out=tmp_path/'approval.json'
    draft.write_text(json.dumps({'pack_id':'p','reviewer':'r','decision':'approved','checks':{}}),encoding='utf-8')
    assert promote(draft,out) == 10
    assert not out.exists()
