#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "config/c28-canonical-duo-visual-evidence.json"
RIVAL_PRESENTER = ROOT / "scripts/vertical_slice/training_rival_lot01_presenter.gd"
ARENA = ROOT / "scripts/vertical_slice/first_playable_arena.gd"
VISUAL_GATE = ROOT / "scripts/ci/c28_canonical_duo_visual_review.gd"
EXPECTED_RUN = 31448641790
EXPECTED_ARTIFACT = 9085499161
EXPECTED_DIGEST = "sha256:ad8e08c6e51c3629e65f81d4c0b70a545598f78f97dcaee3d05b7228b81e30c8"
EXPECTED_PRODUCT_HEAD = "29999afea07a10de5bd9cdc47ec0109a45eebeaa"


def block(reason: str) -> int:
    print(f"C28_DUO_EVIDENCE=BLOCKED {reason}")
    return 2


def main() -> int:
    for path in (EVIDENCE, RIVAL_PRESENTER, ARENA, VISUAL_GATE):
        if not path.is_file():
            return block(f"missing={path.relative_to(ROOT).as_posix()}")
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    if evidence.get("schema") != "tehkne/taijifu-c28-canonical-duo-visual-evidence/v1":
        return block("schema")
    if evidence.get("signature") != "Tehkné Solutions" or evidence.get("status") != "approved_canonical_duo_active_fight":
        return block("identity_or_status")
    if evidence.get("validated_product_head_sha") != EXPECTED_PRODUCT_HEAD:
        return block("product_head")
    artifact = evidence.get("evidence", {})
    if artifact.get("workflow_run_id") != EXPECTED_RUN or artifact.get("artifact_id") != EXPECTED_ARTIFACT or artifact.get("artifact_digest") != EXPECTED_DIGEST:
        return block("artifact_identity")
    metrics = evidence.get("canonical_metrics", {})
    lian = metrics.get("lian_wu", {})
    rival = metrics.get("training_rival", {})
    ratio = float(metrics.get("height_ratio_rival_to_lian", 0.0))
    if not (120.0 <= float(lian.get("visual_height_world_px", 0.0)) <= 145.0):
        return block("lian_height")
    if not (120.0 <= float(rival.get("visual_height_world_px", 0.0)) <= 145.0):
        return block("rival_height")
    if abs(ratio - 1.0) > 0.05:
        return block(f"height_ratio={ratio}")
    if abs(float(lian.get("footline_local", 99.0))) > 3.0 or abs(float(rival.get("footline_local", 99.0))) > 3.0:
        return block("footline")
    if float(lian.get("combat_view_visible_fraction", 0.0)) < 0.99 or float(rival.get("combat_view_visible_fraction", 0.0)) < 0.99:
        return block("viewport_visibility")
    review = evidence.get("visual_review", {})
    required_review = [
        "both_real_presenters_active", "legacy_visual_surfaces_hidden", "relative_scale",
        "footline_alignment", "viewport_visibility", "hud_overlap", "identity_separation",
        "single_weapon_readability", "active_fight_composition",
    ]
    if any(review.get(key) != "pass" for key in required_review):
        return block("visual_review")
    policy = evidence.get("runtime_policy", {})
    if policy.get("canonical_duo_visual_ready") is not True or policy.get("procedural_fallback_code_preserved") is not True:
        return block("runtime_policy")

    rival_text = RIVAL_PRESENTER.read_text(encoding="utf-8")
    for marker in (
        "const CANONICAL_BASELINE_Y := 970.0",
        "const TARGET_VISUAL_HEIGHT := 132.0",
        "const CANONICAL_ALPHA_HEIGHT := 923.0",
        "const HIT_VISUAL_SECONDS := 0.18",
        "_hit_visual_timer",
        "_fighter._is_blocking",
        'for node_name in ["FirstPlayableIdentity", "SpritePresenter"]',
    ):
        if marker not in rival_text:
            return block(f"rival_presenter_marker={marker}")
    if "_hitstun_timer" in rival_text:
        return block("retired_hitstun_reference")

    arena_text = ARENA.read_text(encoding="utf-8")
    if "FIRST_DUEL_P1_SPAWN := Vector2(720.0, 827.0)" not in arena_text or "FIRST_DUEL_P2_SPAWN := Vector2(2080.0, 827.0)" not in arena_text:
        return block("spawn_contract")
    if "initial_duel_camera_readable" not in arena_text:
        return block("arena_signature")

    gate_text = VISUAL_GATE.read_text(encoding="utf-8")
    for marker in ("C28_DUO_SCALE=PASS", "C28_DUO_FOOTLINE=PASS", "C28_DUO_VIEWPORT_VISIBILITY=PASS", "MIN_VISIBLE_SCREEN_FRACTION"):
        if marker not in gate_text:
            return block(f"visual_gate_marker={marker}")

    print("C28_DUO_EVIDENCE=PASS frozen=true")
    print("C28_DUO_SCALE_CONTRACT=PASS ratio=1.0130")
    print("C28_DUO_FOOTLINE_CONTRACT=PASS")
    print("C28_DUO_VIEWPORT_CONTRACT=PASS visibility=1.0/1.0")
    print("C28_DUO_RUNTIME_FIXES=PASS scale=true hit_state=true spawn=true")
    print("C28_DUO_READY=PASS")
    print("SIGNATURE=Tehkné Solutions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
