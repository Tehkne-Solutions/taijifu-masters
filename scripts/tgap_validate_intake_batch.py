#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_info(path: Path) -> tuple[int, int, bool]:
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise ValueError("invalid_png")
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type in {4, 6}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", default="pack_01_lian_wu")
    parser.add_argument("--batch", default="master-and-identity")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    root = repo / "assets" / "tgap" / args.pack
    contract_path = root / "intake" / f"{args.batch}.json"
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    files = []
    errors = []

    for item in contract["required"]:
        path = root / item["path"]
        result = {"path": item["path"], "present": path.is_file()}
        if not path.is_file():
            result["errors"] = ["missing"]
            files.append(result)
            continue
        item_errors = []
        try:
            width, height, has_alpha = png_info(path)
            result.update({"width": width, "height": height, "alpha": has_alpha, "sha256": sha256(path)})
            if "width" in item and width != item["width"]: item_errors.append("width_mismatch")
            if "height" in item and height != item["height"]: item_errors.append("height_mismatch")
            if width < item.get("min_width", 0): item_errors.append("width_below_minimum")
            if height < item.get("min_height", 0): item_errors.append("height_below_minimum")
            if item.get("alpha_required") and not has_alpha: item_errors.append("alpha_required")
        except ValueError as exc:
            item_errors.append(str(exc))
        result["errors"] = item_errors
        errors.extend(f"{item['path']}:{error}" for error in item_errors)
        files.append(result)

    missing = [item["path"] for item in files if not item["present"]]
    ready = not missing and not errors
    report = {
        "schema": "tgap/intake-validation/v1",
        "pack_id": args.pack,
        "batch_id": contract["batch_id"],
        "required_total": len(files),
        "present_total": len(files) - len(missing),
        "missing": missing,
        "errors": errors,
        "ready_for_visual_gate": ready,
        "files": files,
    }
    output = repo / "artifacts" / "tgap" / "pack01-master-identity-intake.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"present": report["present_total"], "required": report["required_total"], "ready": ready}))
    return 1 if args.strict and not ready else 0


if __name__ == "__main__":
    raise SystemExit(main())
