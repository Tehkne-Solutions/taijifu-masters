#!/usr/bin/env python3
"""Gera o inventário oficial do PACK 01 — Terrain Core.

Assinatura: Tehkné Solutions
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACK_DIR = ROOT / "assets" / "packs" / "pack_01_terrain_core"
OUTPUT = PACK_DIR / "inventory.json"

BASE_FAMILIES = {
    "grass": ["BASE", "LIGHT", "DARK", "DRY", "WET", "WORN", "SOFT", "SPIRIT"],
    "dirt": ["DRY", "PACKED", "WET", "CRACKED", "ROOTS"],
    "stone": ["SMOOTH", "ANCIENT", "CRACKED", "MOSS", "SPIRIT"],
    "sand": ["BASE", "FINE", "GOLDEN", "PACKED"],
    "mud": ["LIGHT", "DARK", "DEEP"],
    "snow": ["CLEAN", "TRACKED", "ICY"],
    "ice": ["BLUE", "WHITE", "CRACKED"],
    "water": ["SHALLOW", "DEEP", "CRYSTAL", "SPIRIT"],
    "corrupted": ["LEVEL_1", "LEVEL_2", "LEVEL_3"],
}

TRANSITION_PAIRS = [
    ("GRASS", "DIRT"),
    ("DIRT", "STONE"),
    ("GRASS", "WATER"),
    ("SNOW", "STONE"),
    ("ICE", "WATER"),
]
DIRECTIONS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
OVERLAYS = {
    "grass": ["FLOWERS", "LEAVES", "MOSS", "PATCH", "PETALS", "HERBS"],
    "dirt": ["PEBBLES", "ROOTS", "TRACKS", "CRACKS"],
    "stone": ["MOSS", "CRACKS", "RUNES", "DUST"],
    "water": ["RIPPLES", "LOTUS", "FOAM", "SPARKLES"],
}


def record(asset_id: str, category: str, family: str, variant: str, source: str, hd: str, mobile: str, tileable: bool) -> dict:
    return {
        "id": asset_id,
        "category": category,
        "family": family,
        "variant": variant,
        "status": "PLANNED",
        "tileable": tileable,
        "source": source,
        "runtime": {"hd": hd, "mobile": mobile},
        "pivot": {"x": 0.5, "y": 0.5},
    }


def build_assets() -> list[dict]:
    assets: list[dict] = []
    for family, variants in BASE_FAMILIES.items():
        for index, variant in enumerate(variants, 1):
            asset_id = f"TM_TERRAIN_{family.upper()}_{variant}_{index:03d}"
            assets.append(record(
                asset_id, "terrain", family, variant.lower(),
                f"master/{family}/{asset_id}.png",
                f"runtime/hd/{family}/{asset_id}.webp",
                f"runtime/mobile/{family}/{asset_id}.webp",
                True,
            ))

    for origin, target in TRANSITION_PAIRS:
        family = f"{origin.lower()}_{target.lower()}"
        for index, direction in enumerate(DIRECTIONS, 1):
            asset_id = f"TM_TRANSITION_{origin}_{target}_{direction}_{index:03d}"
            assets.append(record(
                asset_id, "transition", family, direction.lower(),
                f"transitions/master/{family}/{asset_id}.png",
                f"transitions/runtime/hd/{family}/{asset_id}.webp",
                f"transitions/runtime/mobile/{family}/{asset_id}.webp",
                True,
            ))

    for family, variants in OVERLAYS.items():
        for index, variant in enumerate(variants, 1):
            asset_id = f"TM_OVERLAY_{family.upper()}_{variant}_{index:03d}"
            assets.append(record(
                asset_id, "overlay", family, variant.lower(),
                f"overlays/master/{family}/{asset_id}.png",
                f"overlays/runtime/hd/{family}/{asset_id}.webp",
                f"overlays/runtime/mobile/{family}/{asset_id}.webp",
                False,
            ))
    return assets


def main() -> None:
    assets = build_assets()
    if len(assets) != 96:
        raise RuntimeError(f"Inventário inválido: esperado 96, obtido {len(assets)}")
    payload = {
        "pack": "PACK_01",
        "version": "0.1.0",
        "signature": "Tehkné Solutions",
        "asset_count": len(assets),
        "assets": assets,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Gerado: {OUTPUT} ({len(assets)} assets)")


if __name__ == "__main__":
    main()
