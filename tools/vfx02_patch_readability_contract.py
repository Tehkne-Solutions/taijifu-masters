#!/usr/bin/env python3
from pathlib import Path

IMPACT = Path("scripts/runtime/impact_director.gd")
VFX01_BENCH = Path("scripts/ci/vfx01_presentation_owner_bench.gd")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"VFX02_PATCH=BLOCKED {label} count={count}")
    return text.replace(old, new, 1)


def patch_impact() -> None:
    text = IMPACT.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "const CONNECT_INTERVAL := 0.35\nconst MAX_BURSTS := 26\n",
        "const CONNECT_INTERVAL := 0.35\nconst MAX_BURSTS := 26\nconst IMPACT_LENGTH_BASE := 28.0\nconst IMPACT_LENGTH_INTENSITY := 42.0\nconst IMPACT_LENGTH_PROGRESS := 12.0\nconst ELEMENT_RADIUS_BASE := 18.0\nconst ELEMENT_RADIUS_INTENSITY := 24.0\nconst ELEMENT_RADIUS_PROGRESS := 16.0\nconst MAX_PHYSICAL_IMPACT_EXTENT := IMPACT_LENGTH_BASE + IMPACT_LENGTH_INTENSITY + IMPACT_LENGTH_PROGRESS\nconst MAX_ELEMENT_RADIUS := ELEMENT_RADIUS_BASE + ELEMENT_RADIUS_INTENSITY + ELEMENT_RADIUS_PROGRESS\nconst MAX_HITSTOP_SECONDS := 0.105\n",
        "readability_constants",
    )
    text = replace_once(
        text,
        "\tvar length := 28.0 + intensity * 42.0 + progress * 12.0\n",
        "\tvar length := IMPACT_LENGTH_BASE + intensity * IMPACT_LENGTH_INTENSITY + progress * IMPACT_LENGTH_PROGRESS\n",
        "impact_length_formula",
    )
    text = replace_once(
        text,
        "\tvar radius := 18.0 + intensity * 24.0 + progress * 16.0\n",
        "\tvar radius := ELEMENT_RADIUS_BASE + intensity * ELEMENT_RADIUS_INTENSITY + progress * ELEMENT_RADIUS_PROGRESS\n",
        "element_radius_formula",
    )
    text = replace_once(
        text,
        'if result_id == &"posture_break": return [0.105, 0.055]',
        'if result_id == &"posture_break": return [MAX_HITSTOP_SECONDS, 0.055]',
        "max_hitstop_constant",
    )
    text = replace_once(text, '"stage": "VFX-01",', '"stage": "VFX-02",', "stage")
    text = replace_once(
        text,
        '\t\t"world_space_impact_shapes": true,\n',
        '\t\t"world_space_impact_shapes": true,\n\t\t"canonical_impact_readability_contract": true,\n\t\t"max_physical_impact_extent_world": MAX_PHYSICAL_IMPACT_EXTENT,\n\t\t"max_element_radius_world": MAX_ELEMENT_RADIUS,\n\t\t"max_hitstop_seconds": MAX_HITSTOP_SECONDS,\n\t\t"max_bursts": MAX_BURSTS,\n',
        "signature_readability",
    )
    IMPACT.write_text(text, encoding="utf-8")


def patch_vfx01_bench() -> None:
    text = VFX01_BENCH.read_text(encoding="utf-8")
    text = replace_once(
        text,
        '\tif String(impact_signature.get("stage", "")) != "VFX-01":\n\t\t_fail("VFX01_PRESENTATION_OWNER=BLOCKED impact_stage", battle)\n\t\treturn\n',
        '\tvar impact_stage := String(impact_signature.get("stage", ""))\n\tif not impact_stage.begins_with("VFX-") or impact_stage.trim_prefix("VFX-").to_int() < 1:\n\t\t_fail("VFX01_PRESENTATION_OWNER=BLOCKED impact_stage=%s" % impact_stage, battle)\n\t\treturn\n',
        "vfx01_cumulative_stage",
    )
    text = replace_once(
        text,
        'print("VFX01_PRESENTATION_OWNER=PASS")',
        'print("VFX01_PRESENTATION_OWNER=PASS stage=%s" % impact_stage)',
        "vfx01_stage_report",
    )
    VFX01_BENCH.write_text(text, encoding="utf-8")


def main() -> None:
    patch_impact()
    patch_vfx01_bench()
    print("VFX02_PATCH=PASS")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
