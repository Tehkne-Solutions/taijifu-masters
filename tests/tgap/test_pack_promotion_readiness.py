from __future__ import annotations

import importlib.util
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/tgap_pack_promotion_readiness.py"


def load_module():
    spec = importlib.util.spec_from_file_location("promotion_readiness", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_pack01_inventory_formula_matches_closed_inventory() -> None:
    module = load_module()
    root = REPO / "assets/tgap/pack_01_lian_wu"
    expected = json.loads((root / "expected-assets.json").read_text(encoding="utf-8"))
    paths = module.expected_paths(root, expected)
    assert len(list(dict.fromkeys(paths))) == 163
    assert expected["summary"]["total_expected"] == 163


def test_pack01_cannot_be_promoted_without_all_gates() -> None:
    module = load_module()
    registry = json.loads((REPO / "tgap-registry.json").read_text(encoding="utf-8"))
    entry = next(item for item in registry["packs"] if item["pack_id"] == "pack_01_lian_wu")
    result = module.inspect_pack(REPO, entry)
    assert result["pack_id"] == "pack_01_lian_wu"
    assert result["ready"] is False
    assert result["promotion_transition_allowed"] is False
    assert set(result["failed_gates"]).issubset(set(module.REQUIRED_PROMOTION_GATES))


def test_missing_evidence_defaults_every_gate_to_false(tmp_path: Path) -> None:
    module = load_module()
    gates = module.read_gate_evidence(tmp_path)
    assert set(gates) == set(module.REQUIRED_PROMOTION_GATES)
    assert not any(gates.values())


def test_evidence_never_overrides_inventory_truth(tmp_path: Path) -> None:
    module = load_module()
    (tmp_path / "promotion-evidence.json").write_text(
        json.dumps({"gates": {gate: True for gate in module.REQUIRED_PROMOTION_GATES}}),
        encoding="utf-8",
    )
    gates = module.read_gate_evidence(tmp_path)
    assert all(gates.values())
    # inspect_pack recalcula presença e hashes; evidência não pode fabricar arquivos.
