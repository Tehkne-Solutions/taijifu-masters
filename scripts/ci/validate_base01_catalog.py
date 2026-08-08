from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets" / "modular_fighters" / "base_01"
CATALOG = BASE / "catalog.json"
HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")


def load(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def fail(message: str) -> None:
    raise SystemExit(f"BASE01_CATALOG=BLOCKED {message}")


def main() -> None:
    if not CATALOG.exists():
        fail("catalog_missing")

    catalog = load(CATALOG)
    targets = catalog.get("targets", {})
    expected = {"skin_palettes": 8, "faces": 4, "eyes": 6, "brows": 6}
    if targets != expected:
        fail(f"targets={targets}")

    skins = catalog.get("skin_palettes", [])
    faces = catalog.get("faces", [])
    eyes = catalog.get("eyes", [])
    brows = catalog.get("brows", [])

    if len(skins) != 8 or len(set(skins)) != 8:
        fail("skin_palette_count_or_duplicates")
    for name, rows, count in (("faces", faces, 4), ("eyes", eyes, 6), ("brows", brows, 6)):
        ids = [row.get("id") for row in rows]
        if len(ids) != count or len(set(ids)) != count or any(not value for value in ids):
            fail(f"{name}_count_or_duplicates")

    required_channels = {"skin_base", "skin_shadow", "skin_highlight", "cheek_tint"}
    for palette_id in skins:
        path = BASE / "palettes" / f"{palette_id}.json"
        if not path.exists():
            fail(f"palette_missing={palette_id}")
        palette = load(path)
        if palette.get("schema") != "tehkne/taijifu-skin-palette/v1":
            fail(f"palette_schema={palette_id}")
        if palette.get("palette_id") != palette_id:
            fail(f"palette_id={palette_id}")
        channels = palette.get("channels", {})
        if set(channels) != required_channels:
            fail(f"palette_channels={palette_id}")
        if any(not HEX.match(value or "") for value in channels.values()):
            fail(f"palette_hex={palette_id}")
        if palette.get("signature") != "Tehkné Solutions":
            fail(f"signature={palette_id}")

    contract = catalog.get("authoring_contract", {})
    if contract.get("canvas") != [1024, 1024] or contract.get("mode") != "RGBA":
        fail("authoring_canvas_or_mode")
    if contract.get("pivot") != [0.5, 0.92] or contract.get("root_anchor") != "bottom_center":
        fail("authoring_pivot_or_anchor")
    if catalog.get("signature") != "Tehkné Solutions":
        fail("catalog_signature")

    print("BASE01_CATALOG_TARGETS=PASS skins=8 faces=4 eyes=6 brows=6")
    print("BASE01_SKIN_PALETTES=PASS count=8")
    print("BASE01_AUTHORING_CONTRACT=PASS")
    print("BASE01_CATALOG=PASS")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
