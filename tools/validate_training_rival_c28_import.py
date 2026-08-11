#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from pathlib import Path

# C28 closeout validator intentionally runs only after the disposable importer is absent.
ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "config/v2-rival-intake-contract.json"
EVIDENCE = ROOT / "config/c28-training-rival-runtime-evidence.json"
PRESENTER = ROOT / "scripts/vertical_slice/training_rival_lot01_presenter.gd"
WRITER = ROOT / ".github/workflows/materialize-c28-training-rival-import.yml"
EXPECTED_PRODUCT_HEAD = "673c7dc23fe641cbb3950ec7ede3b44722e97375"
EXPECTED_STATIC_RUN = 31446407367
EXPECTED_STATIC_ARTIFACT = 9084682798
EXPECTED_STATIC_DIGEST = "sha256:6db837ac786cbbd74cbbeb2b21de3144d2e15aff1261d00c8ca28df61843cff8"
EXPECTED_GODOT_RUN = 31446407240
EXPECTED_GODOT_ARTIFACT = 9084703609
EXPECTED_GODOT_DIGEST = "sha256:325f7d5edcb41b7c8db18f830fe54eeebfffdd49c4a5382fcd75555b50da551b"


def block(reason: str) -> int:
    print(f"VM02_C28_IMPORTED_PACK=BLOCKED {reason}")
    return 2


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if not CONTRACT.is_file() or not EVIDENCE.is_file() or not PRESENTER.is_file():
        return block("required_contract_evidence_or_presenter_missing")
    if WRITER.exists():
        return block("disposable_writer_present")
    contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    if evidence.get("schema") != "tehkne/taijifu-c28-training-rival-runtime-evidence/v1":
        return block("runtime_evidence_schema")
    if evidence.get("signature") != "Tehkné Solutions" or evidence.get("character_id") != "training_rival":
        return block("runtime_evidence_identity")
    if evidence.get("status") != "validated_runtime_active_proxy_fallback_preserved":
        return block("runtime_evidence_status")
    if evidence.get("validated_product_head_sha") != EXPECTED_PRODUCT_HEAD:
        return block("runtime_evidence_product_head")
    if evidence.get("source_assets_revision") != contract.get("source_revision"):
        return block("runtime_evidence_source_revision")
    static = evidence.get("static_import_evidence", {})
    godot = evidence.get("godot_runtime_evidence", {})
    if static.get("workflow_run_id") != EXPECTED_STATIC_RUN or static.get("artifact_id") != EXPECTED_STATIC_ARTIFACT or static.get("artifact_digest") != EXPECTED_STATIC_DIGEST or static.get("result") != "pass":
        return block("static_evidence")
    if godot.get("workflow_run_id") != EXPECTED_GODOT_RUN or godot.get("artifact_id") != EXPECTED_GODOT_ARTIFACT or godot.get("artifact_digest") != EXPECTED_GODOT_DIGEST or godot.get("presenter_using_real_assets") is not True or godot.get("result") != "pass":
        return block("godot_evidence")
    runtime_policy = evidence.get("runtime_policy", {})
    if runtime_policy.get("runtime_ready") is not True or runtime_policy.get("real_training_rival_active_when_resource_loads") is not True or runtime_policy.get("procedural_fallback_code_preserved") is not True:
        return block("runtime_evidence_policy")

    destination = ROOT / str(contract["destination_root"])
    resource = ROOT / str(contract["sprite_frames_resource"])
    import_manifest_path = destination / "c28-import-manifest.json"
    canonical_copy = destination / "source-canonical-production-v1.json"
    review_copy = destination / "source-PRESET02_P05_REVIEW.json"
    for path in (destination, resource, import_manifest_path, canonical_copy, review_copy):
        if not path.exists():
            return block(f"missing={path.relative_to(ROOT).as_posix()}")

    presenter_text = PRESENTER.read_text(encoding="utf-8")
    expected_root_literal = 'const LOT_ROOT := "res://' + str(contract["destination_root"]) + '"'
    expected_resource_suffix = 'const SPRITE_FRAMES_PATH := LOT_ROOT + "/training_rival_first_playable_frames.tres"'
    if expected_root_literal not in presenter_text or expected_resource_suffix not in presenter_text:
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
    print("VM02_C28_RUNTIME_EVIDENCE=PASS frozen=true")
    print("VM02_C28_DISPOSABLE_WRITER=ABSENT")
    print("VM02_C28_RUNTIME_READY=PASS presenter_using_real_assets=true fallback_preserved=true")
    print("SIGNATURE=Tehkné Solutions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
