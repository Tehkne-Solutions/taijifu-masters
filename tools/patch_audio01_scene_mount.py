#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / "scenes/vertical_slice/first_playable.tscn"


def replace_once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"AUDIO01_SCENE_PATCH=BLOCKED anchor_count={count} anchor={old!r}")
    return text.replace(old, new, 1)


def main() -> int:
    text = SCENE.read_text(encoding="utf-8")
    if 'path="res://scripts/vertical_slice/first_playable_audio_director.gd"' in text:
        print("AUDIO01_SCENE_PATCH=PASS already_mounted=true")
        return 0
    text = replace_once(text, "[gd_scene load_steps=9 format=3]", "[gd_scene load_steps=10 format=3]")
    text = replace_once(
        text,
        '[ext_resource type="Script" path="res://scripts/vertical_slice/first_playable_combat_guide.gd" id="8_guide"]',
        '[ext_resource type="Script" path="res://scripts/vertical_slice/first_playable_combat_guide.gd" id="8_guide"]\n[ext_resource type="Script" path="res://scripts/vertical_slice/first_playable_audio_director.gd" id="9_audio"]',
    )
    text = replace_once(
        text,
        '[node name="HudController" type="Node" parent="."]\nscript = ExtResource("7_hud")',
        '[node name="HudController" type="Node" parent="."]\nscript = ExtResource("7_hud")\n\n[node name="AudioDirector" type="Node" parent="."]\nscript = ExtResource("9_audio")',
    )
    SCENE.write_text(text, encoding="utf-8")
    print("AUDIO01_SCENE_PATCH=PASS mounted=AudioDirector")
    print("SIGNATURE=Tehkné Solutions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
