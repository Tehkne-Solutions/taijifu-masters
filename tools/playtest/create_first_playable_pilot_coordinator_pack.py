#!/usr/bin/env python3
"""Create the coordinator pack for the Taijifu Masters First Playable pilot.

The coordinator pack wraps the already-audited external game kit with the
anonymous pilot plan, hardened intake/triage tools, empty evidence templates and
operational documentation. It refuses fabricated observations or decisions.

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
from typing import Any, BinaryIO

SIGNATURE = "Tehkné Solutions"
COORDINATOR_SCHEMA = "tehkne/taijifu-first-playable-pilot-coordinator-pack/v1"
PLAN_SCHEMA = "tehkne/taijifu-first-playable-pilot-plan/v1"
OBSERVATIONS_SCHEMA = "tehkne/taijifu-first-playable-observations/v1"
DECISIONS_SCHEMA = "tehkne/taijifu-first-playable-decisions/v1"
FIXED_ZIP_TIME = (2020, 1, 1, 0, 0, 0)
DEFAULT_PILOT_ID = "pilot-09-r1"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Monta o pacote privado de coordenação do piloto externo."
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
    )
    parser.add_argument("--pilot-id", default=DEFAULT_PILOT_ID)
    parser.add_argument("--external-kit", type=Path)
    parser.add_argument("--external-kit-checksum", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--stage-dir", type=Path)
    return parser.parse_args(argv)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def portable_checksum(path: Path) -> str:
    return f"{sha256(path)}  {path.name}\n"


def validate_checksum(archive: Path, checksum_path: Path) -> str:
    raw = checksum_path.read_text(encoding="utf-8").strip()
    parts = raw.split(maxsplit=1)
    if len(parts) != 2:
        raise ValueError(f"Checksum inválido: {checksum_path}")
    expected, referenced = parts
    referenced = referenced.lstrip("*")
    if referenced != archive.name:
        raise ValueError(
            f"Checksum referencia {referenced}, esperado {archive.name}"
        )
    if "/" in referenced or "\\" in referenced:
        raise ValueError(f"Checksum não portátil: {referenced}")
    actual = sha256(archive)
    if actual != expected:
        raise ValueError(f"SHA-256 divergente para {archive}")
    return actual


def project_version(project_file: Path) -> str:
    pattern = re.compile(r'^config/version="([^"]+)"$', re.MULTILINE)
    match = pattern.search(project_file.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"config/version ausente em {project_file}")
    return match.group(1)


def read_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path}: raiz JSON deve ser objeto")
    return payload


def validate_pilot_contract(pilot_dir: Path, pilot_id: str, version: str) -> dict[str, Any]:
    plan_path = pilot_dir / "pilot-plan.json"
    observations_path = pilot_dir / "pilot-observations.json"
    decisions_path = pilot_dir / "pilot-decisions.json"
    plan = read_json(plan_path)
    observations = read_json(observations_path)
    decisions = read_json(decisions_path)

    if plan.get("schema") != PLAN_SCHEMA:
        raise ValueError("Schema do plano oficial incompatível")
    if plan.get("pilot_id") != pilot_id:
        raise ValueError("pilot_id divergente no plano oficial")
    if plan.get("build_version") != version:
        raise ValueError("build_version divergente no plano oficial")
    if plan.get("signature") != SIGNATURE:
        raise ValueError("Assinatura inválida no plano oficial")
    participants = plan.get("participants", [])
    if not isinstance(participants, list) or len(participants) < 6:
        raise ValueError("Plano oficial deve possuir pelo menos 6 participantes")
    participant_ids = [
        str(item.get("participant_id", ""))
        for item in participants
        if isinstance(item, dict)
    ]
    if len(participant_ids) != len(set(participant_ids)):
        raise ValueError("Plano oficial contém participant_id duplicado")

    if observations.get("schema") != OBSERVATIONS_SCHEMA:
        raise ValueError("Schema do template de observações incompatível")
    if observations.get("pilot_id") != pilot_id:
        raise ValueError("pilot_id divergente no template de observações")
    if observations.get("observations") != []:
        raise ValueError("Template de observações contém resultados fabricados")

    if decisions.get("schema") != DECISIONS_SCHEMA:
        raise ValueError("Schema do template de decisões incompatível")
    if decisions.get("pilot_id") != pilot_id:
        raise ValueError("pilot_id divergente no template de decisões")
    if decisions.get("decisions") != []:
        raise ValueError("Template de decisões contém resultados fabricados")
    return plan


def copy_stream(source: BinaryIO, destination: BinaryIO) -> None:
    shutil.copyfileobj(source, destination, length=1024 * 1024)


def add_file_to_zip(archive: zipfile.ZipFile, source: Path, arcname: str) -> None:
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


def collect_files(stage_dir: Path) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for path in sorted(stage_dir.rglob("*")):
        if not path.is_file() or path.name == "coordinator-pack-info.json":
            continue
        entries.append(
            {
                "path": path.relative_to(stage_dir).as_posix(),
                "size_bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
        )
    return entries


def write_readme(path: Path, pilot_id: str, version: str, participant_count: int) -> None:
    path.write_text(
        f"""TAIJIFU MASTERS — PACOTE DO COORDENADOR

