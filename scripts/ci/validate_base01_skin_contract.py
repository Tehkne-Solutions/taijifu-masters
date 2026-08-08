#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/modular_fighters/base_01"
CONFIG = ROOT / "config/fighter-modules/base_01_faces_skin_v1.json"
CATALOG = BASE / "catalog.json"
CONTRACT = BASE / "production/BASE01_SKIN_PALETTES.json"
PALETTES = BASE / "palettes"

EXPECTED_IDS = [
    "skin_tone_01_porcelain",
    "skin_tone_02_light_neutral",
    "skin_tone_03_warm",
    "skin_tone_04_olive",
    "skin_tone_05_tan",
    "skin_tone_06_brown",
    "skin_tone_07_deep",
    "skin_tone_08_ebony",
]
CHANNELS = ["skin_base", "skin_shadow", "skin_highlight", "cheek_tint"]
HEX = re.compile(r"^#[0-9A-F]{6}$")
SIGNATURE = "Tehkné Solutions"


def load(path: Path):
    if not path.is_file():
        raise SystemExit(f"C62_0_SKIN_CONTRACT=BLOCKED missing={path.relative_to(ROOT)}")
    return json.loads(path.read_text(encoding="utf-8"))


def fail(reason: str):
    raise SystemExit(f"C62_0_SKIN_CONTRACT=BLOCKED {reason}")


def main() -> int:
    config = load(CONFIG)
    catalog = load(CATALOG)
    contract = load(CONTRACT)

    config_ids = config.get("skin_system", {}).get("initial_tone_ids")
    catalog_ids = catalog.get("skin_palettes")
    contract_ids = contract.get("palette_ids")
    if config_ids != EXPECTED_IDS:
        fail(f"config_ids={config_ids}")
    if catalog_ids != EXPECTED_IDS:
        fail(f"catalog_ids={catalog_ids}")
    if contract_ids != EXPECTED_IDS:
        fail(f"contract_ids={contract_ids}")

    skin_system = config.get("skin_system", {})
    if skin_system.get("implementation") != "palette_driven_base_tint":
        fail("implementation_mismatch")
    if skin_system.get("full_body_duplicate_png_per_tone_allowed") is not False:
        fail("duplicate_body_png_allowed")
    if skin_system.get("palette_channels") != CHANNELS:
        fail("config_channel_contract_mismatch")
    if config.get("required_default_ids", {}).get("skin") != "skin_tone_03_warm":
        fail("default_skin_mismatch")

    if contract.get("signature") != SIGNATURE:
        fail("contract_signature")
    if contract.get("implementation") != "palette_driven_base_tint":
        fail("contract_implementation")
    if contract.get("duplicate_body_png_per_tone") is not False:
        fail("contract_duplicate_body_png")
    if contract.get("palette_channels") != CHANNELS:
        fail("contract_channels")
    if contract.get("default_palette") != "skin_tone_03_warm":
        fail("contract_default_palette")

    tuples = set()
    for palette_id in EXPECTED_IDS:
        path = PALETTES / f"{palette_id}.json"
        data = load(path)
        if data.get("schema") != "tehkne/taijifu-skin-palette/v1":
            fail(f"schema={palette_id}")
        if data.get("signature") != SIGNATURE:
            fail(f"signature={palette_id}")
        if data.get("palette_id") != palette_id:
            fail(f"palette_id={palette_id}:{data.get('palette_id')}")
        if data.get("source_base_body") != "base_fighter_v1":
            fail(f"source_base_body={palette_id}")
        if data.get("application") != "palette_driven_base_tint":
            fail(f"application={palette_id}")
        if data.get("preserve_linework") is not True or data.get("preserve_shading_structure") is not True:
            fail(f"preservation={palette_id}")
        channels = data.get("channels", {})
        if list(channels.keys()) != CHANNELS:
            fail(f"channels={palette_id}:{list(channels.keys())}")
        values = tuple(channels[key] for key in CHANNELS)
        for value in values:
            if not isinstance(value, str) or not HEX.fullmatch(value):
                fail(f"invalid_hex={palette_id}:{value}")
        if values in tuples:
            fail(f"duplicate_palette_channels={palette_id}")
        tuples.add(values)
        print(f"C62_0_PALETTE=PASS id={palette_id} base={channels['skin_base']}")

    if len(tuples) != 8:
        fail(f"unique_palettes={len(tuples)}")

    print("C62_0_SKIN_IDS_RECONCILED=PASS contract=catalog=config=8")
    print("C62_0_SKIN_PALETTE_FILES=PASS palettes=8 channels=4")
    print("C62_0_DUPLICATE_BODY_PNG_POLICY=PASS allowed=false")
    print("C62_0_SKIN_CONTRACT=PASS")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
