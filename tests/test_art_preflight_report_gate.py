from __future__ import annotations

import importlib.util
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools/release/validate_art_preflight_report.py"
spec = importlib.util.spec_from_file_location("validate_art_preflight_report", MODULE_PATH)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def legacy_payload(lian: int, rival: int, passed: bool) -> dict:
    return {
        "signature": "Tehkné Solutions",
        "total_present": lian + rival,
        "fighters": {
            "lian_wu": {"present": lian},
            "training_rival": {"present": rival},
        },
        "passed": passed,
    }


def v3_payload(lian: int, rival: int, ready: bool) -> dict:
    return {
        "gate_id": "taijifu-first-playable-art-preflight-v3",
        "signature": "Tehkné Solutions",
        "expected_total": 89,
        "present_total": lian + rival,
        "ready": ready,
        "characters": [
            {
                "character": "lian_wu",
                "frames": lian,
                "expected_frames": 45,
                "animations": 10 if lian == 45 else 0,
                "expected_animations": 10,
                "errors": [],
                "complete": ready and lian == 45,
            },
            {
                "character": "training_rival",
                "frames": rival,
                "expected_frames": 44,
                "animations": 10 if rival == 44 else 0,
                "expected_animations": 10,
                "errors": [],
                "complete": ready and rival == 44,
            },
        ],
    }


def test_informative_mode_keeps_historical_schema_readable() -> None:
    assert module.validate(legacy_payload(0, 0, False), strict=False) == []


def test_strict_mode_blocks_incomplete_v3_production() -> None:
    errors = module.validate(v3_payload(45, 0, False), strict=True)
    assert any("training_rival incompleto" in error for error in errors)
    assert any("produção incompleta" in error for error in errors)
    assert any("preflight artístico não aprovado" in error for error in errors)


def test_strict_mode_accepts_full_approved_v3_production() -> None:
    assert module.validate(v3_payload(45, 44, True), strict=True) == []


def test_strict_mode_rejects_historical_44_44_even_if_marked_passed() -> None:
    errors = module.validate(legacy_payload(44, 44, True), strict=True)
    assert any("lian_wu incompleto" in error for error in errors)
    assert any("produção incompleta" in error for error in errors)
    assert any("schema histórico" in error for error in errors)


def test_rejects_invalid_signature() -> None:
    data = v3_payload(45, 44, True)
    data["signature"] = "Outra empresa"
    assert "assinatura inválida" in module.validate(data, strict=True)


def test_rejects_divergent_total() -> None:
    data = v3_payload(45, 44, True)
    data["present_total"] = 88
    assert "contagem total diverge da soma por lutador" in module.validate(data, strict=True)


# Tehkné Solutions
