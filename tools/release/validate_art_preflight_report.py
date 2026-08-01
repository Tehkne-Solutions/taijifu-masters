#!/usr/bin/env python3
"""Valida o relatório de produção artística do First Playable.

Assinatura: Tehkné Solutions
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

EXPECTED_TOTAL = 88
EXPECTED_FIGHTERS = {"lian_wu": 44, "training_rival": 44}
EXPECTED_SIGNATURE = "Tehkné Solutions"


def _read_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"Relatório ausente: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"JSON inválido: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError("O relatório deve ser um objeto JSON")
    return payload


def _extract_counts(payload: dict[str, Any]) -> tuple[int, dict[str, int]]:
    # Schema atual do repositório de assets (art-preflight-v2).
    if isinstance(payload.get("present_total"), int) and isinstance(payload.get("counts"), dict):
        total = int(payload["present_total"])
        counts_raw = payload["counts"]
        counts: dict[str, int] = {}
        for fighter_id in EXPECTED_FIGHTERS:
            present = counts_raw.get(fighter_id)
            if not isinstance(present, int):
                raise ValueError(f"Contagem inválida para {fighter_id}")
            counts[fighter_id] = present
        return total, counts

    # Compatibilidade com o schema legado usado pelo jogo antes do v2.
    total = payload.get("total_present")
    fighters_raw = payload.get("fighters")
    if not isinstance(total, int):
        raise ValueError("Campo present_total/total_present ausente ou inválido")
    if not isinstance(fighters_raw, dict):
        raise ValueError("Campo counts/fighters ausente ou inválido")

    counts = {}
    for fighter_id in EXPECTED_FIGHTERS:
        fighter = fighters_raw.get(fighter_id)
        if not isinstance(fighter, dict):
            raise ValueError(f"Lutador ausente no relatório: {fighter_id}")
        present = fighter.get("present")
        if not isinstance(present, int):
            raise ValueError(f"Contagem inválida para {fighter_id}")
        counts[fighter_id] = present
    return int(total), counts


def validate(payload: dict[str, Any], *, strict: bool) -> list[str]:
    errors: list[str] = []
    if payload.get("signature") != EXPECTED_SIGNATURE:
        errors.append("assinatura inválida")

    try:
        total, counts = _extract_counts(payload)
    except ValueError as exc:
        return [str(exc)]

    if total != sum(counts.values()):
        errors.append("contagem total diverge da soma por lutador")

    for fighter_id, expected in EXPECTED_FIGHTERS.items():
        present = counts[fighter_id]
        if present < 0 or present > expected:
            errors.append(f"contagem fora do intervalo para {fighter_id}: {present}/{expected}")
        if strict and present != expected:
            errors.append(f"{fighter_id} incompleto: {present}/{expected}")

    if strict and total != EXPECTED_TOTAL:
        errors.append(f"produção incompleta: {total}/{EXPECTED_TOTAL}")

    # No modo informativo, o produtor pode aprovar tecnicamente um relatório
    # incompleto com --allow-incomplete. Em modo estrito, arte incompleta ou
    # preflight não aprovado continua bloqueando a release.
    if strict and payload.get("passed") is not True:
        errors.append("preflight artístico não aprovado")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    try:
        payload = _read_json(args.report)
        errors = validate(payload, strict=args.strict)
    except ValueError as exc:
        errors = [str(exc)]

    if errors:
        print("ART_PREFLIGHT_REPORT_BLOCKED")
        for error in errors:
            print(f"- {error}")
        return 1

    total, counts = _extract_counts(payload)
    print("ART_PREFLIGHT_REPORT_OK")
    print(f"- lian_wu: {counts['lian_wu']}/44")
    print(f"- training_rival: {counts['training_rival']}/44")
    print(f"- total: {total}/88")
    if total != EXPECTED_TOTAL:
        print("- estado: incompleto, permitido apenas no modo informativo")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
