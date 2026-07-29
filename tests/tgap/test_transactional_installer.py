from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
INSTALLER = REPO / "scripts/tgap_install_bundle.py"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_bundle(root: Path, version: str = "1.0.0") -> Path:
    bundle = root / f"taijifu-masters-tgap-{version}.zip"
    with zipfile.ZipFile(bundle, "w") as archive:
        archive.writestr("packs/pack_00_test/data.txt", "conteudo-v1")
    manifest = {
        "schema": "tgap/bundle/v1",
        "project_id": "taijifu-masters",
        "bundle_version": version,
        "registry_version": "1.0.0",
        "generated_at": "2026-07-29T00:00:00+00:00",
        "forced": False,
        "publishable": True,
        "integration_plan": ["pack_00_test"],
        "packs": [{
            "pack_id": "pack_00_test",
            "version": "1.0.0",
            "asset_class": "prop",
            "file_count": 1,
            "sha256": hashlib.sha256(b"conteudo-v1").hexdigest(),
        }],
        "archive": {"file_count": 1, "sha256": digest(bundle)},
    }
    bundle.with_suffix(".manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    return bundle


def run(*args: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(INSTALLER), *(str(arg) for arg in args)],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )


def test_installs_bundle_and_updates_catalog(tmp_path: Path) -> None:
    bundle = write_bundle(tmp_path)
    runtime = tmp_path / "runtime"
    result = run(bundle, "--runtime-root", runtime, "--keep-backup")
    assert result.returncode == 0, result.stdout + result.stderr
    assert (runtime / "tgap-current/packs/pack_00_test/data.txt").read_text() == "conteudo-v1"
    catalog = json.loads((runtime / "tgap-catalog.json").read_text())
    assert catalog["generation"] == 1
    assert catalog["active_bundle"]["sha256"] == digest(bundle)


def test_rejects_non_publishable_bundle(tmp_path: Path) -> None:
    bundle = write_bundle(tmp_path)
    manifest_path = bundle.with_suffix(".manifest.json")
    manifest = json.loads(manifest_path.read_text())
    manifest["publishable"] = False
    manifest_path.write_text(json.dumps(manifest))
    result = run(bundle, "--runtime-root", tmp_path / "runtime")
    assert result.returncode != 0


def test_detects_collision_without_replace(tmp_path: Path) -> None:
    bundle = write_bundle(tmp_path)
    runtime = tmp_path / "runtime"
    active = runtime / "tgap-current/packs/pack_00_test"
    active.mkdir(parents=True)
    (active / "data.txt").write_text("conteudo-antigo")
    result = run(bundle, "--runtime-root", runtime)
    assert result.returncode != 0
    assert (active / "data.txt").read_text() == "conteudo-antigo"


def test_explicit_rollback_restores_previous_generation(tmp_path: Path) -> None:
    bundle = write_bundle(tmp_path)
    runtime = tmp_path / "runtime"
    first = run(bundle, "--runtime-root", runtime, "--keep-backup")
    assert first.returncode == 0

    active_file = runtime / "tgap-current/packs/pack_00_test/data.txt"
    active_file.write_text("alterado")
    second = run(bundle, "--runtime-root", runtime, "--allow-replace", "--keep-backup")
    assert second.returncode == 0
    transaction_id = json.loads(second.stdout)["transaction_id"]

    rolled = run("--runtime-root", runtime, "--rollback", transaction_id)
    assert rolled.returncode == 0, rolled.stdout + rolled.stderr
    assert active_file.read_text() == "alterado"
