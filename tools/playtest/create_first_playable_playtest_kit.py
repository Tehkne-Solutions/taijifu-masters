#!/usr/bin/env python3
"""Create a traceable external playtest kit for Taijifu Masters.

The kit combines validated Windows and Web builds, local playtest instructions,
the offline report aggregator and SHA-256 manifests. It uses only Python's
standard library and never uploads data.

Signature: Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import BinaryIO

KIT_SCHEMA = "tehkne/taijifu-first-playable-kit/v1"
BUILD_SCHEMA = "tehkne/taijifu-first-playable-build/v1"
ASSET_SNAPSHOT_SCHEMA = "tehkne/taijifu-first-playable-asset-snapshot/v1"
TELEMETRY_SCHEMA = "tehkne/taijifu-match-telemetry/v3"
SIGNATURE = "Tehkné Solutions"
FIXED_ZIP_TIME = (2020, 1, 1, 0, 0, 0)
WINDOWS_ZIP_NAME = "Taijifu-Masters-First-Playable-Windows-x86_64.zip"
WEB_ZIP_NAME = "Taijifu-Masters-First-Playable-Web.zip"
EXPECTED_ASSET_SNAPSHOT = {
    "schema": ASSET_SNAPSHOT_SCHEMA,
    "signature": SIGNATURE,
    "tag": "assets-first-playable-v1.0.0",
    "commit": "b6767d9d30fb2980de5d0a57a8a4c414b854cad5",
    "archive": "TAIJIFU_FIRST_PLAYABLE_ASSETS_v1.0.0.zip",
    "archive_sha256": "69b6b4641fb93bffa81555926887d44a0dfed5edaa4368b8a58a62f689bd58d2",
    "content_sha256": "b2b4e8e274cd1a819d3062c237907132b4067c3aac4a33ef2d7230e73f565eec",
    "fighter_frames": 89,
    "fighter_animations": 20,
    "stage": "mountain_dojo_night",
    "stage_layers": 3,
    "immutable": True,
    "source_pin_verified_by_build_gate": True,
}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Monta o kit externo do First Playable.")
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    parser.add_argument("--windows-zip", type=Path)
    parser.add_argument("--windows-checksum", type=Path)
    parser.add_argument("--windows-manifest", type=Path)
    parser.add_argument("--web-build", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--stage-dir", type=Path)
    return parser.parse_args(argv)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def project_value(project_file: Path, key: str) -> str:
    pattern = re.compile(rf'^{re.escape(key)}="([^"]+)"$', re.MULTILINE)
    match = pattern.search(project_file.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"Campo {key} ausente em {project_file}")
    return match.group(1)


def portable_checksum(path: Path) -> str:
    return f"{sha256(path)}  {path.name}\n"


def validate_checksum(archive: Path, checksum_path: Path) -> str:
    raw = checksum_path.read_text(encoding="utf-8").strip()
    parts = raw.split(maxsplit=1)
    if len(parts) != 2:
        raise ValueError(f"Checksum inválido: {checksum_path}")
    expected, referenced_name = parts
    referenced_name = referenced_name.lstrip("*")
    if referenced_name != archive.name:
        raise ValueError(
            f"Checksum referencia {referenced_name}, esperado {archive.name}"
        )
    if "/" in referenced_name or "\\" in referenced_name:
        raise ValueError(f"Checksum não portátil: {referenced_name}")
    actual = sha256(archive)
    if actual != expected:
        raise ValueError(f"SHA-256 divergente para {archive}")
    return actual


def validate_asset_snapshot(payload: dict, *, path: Path) -> dict:
    snapshot = payload.get("asset_snapshot")
    if not isinstance(snapshot, dict):
        raise ValueError(f"Snapshot de assets ausente em {path}")
    if snapshot != EXPECTED_ASSET_SNAPSHOT:
        raise ValueError(
            "Snapshot de assets divergente em "
            f"{path}: {json.dumps(snapshot, ensure_ascii=False, sort_keys=True)}"
        )
    return snapshot


def validate_build_manifest(
    path: Path, *, platform: str, version: str
) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schema") != BUILD_SCHEMA:
        raise ValueError(f"Schema de build inválido: {path}")
    if payload.get("platform") != platform:
        raise ValueError(f"Plataforma inválida em {path}")
    if payload.get("version") != version:
        raise ValueError(f"Versão divergente em {path}")
    if payload.get("signature") != SIGNATURE:
        raise ValueError(f"Assinatura inválida em {path}")
    telemetry = payload.get("telemetry", {})
    if telemetry.get("schema") != TELEMETRY_SCHEMA:
        raise ValueError(f"Contrato de telemetria ausente em {path}")
    if telemetry.get("privacy") != "local_only":
        raise ValueError(f"Privacidade local não declarada em {path}")
    validate_asset_snapshot(payload, path=path)
    return payload


def copy_stream(source: BinaryIO, destination: BinaryIO) -> None:
    shutil.copyfileobj(source, destination, length=1024 * 1024)


def add_file_to_zip(
    archive: zipfile.ZipFile, source: Path, arcname: str
) -> None:
    info = zipfile.ZipInfo(arcname.replace("\\", "/"), FIXED_ZIP_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    with source.open("rb") as input_stream, archive.open(info, "w") as output_stream:
        copy_stream(input_stream, output_stream)


def zip_directory(source_dir: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for path in sorted(source_dir.rglob("*")):
            if path.is_file():
                add_file_to_zip(
                    archive, path, path.relative_to(source_dir).as_posix()
                )


def collect_stage_files(stage_dir: Path) -> list[dict]:
    entries: list[dict] = []
    for path in sorted(stage_dir.rglob("*")):
        if not path.is_file() or path.name == "kit-info.json":
            continue
        entries.append(
            {
                "path": path.relative_to(stage_dir).as_posix(),
                "size_bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
        )
    return entries


def write_readme(path: Path, version: str) -> None:
    path.write_text(
        f"""TAIJIFU MASTERS — KIT DE PLAYTEST EXTERNO {version}

