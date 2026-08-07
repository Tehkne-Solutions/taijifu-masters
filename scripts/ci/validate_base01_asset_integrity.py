from __future__ import annotations

import hashlib
import struct
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

ASSETS = {
    "face": (
        Path("assets/modular_fighters/base_01/face/face_01_balanced.png"),
        "d8bc0218b6104d2095e20a074fa4e0a23d428d1bf71e91fcac7139374b3504d9",
    ),
    "eyes": (
        Path("assets/modular_fighters/base_01/eyes/eyes_01_focused.png"),
        "7517e6d14cef106fbe782736524321b992ea3088486498fc24e71f1e158419a9",
    ),
    "brows": (
        Path("assets/modular_fighters/base_01/brows/brows_01_focused.png"),
        "44fa5d30e0963582b5cf2d877b7a61a6d68f8028b9a2da19cbba9a73afc80225",
    ),
}


def validate_png(data: bytes) -> tuple[int, int, int]:
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("invalid_png_signature")

    offset = len(PNG_SIGNATURE)
    width = height = 0
    chunks = 0
    seen_ihdr = False
    seen_idat = False
    seen_iend = False

    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("truncated_chunk_header")
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        data_start = offset + 8
        data_end = data_start + length
        crc_end = data_end + 4
        if crc_end > len(data):
            raise ValueError(f"truncated_chunk:{chunk_type.decode('latin1')}")

        payload = data[data_start:data_end]
        stored_crc = struct.unpack(">I", data[data_end:crc_end])[0]
        actual_crc = zlib.crc32(chunk_type)
        actual_crc = zlib.crc32(payload, actual_crc) & 0xFFFFFFFF
        if stored_crc != actual_crc:
            raise ValueError(f"crc_mismatch:{chunk_type.decode('latin1')}")

        chunks += 1
        if chunk_type == b"IHDR":
            if seen_ihdr or length != 13:
                raise ValueError("invalid_ihdr")
            width, height = struct.unpack(">II", payload[:8])
            seen_ihdr = True
        elif chunk_type == b"IDAT":
            seen_idat = True
        elif chunk_type == b"IEND":
            if length != 0:
                raise ValueError("invalid_iend")
            seen_iend = True
            offset = crc_end
            break

        offset = crc_end

    if not (seen_ihdr and seen_idat and seen_iend):
        raise ValueError("missing_required_png_chunks")
    if offset != len(data):
        raise ValueError("trailing_bytes_after_iend")
    if (width, height) != (1024, 1024):
        raise ValueError(f"unexpected_dimensions:{width}x{height}")
    return width, height, chunks


def main() -> int:
    failures: list[str] = []
    for slot, (path, expected_sha) in ASSETS.items():
        if not path.exists():
            failures.append(f"{slot}:missing:{path}")
            continue
        data = path.read_bytes()
        actual_sha = hashlib.sha256(data).hexdigest()
        if actual_sha != expected_sha:
            failures.append(f"{slot}:sha256_mismatch expected={expected_sha} actual={actual_sha}")
        try:
            width, height, chunks = validate_png(data)
            print(
                f"BASE01_ASSET slot={slot} png=PASS dimensions={width}x{height} "
                f"chunks={chunks} bytes={len(data)} sha256={actual_sha}"
            )
        except ValueError as exc:
            failures.append(f"{slot}:png_invalid:{exc}")

    if failures:
        print("BASE01_ASSET_INTEGRITY=FAIL")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("BASE01_ASSET_INTEGRITY=PASS canonical=3/3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
