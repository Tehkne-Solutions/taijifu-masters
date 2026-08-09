#!/usr/bin/env python3
"""Validate Lian Wu Character Lock by exact historical decoded RGBA identity.

The recovered historical Character Lock is the authoritative art source. Its
PNG SHA is preserved as binary provenance and its decoded 1024x1024 RGBA digest
is the canonical visual identity. Alternative PNG encodings are accepted only
when they decode to those exact historical pixels.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

try:
    from PIL import Image
except ImportError as exc:
    raise SystemExit(
        "C63_4_LIAN_CANONICAL_IDENTITY=BLOCKED missing dependency Pillow"
    ) from exc

HISTORICAL_FILE_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANONICAL_RGBA_SHA256 = "0bedec17308acd2c7b392f2c989cf97238908aa4f18b73371aa67c741eb6030b"
CANONICAL_ALPHA_BOUNDS_THRESHOLD_3 = (325, 70, 720, 970)
CANVAS = (1024, 1024)
SIGNATURE = "Tehkné Solutions"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def alpha_bounds_threshold_3(rgba: Image.Image) -> tuple[int, int, int, int]:
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 3 else 0)
    return alpha.getbbox() or (0, 0, 0, 0)


def validate_source(path: Path) -> dict:
    if not path.is_file():
        raise ValueError(f"source_missing={path}")

    file_bytes = path.read_bytes()
    file_sha = sha256_bytes(file_bytes)

    with Image.open(path) as opened:
        rgba = opened.convert("RGBA")
        canvas = rgba.size
        pixel_sha = sha256_bytes(rgba.tobytes())
        bounds = alpha_bounds_threshold_3(rgba)

    if canvas != CANVAS:
        raise ValueError(f"canvas={canvas} expected={CANVAS}")
    if pixel_sha != CANONICAL_RGBA_SHA256:
        raise ValueError(
            "rgba_identity_mismatch="
            f"{pixel_sha} expected={CANONICAL_RGBA_SHA256}"
        )
    if bounds != CANONICAL_ALPHA_BOUNDS_THRESHOLD_3:
        raise ValueError(
            "alpha_bounds_mismatch="
            f"{bounds} expected={CANONICAL_ALPHA_BOUNDS_THRESHOLD_3}"
        )

    encoding_class = (
        "exact_historical_bytes"
        if file_sha == HISTORICAL_FILE_SHA256
        else "historical_pixel_equivalent_png_encoding"
    )
    return {
        "schema": "tehkne/c63-4-lian-canonical-visual-identity/v1",
        "signature": SIGNATURE,
        "source": str(path),
        "canvas": list(canvas),
        "file_sha256": file_sha,
        "historical_file_sha256": HISTORICAL_FILE_SHA256,
        "decoded_rgba_sha256": pixel_sha,
        "canonical_decoded_rgba_sha256": CANONICAL_RGBA_SHA256,
        "alpha_bounds_threshold_3": list(bounds),
        "canonical_alpha_bounds_threshold_3": list(CANONICAL_ALPHA_BOUNDS_THRESHOLD_3),
        "encoding_class": encoding_class,
        "art_identity": "exact_historical_character_lock",
        "pass": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()

    try:
        report = validate_source(args.source.resolve())
    except (OSError, ValueError) as exc:
        print(f"C63_4_LIAN_CANONICAL_IDENTITY=BLOCKED {exc}", file=sys.stderr)
        return 2

    if args.json:
        args.json.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    print(
        "C63_4_LIAN_CANONICAL_IDENTITY=PASS "
        f"encoding={report['encoding_class']}"
    )
    print(f"file_sha256={report['file_sha256']}")
    print(f"decoded_rgba_sha256={report['decoded_rgba_sha256']}")
    print(f"alpha_bounds_threshold_3={tuple(report['alpha_bounds_threshold_3'])}")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
