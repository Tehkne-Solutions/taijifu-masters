from __future__ import annotations
import json, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw

REPO=Path(__file__).resolve().parents[2]
SCRIPT=REPO/"scripts"/"tgap_visual_gate.py"

def run(pack:Path):
    return subprocess.run([sys.executable,str(SCRIPT),str(pack)],cwd=REPO,text=True,capture_output=True,check=False)

def make_pack(tmp:Path,asset_class:str,size:tuple[int,int],opaque:bool=False,override:dict|None=None)->Path:
    pack=tmp/asset_class; pack.mkdir(); manifest={"asset_class":asset_class}
    if override: manifest["validation_profile"]={"visual":override}
    (pack/"manifest.json").write_text(json.dumps(manifest),encoding="utf-8")
    mode="RGB" if opaque else "RGBA"; bg=(0,0,0) if opaque else (0,0,0,0)
    image=Image.new(mode,size,bg); draw=ImageDraw.Draw(image); fill=(255,255,255) if opaque else (255,255,255,255)
    draw.rectangle((8,8,size[0]-8,size[1]-4),fill=fill); image.save(pack/"asset.png")
    return pack

def report(pack:Path)->dict:
    return json.loads((pack/"validation"/"visual-gate-report.json").read_text(encoding="utf-8"))

def test_character_requires_128_rgba(tmp_path:Path):
    pack=make_pack(tmp_path,"character",(128,128)); result=run(pack); data=report(pack)
    assert result.returncode==0; assert data["asset_class"]=="character"; assert data["rules"]["pivot"]=="bottom_center"

def test_tile_accepts_opaque_isometric_canvas(tmp_path:Path):
    pack=make_pack(tmp_path,"tile",(128,64),opaque=True); result=run(pack); data=report(pack)
    assert result.returncode==0; assert data["promotion_blocked"] is False

def test_vfx_rejects_wrong_canvas(tmp_path:Path):
    pack=make_pack(tmp_path,"vfx",(128,128)); result=run(pack); data=report(pack)
    assert result.returncode==1; assert any("size_invalid" in e for e in data["results"][0]["errors"])

def test_ui_allows_custom_canvas_and_alpha(tmp_path:Path):
    pack=make_pack(tmp_path,"ui",(320,96),opaque=True); result=run(pack)
    assert result.returncode==0

def test_manifest_can_override_visual_rules(tmp_path:Path):
    pack=make_pack(tmp_path,"prop",(64,64),override={"canvas":[64,64],"alpha":"allowed","pivot":"center"}); result=run(pack); data=report(pack)
    assert result.returncode==0; assert data["rules"]["canvas"]==[64,64]; assert data["rules"]["pivot"]=="center"
