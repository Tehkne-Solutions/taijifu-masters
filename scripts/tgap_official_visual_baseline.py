#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

REQUIRED_RUNTIME_KEYS = ("atlas_png", "atlas_json", "spriteframes", "manifest")
PROMOTABLE_STATES = {"approved", "integrated", "released"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", type=Path, default=Path("tgap-registry.json"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/tgap/official-visual-baseline.json"))
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    registry = json.loads((root / args.registry).read_text(encoding="utf-8"))
    packs = []
    blocking = []

    for entry in registry.get("packs", []):
        pack_root = root / entry["root"]
        manifest_path = pack_root / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        runtime = manifest.get("runtime", {})
        files = {}
        missing = []
        for key in REQUIRED_RUNTIME_KEYS:
            rel = runtime.get(key)
            if not rel:
                missing.append(key)
                continue
            target = pack_root / rel
            if not target.is_file():
                missing.append(rel)
                continue
            files[key] = {"path": target.relative_to(root).as_posix(), "sha256": sha256(target), "bytes": target.stat().st_size}

        state = str(manifest.get("state", ""))
        promotable = state in PROMOTABLE_STATES and not missing and not manifest.get("promotion", {}).get("blocked", False)
        if args.strict and not promotable:
            blocking.append(entry["pack_id"])
        packs.append({
            "pack_id": entry["pack_id"],
            "version": entry["version"],
            "state": state,
            "promotable": promotable,
            "missing": missing,
            "files": files,
            "visual_identity": manifest.get("visual_identity", {}),
        })

    report = {
        "schema": "tgap/official-visual-baseline/v1",
        "registry_version": registry.get("registry_version"),
        "packs": packs,
        "summary": {
            "packs_total": len(packs),
            "packs_promotable": sum(1 for item in packs if item["promotable"]),
            "packs_blocked": sum(1 for item in packs if not item["promotable"]),
            "strict_blocking": blocking,
        },
    }
    output = args.output if args.output.is_absolute() else root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], ensure_ascii=False))
    return 1 if blocking else 0


if __name__ == "__main__":
    raise SystemExit(main())
