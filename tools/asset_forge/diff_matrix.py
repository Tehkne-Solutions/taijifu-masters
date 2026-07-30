#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageOps


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    fitted = ImageOps.contain(image.convert("RGBA"), size)
    canvas.alpha_composite(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas


def main() -> int:
    parser = argparse.ArgumentParser(description="Taijifu Asset Forge visual diff matrix")
    parser.add_argument("config", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    config = json.loads(args.config.read_text(encoding="utf-8"))
    cell = tuple(config.get("cell_size", [512, 512]))
    comparisons = config["comparisons"]
    missing: list[str] = []
    rows: list[Image.Image] = []
    results: list[dict] = []

    for item in comparisons:
        left_path, right_path = Path(item["left"]), Path(item["right"])
        if not left_path.exists() or not right_path.exists():
            missing.extend(str(p) for p in (left_path, right_path) if not p.exists())
            results.append({"id": item["id"], "ok": False, "reason": "missing_asset"})
            continue
        left, right = fit(Image.open(left_path), cell), fit(Image.open(right_path), cell)
        difference = ImageChops.difference(left, right)
        row = Image.new("RGBA", (cell[0] * 3, cell[1] + 42), (20, 20, 24, 255))
        row.alpha_composite(left, (0, 42))
        row.alpha_composite(right, (cell[0], 42))
        row.alpha_composite(difference, (cell[0] * 2, 42))
        ImageDraw.Draw(row).text((12, 12), f"{item['id']} | original A | original B | diferença", fill="white")
        rows.append(row)
        results.append({"id": item["id"], "ok": True})

    output = Path(config["output"])
    if rows:
        matrix = Image.new("RGBA", (rows[0].width, sum(row.height for row in rows)), (20, 20, 24, 255))
        y = 0
        for row in rows:
            matrix.alpha_composite(row, (0, y))
            y += row.height
        output.parent.mkdir(parents=True, exist_ok=True)
        matrix.save(output)

    report = {
        "schema": "taijifu/asset-forge-diff-matrix-report/v1",
        "pack_id": config["pack_id"],
        "ready": not missing and len(results) == len(comparisons),
        "missing": sorted(set(missing)),
        "comparisons": results,
        "output": str(output) if rows else None,
    }
    report_path = Path(config["report"])
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["ready"] or not args.strict else 12


if __name__ == "__main__":
    raise SystemExit(main())
