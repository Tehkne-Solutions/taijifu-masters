#!/usr/bin/env python3
"""Gera inventário TGAP com presença, qualidade, hashes e bloqueios de promoção."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any

FINAL_STATES = {"final", "approved", "integrated", "released"}
PROTOTYPE_MARKERS = ("prototype", "keypose", "placeholder", "preview", "concept", "mockup")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def classify(path: str, declared_quality: str | None = None) -> str:
    quality = (declared_quality or "").lower()
    lower = path.lower()
    if quality in FINAL_STATES:
        return "final"
    if quality == "prototype" or any(marker in lower for marker in PROTOTYPE_MARKERS):
        return "prototype"
    return "unverified"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_root", type=Path)
    parser.add_argument("--write-status", action="store_true")
    args = parser.parse_args()

    root = args.pack_root.resolve()
    expected_path = root / "expected-assets.json"
    status_path = root / "production-status.json"
    report_path = root / "validation" / "inventory-report.json"
    markdown_path = root / "validation" / "inventory-report.md"

    expected = json.loads(expected_path.read_text(encoding="utf-8"))
    entries = expected.get("assets", [])
    results: list[dict[str, Any]] = []

    for item in entries:
        if isinstance(item, str):
            rel = item
            declared_quality = None
        else:
            rel = item["path"]
            declared_quality = item.get("quality")
        target = root / rel
        entry: dict[str, Any] = {
            "path": rel,
            "present": target.is_file(),
            "classification": "missing",
        }
        if target.is_file():
            entry.update({
                "size_bytes": target.stat().st_size,
                "sha256": sha256(target),
                "classification": classify(rel, declared_quality),
            })
        results.append(entry)

    counts = Counter(entry["classification"] for entry in results)
    present = sum(1 for entry in results if entry["present"])
    total = len(results)
    final_count = counts["final"]
    blocked = present != total or final_count != total

    report = {
        "tgap_version": "1.0",
        "pack_root": str(root),
        "expected": total,
        "present": present,
        "missing": total - present,
        "final": final_count,
        "prototype": counts["prototype"],
        "unverified": counts["unverified"],
        "progress_physical": round(present / total, 6) if total else 0,
        "progress_final": round(final_count / total, 6) if total else 0,
        "promotion_blocked": blocked,
        "assets": results,
    }

    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Relatório de Inventário TGAP",
        "",
        f"- Esperados: **{total}**",
        f"- Presentes: **{present}**",
        f"- Ausentes: **{total - present}**",
        f"- Finais: **{final_count}**",
        f"- Protótipos: **{counts['prototype']}**",
        f"- Não verificados: **{counts['unverified']}**",
        f"- Promoção bloqueada: **{'sim' if blocked else 'não'}**",
        "",
        "## Ausentes",
        "",
    ]
    lines.extend(f"- `{entry['path']}`" for entry in results if not entry["present"])
    markdown_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    if args.write_status:
        current = json.loads(status_path.read_text(encoding="utf-8")) if status_path.exists() else {}
        current.update({
            "expected": total,
            "present": present,
            "missing": total - present,
            "final": final_count,
            "prototype": counts["prototype"],
            "unverified": counts["unverified"],
            "progress_physical": report["progress_physical"],
            "progress_final": report["progress_final"],
            "promotion_blocked": blocked,
            "inventory_report": "validation/inventory-report.json",
        })
        status_path.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({key: report[key] for key in ("expected", "present", "missing", "final", "prototype", "unverified", "promotion_blocked")}, ensure_ascii=False))
    return 1 if blocked else 0


if __name__ == "__main__":
    raise SystemExit(main())
