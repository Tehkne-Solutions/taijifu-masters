#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/v2-rival-intake-contract.json"
PRESENTER = ROOT / "scripts/vertical_slice/training_rival_lot01_presenter.gd"


def block(reason: str) -> int:
    print(f"VM02_C28_IMPORTED_PACK=BLOCKED {reason}")
    return 2


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if not CONTRACT.is_file() or not PRESENTER.is_file():
        return block("required_contract_or_presenter_missing")
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    destination = ROOT / str(contract["destination_root"])
    resource = ROOT / str(contract["sprite_frames_resource"])
    import_manifest_path = destination / "c28-import-manifest.json"
    canonical_copy = destination / "source-canonical-production-v1.json"
    review_copy = destination / "source-PRESET02_P05_REVIEW.json"
    for path in (destination, resource, import_manifest_path, canonical_copy, review_copy):
        if not path.exists():
            return block(f"missing={path.relative_to(ROOT).as_posix()}")

    presenter_text = PRESENTER.read_text(encoding="utf-8")
    expected_res = "res://" + str(contract["sprite_frames_resource"])
    if expected_res not in presenter_text:
        return block("presenter_resource_path_drift")

    manifest = json.loads(import_manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema") != "tehkne/taijifu-c28-training-rival-import/v1":
        return block("manifest_schema")
    if manifest.get("signature") != "Tehkné Solutions" or manifest.get("character_id") != "training_rival":
        return block("manifest_identity")
    if manifest.get("source_revision") != contract.get("source_revision"):
        return block("source_revision")
    if int(manifest.get("frame_count", 0)) != 44:
        return block("frame_count")
    if digest(canonical_copy) != manifest.get("source_canonical_sha256"):
        return block("canonical_copy_hash")
    if digest(review_copy) != manifest.get("source_final_review_sha256"):
        return block("review_copy_hash")
    if manifest.get("runtime_policy", {}).get("proxy_retirement_allowed") is not False:
        return block("proxy_policy")

    expected = contract["required_animations"]
    by_animation: dict[str, list[dict]] = {name: [] for name in expected}
    for frame in manifest.get("frames", []):
        animation = frame.get("animation")
        if animation not in by_animation:
            return block(f"unexpected_animation={animation}")
        by_animation[animation].append(frame)

    total = 0
    for animation, count_value in expected.items():
        count = int(count_value)
        frames = sorted(by_animation[animation], key=lambda item: int(item.get("index", 0)))
        if len(frames) != count:
            return block(f"animation_count={animation}:{len(frames)}/{count}")
        for index, frame in enumerate(frames, 1):
            name = f"char_training_rival__{animation}__f{index:03d}.png"
            if frame.get("name") != name:
                return block(f"frame_name={animation}:f{index:03d}")
            path = destination / "animations" / animation / name
            if not path.is_file():
                return block(f"frame_missing={animation}/{name}")
            if digest(path) != frame.get("sha256"):
                return block(f"frame_hash={animation}/{name}")
            total += 1
    if total != 44:
        return block(f"total={total}/44")

    tres = resource.read_text(encoding="utf-8")
    if tres.count("[ext_resource type=\"Texture2D\"") != 44:
        return block("spriteframes_ext_resource_count")
    for animation, count_value in expected.items():
        if f'&"{animation}"' not in tres:
            return block(f"spriteframes_animation={animation}")
        for index in range(1, int(count_value) + 1):
            name = f"char_training_rival__{animation}__f{index:03d}.png"
            if name not in tres:
                return block(f"spriteframes_frame={animation}/{name}")

    print("VM02_C28_IMPORTED_PACK=PASS frames=44/44")
    print("VM02_C28_IMPORTED_HASHES=PASS frames=44")
    print("VM02_C28_PRESENTER_PATH=PASS")
    print("VM02_C28_SPRITEFRAMES_STATIC=PASS animations=10 frames=44")
    print("VM02_C28_PROXY_RETIREMENT=BLOCKED godot_runtime_bench_required=true")
    print("SIGNATURE=Tehkné Solutions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
