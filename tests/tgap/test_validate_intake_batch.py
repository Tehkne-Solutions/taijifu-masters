from __future__ import annotations

import importlib.util
import json
import struct
import zlib
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/tgap_validate_intake_batch.py"
CONTRACT = REPO / "assets/tgap/pack_01_lian_wu/intake/master-and-identity.json"


def load_module():
    spec = importlib.util.spec_from_file_location("intake", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def png(width: int, height: int, color_type: int = 6) -> bytes:
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    chunk = struct.pack(">I", len(ihdr)) + b"IHDR" + ihdr
    chunk += struct.pack(">I", zlib.crc32(b"IHDR" + ihdr) & 0xFFFFFFFF)
    return signature + chunk + b"\x00\x00\x00\x00IEND\xaeB`\x82"


def test_contract_has_six_real_outputs() -> None:
    data = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert data["batch_id"] == "master_and_identity"
    assert len(data["required"]) == 6
    assert all(item["path"].endswith(".png") for item in data["required"])


def test_png_reader_detects_dimensions_and_alpha(tmp_path: Path) -> None:
    module = load_module()
    target = tmp_path / "asset.png"
    target.write_bytes(png(128, 256, 6))
    assert module.png_info(target) == (128, 256, True)
