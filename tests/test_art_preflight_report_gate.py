from __future__ import annotations

import importlib.util
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools/release/validate_art_preflight_report.py"
spec = importlib.util.spec_from_file_location("validate_art_preflight_report", MODULE_PATH)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def payload(lian: int, rival: int, passed: bool) -> dict:
    return {
        "signature": "Tehkné Solutions",
        "total_present": lian + rival,
        "fighters": {
            "lian_wu": {"present": lian},
            "training_rival": {"present": rival},
        },
        "passed": passed,
    }


def test_informative_mode_accepts_zero_of_eighty_eight() -> None:
    assert module.validate(payload(0, 0, False), strict=False) == []


def test_strict_mode_blocks_incomplete_production() -> None:
    errors = module.validate(payload(44, 0, False), strict=True)
    assert any("training_rival incompleto" in error for error in errors)
    assert any("produção incompleta" in error for error in errors)


def test_strict_mode_accepts_full_approved_production() -> None:
    assert module.validate(payload(44, 44, True), strict=True) == []


def test_rejects_invalid_signature() -> None:
    data = payload(44, 44, True)
    data["signature"] = "Outra empresa"
    assert "assinatura inválida" in module.validate(data, strict=True)


def test_rejects_divergent_total() -> None:
    data = payload(44, 44, True)
    data["total_present"] = 87
    assert "total_present diverge da soma por lutador" in module.validate(data, strict=True)


# Tehkné Solutions
