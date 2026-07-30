#!/usr/bin/env python3
"""Taijifu Asset Forge MVP.

Pipeline determinístico para estruturar, validar, recortar spritesheets regulares,
gerar atlas, manifesto, preview HTML e ZIP. Não gera arte e nunca promove
placeholders como assets concluídos.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import sys
import zipfile
from pathlib import Path
from typing import Any

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_info(path: Path) -> tuple[int, int, bool]:
    with path.open("rb") as handle:
        header = handle.read(33)
    if len(header) < 33 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise ValueError("invalid_png")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", header[16:26])
    has_alpha = color_type in {4, 6}
    return width, height, has_alpha


def pack_root(repo: Path, spec: dict[str, Any]) -> Path:
    root = spec.get("output_root") or f"assets/tgap/{spec['pack_id']}"
    return repo / root


def expected_files(spec: dict[str, Any]) -> list[dict[str, Any]]:
    files: list[dict[str, Any]] = []
    for asset in spec.get("assets", []):
        files.append(dict(asset))
    for animation in spec.get("animations", []):
        name = animation["name"]
        count = int(animation["frames"])
        pattern = animation.get("pattern", f"frames/{name}/{spec['subject_id']}__{name}__f{{frame:02d}}.png")
        for frame in range(1, count + 1):
            files.append({
                "path": pattern.format(frame=frame),
                "kind": "animation_frame",
                "animation": name,
                "frame": frame,
                "width": int(animation.get("width", spec.get("frame", {}).get("width", 128))),
                "height": int(animation.get("height", spec.get("frame", {}).get("height", 128))),
                "alpha": True,
            })
    return files


def init_pack(repo: Path, spec_path: Path) -> dict[str, Any]:
    spec = load_json(spec_path)
    root = pack_root(repo, spec)
    root.mkdir(parents=True, exist_ok=True)
    for asset in expected_files(spec):
        (root / asset["path"]).parent.mkdir(parents=True, exist_ok=True)
    for directory in ("input", "build", "reports", "preview", "runtime", "atlases"):
        (root / directory).mkdir(parents=True, exist_ok=True)
    shutil.copy2(spec_path, root / "forge-spec.json")
    manifest = {
        "schema": "taijifu/asset-forge-manifest/v1",
        "pack_id": spec["pack_id"],
        "subject_id": spec["subject_id"],
        "state": "specified",
        "promotion": {"blocked": True},
        "expected_total": len(expected_files(spec)),
        "generator": "taijifu-asset-forge",
    }
    dump_json(root / "manifest.json", manifest)
    return {"pack_root": str(root.relative_to(repo)), "expected_total": manifest["expected_total"]}


def validate(repo: Path, spec_path: Path) -> dict[str, Any]:
    spec = load_json(spec_path)
    root = pack_root(repo, spec)
    items = []
    missing = []
    invalid = []
    for asset in expected_files(spec):
        path = root / asset["path"]
        item = {"path": asset["path"], "present": path.is_file()}
        if not path.is_file():
            missing.append(asset["path"])
            items.append(item)
            continue
        item["size"] = path.stat().st_size
        item["sha256"] = sha256(path)
        if path.suffix.lower() == ".png":
            try:
                width, height, alpha = png_info(path)
                item.update({"width": width, "height": height, "alpha": alpha})
                errors = []
                if asset.get("width") and width != int(asset["width"]):
                    errors.append(f"width:{width}!={asset['width']}")
                if asset.get("height") and height != int(asset["height"]):
                    errors.append(f"height:{height}!={asset['height']}")
                if asset.get("alpha") is True and not alpha:
                    errors.append("alpha_required")
                if errors:
                    item["errors"] = errors
                    invalid.append(asset["path"])
            except ValueError as exc:
                item["errors"] = [str(exc)]
                invalid.append(asset["path"])
        items.append(item)
    report = {
        "schema": "taijifu/asset-forge-validation/v1",
        "pack_id": spec["pack_id"],
        "expected_total": len(items),
        "present_total": sum(1 for item in items if item["present"]),
        "missing_total": len(missing),
        "invalid_total": len(invalid),
        "ready": not missing and not invalid,
        "missing": missing,
        "invalid": invalid,
        "items": items,
    }
    dump_json(root / "reports/validation.json", report)
    return report


def build_atlas(repo: Path, spec_path: Path) -> dict[str, Any]:
    """Gera metadados de atlas determinísticos.

    O MVP não rasteriza uma nova imagem sem Pillow; usa a lista física dos frames
    e produz atlas.json compatível com a etapa posterior de composição.
    """
    spec = load_json(spec_path)
    root = pack_root(repo, spec)
    validation = validate(repo, spec_path)
    frames = {}
    x = y = 0
    max_width = int(spec.get("atlas", {}).get("width", 2048))
    row_height = 0
    for item in validation["items"]:
        if not item["present"] or not item["path"].endswith(".png"):
            continue
        width, height = item.get("width", 0), item.get("height", 0)
        if x + width > max_width:
            x = 0
            y += row_height
            row_height = 0
        frames[item["path"]] = {"frame": {"x": x, "y": y, "w": width, "h": height}, "sha256": item["sha256"]}
        x += width
        row_height = max(row_height, height)
    atlas = {
        "schema": "taijifu/asset-forge-atlas/v1",
        "pack_id": spec["pack_id"],
        "image": f"{spec['pack_id']}__atlas.png",
        "width": max_width,
        "height": y + row_height,
        "frames": frames,
        "image_pending": True,
    }
    dump_json(root / f"atlases/{spec['pack_id']}__atlas.json", atlas)
    return atlas


def build_preview(repo: Path, spec_path: Path) -> Path:
    spec = load_json(spec_path)
    root = pack_root(repo, spec)
    report = validate(repo, spec_path)
    cards = "\n".join(
        f'<article><code>{item["path"]}</code><strong>{"OK" if item["present"] else "MISSING"}</strong></article>'
        for item in report["items"]
    )
    html = f"""<!doctype html><html><head><meta charset='utf-8'><title>{spec['pack_id']}</title>