PILOTO: {pilot_id}
BUILD: {version}
VAGAS ANÔNIMAS: {participant_count}

USO
1. Confira o SHA-256 deste pacote.
2. Não envie este pacote inteiro aos participantes: ele contém o roster de coordenação.
3. Envie apenas game-kit/ e a atribuição individual TJFP-### correspondente.
4. Mantenha contatos e relatórios reais fora do GitHub.
5. Renomeie cada JSON recebido com o prefixo TJFP-###__.
6. Execute o intake pelo entrypoint endurecido.
7. Consolide e gere o backlog somente após corrigir todas as rejeições.

COMANDOS
python tools/run_first_playable_pilot.py intake <reports> --plan pilot/pilot-plan.json --output-dir results/intake --strict
python tools/aggregate_first_playable_reports.py <reports> --output-dir results/summary --fail-on-invalid
python tools/run_first_playable_pilot.py triage --plan pilot/pilot-plan.json --intake results/intake/pilot-intake-manifest.json --summary results/summary/first-playable-playtest-summary.json --observations pilot/pilot-observations.json --decisions pilot/pilot-decisions.json --output-dir results/triage --strict --fail-on-p0

PRIVACIDADE
- Nenhum dado real está incluído neste pacote.
- Os templates de observações e decisões estão vazios.
- Não versionar relatórios reais.
- Não inserir nome, e-mail, telefone, IP, senha, token ou credencial.

