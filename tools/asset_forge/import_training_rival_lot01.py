#!/usr/bin/env python3
"""Importa o pacote aprovado do Rival de Treino para o First Playable.

Assinatura: Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
import zipfile
from pathlib import Path

REQUIRED = ("idle", "run", "jump_start", "airborne", "fall", "attack_light", "guard", "dodge", "hit", "ko")
LOT_ID = "training_rival_first_playable_lot_01"
DESTINATION = Path("assets/tgap/training_rival/first_playable_lot_01")


def _safe_extract(archive: zipfile.ZipFile, destination: Path) -> None:
    root = destination.resolve()
    for member in archive.infolist():
        target = (destination / member.filename).resolve()
        if root not in target.parents and target != root:
            raise ValueError(f"entrada insegura no ZIP: {member.filename}")
    archive.extractall(destination)


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _validate_checksums(root: Path) -> None:
    checksum_file = root / "checksums.sha256"
    if not checksum_file.exists():
        raise ValueError("checksums.sha256 ausente")
    for line in checksum_file.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        digest, relative = line.split(maxsplit=1)
        relative = relative.lstrip("* ")
        file_path = root / relative
        if not file_path.is_file():
            raise ValueError(f"arquivo listado não encontrado: {relative}")
        actual = hashlib.sha256(file_path.read_bytes()).hexdigest()
        if actual.lower() != digest.lower():
            raise ValueError(f"checksum inválido: {relative}")


def _find_root(extracted: Path) -> Path:
    manifests = list(extracted.rglob("manifest.json"))
    if len(manifests) != 1:
        raise ValueError("o ZIP deve conter exatamente um manifest.json")
    return manifests[0].parent


def _validate(root: Path) -> dict:
    manifest = _load_json(root / "manifest.json")
    approval = _load_json(root / "approval.json")
    if manifest.get("lot_id") != LOT_ID:
        raise ValueError("lot_id incompatível")
    if approval.get("status") != "approved":
        raise ValueError("lote ainda não aprovado")
    for animation in REQUIRED:
        frames = sorted((root / "animations" / animation).glob("*.png"))
        if not frames:
            raise ValueError(f"animação sem frames: {animation}")
    _validate_checksums(root)
    return manifest


def _write_sprite_frames(root: Path, destination: Path, manifest: dict) -> Path:
    ext_resources: list[str] = []
    animations: list[str] = []
    resource_id = 1
    for animation in REQUIRED:
        frames = sorted((root / "animations" / animation).glob("*.png"))
        frame_entries: list[str] = []
        for frame in frames:
            target = destination / "animations" / animation / frame.name
            ext_resources.append(f'[ext_resource type="Texture2D" path="res://{target.as_posix()}" id="{resource_id}"]')
            frame_entries.append('{"duration": 1.0, "texture": ExtResource("%d")}' % resource_id)
            resource_id += 1
        fps = float(manifest.get("animations", {}).get(animation, {}).get("fps", 12.0))
        loop = "true" if bool(manifest.get("animations", {}).get(animation, {}).get("loop", animation in {"idle", "run", "airborne", "fall", "guard"})) else "false"
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.2f}' % (", ".join(frame_entries), loop, animation, fps))
    content = "[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]\n\n%s\n\n[resource]\nanimations = [%s]\n" % (
        resource_id,
        "\n".join(ext_resources),
        ",\n".join(animations),
    )
    output = destination / "training_rival_first_playable_frames.tres"
    output.write_text(content, encoding="utf-8")
    return output


def import_package(zip_path: Path, project_root: Path) -> Path:
    destination = project_root / DESTINATION
    with tempfile.TemporaryDirectory(prefix="training-rival-lot01-") as temp:
        extracted = Path(temp)
        with zipfile.ZipFile(zip_path) as archive:
            _safe_extract(archive, extracted)
        source_root = _find_root(extracted)
        manifest = _validate(source_root)
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(source_root, destination)
        _write_sprite_frames(source_root, destination, manifest)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("zip_path", type=Path)
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    destination = import_package(args.zip_path.resolve(), args.project_root.resolve())
    print(f"TRAINING_RIVAL_LOT01_IMPORTED {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
