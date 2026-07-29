from __future__ import annotations

import importlib.util
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/tgap_pack_production_batches.py"


def load_module():
    spec = importlib.util.spec_from_file_location("production_batches", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_classification_is_deterministic() -> None:
    module = load_module()
    assert module.classify("source/char_lian_wu__master.png") == "master_and_identity"
    assert module.classify("frames/idle/char_lian_wu__idle__f01.png") == "core_movement"
    assert module.classify("frames/attack_light_01/char_lian_wu__attack_light_01__f01.png") == "core_combat"
    assert module.classify("frames/death/char_lian_wu__death__f01.png") == "advanced_combat"
    assert module.classify("vfx/water_dragon/vfx_lian_wu__water_dragon__f01.png") == "vfx"
    assert module.classify("runtime/lian_wu_spriteframes.tres") == "runtime_and_atlas"
    assert module.classify("preview/pack01_lian_wu_preview.png") == "validation_and_preview"


def test_plan_preserves_missing_total() -> None:
    module = load_module()
    pack = {
        "pack_id": "pack_01_lian_wu",
        "expected_total": 4,
        "present_total": 1,
        "missing_total": 3,
        "empty_total": 0,
        "missing": [
            "source/char_lian_wu__master.png",
            "frames/idle/char_lian_wu__idle__f01.png",
            "runtime/lian_wu_spriteframes.tres",
        ],
    }
    plan = module.build_plan(pack)
    assert sum(batch["missing_total"] for batch in plan["batches"]) == 3
    assert plan["next_batch"] == "master_and_identity"
    assert plan["production_complete"] is False


def test_empty_pack_is_complete() -> None:
    module = load_module()
    plan = module.build_plan({
        "pack_id": "pack_01_lian_wu",
        "expected_total": 163,
        "present_total": 163,
        "missing_total": 0,
        "empty_total": 0,
        "missing": [],
    })
    assert plan["production_complete"] is True
    assert plan["next_batch"] is None