Assinatura: {SIGNATURE}
""",
        encoding="utf-8",
    )


def build_pack(args: argparse.Namespace) -> dict[str, Any]:
    root = args.project_root.resolve()
    version = project_version(root / "project.godot")
    pilot_id = args.pilot_id.strip()
    if not pilot_id:
        raise ValueError("pilot_id não pode ser vazio")

    external_name = f"Taijifu-Masters-External-Playtest-Kit-{version}.zip"
    external_kit = (
        args.external_kit or root / "dist" / external_name
    ).resolve()
    external_checksum = (
        args.external_kit_checksum
        or root / "dist" / f"{external_name}.sha256"
    ).resolve()
    output_dir = (args.output_dir or root / "dist").resolve()
    pilot_dir = root / "playtest" / "pilots" / pilot_id

    required = [
        external_kit,
        external_checksum,
        pilot_dir / "pilot-plan.json",
        pilot_dir / "pilot-plan.md",
        pilot_dir / "pilot-roster.csv",
        pilot_dir / "pilot-observations.json",
        pilot_dir / "pilot-decisions.json",
        root / "docs" / "FIRST-PLAYABLE-PILOT-09.md",
        root / "tools" / "playtest" / "run_first_playable_pilot.py",
        root / "tools" / "playtest" / "first_playable_pilot.py",
        root / "tools" / "playtest" / "aggregate_first_playable_reports.py",
    ]
    missing = [str(path) for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError("Componentes ausentes: " + ", ".join(missing))

    external_sha = validate_checksum(external_kit, external_checksum)
    plan = validate_pilot_contract(pilot_dir, pilot_id, version)
    output_dir.mkdir(parents=True, exist_ok=True)
    pack_name = f"Taijifu-Masters-Pilot-Coordinator-{pilot_id}-{version}.zip"
    pack_zip = output_dir / pack_name
    pack_checksum = output_dir / f"{pack_name}.sha256"

    temporary_context = None
    if args.stage_dir:
        stage_dir = args.stage_dir.resolve()
        if stage_dir.exists():
            shutil.rmtree(stage_dir)
        stage_dir.mkdir(parents=True)
    else:
        temporary_context = tempfile.TemporaryDirectory(prefix="taijifu-pilot-coordinator-")
        stage_dir = Path(temporary_context.name)

    try:
        for directory in ("game-kit", "pilot", "docs", "tools", "manifests"):
            (stage_dir / directory).mkdir(parents=True, exist_ok=True)

        shutil.copy2(external_kit, stage_dir / "game-kit" / external_kit.name)
        shutil.copy2(
            external_checksum,
            stage_dir / "game-kit" / external_checksum.name,
        )
        for filename in (
            "pilot-plan.json",
            "pilot-plan.md",
            "pilot-roster.csv",
            "pilot-observations.json",
            "pilot-decisions.json",
        ):
            shutil.copy2(pilot_dir / filename, stage_dir / "pilot" / filename)
        shutil.copy2(
            root / "docs" / "FIRST-PLAYABLE-PILOT-09.md",
            stage_dir / "docs" / "FIRST-PLAYABLE-PILOT-09.md",
        )
        shutil.copy2(
            root / "tools" / "playtest" / "run_first_playable_pilot.py",
            stage_dir / "tools" / "run_first_playable_pilot.py",
        )
        shutil.copy2(
            root / "tools" / "playtest" / "first_playable_pilot.py",
            stage_dir / "tools" / "first_playable_pilot.py",
        )
        shutil.copy2(
            root / "tools" / "playtest" / "aggregate_first_playable_reports.py",
            stage_dir / "tools" / "aggregate_first_playable_reports.py",
        )
        write_readme(
            stage_dir / "README-COORDENADOR.txt",
            pilot_id,
            version,
            int(plan.get("participant_count", 0)),
        )

        entries = collect_files(stage_dir)
        manifest = {
            "schema": COORDINATOR_SCHEMA,
            "product": "Taijifu Masters",
            "signature": SIGNATURE,
            "pilot_id": pilot_id,
            "build_version": version,
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "privacy": "anonymous_templates_only_no_real_results",
            "external_kit_sha256": external_sha,
            "participant_count": int(plan.get("participant_count", 0)),
            "expected_total_matches": int(plan.get("expected_total_matches", 0)),
            "templates_empty": True,
            "files": entries,
            "totals": {
                "file_count": len(entries),
                "size_bytes": sum(entry["size_bytes"] for entry in entries),
            },
        }
        manifest_path = stage_dir / "manifests" / "coordinator-pack-info.json"
        manifest_path.write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        if pack_zip.exists():
            pack_zip.unlink()
        if pack_checksum.exists():
            pack_checksum.unlink()
        zip_directory(stage_dir, pack_zip)
        pack_checksum.write_text(portable_checksum(pack_zip), encoding="utf-8")
        pack_sha = validate_checksum(pack_zip, pack_checksum)
        return {
            "pilot_id": pilot_id,
            "version": version,
            "pack_zip": str(pack_zip),
            "pack_checksum": str(pack_checksum),
            "pack_sha256": pack_sha,
            "pack_size_bytes": pack_zip.stat().st_size,
            "manifest": manifest,
        }
    finally:
        if temporary_context is not None:
            temporary_context.cleanup()


def run(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        result = build_pack(args)
    except (FileNotFoundError, ValueError, OSError, json.JSONDecodeError) as error:
        print(f"PILOT_COORDINATOR_PACK_FAILED: {error}", file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "pilot_id": result["pilot_id"],
                "version": result["version"],
                "pack_zip": result["pack_zip"],
                "pack_checksum": result["pack_checksum"],
                "pack_sha256": result["pack_sha256"],
                "pack_size_bytes": result["pack_size_bytes"],
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
