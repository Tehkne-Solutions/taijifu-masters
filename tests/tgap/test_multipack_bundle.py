from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BUNDLER = REPO / "scripts" / "tgap_bundle_packs.py"


def run(*args: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(BUNDLER), *(str(arg) for arg in args)],
        cwd=REPO,
        text=True,
        capture_output=True,
        check=False,
    )


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_plan_only_uses_registry_integration_order(tmp_path: Path) -> None:
    result = run("--version", "1.0.0", "--output-dir", tmp_path, "--plan-only")
    assert result.returncode == 0, result.stdout + result.stderr
    plan = json.loads((tmp_path / "taijifu-masters-tgap-1.0.0.plan.json").read_text(encoding="utf-8"))
    assert plan["integration_plan"] == ["pack_01_lian_wu"]
    assert plan["packs"][0]["integration_order"] == 100


def test_bundle_is_blocked_when_registered_pack_pipeline_is_not_approved(tmp_path: Path) -> None:
    result = run("--version", "1.0.1", "--output-dir", tmp_path)
    assert result.returncode == 1
    report = json.loads((tmp_path / "taijifu-masters-tgap-1.0.1.bundle-report.json").read_text(encoding="utf-8"))
    assert report["bundle_created"] is False
    assert report["promotion_blocked"] is True
    assert report["packs"][0]["pipeline_approved"] is False


def test_forced_diagnostic_bundle_is_deterministic_and_not_publishable(tmp_path: Path) -> None:
    first_dir = tmp_path / "first"
    second_dir = tmp_path / "second"
    first = run("--version", "1.0.2", "--output-dir", first_dir, "--force")
    second = run("--version", "1.0.2", "--output-dir", second_dir, "--force")
    assert first.returncode == 0, first.stdout + first.stderr
    assert second.returncode == 0, second.stdout + second.stderr

    archive_a = first_dir / "taijifu-masters-tgap-1.0.2.zip"
    archive_b = second_dir / "taijifu-masters-tgap-1.0.2.zip"
    assert digest(archive_a) == digest(archive_b)

    manifest = json.loads((first_dir / "taijifu-masters-tgap-1.0.2.manifest.json").read_text(encoding="utf-8"))
    assert manifest["forced"] is True
    assert manifest["publishable"] is False
    assert manifest["archive"]["sha256"] == digest(archive_a)
