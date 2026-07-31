#!/usr/bin/env python3
"""Importa o First Playable Lot 01 de Lian Wu e gera SpriteFrames do Godot.

Assinatura: Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

REQUIRED = (
    "idle", "run", "jump_start", "airborne", "fall",
    "attack_light", "guard", "dodge", "hit", "ko",
)
TARGET = Path("assets/tgap/pack_01_lian_wu/first_playable_lot_01")
RESOURCE = TARGET / "lian_wu_first_playable_frames.tres"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_extract(archive: Path, destination: Path) -> None:
    with zipfile.ZipFile(archive) as bundle:
        root = destination.resolve()
        for member in bundle.infolist():
            output = (destination / member.filename).resolve()
            if root not in output.parents and output != root:
                raise ValueError(f"caminho inseguro no ZIP: {member.filename}")
        bundle.extractall(destination)


def locate_root(extracted: Path) -> Path:
    candidates = [p.parent for p in extracted.rglob("manifest.json")]
    if len(candidates) != 1:
        raise ValueError(f"esperado um manifest.json; encontrados {len(candidates)}")
    return candidates[0]


def validate_checksums(root: Path) -> None:
    checksum_file = root / "checksums.sha256"
    if not checksum_file.is_file():
        raise ValueError("checksums.sha256 ausente")
    for raw in checksum_file.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        expected, relative = line.split(maxsplit=1)
        relative = relative.lstrip("*")
        path = root / relative
        if not path.is_file() or sha256(path) != expected.lower():
            raise ValueError(f"checksum inválido: {relative}")


def load_contract(root: Path) -> tuple[dict, dict]:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    runtime = json.loads((root / "runtime-map.json").read_text(encoding="utf-8"))
    approval = json.loads((root / "approval.json").read_text(encoding="utf-8"))
    if manifest.get("lot_id") != "pack_01_lian_wu_first_playable_lot_01":
        raise ValueError("lot_id inválido")
    if approval.get("status") != "approved":
        raise ValueError("lote ainda não aprovado")
    animations = runtime.get("animations", {})
    missing = [name for name in REQUIRED if name not in animations]
    if missing:
        raise ValueError(f"animações ausentes no runtime-map: {missing}")
    return manifest, runtime


def collect_frames(root: Path, runtime: dict) -> dict[str, list[Path]]:
    result: dict[str, list[Path]] = {}
    for name in REQUIRED:
        spec = runtime["animations"][name]
        folder = root / spec.get("path", f"animations/{name}")
        frames = sorted(folder.glob("*.png"))
        if not frames:
            raise ValueError(f"nenhum frame PNG para {name}")
        result[name] = frames
    return result


def write_sprite_frames(target: Path, frames: dict[str, list[Path]], runtime: dict) -> None:
    resources: list[str] = []
    animations: list[str] = []
    ext_id = 1
    ids: dict[Path, int] = {}
    for name in REQUIRED:
        for source in frames[name]:
            relative = source.relative_to(target.parent.parent.parent.parent) if target.parent.parent.parent.parent in source.parents else source
            ids[source] = ext_id
            resources.append(f'[ext_resource type="Texture2D" path="res://{relative.as_posix()}" id="{ext_id}"]')
            ext_id += 1
    for name in REQUIRED:
        spec = runtime["animations"][name]
        fps = float(spec.get("fps", 10.0))
        loop = "true" if bool(spec.get("loop", False)) else "false"
        frame_rows = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%d")}' % ids[path]
            for path in frames[name]
        )
        animations.append(
            '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'
            % (frame_rows, loop, name, fps)
        )
    text = "\n".join([
        f'[gd_resource type="SpriteFrames" load_steps={ext_id} format=3]',
        "",
        *resources,
        "",
        "[resource]",
        "animations = [%s]" % ",\n".join(animations),
        "",
    ])
    target.write_text(text, encoding="utf-8")


def import_lot(archive: Path, project_root: Path) -> Path:
    with tempfile.TemporaryDirectory(prefix="taijifu-lot01-") as temp:
        extracted = Path(temp)
        safe_extract(archive, extracted)
        source_root = locate_root(extracted)
        validate_checksums(source_root)
        _, runtime = load_contract(source_root)
        source_frames = collect_frames(source_root, runtime)

        target = project_root / TARGET
        if target.exists():
            shutil.rmtree(target)
        target.mkdir(parents=True)

        copied: dict[str, list[Path]] = {}
        for name, files in source_frames.items():
            folder = target / "animations" / name
            folder.mkdir(parents=True)
            copied[name] = []
            for source in files:
                output = folder / source.name
                shutil.copy2(source, output)
                copied[name].append(output)
        for filename in ("manifest.json", "runtime-map.json", "approval.json", "checksums.sha256"):
            shutil.copy2(source_root / filename, target / filename)
        write_sprite_frames(project_root / RESOURCE, copied, runtime)
        return project_root / RESOURCE


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        output = import_lot(args.archive.resolve(), args.project_root.resolve())
    except (OSError, ValueError, zipfile.BadZipFile, json.JSONDecodeError) as exc:
        print(f"LOT01_IMPORT_FAILED: {exc}", file=sys.stderr)
        return 1
    print(f"LOT01_IMPORT_OK: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
