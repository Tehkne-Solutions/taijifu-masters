#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

SCHEMA = "taijifu/asset-budget-report/v1"
EXIT_INVALID = 16
EXIT_EXCEEDED = 17


def image_stats(root: Path) -> dict:
    files = []
    total_bytes = 0
    estimated_rgba_bytes = 0
    max_width = 0
    max_height = 0
    for path in sorted(root.rglob("*.png")) if root.exists() else []:
        size = path.stat().st_size
        total_bytes += size
        try:
            with Image.open(path) as image:
                width, height = image.size
        except Exception:
            width = height = 0
        estimated_rgba_bytes += width * height * 4
        max_width = max(max_width, width)
        max_height = max(max_height, height)
        files.append({"path": str(path), "bytes": size, "width": width, "height": height})
    return {
        "files": files,
        "file_count": len(files),
        "total_bytes": total_bytes,
        "estimated_rgba_bytes": estimated_rgba_bytes,
        "max_width": max_width,
        "max_height": max_height,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a Taijifu character asset budget")
    parser.add_argument("dna", type=Path)
    parser.add_argument("--root", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    try:
        dna = json.loads(args.dna.read_text(encoding="utf-8"))
        budget = dna["asset_budget"]
        pack_id = dna["pack_id"]
    except Exception as exc:
        print(json.dumps({"schema": SCHEMA, "ok": False, "error": str(exc)}, ensure_ascii=False))
        return EXIT_INVALID

    root = args.root or Path("assets/tgap") / pack_id
    stats = image_stats(root)
    limits = {
        "max_png_files": int(budget["max_png_files"]),
        "max_disk_bytes": int(budget["max_disk_mb"] * 1024 * 1024),
        "max_estimated_rgba_bytes": int(budget["max_runtime_memory_mb"] * 1024 * 1024),
        "max_dimension": int(budget["max_dimension"]),
        "max_frames": int(budget["max_frames"]),
        "max_draw_calls": int(budget["max_draw_calls"]),
    }
    measured_frames = stats["file_count"]
    measured_draw_calls = int(budget.get("estimated_draw_calls", 1))
    violations = []
    checks = {
        "png_files": (stats["file_count"], limits["max_png_files"]),
        "disk_bytes": (stats["total_bytes"], limits["max_disk_bytes"]),
        "runtime_rgba_bytes": (stats["estimated_rgba_bytes"], limits["max_estimated_rgba_bytes"]),
        "max_width": (stats["max_width"], limits["max_dimension"]),
        "max_height": (stats["max_height"], limits["max_dimension"]),
        "frames": (measured_frames, limits["max_frames"]),
        "draw_calls": (measured_draw_calls, limits["max_draw_calls"]),
    }
    for name, (value, limit) in checks.items():
        if value > limit:
            violations.append({"metric": name, "value": value, "limit": limit})

    report = {
        "schema": SCHEMA,
        "character_id": dna["id"],
        "pack_id": pack_id,
        "root": str(root),
        "ok": not violations,
        "limits": limits,
        "stats": stats,
        "violations": violations,
    }
    output = args.report or Path("artifacts/asset-forge/budgets") / f"{pack_id}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["ok"] or not args.strict else EXIT_EXCEEDED


if __name__ == "__main__":
    raise SystemExit(main())
