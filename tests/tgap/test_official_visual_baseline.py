from __future__ import annotations

import importlib.util
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/tgap_official_visual_baseline.py"


def load_module():
    spec = importlib.util.spec_from_file_location("baseline", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_registered_official_pack_is_lian_wu() -> None:
    registry = json.loads((REPO / "tgap-registry.json").read_text(encoding="utf-8"))
    ids = [item["pack_id"] for item in registry["packs"]]
    assert "pack_01_lian_wu" in ids


def test_manifest_declares_deterministic_visual_identity() -> None:
    manifest = json.loads((REPO / "assets/tgap/pack_01_lian_wu/manifest.json").read_text(encoding="utf-8"))
    visual = manifest["visual_identity"]
    assert visual["frame_size"] == [128, 128]
    assert visual["pivot"] == [64, 120]
    assert visual["signature_color"] == "#1769C2"
    assert manifest["runtime"]["spriteframes"].endswith(".tres")


def test_sha256_changes_with_content(tmp_path: Path) -> None:
    module = load_module()
    target = tmp_path / "fixture.bin"
    target.write_bytes(b"taijifu-official-baseline")
    first = module.sha256(target)
    assert first == module.sha256(target)
    target.write_bytes(b"taijifu-official-baseline-v2")
    assert first != module.sha256(target)
