from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/asset_forge/audit_first_playable_visuals.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("audit_first_playable_visuals", MODULE_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_current_repository_is_explicitly_blocked_for_visual_release() -> None:
    report = _load_module().audit()

    assert report["schema"] == "tehkne/taijifu-first-playable-visual-audit/v1"
    assert report["signature"] == "Tehkné Solutions"
    assert report["scene"] == "scenes/vertical_slice/first_playable.tscn"
    assert report["pack_01"]["expected"] == 163
    assert report["pack_01"]["present"] == 0
    assert report["pack_01"]["promotion_blocked"] is True
    assert report["runtime"]["procedural_lian_wu"] is True
    assert report["runtime"]["procedural_training_rival"] is True
    assert report["visual_release_ready"] is False
    assert report["blockers"]


def test_visual_release_requires_pack_and_runtime_gates() -> None:
    report = _load_module().audit()

    assert report["pack_01"]["ready"] is False
    assert report["runtime"]["procedural_runtime_active"] is True
