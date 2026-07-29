#!/usr/bin/env python3
"""Valida tecnicamente imagens de um pack TGAP antes da promoção visual."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image

IMAGE_EXTENSIONS = {".png", ".webp"}
DEFAULT_CANVAS = (128, 128)


def inspect_image(path: Path, expected_size: tuple[int, int], min_margin: int) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        image = Image.open(path)
        image.load()
    except Exception as exc:
        return {"path": str(path), "passed": False, "errors": [f"decode_error: {exc}"], "warnings": []}

    mode = image.mode
    size = image.size
    has_alpha = "A" in image.getbands()
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    alpha_min, alpha_max = alpha.getextrema()
    bbox = alpha.getbbox()

    if path.suffix.lower() == ".png" and mode != "RGBA":
        errors.append(f"mode_invalid:{mode}; expected RGBA")
    if not has_alpha:
        errors.append("alpha_missing")
    if alpha_min == 255:
        errors.append("transparency_missing")
    if alpha_max == 0 or bbox is None:
        errors.append("frame_empty")
    if size != expected_size:
        errors.append(f"size_invalid:{size[0]}x{size[1]}; expected {expected_size[0]}x{expected_size[1]}")

    margins = None
    pivot_candidate = None
    if bbox:
        left, top, right, bottom = bbox
        margins = {
            "left": left,
            "top": top,
            "right": size[0] - right,
            "bottom": size[1] - bottom,
        }
        if min(margins.values()) < min_margin:
            warnings.append("content_near_canvas_edge")
        pivot_candidate = [round((left + right) / 2), bottom]
        if bottom < int(size[1] * 0.70):
            warnings.append("subject_floating_above_baseline")

    return {
        "path": str(path),
        "passed": not errors,
        "format": image.format,
        "mode": mode,
        "size": list(size),
        "has_alpha": has_alpha,
        "alpha_range": [alpha_min, alpha_max],
        "content_bbox": list(bbox) if bbox else None,
        "margins": margins,
        "pivot_candidate": pivot_candidate,
        "errors": errors,
        "warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_root", type=Path)
    parser.add_argument("--width", type=int, default=DEFAULT_CANVAS[0])
    parser.add_argument("--height", type=int, default=DEFAULT_CANVAS[1])
    parser.add_argument("--min-margin", type=int, default=2)
    args = parser.parse_args()

    root = args.pack_root.resolve()
    report_dir = root / "validation"
    report_dir.mkdir(parents=True, exist_ok=True)

    candidates = sorted(
        path for path in root.rglob("*")
        if path.is_file()
        and path.suffix.lower() in IMAGE_EXTENSIONS
        and "preview" not in path.parts
        and "validation" not in path.parts
    )

    results = [inspect_image(path, (args.width, args.height), args.min_margin) for path in candidates]
    passed = sum(1 for item in results if item["passed"])
    failed = len(results) - passed
    warnings = sum(len(item["warnings"]) for item in results)

    pivot_groups: dict[str, list[list[int]]] = {}
    for item in results:
        if item.get("pivot_candidate"):
            rel = Path(item["path"]).relative_to(root)
            group = rel.parts[1] if len(rel.parts) > 2 and rel.parts[0] == "frames" else rel.parts[0]
            pivot_groups.setdefault(group, []).append(item["pivot_candidate"])

    pivot_drift: dict[str, dict[str, int]] = {}
    for group, pivots in pivot_groups.items():
        xs = [pivot[0] for pivot in pivots]
        ys = [pivot[1] for pivot in pivots]
        pivot_drift[group] = {"x": max(xs) - min(xs), "y": max(ys) - min(ys)}

    report = {
        "tgap_version": "1.0",
        "gate": "visual",
        "pack_root": str(root),
        "expected_canvas": [args.width, args.height],
        "images_checked": len(results),
        "passed": passed,
        "failed": failed,
        "warnings": warnings,
        "pivot_drift": pivot_drift,
        "promotion_blocked": failed > 0 or len(results) == 0,
        "results": results,
    }

    json_path = report_dir / "visual-gate-report.json"
    md_path = report_dir / "visual-gate-report.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Gate Visual TGAP",
        "",
        f"- Imagens verificadas: **{len(results)}**",
        f"- Aprovadas tecnicamente: **{passed}**",
        f"- Reprovadas: **{failed}**",
        f"- Alertas: **{warnings}**",
        f"- Promoção bloqueada: **{'sim' if report['promotion_blocked'] else 'não'}**",
        "",
        "## Reprovações",
        "",
    ]
    for item in results:
        if not item["passed"]:
            rel = Path(item["path"]).relative_to(root)
            lines.append(f"- `{rel}` — {', '.join(item['errors'])}")
    lines.extend(["", "## Deriva de pivô", ""])
    for group, drift in pivot_drift.items():
        lines.append(f"- `{group}` — x: {drift['x']} px; y: {drift['y']} px")
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(json.dumps({key: report[key] for key in ("images_checked", "passed", "failed", "warnings", "promotion_blocked")}, ensure_ascii=False))
    return 1 if report["promotion_blocked"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