CONTEÚDO
- builds/windows/{WINDOWS_ZIP_NAME}
- builds/web/{WEB_ZIP_NAME}
- docs/FIRST-PLAYABLE-PLAYTEST.md
- docs/FIRST-PLAYABLE-PLAYTEST-AGGREGATION.md
- tools/aggregate_first_playable_reports.py
- manifests/kit-info.json

BASE CANÔNICA DE ASSETS
- snapshot: assets-first-playable-v1.0.0
- Lian Wu: 45 frames / 10 animações
- Training Rival: 44 frames / 10 animações
- total: 89 frames / 20 animações
- cenário: Mountain Dojo Night / 3 layers
- snapshot imutável e verificado antes das builds Windows e Web

FLUXO DO TESTADOR
1. Windows: confira o SHA-256, extraia o ZIP e execute o arquivo .exe.
2. Web: extraia o ZIP e sirva a pasta por HTTP; não abra index.html por file://.
3. Jogue Aprendiz, Discípulo e Mestre.
4. Responda à pergunta de equilíbrio após cada partida.
5. Use COPIAR RELATÓRIO DO PLAYTEST e envie somente o JSON técnico.

CONSOLIDAÇÃO
python tools/aggregate_first_playable_reports.py <pasta-de-jsons> --output-dir resumo

PRIVACIDADE
A coleta é local. Nenhum relatório é enviado automaticamente.
Não inclua nome, e-mail, credenciais ou dados pessoais nos JSONs.