<style>body{{font:16px system-ui;background:#101827;color:#eef;padding:32px}}article{{display:flex;justify-content:space-between;padding:10px;border-bottom:1px solid #334}}strong{{color:#7dd3fc}}</style></head>
<body><h1>{spec['pack_id']}</h1><p>{report['present_total']}/{report['expected_total']} presentes; {report['invalid_total']} inválidos.</p>{cards}</body></html>"""
    output = root / "preview/index.html"
    output.write_text(html, encoding="utf-8")
    return output


def bundle(repo: Path, spec_path: Path, strict: bool) -> dict[str, Any]:
    spec = load_json(spec_path)
    root = pack_root(repo, spec)
    report = validate(repo, spec_path)
    build_atlas(repo, spec_path)
    build_preview(repo, spec_path)
    if strict and not report["ready"]:
        raise RuntimeError(f"pack_not_ready: missing={report['missing_total']} invalid={report['invalid_total']}")
    output_dir = repo / "artifacts/asset-forge"
    output_dir.mkdir(parents=True, exist_ok=True)
    zip_path = output_dir / f"{spec['pack_id']}.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(root.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(root.parent))
    result = {"zip": str(zip_path.relative_to(repo)), "ready": report["ready"], "missing_total": report["missing_total"]}
    dump_json(output_dir / f"{spec['pack_id']}__bundle-report.json", result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(prog="taijifu-asset-forge")
    parser.add_argument("command", choices=("init", "validate", "atlas", "preview", "bundle"))
    parser.add_argument("spec", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    spec = args.spec if args.spec.is_absolute() else repo / args.spec
    try:
        if args.command == "init": result = init_pack(repo, spec)
        elif args.command == "validate": result = validate(repo, spec)
        elif args.command == "atlas": result = build_atlas(repo, spec)
        elif args.command == "preview": result = {"preview": str(build_preview(repo, spec).relative_to(repo))}
        else: result = bundle(repo, spec, args.strict)
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except (KeyError, ValueError, RuntimeError, FileNotFoundError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
