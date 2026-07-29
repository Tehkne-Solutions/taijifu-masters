from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path


def run_release(pack: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    repo = Path(__file__).resolve().parents[2]
    return subprocess.run(
        [sys.executable, str(repo / "scripts/tgap_release_pack.py"), str(pack), "--version", "1.2.3", *extra],
        text=True,
        capture_output=True,
        check=False,
    )


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_pack(tmp_path: Path, *, approved: bool) -> Path:
    pack = tmp_path / "pack_release_fixture"
    (pack / "validation").mkdir(parents=True)
    (pack / "runtime").mkdir()
    (pack / "runtime" / "asset.txt").write_text("conteudo-estavel\n", encoding="utf-8")
    (pack / "manifest.json").write_text(json.dumps({"pack_id": "pack_release_fixture"}), encoding="utf-8")
    (pack / "validation" / "pipeline-report.json").write_text(
        json.dumps({"pipeline_passed": approved, "promotion_blocked": not approved}),
        encoding="utf-8",
    )
    return pack


def test_release_is_blocked_without_approved_pipeline(tmp_path: Path) -> None:
    pack = make_pack(tmp_path, approved=False)
    result = run_release(pack)
    assert result.returncode != 0
    assert not list((pack / "release").glob("*.zip")) if (pack / "release").exists() else True


def test_forced_release_is_marked_non_publishable(tmp_path: Path) -> None:
    pack = make_pack(tmp_path, approved=False)
    result = run_release(pack, "--force")
    assert result.returncode == 0, result.stderr or result.stdout
    manifest = next((pack / "release").glob("*.manifest.json"))
    data = json.loads(manifest.read_text(encoding="utf-8"))
    assert data.get("forced") is True or data.get("approved") is False


def test_release_zip_is_deterministic(tmp_path: Path) -> None:
    pack = make_pack(tmp_path, approved=True)
    first = run_release(pack)
    assert first.returncode == 0, first.stderr or first.stdout
    archive = next((pack / "release").glob("*.zip"))
    first_hash = sha256(archive)
    archive.unlink()
    second = run_release(pack)
    assert second.returncode == 0, second.stderr or second.stdout
    archive = next((pack / "release").glob("*.zip"))
    assert sha256(archive) == first_hash
