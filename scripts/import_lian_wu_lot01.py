#!/usr/bin/env python3
"""Importa o lote físico 01 de Lian Wu a partir de spritesheets limpas."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

from PIL import Image

FRAME_SIZE = (128, 128)
ANIMATIONS = {
    "idle": {"frames": 6, "fps": 8},
    "walk": {"frames": 8, "fps": 12},
    "run": {"frames": 8, "fps": 14},
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_rgba(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(path)
    image = Image.open(path)
    return image if image.mode == "RGBA" else image.convert("RGBA")


def validate_transparency(image: Image.Image, label: str) -> None:
    minimum, maximum = image.getchannel("A").getextrema()
    if minimum == 255:
        raise ValueError(f"{label}: imagem sem transparência")
    if maximum == 0:
        raise ValueError(f"{label}: imagem totalmente transparente")


def crop_sheet(sheet_path: Path, animation: str, frame_count: int, output_dir: Path) -> list[Path]:
    sheet = load_rgba(sheet_path)
    expected_size = (FRAME_SIZE[0] * frame_count, FRAME_SIZE[1])
    if sheet.size != expected_size:
        raise ValueError(f"{animation}: dimensões {sheet.size}; esperado {expected_size}")
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs: list[Path] = []
    for index in range(frame_count):
        left = index * FRAME_SIZE[0]
        frame = sheet.crop((left, 0, left + FRAME_SIZE[0], FRAME_SIZE[1]))
        validate_transparency(frame, f"{animation} f{index + 1:02d}")
        target = output_dir / f"char_lian_wu__{animation}__f{index + 1:02d}.png"
        frame.save(target, "PNG", optimize=True)
        outputs.append(target)
    return outputs


def write_metadata(pack_root: Path, animation: str, frame_paths: list[Path], fps: int) -> Path:
    metadata_dir = pack_root / "metadata"
    metadata_dir.mkdir(parents=True, exist_ok=True)
    payload: dict[str, Any] = {
        "animation_id": animation,
        "frame_count": len(frame_paths),
        "fps": fps,
        "loop": True,
        "frame_size": [128, 128],
        "pivot": [64, 120],
        "frames": [
            {
                "index": index,
                "path": str(path.relative_to(pack_root)).replace("\\", "/"),
                "sha256": sha256(path),
            }
            for index, path in enumerate(frame_paths)
        ],
    }
    target = metadata_dir / f"{animation}.json"
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return target


def build_atlas(pack_root: Path, animations: dict[str, list[Path]]) -> tuple[Path, Path]:
    atlas_dir = pack_root / "atlases"
    atlas_dir.mkdir(parents=True, exist_ok=True)
    ordered = [(name, path) for name in ANIMATIONS for path in animations[name]]
    columns = 8
    rows = (len(ordered) + columns - 1) // columns
    atlas = Image.new("RGBA", (columns * 128, rows * 128), (0, 0, 0, 0))
    frames: dict[str, Any] = {}
    for index, (animation, path) in enumerate(ordered):
        x = (index % columns) * 128
        y = (index // columns) * 128
        atlas.alpha_composite(load_rgba(path), (x, y))
        frames[path.name] = {
            "frame": {"x": x, "y": y, "w": 128, "h": 128},
            "animation": animation,
            "pivot": {"x": 0.5, "y": 0.9375},
        }
    atlas_png = atlas_dir / "char_lian_wu__lot01.png"
    atlas_json = atlas_dir / "char_lian_wu__lot01.json"
    atlas.save(atlas_png, "PNG", optimize=True)
    atlas_json.write_text(
        json.dumps({"meta": {"size": {"w": atlas.width, "h": atlas.height}}, "frames": frames}, indent=2) + "\n",
        encoding="utf-8",
    )
    return atlas_png, atlas_json


def update_status(pack_root: Path) -> None:
    expected = json.loads((pack_root / "expected-assets.json").read_text(encoding="utf-8"))
    assets = expected.get("assets", [])
    present: list[dict[str, str]] = []
    missing: list[str] = []
    for item in assets:
        rel = item["path"] if isinstance(item, dict) else item
        target = pack_root / rel
        if target.exists():
            present.append({"path": rel, "sha256": sha256(target)})
        else:
            missing.append(rel)
    payload = {
        "pack_id": "pack_01_characters",
        "asset_id": "char_lian_wu",
        "state": "production" if present else "specified",
        "expected": len(assets),
        "present": len(present),
        "missing": len(missing),
        "progress": round(len(present) / len(assets), 6) if assets else 0.0,
        "promotion_blocked": bool(missing),
        "present_assets": present,
        "missing_assets": missing,
    }
    (pack_root / "production-status.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--pack-root", type=Path, default=Path("assets/pack_01_characters/lian_wu"))
    args = parser.parse_args()
    pack_root: Path = args.pack_root
    source_dir = pack_root / "source"
    source_dir.mkdir(parents=True, exist_ok=True)

    master = load_rgba(args.input / "master.png")
    validate_transparency(master, "master")
    if master.size[0] < 128 or master.size[1] < 128:
        raise ValueError("master.png deve ter pelo menos 128x128")
    master.save(source_dir / "char_lian_wu__master.png", "PNG", optimize=True)

    produced: dict[str, list[Path]] = {}
    for animation, config in ANIMATIONS.items():
        produced[animation] = crop_sheet(
            args.input / f"{animation}.png",
            animation,
            config["frames"],
            pack_root / "frames" / animation,
        )
        write_metadata(pack_root, animation, produced[animation], config["fps"])

    build_atlas(pack_root, produced)
    update_status(pack_root)
    print("Lote 01 importado e validado com sucesso.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        raise SystemExit(1)
