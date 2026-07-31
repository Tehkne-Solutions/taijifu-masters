from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = (
    ROOT / "tools" / "playtest" / "create_first_playable_pilot_coordinator_pack.py"
)
SPEC = importlib.util.spec_from_file_location("pilot_coordinator_pack", MODULE_PATH)
pack = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(pack)


class Args:
    def __init__(self, root: Path, output: Path, stage: Path) -> None:
        self.project_root = root
        self.pilot_id = "pilot-09-r1"
        self.external_kit = root / "dist" / "Taijifu-Masters-External-Playtest-Kit-0.2.1-playtest.zip"
        self.external_kit_checksum = Path(str(self.external_kit) + ".sha256")
        self.output_dir = output
        self.stage_dir = stage


def build_fixture(root: Path) -> Args:
    (root / "dist").mkdir(parents=True)
    (root / "docs").mkdir()
    (root / "tools" / "playtest").mkdir(parents=True)
    pilot_dir = root / "playtest" / "pilots" / "pilot-09-r1"
    pilot_dir.mkdir(parents=True)
    (root / "project.godot").write_text(
        '[application]\nconfig/version="0.2.1-playtest"\n', encoding="utf-8"
    )

    external = root / "dist" / "Taijifu-Masters-External-Playtest-Kit-0.2.1-playtest.zip"
    with zipfile.ZipFile(external, "w") as archive:
        archive.writestr("README-PLAYTEST.txt", "fixture")
    checksum = Path(str(external) + ".sha256")
    checksum.write_text(pack.portable_checksum(external), encoding="utf-8")

    plan = {
        "schema": pack.PLAN_SCHEMA,
        "signature": pack.SIGNATURE,
        "pilot_id": "pilot-09-r1",
        "build_version": "0.2.1-playtest",
        "participant_count": 6,
        "expected_total_matches": 36,
        "participants": [
            {"participant_id": f"TJFP-{index:03d}"} for index in range(1, 7)
        ],
    }
    (pilot_dir / "pilot-plan.json").write_text(
        json.dumps(plan), encoding="utf-8"
    )
    (pilot_dir / "pilot-plan.md").write_text("# Pilot\n", encoding="utf-8")
    (pilot_dir / "pilot-roster.csv").write_text(
        "participant_id\nTJFP-001\n", encoding="utf-8"
    )
    (pilot_dir / "pilot-observations.json").write_text(
        json.dumps(
            {
                "schema": pack.OBSERVATIONS_SCHEMA,
                "pilot_id": "pilot-09-r1",
                "observations": [],
            }
        ),
        encoding="utf-8",
    )
    (pilot_dir / "pilot-decisions.json").write_text(
        json.dumps(
            {
                "schema": pack.DECISIONS_SCHEMA,
                "pilot_id": "pilot-09-r1",
                "decisions": [],
            }
        ),
        encoding="utf-8",
    )
    (root / "docs" / "FIRST-PLAYABLE-PILOT-09.md").write_text(
        "# Protocol\n", encoding="utf-8"
    )
    for filename in (
        "run_first_playable_pilot.py",
        "first_playable_pilot.py",
        "aggregate_first_playable_reports.py",
    ):
        (root / "tools" / "playtest" / filename).write_text(
            "# fixture\n", encoding="utf-8"
        )
    return Args(root, root / "output", root / "stage")


class PilotCoordinatorPackTests(unittest.TestCase):
    def test_builds_pack_with_required_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            args = build_fixture(root)
            result = pack.build_pack(args)
            archive_path = Path(result["pack_zip"])
            self.assertTrue(archive_path.is_file())
            self.assertEqual(
                pack.validate_checksum(archive_path, Path(result["pack_checksum"])),
                result["pack_sha256"],
            )
            manifest = result["manifest"]
            self.assertEqual(manifest["schema"], pack.COORDINATOR_SCHEMA)
            self.assertTrue(manifest["templates_empty"])
            self.assertEqual(manifest["participant_count"], 6)
            required = {
                "README-COORDENADOR.txt",
                "game-kit/Taijifu-Masters-External-Playtest-Kit-0.2.1-playtest.zip",
                "game-kit/Taijifu-Masters-External-Playtest-Kit-0.2.1-playtest.zip.sha256",
                "pilot/pilot-plan.json",
                "pilot/pilot-roster.csv",
                "pilot/pilot-observations.json",
                "pilot/pilot-decisions.json",
                "docs/FIRST-PLAYABLE-PILOT-09.md",
                "tools/run_first_playable_pilot.py",
                "tools/first_playable_pilot.py",
                "tools/aggregate_first_playable_reports.py",
                "manifests/coordinator-pack-info.json",
            }
            with zipfile.ZipFile(archive_path) as archive:
                names = set(archive.namelist())
            self.assertTrue(required.issubset(names), required - names)

    def test_rejects_non_empty_observations_template(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            args = build_fixture(root)
            path = (
                root
                / "playtest"
                / "pilots"
                / "pilot-09-r1"
                / "pilot-observations.json"
            )
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["observations"] = [{"title": "fabricated"}]
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "resultados fabricados"):
                pack.build_pack(args)

    def test_rejects_duplicate_participant_codes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            args = build_fixture(root)
            path = root / "playtest" / "pilots" / "pilot-09-r1" / "pilot-plan.json"
            payload = json.loads(path.read_text(encoding="utf-8"))
            payload["participants"][1]["participant_id"] = "TJFP-001"
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicado"):
                pack.build_pack(args)


if __name__ == "__main__":
    unittest.main()
