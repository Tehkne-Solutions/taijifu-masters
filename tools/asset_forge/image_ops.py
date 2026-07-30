#!/usr/bin/env python3
"""Operações físicas de imagem do Taijifu Asset Forge.

Não gera arte. Processa PNGs fornecidos: chroma key, trim, normalização,
recorte por grade e atlas físico determinístico.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def parse_hex(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    if len(value) != 6:
        raise ValueError("invalid_hex_color")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def remove_chroma(image: Image.Image, color: tuple[int, int, int], tolerance: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for r, g, b, a in rgba.getdata():
        distance = max(abs(r - color[0]), abs(g - color[1]), abs(b - color[2]))
        pixels.append((r, g, b, 0 if distance <= tolerance else a))
    rgba.putdata(pixels)
    return rgba


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    rgba = image.convert("RGBA")
    return rgba.getchannel("A").getbbox()


def trim_alpha(image: Image.Image, padding: int = 0) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = alpha_bbox(rgba)
    if bbox is None:
        raise ValueError("empty_alpha_content")
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(rgba.width, right + padding)
    bottom = min(rgba.height, bottom + padding)
    return rgba.crop((left, top, right, bottom))


def normalize_canvas(
    image: Image.Image,
    width: int,
    height: int,
    pivot_x: int | None = None,
    pivot_y: int | None = None,
    margin: int = 4,
) -> Image.Image:
    source = trim_alpha(image)
    max_width = max(1, width - margin * 2)
    max_height = max(1, height - margin * 2)
    scale = min(max_width / source.width, max_height / source.height, 1.0)
    if scale < 1.0:
        source = source.resize(
            (max(1, round(source.width * scale)), max(1, round(source.height * scale))),
            Image.Resampling.LANCZOS,
        )
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    px = width // 2 if pivot_x is None else pivot_x
    py = height - margin if pivot_y is None else pivot_y
    x = px - source.width // 2
    y = py - source.height
    x = min(max(0, x), width - source.width)
    y = min(max(0, y), height - source.height)
    canvas.alpha_composite(source, (x, y))
    return canvas


def split_grid(
    source: Path,
    output_dir: Path,
    columns: int,
    rows: int,
    pattern: str,
    chroma: tuple[int, int, int] | None = None,
    tolerance: int = 16,
    normalize: tuple[int, int, int, int] | None = None,
) -> list[str]:
    image = Image.open(source).convert("RGBA")
    if image.width % columns or image.height % rows:
        raise ValueError("grid_not_divisible")
    cell_width = image.width // columns
    cell_height = image.height // rows
    output_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    index = 1
    for row in range(rows):
        for column in range(columns):
            frame = image.crop((
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            ))
            if chroma is not None:
                frame = remove_chroma(frame, chroma, tolerance)
            if normalize is not None:
                frame = normalize_canvas(frame, *normalize)
            name = pattern.format(frame=index)
            target = output_dir / name
            target.parent.mkdir(parents=True, exist_ok=True)
            frame.save(target, optimize=True)
            written.append(target.as_posix())
            index += 1
    return written


def build_atlas(files: list[Path], output: Path, metadata: Path, max_width: int = 2048, padding: int = 2) -> dict[str, Any]:
    if not files:
        raise ValueError("atlas_has_no_sources")
    images = [(path, Image.open(path).convert("RGBA")) for path in files]
    cell_width = max(image.width for _, image in images) + padding * 2
    cell_height = max(image.height for _, image in images) + padding * 2
    columns = max(1, min(len(images), max_width // cell_width))
    rows = math.ceil(len(images) / columns)
    atlas = Image.new("RGBA", (columns * cell_width, rows * cell_height), (0, 0, 0, 0))
    frames: dict[str, Any] = {}
    for index, (path, image) in enumerate(images):
        column = index % columns
        row = index // columns
        x = column * cell_width + padding
        y = row * cell_height + padding
        atlas.alpha_composite(image, (x, y))
        frames[path.as_posix()] = {"x": x, "y": y, "w": image.width, "h": image.height}
    output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output, optimize=True)
    result = {
        "schema": "taijifu/asset-forge-atlas/v2",
        "image": output.as_posix(),
        "width": atlas.width,
        "height": atlas.height,
        "padding": padding,
        "frames": frames,
    }
    dump_json(metadata, result)
    return result


def process_recipe(recipe_path: Path, repo: Path) -> dict[str, Any]:
    recipe = load_json(recipe_path)
    outputs: list[str] = []
    for operation in recipe.get("operations", []):
        kind = operation["type"]
        if kind == "split_grid":
            chroma = parse_hex(operation["chroma"]) if operation.get("chroma") else None
            normalize = None
            if operation.get("normalize"):
                value = operation["normalize"]
                pivot = value.get("pivot", [value["width"] // 2, value["height"]])
                normalize = (value["width"], value["height"], pivot[0], pivot[1])
            outputs.extend(split_grid(
                repo / operation["source"],
                repo / operation["output_dir"],
                int(operation["columns"]),
                int(operation["rows"]),
                operation.get("pattern", "frame_{frame:02d}.png"),
                chroma,
                int(operation.get("tolerance", 16)),
                normalize,
            ))
        elif kind == "normalize":
            source = repo / operation["source"]
            target = repo / operation["output"]
            image = Image.open(source).convert("RGBA")
            if operation.get("chroma"):
                image = remove_chroma(image, parse_hex(operation["chroma"]), int(operation.get("tolerance", 16)))
            pivot = operation.get("pivot", [operation["width"] // 2, operation["height"]])
            normalized = normalize_canvas(image, int(operation["width"]), int(operation["height"]), int(pivot[0]), int(pivot[1]))
            target.parent.mkdir(parents=True, exist_ok=True)
            normalized.save(target, optimize=True)
            outputs.append(target.as_posix())
        elif kind == "atlas":
            files = sorted(repo.glob(operation["glob"]))
            result = build_atlas(
                files,
                repo / operation["output"],
                repo / operation["metadata"],
                int(operation.get("max_width", 2048)),
                int(operation.get("padding", 2)),
            )
            outputs.extend([result["image"], str(repo / operation["metadata"])])
        else:
            raise ValueError(f"unknown_operation:{kind}")
    report = {
        "schema": "taijifu/asset-forge-image-processing/v2",
        "recipe": str(recipe_path),
        "operation_total": len(recipe.get("operations", [])),
        "outputs": outputs,
    }
    report_path = repo / recipe.get("report", "artifacts/asset-forge/image-processing.json")
    dump_json(report_path, report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("recipe", type=Path)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()
    recipe = args.recipe if args.recipe.is_absolute() else args.repo / args.recipe
    report = process_recipe(recipe, args.repo.resolve())
    print(json.dumps({"operations": report["operation_total"], "outputs": len(report["outputs"])}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
