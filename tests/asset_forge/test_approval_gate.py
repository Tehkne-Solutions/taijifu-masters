from __future__ import annotations

import importlib.util
import json
from pathlib import Path

MODULE = Path(__file__).resolve().parents[2] / "tools" / "asset_forge" / "approval_gate.py"
spec = importlib.util.spec_from_file_location("approval_gate", MODULE)
mod = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(mod)


def test_approved_document_verifies(tmp_path: Path):
    checks = {name: True for name in mod.REQUIRED_CHECKS}
    data = mod.create_approval("pack_test", "Reviewer", checks)
    path = tmp_path / "approval.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    result = mod.verify(path, "pack_test")
    assert result["verified"] is True


def test_tampered_document_is_blocked(tmp_path: Path):
    checks = {name: True for name in mod.REQUIRED_CHECKS}
    data = mod.create_approval("pack_test", "Reviewer", checks)
    data["notes"] = "tampered"
    path = tmp_path / "approval.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    result = mod.verify(path, "pack_test")
    assert result["verified"] is False
    assert "invalid_signature" in result["errors"]


def test_failed_check_rejects_document(tmp_path: Path):
    checks = {name: True for name in mod.REQUIRED_CHECKS}
    checks["icons_legible"] = False
    data = mod.create_approval("pack_test", "Reviewer", checks)
    path = tmp_path / "approval.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    result = mod.verify(path, "pack_test")
    assert result["verified"] is False
