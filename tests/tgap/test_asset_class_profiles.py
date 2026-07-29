from __future__ import annotations
import json, subprocess, sys
from pathlib import Path

REPO=Path(__file__).resolve().parents[2]

def run(script:str, pack:Path):
    return subprocess.run([sys.executable,str(REPO/'scripts'/script),str(pack)],cwd=REPO,text=True,capture_output=True,check=False)

def write_pack(root:Path, asset_class:str, assets:list[dict], animations=None, profile=None):
    root.mkdir(); (root/'manifest.json').write_text(json.dumps({'schema':'tgap/v1','pack_id':'pack_test','asset_class':asset_class,'validation_profile':profile or {}}),encoding='utf-8'); (root/'expected-assets.json').write_text(json.dumps({'assets':assets,'animations':animations or {}}),encoding='utf-8')

def test_static_tile_skips_animation_gate(tmp_path:Path):
    pack=tmp_path/'tile'; write_pack(pack,'tile',[])
    result=run('tgap_animation_gate.py',pack); report=json.loads((pack/'validation/animation-gate-report.json').read_text())
    assert result.returncode==0 and report['skipped'] is True and report['promotion_blocked'] is False

def test_inventory_supports_glob_groups(tmp_path:Path):
    pack=tmp_path/'ui'; write_pack(pack,'ui',[])
    (pack/'icons').mkdir(); (pack/'icons/a.png').write_bytes(b'a'); (pack/'icons/b.png').write_bytes(b'b')
    expected={'assets':[],'groups':[{'id':'icons','glob':'icons/*.png','required':2,'quality':'final'}]}; (pack/'expected-assets.json').write_text(json.dumps(expected))
    result=run('tgap_inventory_report.py',pack); report=json.loads((pack/'validation/inventory-report.json').read_text())
    assert result.returncode==0 and report['asset_class']=='ui' and report['final']==2

def test_inventory_blocks_incomplete_group(tmp_path:Path):
    pack=tmp_path/'props'; write_pack(pack,'prop',[])
    (pack/'props').mkdir(); (pack/'props/a.png').write_bytes(b'a')
    (pack/'expected-assets.json').write_text(json.dumps({'groups':[{'id':'props','glob':'props/*.png','required':2,'quality':'final'}]}))
    result=run('tgap_inventory_report.py',pack); report=json.loads((pack/'validation/inventory-report.json').read_text())
    assert result.returncode==1 and report['missing']==1
