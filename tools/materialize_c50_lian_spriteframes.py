#!/usr/bin/env python3
"""Materialize the C50 Lian Wu first-playable SpriteFrames from approved real frame families.

This script never draws or synthesizes a procedural fighter. It only packages PNG frames
produced by the already-reviewed VM02 Lian Wu generators. Missing gameplay states are
mapped to the nearest approved real pose so the visual cutover can retire the procedural
renderer without pretending animation coverage is complete.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path("assets/pack_01_characters/lian_wu/frames")
OUTPUT = Path("assets/tgap/pack_01_lian_wu/first_playable_lot_01/lian_wu_first_playable_frames.tres")
MANIFEST = OUTPUT.with_name("materialization-manifest.json")

FAMILIES = {
    "idle": (ROOT / "idle", "char_lian_wu__idle__f%02d.png", 6),
    "run": (ROOT / "run", "char_lian_wu__run__f%02d.png", 8),
    "jump_start": (ROOT / "jump_start", "char_lian_wu__jump_start__f%02d.png", 4),
    "airborne": (ROOT / "jump_loop", "char_lian_wu__jump_loop__f%02d.png", 3),
    "fall": (ROOT / "fall", "char_lian_wu__fall__f%02d.png", 3),
    "attack_light": (ROOT / "attacks/ji_body_hook", "char_lian_wu__ji_body_hook__f%02d.png", 6),
}

# Temporary nearest-real-pose mappings. These remain real Lian Wu art and are explicitly
# recorded as incomplete animation coverage; they are not promotion of these states.
TEMP_STATE_MAPS = {
    "guard": (ROOT / "attacks/ji_body_hook" / "char_lian_wu__ji_body_hook__f01.png", 1, False, 6.0),
    "dodge": (ROOT / "run" / "char_lian_wu__run__f04.png", 1, False, 8.0),
    "hit": (ROOT / "attacks/ji_body_hook" / "char_lian_wu__ji_body_hook__f05.png", 1, False, 6.0),
    "ko": (ROOT / "land" / "char_lian_wu__land__f04.png", 1, False, 4.0),
}

SPEEDS = {
    "idle": 8.0,
    "run": 12.0,
    "jump_start": 8.0,
    "airborne": 6.0,
    "fall": 6.0,
    "attack_light": 9.0,
}
LOOPS = {
    "idle": True,
    "run": True,
    "jump_start": False,
    "airborne": True,
    "fall": True,
    "attack_light": False,
}


def rel_resource(path: Path) -> str:
    return "res://" + path.as_posix()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    repo = args.repo_root.resolve()

    resolved: dict[str, list[Path]] = {}
    missing: list[str] = []

    for anim, (directory, pattern, count) in FAMILIES.items():
        frames = []
        for index in range(1, count + 1):
            rel = directory / (pattern % index)
            if not (repo / rel).is_file():
                missing.append(rel.as_posix())
            frames.append(rel)
        resolved[anim] = frames

    for anim, (rel, _count, _loop, _speed) in TEMP_STATE_MAPS.items():
        if not (repo / rel).is_file():
            missing.append(rel.as_posix())
        resolved[anim] = [rel]

    if missing:
        print("VM02_C50_LIAN_MATERIALIZATION=BLOCKED")
        print(f"VM02_C50_LIAN_MISSING_COUNT={len(missing)}")
        for item in missing[:20]:
            print(f"VM02_C50_LIAN_MISSING_FRAME={item}")
        return 2

    ordered_anims = [
        "idle", "run", "jump_start", "airborne", "fall",
        "attack_light", "guard", "dodge", "hit", "ko",
    ]

    unique_paths: list[Path] = []
    for anim in ordered_anims:
        for rel in resolved[anim]:
            if rel not in unique_paths:
                unique_paths.append(rel)

    ext_ids = {rel: f"tex_{idx:03d}" for idx, rel in enumerate(unique_paths, start=1)}
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(unique_paths) + 1} format=3]', ""]
    for rel in unique_paths:
        lines.append(f'[ext_resource type="Texture2D" path="{rel_resource(rel)}" id="{ext_ids[rel]}"]')
    lines += ["", "[resource]", "animations = ["]

    blocks: list[str] = []
    for anim in ordered_anims:
        frames = resolved[anim]
        if anim in TEMP_STATE_MAPS:
            _rel, _count, loop, speed = TEMP_STATE_MAPS[anim]
        else:
            loop = LOOPS[anim]
            speed = SPEEDS[anim]
        frame_entries = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%s")}' % ext_ids[rel]
            for rel in frames
        )
        block = (
            "{\n"
            f'"frames": [{frame_entries}],\n'
            f'"loop": {str(loop).lower()},\n'
            f'"name": &"{anim}",\n'
            f'"speed": {speed:.1f}\n'
            "}"
        )
        blocks.append(block)
    lines.append(",\n".join(blocks))
    lines.append("]")
    lines.append("")

    output = repo / OUTPUT
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")

    manifest = {
        "schema": "tehkne/taijifu-c50-lian-materialization/v1",
        "signature": "Tehkné Solutions",
        "character_id": "lian_wu",
        "visual_cutover": "real_assets_only",
        "procedural_renderer_allowed": False,
        "spriteframes": OUTPUT.as_posix(),
        "approved_real_families": {
            anim: [p.as_posix() for p in resolved[anim]]
            for anim in ["idle", "run", "jump_start", "airborne", "fall", "attack_light"]
        },
        "temporary_nearest_real_pose_mappings": {
            anim: resolved[anim][0].as_posix() for anim in ["guard", "dodge", "hit", "ko"]
        },
        "animation_coverage_complete": False,
        "temporary_states_not_promoted": ["guard", "dodge", "hit", "ko"],
        "purpose": "C50 canonical visual cutover; replace procedural fighter rendering with canonical Lian Wu art",
    }
    (repo / MANIFEST).write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print("VM02_C50_LIAN_MATERIALIZATION=PASS")
    print(f"VM02_C50_LIAN_SPRITEFRAMES={output}")
    print("VM02_C50_LIAN_REAL_ANIMATION_FAMILIES=6/6")
    print("VM02_C50_LIAN_TEMP_REAL_POSE_STATES=4")
    print("VM02_C50_LIAN_PROCEDURAL_RENDERER=RETIRED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
