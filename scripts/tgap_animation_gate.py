#!/usr/bin/env python3
"""Valida estrutura, sequência e metadados das animações TGAP."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

FRAME_RE = re.compile(r"__f(?P<index>\d{2})\.png$")
DEFAULT_FPS = 12.0


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_metadata(path: Path, animation: str, frame_count: int) -> tuple[list[str], dict[str, Any]]:
    errors: list[str] = []
    if not path.is_file():
        return [f"metadata ausente: {path.name}"], {}

    try:
        data = load_json(path)
    except Exception as exc:
        return [f"metadata inválido: {path.name}: {exc}"], {}

    if data.get("animation") not in (None, animation):
        errors.append("campo animation não corresponde ao diretório")

    fps = data.get("fps", DEFAULT_FPS)
    if not isinstance(fps, (int, float)) or fps <= 0 or fps > 60:
        errors.append("fps deve estar entre 0 e 60")

    if "loop" not in data or not isinstance(data.get("loop"), bool):
        errors.append("loop booleano obrigatório")

    declared = data.get("frame_count")
    if declared is not None and declared != frame_count:
        errors.append(f"frame_count declarado={declared}, físico={frame_count}")

    return errors, data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_root", type=Path)
    parser.add_argument("--pivot-drift-limit", type=float, default=12.0)
    args = parser.parse_args()

    root = args.pack_root.resolve()
    expected = load_json(root / "expected-assets.json")
    animations: dict[str, int] = expected.get("animations", {})
    visual_report_path = root / "validation" / "visual-gate-report.json"
    visual_report = load_json(visual_report_path) if visual_report_path.is_file() else {}
    drift_by_animation = visual_report.get("pivot_drift_by_animation", {})

    results: list[dict[str, Any]] = []
    total_errors = 0

    for animation, expected_count in animations.items():
        frame_dir = root / "frames" / animation
        files = sorted(frame_dir.glob("*.png")) if frame_dir.is_dir() else []
        indices: list[int] = []
        naming_errors: list[str] = []

        for file in files:
            match = FRAME_RE.search(file.name)
            if not match:
                naming_errors.append(file.name)
                continue
            indices.append(int(match.group("index")))

        expected_indices = list(range(expected_count))
        missing_indices = sorted(set(expected_indices) - set(indices))
        extra_indices = sorted(set(indices) - set(expected_indices))
        duplicate_indices = sorted({index for index in indices if indices.count(index) > 1})

        errors: list[str] = []
        if len(files) != expected_count:
            errors.append(f"quantidade física={len(files)}, esperada={expected_count}")
        if missing_indices:
            errors.append(f"frames ausentes: {missing_indices}")
        if extra_indices:
            errors.append(f"frames extras: {extra_indices}")
        if duplicate_indices:
            errors.append(f"índices duplicados: {duplicate_indices}")
        if naming_errors:
            errors.append(f"nomes não canônicos: {naming_errors}")

        metadata_errors, metadata = validate_metadata(
            root / "metadata" / f"{animation}.json", animation, len(files)
        )
        errors.extend(metadata_errors)

        drift = drift_by_animation.get(animation)
        if isinstance(drift, (int, float)) and drift > args.pivot_drift_limit:
            errors.append(f"deriva de pivô={drift:.2f}px excede {args.pivot_drift_limit:.2f}px")

        fps = metadata.get("fps", DEFAULT_FPS) if metadata else DEFAULT_FPS
        duration = round(len(files) / fps, 4) if isinstance(fps, (int, float)) and fps > 0 else None
        total_errors += len(errors)
        results.append({
            "animation": animation,
            "expected_frames": expected_count,
            "present_frames": len(files),
            "fps": fps,
            "loop": metadata.get("loop") if metadata else None,
            "duration_seconds": duration,
            "pivot_drift_px": drift,
            "passed": not errors,
            "errors": errors,
        })

    blocked = not animations or total_errors > 0
    report = {
        "tgap_version": "1.0",
        "pack_root": str(root),
        "animations_expected": len(animations),
        "animations_passed": sum(1 for item in results if item["passed"]),
        "animations_failed": sum(1 for item in results if not item["passed"]),
        "total_errors": total_errors,
        "promotion_blocked": blocked,
        "animations": results,
    }

    validation = root / "validation"
    validation.mkdir(parents=True, exist_ok=True)
    (validation / "animation-gate-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    lines = [
        "# Gate de Animação TGAP",
        "",
        f"- Animações esperadas: **{report['animations_expected']}**",
        f"- Aprovadas: **{report['animations_passed']}**",
        f"- Reprovadas: **{report['animations_failed']}**",
        f"- Promoção bloqueada: **{'sim' if blocked else 'não'}**",
        "",
    ]
    for item in results:
        mark = "OK" if item["passed"] else "FALHA"
        lines.append(f"## {item['animation']} — {mark}")
        lines.append(f"- Frames: {item['present_frames']}/{item['expected_frames']}")
        lines.append(f"- FPS: {item['fps']}")
        lines.append(f"- Loop: {item['loop']}")
        lines.append(f"- Duração: {item['duration_seconds']} s")
        for error in item["errors"]:
            lines.append(f"- Erro: {error}")
        lines.append("")

    (validation / "animation-gate-report.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("animations_expected", "animations_passed", "animations_failed", "promotion_blocked")}, ensure_ascii=False))
    return 1 if blocked else 0


if __name__ == "__main__":
    raise SystemExit(main())
