#!/usr/bin/env python3
"""Valida estrutura, nomes e dimensões do PACK 01.

Assinatura: Tehkné Solutions
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit("Instale Pillow para validar imagens: python -m pip install Pillow") from exc

ROOT = Path(__file__).resolve().parents[1]
PACK_DIR = ROOT / "assets" / "packs" / "pack_01_terrain_core"
INVENTORY = PACK_DIR / "inventory.json"
NAME_PATTERN = re.compile(r"^TM_(TERRAIN|TRANSITION|OVERLAY)_[A-Z0-9_]+_[0-9]{3}$")
EXPECTED = {"source": (1024, 1024), "hd": (512, 512), "mobile": (256, 256)}


def validate_image(path: Path, expected_size: tuple[int, int], require_alpha: bool) -> list[str]:
    errors: list[str] = []
    if not path.exists():
        return [f"arquivo ausente: {path.relative_to(ROOT)}"]
    try:
        with Image.open(path) as image:
            if image.size != expected_size:
                errors.append(f"dimensão inválida em {path.name}: {image.size}, esperado {expected_size}")
            if require_alpha and "A" not in image.mode:
                errors.append(f"canal alpha ausente em {path.name}")
    except Exception as exc:
        errors.append(f"imagem ilegível {path.name}: {exc}")
    return errors


def main() -> int:
    if not INVENTORY.exists():
        print("ERRO: inventory.json ausente")
        return 1

    payload = json.loads(INVENTORY.read_text(encoding="utf-8"))
    assets = payload.get("assets", [])
    errors: list[str] = []

    if payload.get("signature") != "Tehkné Solutions":
        errors.append("assinatura inválida")
    if payload.get("asset_count") != 96 or len(assets) != 96:
        errors.append(f"inventário incompleto: declarado={payload.get('asset_count')} real={len(assets)} esperado=96")

    seen: set[str] = set()
    for asset in assets:
        asset_id = asset.get("id", "")
        if not NAME_PATTERN.match(asset_id):
            errors.append(f"nome inválido: {asset_id}")
        if asset_id in seen:
            errors.append(f"id duplicado: {asset_id}")
        seen.add(asset_id)

        source = PACK_DIR / asset.get("source", "")
        hd = PACK_DIR / asset.get("runtime", {}).get("hd", "")
        mobile = PACK_DIR / asset.get("runtime", {}).get("mobile", "")
        errors.extend(validate_image(source, EXPECTED["source"], True))
        errors.extend(validate_image(hd, EXPECTED["hd"], asset.get("category") == "overlay"))
        errors.extend(validate_image(mobile, EXPECTED["mobile"], asset.get("category") == "overlay"))

    if errors:
        print(f"PACK 01 REPROVADO — {len(errors)} erro(s)")
        for error in errors:
            print(f"- {error}")
        return 1

    print("PACK 01 VALIDADO — 96 assets individuais encontrados")
    return 0


if __name__ == "__main__":
    sys.exit(main())
