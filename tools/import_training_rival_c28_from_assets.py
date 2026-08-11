#!/usr/bin/env python3
"""Import PRESET-02 Training Rival 44/44 into the game atomically.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

REQUIRED_PACK_FOR_ANIMATION = {
    "idle": "P01",
    "run": "P01",
    "jump_start": "P02",
    "airborne": "P02",
    "fall": "P02",
    "attack_light": "P03",
    "guard": "P04",
    "dodge": "P04",
    "hit": "P05",
    "ko": "P05",
}


def block(reason: str) -> int:
    print(f"VM02_C28_IMPORT=BLOCKED {reason}")
    return 2


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git_revision(root: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def records_for_animation(pack: dict, animation: str) -> list[dict]:
    if animation in {"idle", "run", "attack_light"}:
        records = pack.get(animation, [])
    else:
        records = pack.get("frames", {}).get(animation, [])
    return records if isinstance(records, list) else []


def write_sprite_frames(destination_root: str, destination: Path, contract: dict, frame_names: dict[str, list[str]]) -> Path:
    ext_resources: list[str] = []
    animations: list[str] = []
    resource_id = 1
    settings = contract["animation_settings"]
    for animation, expected in contract["required_animations"].items():
        names = frame_names[animation]
        if len(names) != int(expected):
            raise ValueError(f"spriteframes_count={animation}:{len(names)}/{expected}")
        entries: list[str] = []
        for name in names:
            relative = f"{destination_root}/animations/{animation}/{name}"
            ext_resources.append(
                f'[ext_resource type="Texture2D" path="res://{relative}" id="{resource_id}"]'
            )
            entries.append('{"duration": 1.0, "texture": ExtResource("%d")}' % resource_id)
            resource_id += 1
        fps = float(settings[animation]["fps"])
        loop = "true" if bool(settings[animation]["loop"]) else "false"
        animations.append(
            '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.2f}'
            % (", ".join(entries), loop, animation, fps)
        )
    content = (
        '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n[resource]\nanimations = [%s]\n'
        % (resource_id, "\n".join(ext_resources), ",\n".join(animations))
    )
    output = destination / "training_rival_first_playable_frames.tres"
    output.write_text(content, encoding="utf-8")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--assets-root", required=True, type=Path)
    parser.add_argument("--game-root", default=Path.cwd(), type=Path)
    args = parser.parse_args()

    assets_root = args.assets_root.resolve()
    game_root = args.game_root.resolve()
    contract_path = game_root / "config/v2-rival-intake-contract.json"
    if not contract_path.is_file():
        return block("game_contract_missing")
    contract = load_json(contract_path)
    if contract.get("signature") != "Tehkné Solutions" or contract.get("character_id") != "training_rival":
        return block("game_contract_identity")
    if int(contract.get("required_total_frames", 0)) != 44:
        return block("game_contract_frame_count")

    try:
        source_revision = git_revision(assets_root)
    except Exception as exc:
        return block(f"assets_revision={exc}")
    expected_revision = str(contract.get("source_revision", ""))
    if source_revision != expected_revision:
        return block(f"assets_revision={source_revision}:expected={expected_revision}")
    print(f"VM02_C28_ASSETS_REVISION=PASS sha={source_revision}")

    canonical_path = assets_root / str(contract["source_canonical_contract"])
    review_path = assets_root / str(contract["source_final_review"])
    if not canonical_path.is_file() or not review_path.is_file():
        return block("canonical_or_review_missing")
    canonical = load_json(canonical_path)
    review = load_json(review_path)
    if canonical.get("signature") != "Tehkné Solutions" or canonical.get("character_id") != "training_rival":
        return block("canonical_identity")
    if canonical.get("status") != "canonical_complete_44_of_44_runtime_pending":
        return block(f"canonical_status={canonical.get('status')}")
    completion = canonical.get("completion", {})
    promotion = canonical.get("promotion", {})
    if int(completion.get("frames_present", 0)) != 44 or int(completion.get("frames_required", 0)) != 44:
        return block("canonical_completion")
    if promotion.get("asset_matrix_complete") is not True:
        return block("canonical_asset_matrix")
    if promotion.get("runtime_ready") is not False or promotion.get("current_proxy_may_be_removed") is not False:
        return block("canonical_runtime_must_remain_pending")
    if review.get("schema") != "tehkne/taijifu-training-rival-p05-review/v1":
        return block("final_review_schema")
    if review.get("visual_review", {}).get("approved_for_completion") is not True:
        return block("final_review_not_approved")
    if review.get("global_progress_after_pack") != "44/44":
        return block("final_review_progress")
    print("VM02_C28_CANONICAL_CONTRACT=PASS frames=44/44 runtime_pending=true")
    print("VM02_C28_FINAL_VISUAL_REVIEW=PASS")

    pack_paths = contract["source_pack_manifests"]
    packs: dict[str, dict] = {}
    for pack_id, relative in pack_paths.items():
        path = assets_root / str(relative)
        if not path.is_file():
            return block(f"pack_manifest_missing={pack_id}")
        pack = load_json(path)
        if pack.get("signature") != "Tehkné Solutions" or pack.get("character_id") != "training_rival":
            return block(f"pack_identity={pack_id}")
        packs[pack_id] = pack

    source_lot = assets_root / str(contract["source_lot"])
    expected_animations = contract["required_animations"]
    frame_entries: list[dict] = []
    frame_names: dict[str, list[str]] = {}
    total = 0
    for animation, count_value in expected_animations.items():
        expected_count = int(count_value)
        pack_id = REQUIRED_PACK_FOR_ANIMATION[animation]
        records = records_for_animation(packs[pack_id], animation)
        if len(records) != expected_count:
            return block(f"manifest_count={animation}:{len(records)}/{expected_count}")
        names: list[str] = []
        for index, record in enumerate(records, 1):
            name = f"char_training_rival__{animation}__f{index:03d}.png"
            expected_file = f"{animation}/{name}"
            if record.get("file") != expected_file:
                return block(f"manifest_name={pack_id}:{animation}:f{index:03d}")
            source = source_lot / "animations" / animation / name
            if not source.is_file():
                return block(f"source_frame_missing={animation}/{name}")
            actual_sha = digest(source)
            if actual_sha != record.get("sha256"):
                return block(f"source_frame_hash={animation}/{name}")
            names.append(name)
            frame_entries.append({
                "animation": animation,
                "index": index,
                "name": name,
                "sha256": actual_sha,
            })
            total += 1
        frame_names[animation] = names
    if total != 44:
        return block(f"frame_total={total}/44")
    print("VM02_C28_RIVAL_FRAME_CONTRACT=PASS frames=44/44 hashes=true")

    destination_relative = str(contract["destination_root"])
    destination = game_root / destination_relative
    staging = Path(str(destination) + ".__c28_staging")
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True, exist_ok=True)

    for animation, names in frame_names.items():
        target_folder = staging / "animations" / animation
        target_folder.mkdir(parents=True, exist_ok=True)
        for name in names:
            shutil.copy2(source_lot / "animations" / animation / name, target_folder / name)

    shutil.copy2(canonical_path, staging / "source-canonical-production-v1.json")
    shutil.copy2(review_path, staging / "source-PRESET02_P05_REVIEW.json")
    sprite_frames = write_sprite_frames(destination_relative, staging, contract, frame_names)

    import_manifest = {
        "schema": "tehkne/taijifu-c28-training-rival-import/v1",
        "signature": "Tehkné Solutions",
        "character_id": "training_rival",
        "source_repository": contract["source_repository"],
        "source_revision": source_revision,
        "source_canonical_sha256": digest(canonical_path),
        "source_final_review_sha256": digest(review_path),
        "frame_count": total,
        "required_animations": expected_animations,
        "animation_settings": contract["animation_settings"],
        "frames": frame_entries,
        "sprite_frames_resource": contract["sprite_frames_resource"],
        "runtime_policy": {
            "proxy_retirement_allowed": False,
            "requires_godot_runtime_bench": True,
        },
    }
    (staging / "c28-import-manifest.json").write_text(
        json.dumps(import_manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    if not sprite_frames.is_file():
        return block("spriteframes_not_written")
    if destination.exists():
        shutil.rmtree(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging.replace(destination)

    print(f"VM02_C28_RIVAL_IMPORT=PASS destination={destination_relative}")
    print("VM02_C28_SPRITEFRAMES_GENERATED=PASS animations=10 frames=44")
    print("VM02_C28_PROXY_RETIREMENT=BLOCKED godot_runtime_bench_required=true")
    print("VM02_C28_IMPORT=PASS")
    print("SIGNATURE=Tehkné Solutions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
