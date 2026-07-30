#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

REQUIRED = {
    "source/char_lian_wu__master_raw.png",
    "source/turnaround_raw.png",
    "source/portraits_raw.png",
    "source/icons_raw.png",
    "manifest.json",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(command: list[str]) -> None:
    result = subprocess.run(command, text=True)
    if result.returncode:
        raise SystemExit(result.returncode)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Valida e importa o PACK 01 Lian Wu para o Asset Forge."
    )
    parser.add_argument("pack_zip", type=Path)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--keep-intake", action="store_true")
    args = parser.parse_args()

    if not args.pack_zip.is_file():
        print(f"ZIP não encontrado: {args.pack_zip}", file=sys.stderr)
        return 18

    with zipfile.ZipFile(args.pack_zip) as archive:
        names = {name.rstrip("/") for name in archive.namelist() if not name.endswith("/")}
        missing = sorted(REQUIRED - names)
        if missing:
            print(json.dumps({"ok": False, "missing": missing}, ensure_ascii=False))
            return 19

        with tempfile.TemporaryDirectory(prefix="taijifu-pack01-") as temp:
            extracted = Path(temp) / "pack"
            archive.extractall(extracted)

            manifest = json.loads((extracted / "manifest.json").read_text(encoding="utf-8"))
            if manifest.get("pack_id") != "pack_01_lian_wu_base":
                print("pack_id inválido", file=sys.stderr)
                return 20

            checks = []
            for item in manifest.get("required_sources", []):
                path = extracted / item["path"]
                checks.append({
                    "path": item["path"],
                    "exists": path.is_file(),
                    "sha256_ok": path.is_file() and sha256(path) == item.get("sha256"),
                })

            if not checks or not all(c["exists"] and c["sha256_ok"] for c in checks):
                print(json.dumps({"ok": False, "checks": checks}, ensure_ascii=False))
                return 21

            intake_root = Path("artifacts/asset-forge/intake/pack_01_lian_wu_base/manual")
            if intake_root.exists():
                shutil.rmtree(intake_root)
            shutil.copytree(extracted, intake_root)

            source = intake_root / "source"
            command = [
                sys.executable,
                "tools/asset_forge/release_pipeline.py",
                "asset-forge/releases/pack_01_lian_wu_base.json",
                "--source",
                str(source),
            ]
            if args.strict:
                command.append("--strict")
            run(command)

            if not args.keep_intake and intake_root.exists():
                shutil.rmtree(intake_root)

    print(json.dumps({
        "ok": True,
        "pack_id": "pack_01_lian_wu_base",
        "zip": str(args.pack_zip),
        "strict": args.strict,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
