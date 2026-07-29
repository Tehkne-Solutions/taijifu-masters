#!/usr/bin/env python3
"""Valida recursos de runtime de um pack TGAP antes da promoção."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

RES_PATH_RE = re.compile(r'res://[^"\s)\]]+')
FRAME_KEY_RE = re.compile(r"char_lian_wu__(?P<animation>[a-z0-9_]+)__f(?P<index>\d{2})")


def load_json(path: Path) -> tuple[Any | None, str | None]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except Exception as exc:  # noqa: BLE001
        return None, str(exc)


def rel_resolve(pack_root: Path, value: str) -> Path:
    if value.startswith("res://"):
        repo_root = pack_root
        while repo_root.parent != repo_root and not (repo_root / ".git").exists():
            repo_root = repo_root.parent
        return repo_root / value.removeprefix("res://")
    return pack_root / value


def check_file(path: Path, label: str, errors: list[str]) -> bool:
    if not path.is_file():
        errors.append(f"{label} ausente: {path}")
        return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_root", type=Path)
    args = parser.parse_args()

    root = args.pack_root.resolve()
    validation = root / "validation"
    validation.mkdir(parents=True, exist_ok=True)

    expected_path = root / "expected-assets.json"
    expected, expected_error = load_json(expected_path)
    errors: list[str] = []
    warnings: list[str] = []
    checks: dict[str, Any] = {}

    if expected_error or not isinstance(expected, dict):
        errors.append(f"expected-assets.json inválido: {expected_error}")
        expected = {}

    atlas_png = root / "atlases/char_lian_wu__atlas.png"
    atlas_json = root / "atlases/char_lian_wu__atlas.json"
    spriteframes = root / "runtime/lian_wu_spriteframes.tres"
    runtime_manifest = root / "runtime/lian_wu_runtime_manifest.json"

    checks["required_files"] = {
        "atlas_png": check_file(atlas_png, "atlas PNG", errors),
        "atlas_json": check_file(atlas_json, "atlas JSON", errors),
        "spriteframes": check_file(spriteframes, "SpriteFrames", errors),
        "runtime_manifest": check_file(runtime_manifest, "manifesto de runtime", errors),
    }

    expected_frames: set[str] = set()
    for animation, count in expected.get("animations", {}).items():
        for index in range(int(count)):
            expected_frames.add(f"char_lian_wu__{animation}__f{index:02d}")

    atlas_frames: set[str] = set()
    atlas_data: Any = None
    if atlas_json.is_file():
        atlas_data, atlas_error = load_json(atlas_json)
        if atlas_error:
            errors.append(f"atlas JSON inválido: {atlas_error}")
        elif isinstance(atlas_data, dict):
            raw_frames = atlas_data.get("frames", {})
            if isinstance(raw_frames, dict):
                atlas_frames = {Path(key).stem for key in raw_frames}
            elif isinstance(raw_frames, list):
                for item in raw_frames:
                    if isinstance(item, dict) and item.get("filename"):
                        atlas_frames.add(Path(str(item["filename"])).stem)
            else:
                errors.append("atlas JSON sem coleção 'frames' válida")

    missing_in_atlas = sorted(expected_frames - atlas_frames)
    extra_in_atlas = sorted(atlas_frames - expected_frames)
    if missing_in_atlas:
        errors.append(f"{len(missing_in_atlas)} frames esperados não estão no atlas")
    if extra_in_atlas:
        warnings.append(f"{len(extra_in_atlas)} frames extras encontrados no atlas")

    checks["atlas_consistency"] = {
        "expected_frames": len(expected_frames),
        "atlas_frames": len(atlas_frames),
        "missing": missing_in_atlas,
        "extra": extra_in_atlas,
    }

    sprite_text = ""
    sprite_frame_names: set[str] = set()
    referenced_paths: set[str] = set()
    if spriteframes.is_file():
        sprite_text = spriteframes.read_text(encoding="utf-8", errors="replace")
        sprite_frame_names = {match.group(0) for match in FRAME_KEY_RE.finditer(sprite_text)}
        referenced_paths = set(RES_PATH_RE.findall(sprite_text))
        if "SpriteFrames" not in sprite_text:
            errors.append("arquivo .tres não declara recurso SpriteFrames")
        if not sprite_frame_names:
            errors.append("arquivo .tres não referencia frames canônicos")

    missing_in_spriteframes = sorted(expected_frames - sprite_frame_names)
    if missing_in_spriteframes:
        errors.append(f"{len(missing_in_spriteframes)} frames esperados não estão no SpriteFrames")

    broken_refs: list[str] = []
    for ref in sorted(referenced_paths):
        clean = ref.rstrip('"')
        if not rel_resolve(root, clean).exists():
            broken_refs.append(clean)
    if broken_refs:
        errors.append(f"{len(broken_refs)} referências res:// quebradas")

    checks["spriteframes_consistency"] = {
        "declared_frames": len(sprite_frame_names),
        "missing": missing_in_spriteframes,
        "resource_references": sorted(referenced_paths),
        "broken_references": broken_refs,
    }

    manifest_data: Any = None
    if runtime_manifest.is_file():
        manifest_data, manifest_error = load_json(runtime_manifest)
        if manifest_error:
            errors.append(f"manifesto de runtime inválido: {manifest_error}")
        elif not isinstance(manifest_data, dict):
            errors.append("manifesto de runtime deve ser um objeto JSON")
        else:
            for field in ("pack_id", "character_id", "atlas", "spriteframes", "animations"):
                if field not in manifest_data:
                    errors.append(f"manifesto de runtime sem campo obrigatório: {field}")
            declared_animations = manifest_data.get("animations", {})
            if isinstance(declared_animations, dict):
                for animation, count in expected.get("animations", {}).items():
                    declared = declared_animations.get(animation)
                    if isinstance(declared, dict):
                        declared_count = declared.get("frame_count")
                    else:
                        declared_count = declared
                    if declared_count != count:
                        errors.append(
                            f"manifesto divergente em {animation}: esperado {count}, recebido {declared_count}"
                        )
            else:
                errors.append("campo animations do manifesto não é um objeto")

    checks["runtime_manifest"] = {
        "valid": isinstance(manifest_data, dict),
        "animation_count": len(manifest_data.get("animations", {})) if isinstance(manifest_data, dict) else 0,
    }

    passed = not errors
    report = {
        "tgap_version": "1.0",
        "pack_root": str(root),
        "runtime_gate_passed": passed,
        "promotion_blocked": not passed,
        "errors": errors,
        "warnings": warnings,
        "checks": checks,
    }

    json_path = validation / "runtime-gate-report.json"
    md_path = validation / "runtime-gate-report.md"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Gate de Runtime TGAP",
        "",
        f"- Aprovado: **{'sim' if passed else 'não'}**",
        f"- Erros: **{len(errors)}**",
        f"- Alertas: **{len(warnings)}**",
        f"- Frames esperados: **{len(expected_frames)}**",
        f"- Frames no atlas: **{len(atlas_frames)}**",
        f"- Frames no SpriteFrames: **{len(sprite_frame_names)}**",
        "",
        "## Erros",
        "",
    ]
    lines.extend(f"- {item}" for item in errors)
    lines.extend(["", "## Alertas", ""])
    lines.extend(f"- {item}" for item in warnings)
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(json.dumps({"runtime_gate_passed": passed, "errors": len(errors), "warnings": len(warnings)}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