Assinatura: {SIGNATURE}
""",
        encoding="utf-8",
    )


def prepare_paths(args: argparse.Namespace) -> dict[str, Path]:
    root = args.project_root.resolve()
    output_dir = (args.output_dir or root / "dist").resolve()
    return {
        "root": root,
        "output": output_dir,
        "windows_zip": (
            args.windows_zip or root / "dist" / WINDOWS_ZIP_NAME
        ).resolve(),
        "windows_checksum": (
            args.windows_checksum
            or root / "dist" / f"{WINDOWS_ZIP_NAME}.sha256"
        ).resolve(),
        "windows_manifest": (
            args.windows_manifest or root / "windows-build" / "build-info.json"
        ).resolve(),
        "web_build": (args.web_build or root / "web-build").resolve(),
    }


def build_kit(args: argparse.Namespace) -> dict:
    paths = prepare_paths(args)
    root = paths["root"]
    project_file = root / "project.godot"
    version = project_value(project_file, "config/version")

    required_files = [
        paths["windows_zip"],
        paths["windows_checksum"],
        paths["windows_manifest"],
        paths["web_build"] / "build-info.json",
        paths["web_build"] / "web-validation-info.json",
        root / "docs" / "FIRST-PLAYABLE-PLAYTEST.md",
        root / "docs" / "FIRST-PLAYABLE-PLAYTEST-AGGREGATION.md",
        root / "tools" / "playtest" / "aggregate_first_playable_reports.py",
    ]
    missing = [str(path) for path in required_files if not path.exists()]
    if missing:
        raise FileNotFoundError("Componentes ausentes: " + ", ".join(missing))

    windows_sha = validate_checksum(
        paths["windows_zip"], paths["windows_checksum"]
    )
    windows_manifest = validate_build_manifest(
        paths["windows_manifest"], platform="windows", version=version
    )
    web_manifest = validate_build_manifest(
        paths["web_build"] / "build-info.json", platform="web", version=version
    )
    windows_snapshot = windows_manifest["asset_snapshot"]
    web_snapshot = web_manifest["asset_snapshot"]
    if windows_snapshot != web_snapshot:
        raise ValueError("Windows e Web foram construídos com snapshots de assets diferentes")
    if windows_manifest.get("git_sha") != web_manifest.get("git_sha"):
        raise ValueError("Windows e Web foram construídos a partir de commits diferentes")
    git_sha = windows_manifest.get("git_sha", "unknown")

    output_dir = paths["output"]
    output_dir.mkdir(parents=True, exist_ok=True)
    kit_name = f"Taijifu-Masters-External-Playtest-Kit-{version}.zip"
    kit_zip = output_dir / kit_name
    kit_checksum = output_dir / f"{kit_name}.sha256"

    temporary_context = None
    if args.stage_dir:
        stage_dir = args.stage_dir.resolve()
        if stage_dir.exists():
            shutil.rmtree(stage_dir)
        stage_dir.mkdir(parents=True)
    else:
        temporary_context = tempfile.TemporaryDirectory(prefix="taijifu-playtest-kit-")
        stage_dir = Path(temporary_context.name)

    try:
        (stage_dir / "builds" / "windows").mkdir(parents=True)
        (stage_dir / "builds" / "web").mkdir(parents=True)
        (stage_dir / "docs").mkdir(parents=True)
        (stage_dir / "tools").mkdir(parents=True)
        (stage_dir / "manifests").mkdir(parents=True)

        shutil.copy2(
            paths["windows_zip"],
            stage_dir / "builds" / "windows" / WINDOWS_ZIP_NAME,
        )
        shutil.copy2(
            paths["windows_checksum"],
            stage_dir / "builds" / "windows" / f"{WINDOWS_ZIP_NAME}.sha256",
        )

        web_zip = stage_dir / "builds" / "web" / WEB_ZIP_NAME
        zip_directory(paths["web_build"], web_zip)
        web_checksum = web_zip.with_suffix(web_zip.suffix + ".sha256")
        web_checksum.write_text(portable_checksum(web_zip), encoding="utf-8")
        web_sha = validate_checksum(web_zip, web_checksum)

        shutil.copy2(
            root / "docs" / "FIRST-PLAYABLE-PLAYTEST.md",
            stage_dir / "docs" / "FIRST-PLAYABLE-PLAYTEST.md",
        )
        shutil.copy2(
            root / "docs" / "FIRST-PLAYABLE-PLAYTEST-AGGREGATION.md",
            stage_dir / "docs" / "FIRST-PLAYABLE-PLAYTEST-AGGREGATION.md",
        )
        shutil.copy2(
            root / "tools" / "playtest" / "aggregate_first_playable_reports.py",
            stage_dir / "tools" / "aggregate_first_playable_reports.py",
        )
        shutil.copy2(
            paths["windows_manifest"],
            stage_dir / "manifests" / "windows-build-info.json",
        )
        shutil.copy2(
            paths["web_build"] / "build-info.json",
            stage_dir / "manifests" / "web-build-info.json",
        )
        shutil.copy2(
            paths["web_build"] / "web-validation-info.json",
            stage_dir / "manifests" / "web-validation-info.json",
        )
        write_readme(stage_dir / "README-PLAYTEST.txt", version)

        entries = collect_stage_files(stage_dir)
        manifest = {
            "schema": KIT_SCHEMA,
            "product": "Taijifu Masters",
            "signature": SIGNATURE,
            "channel": "external-playtest",
            "version": version,
            "build_id": f"{version}+{str(git_sha)[:12]}",
            "git_sha": git_sha,
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "privacy": "local_only_no_automatic_upload",
            "telemetry_schema": TELEMETRY_SCHEMA,
            "platforms": ["windows-x86_64", "web"],
            "asset_snapshot": windows_snapshot,
            "asset_snapshot_consistent_across_builds": True,
            "build_checksums": {
                "windows_sha256": windows_sha,
                "web_sha256": web_sha,
            },
            "files": entries,
            "totals": {
                "file_count": len(entries),
                "size_bytes": sum(entry["size_bytes"] for entry in entries),
            },
        }
        manifest_path = stage_dir / "manifests" / "kit-info.json"
        manifest_path.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        if kit_zip.exists():
            kit_zip.unlink()
        if kit_checksum.exists():
            kit_checksum.unlink()
        zip_directory(stage_dir, kit_zip)
        kit_checksum.write_text(portable_checksum(kit_zip), encoding="utf-8")
        kit_sha = validate_checksum(kit_zip, kit_checksum)
        return {
            "version": version,
            "kit_zip": str(kit_zip),
            "kit_checksum": str(kit_checksum),
            "kit_sha256": kit_sha,
            "kit_size_bytes": kit_zip.stat().st_size,
            "stage_dir": str(stage_dir) if args.stage_dir else "temporary",
            "manifest": manifest,
        }
    finally:
        if temporary_context is not None:
            temporary_context.cleanup()


def run(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        result = build_kit(args)
    except (FileNotFoundError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"PLAYTEST_KIT_FAILED: {error}", file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "version": result["version"],
                "kit_zip": result["kit_zip"],
                "kit_checksum": result["kit_checksum"],
                "kit_sha256": result["kit_sha256"],
                "kit_size_bytes": result["kit_size_bytes"],
                "asset_snapshot": result["manifest"]["asset_snapshot"]["tag"],
                "fighter_frames": result["manifest"]["asset_snapshot"]["fighter_frames"],
                "stage": result["manifest"]["asset_snapshot"]["stage"],
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
