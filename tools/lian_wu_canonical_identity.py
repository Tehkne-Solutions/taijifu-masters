#!/usr/bin/env python3
"""Validate Lian Wu Character Lock by decoded RGBA identity.

The historical canonical PNG SHA remains preserved as provenance, but runtime
art identity is validated from the decoded 1024x1024 RGBA pixels so harmless
PNG encoder differences cannot masquerade as an art mutation.

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
        "C63_2_LIAN_CANONICAL_IDENTITY=BLOCKED missing dependency Pillow"
    ) from exc

HISTORICAL_FILE_SHA256 = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
CANONICAL_RGBA_SHA256 = "c2cf8ea213692090832b7859119e98ddf2c862b23f9a3f94200e5d15280b78e2"
CANVAS = (1024, 1024)
SIGNATURE = "Tehkné Solutions"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_source(path: Path) -> dict:
    if not path.is_file():
        raise ValueError(f"source_missing={path}")

    file_bytes = path.read_bytes()
    file_sha = sha256_bytes(file_bytes)

    with Image.open(path) as opened:
        rgba = opened.convert("RGBA")
        canvas = rgba.size
        pixel_sha = sha256_bytes(rgba.tobytes())

    if canvas != CANVAS:
        raise ValueError(f"canvas={canvas} expected={CANVAS}")
    if pixel_sha != CANONICAL_RGBA_SHA256:
        raise ValueError(
            "rgba_identity_mismatch="
            f"{pixel_sha} expected={CANONICAL_RGBA_SHA256}"
        )

    encoding_class = (
        "exact_historical_bytes"
        if file_sha == HISTORICAL_FILE_SHA256
        else "pixel_equivalent_png_encoding"
    )
    return {
        "schema": "tehkne/c63-2-lian-canonical-visual-identity/v1",
        "signature": SIGNATURE,
        "source": str(path),
        "canvas": list(canvas),
        "file_sha256": file_sha,
        "historical_file_sha256": HISTORICAL_FILE_SHA256,
        "decoded_rgba_sha256": pixel_sha,
        "canonical_decoded_rgba_sha256": CANONICAL_RGBA_SHA256,
        "encoding_class": encoding_class,
        "art_identity": "canonical",
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
        print(f"C63_2_LIAN_CANONICAL_IDENTITY=BLOCKED {exc}", file=sys.stderr)
        return 2

    if args.json:
        args.json.write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    print(
        "C63_2_LIAN_CANONICAL_IDENTITY=PASS "
        f"encoding={report['encoding_class']}"
    )
    print(f"file_sha256={report['file_sha256']}")
    print(f"decoded_rgba_sha256={report['decoded_rgba_sha256']}")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
