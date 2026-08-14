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


def test_current_repository_has_canonical_89_frame_visual_runtime() -> None:
    report = _load_module().audit()

    assert report["schema"] == "tehkne/taijifu-first-playable-visual-audit/v2"
    assert report["signature"] == "Tehkné Solutions"
    assert report["scene"] == "scenes/vertical_slice/first_playable.tscn"
    assert report["fighters"]["lian_wu"]["expected"] == 45
    assert report["fighters"]["lian_wu"]["present"] == 45
    assert report["fighters"]["lian_wu"]["spriteframe_references"] == 45
    assert report["fighters"]["lian_wu"]["ready"] is True
    assert report["fighters"]["training_rival"]["expected"] == 44
    assert report["fighters"]["training_rival"]["present"] == 44
    assert report["fighters"]["training_rival"]["spriteframe_references"] == 44
    assert report["fighters"]["training_rival"]["ready"] is True
    assert report["fighters"]["total_expected"] == 89
    assert report["fighters"]["total_present"] == 89
    assert report["visual_release_ready"] is True
    assert report["blockers"] == []


def test_visual_release_uses_real_presenters_without_procedural_renderer() -> None:
    report = _load_module().audit()

    assert report["runtime"]["real_presenter_handoff"] is True
    assert report["runtime"]["presenter_scripts_ready"] is True
    assert report["runtime"]["procedural_character_renderer"] is False
    assert report["visual_release_ready"] is True


# Tehkné Solutions
