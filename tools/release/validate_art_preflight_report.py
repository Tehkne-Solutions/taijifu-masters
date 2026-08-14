#!/usr/bin/env python3
"""Valida o relatório de produção artística do First Playable.

O baseline canônico atual é 45 frames de Lian Wu + 44 do Training Rival.
Schemas históricos continuam legíveis em modo informativo, mas não satisfazem
uma release strict se não alcançarem o baseline 89/89.

Assinatura: Tehkné Solutions
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

EXPECTED_TOTAL = 89
EXPECTED_FIGHTERS = {"lian_wu": 45, "training_rival": 44}
EXPECTED_SIGNATURE = "Tehkné Solutions"
EXPECTED_V3_GATE = "taijifu-first-playable-art-preflight-v3"


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


def _extract_counts(payload: dict[str, Any]) -> tuple[int, dict[str, int], bool, str]:
    # Schema canônico v3 do Asset Vault.
    characters_raw = payload.get("characters")
    if isinstance(payload.get("present_total"), int) and isinstance(characters_raw, list):
        counts: dict[str, int] = {}
        complete: dict[str, bool] = {}
        for item in characters_raw:
            if not isinstance(item, dict):
                continue
            fighter_id = item.get("character")
            if fighter_id not in EXPECTED_FIGHTERS:
                continue
            frames = item.get("frames")
            if not isinstance(frames, int):
                raise ValueError(f"Contagem inválida para {fighter_id}")
            counts[str(fighter_id)] = frames
            complete[str(fighter_id)] = item.get("complete") is True
        for fighter_id in EXPECTED_FIGHTERS:
            if fighter_id not in counts:
                raise ValueError(f"Lutador ausente no relatório: {fighter_id}")
        ready = payload.get("ready") is True and all(complete.get(fid, False) for fid in EXPECTED_FIGHTERS)
        return int(payload["present_total"]), counts, ready, "v3"

    # Schema v2 histórico do repositório de assets.
    if isinstance(payload.get("present_total"), int) and isinstance(payload.get("counts"), dict):
        total = int(payload["present_total"])
        counts_raw = payload["counts"]
        counts: dict[str, int] = {}
        for fighter_id in EXPECTED_FIGHTERS:
            present = counts_raw.get(fighter_id)
            if not isinstance(present, int):
                raise ValueError(f"Contagem inválida para {fighter_id}")
            counts[fighter_id] = present
        return total, counts, payload.get("passed") is True, "v2"

    # Schema legado usado pelo jogo antes do Asset Vault v2.
    total = payload.get("total_present")
    fighters_raw = payload.get("fighters")
    if not isinstance(total, int):
        raise ValueError("Campo present_total/total_present ausente ou inválido")
    if not isinstance(fighters_raw, dict):
        raise ValueError("Campo characters/counts/fighters ausente ou inválido")

    counts = {}
    for fighter_id in EXPECTED_FIGHTERS:
        fighter = fighters_raw.get(fighter_id)
        if not isinstance(fighter, dict):
            raise ValueError(f"Lutador ausente no relatório: {fighter_id}")
        present = fighter.get("present")
        if not isinstance(present, int):
            raise ValueError(f"Contagem inválida para {fighter_id}")
        counts[fighter_id] = present
    return int(total), counts, payload.get("passed") is True, "legacy"


def validate(payload: dict[str, Any], *, strict: bool) -> list[str]:
    errors: list[str] = []
    if payload.get("signature") != EXPECTED_SIGNATURE:
        errors.append("assinatura inválida")

    try:
        total, counts, preflight_ready, schema_family = _extract_counts(payload)
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

    if strict and not preflight_ready:
        errors.append("preflight artístico não aprovado")

    if strict:
        if schema_family != "v3":
            errors.append(f"schema histórico não autorizado para release strict: {schema_family}")
        if payload.get("gate_id") != EXPECTED_V3_GATE:
            errors.append("gate_id v3 ausente ou inválido")
        if payload.get("expected_total") != EXPECTED_TOTAL:
            errors.append("expected_total v3 ausente ou inválido")

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
        payload = {}
        errors = [str(exc)]

    if errors:
        print("ART_PREFLIGHT_REPORT_BLOCKED")
        for error in errors:
            print(f"- {error}")
        return 1

    total, counts, _ready, schema_family = _extract_counts(payload)
    print("ART_PREFLIGHT_REPORT_OK")
    print(f"- schema: {schema_family}")
    print(f"- lian_wu: {counts['lian_wu']}/{EXPECTED_FIGHTERS['lian_wu']}")
    print(f"- training_rival: {counts['training_rival']}/{EXPECTED_FIGHTERS['training_rival']}")
    print(f"- total: {total}/{EXPECTED_TOTAL}")
    if total != EXPECTED_TOTAL:
        print("- estado: incompleto, permitido apenas no modo informativo")
    print("- signature: Tehkné Solutions")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
