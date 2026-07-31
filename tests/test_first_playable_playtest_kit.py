from __future__ import annotations

import hashlib
import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "playtest" / "create_first_playable_playtest_kit.py"
SPEC = importlib.util.spec_from_file_location("first_playable_kit", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
kit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(kit)


class FirstPlayablePlaytestKitTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "project"
        self.output = self.root / "release-output"
        self.stage = self.root / "kit-stage"
        for directory in (
            self.root / "dist",
            self.root / "windows-build",
            self.root / "web-build",
            self.root / "docs",
            self.root / "tools" / "playtest",
        ):
            directory.mkdir(parents=True, exist_ok=True)

        (self.root / "project.godot").write_text(
            '[application]\nconfig/version="0.2.1-playtest"\n', encoding="utf-8"
        )
        (self.root / "docs" / "FIRST-PLAYABLE-PLAYTEST.md").write_text(
            "Playtest\nTehkné Solutions\n", encoding="utf-8"
        )
        (
            self.root
            / "docs"
            / "FIRST-PLAYABLE-PLAYTEST-AGGREGATION.md"
        ).write_text("Aggregation\nTehkné Solutions\n", encoding="utf-8")
        (
            self.root
            / "tools"
            / "playtest"
            / "aggregate_first_playable_reports.py"
        ).write_text("# Tehkné Solutions\n", encoding="utf-8")

        self.windows_zip = self.root / "dist" / kit.WINDOWS_ZIP_NAME
        with zipfile.ZipFile(self.windows_zip, "w") as archive:
            archive.writestr("Taijifu-Masters-First-Playable.exe", b"MZ-test")
        self.windows_checksum = self.windows_zip.with_suffix(".zip.sha256")
        self.windows_checksum.write_text(
            kit.portable_checksum(self.windows_zip), encoding="utf-8"
        )

        self.windows_manifest = self.root / "windows-build" / "build-info.json"
        self.windows_manifest.write_text(
            json.dumps(self.build_manifest("windows")), encoding="utf-8"
        )

        (self.root / "web-build" / "index.html").write_text(
            "<html><canvas></canvas></html>", encoding="utf-8"
        )
        (self.root / "web-build" / "index.wasm").write_bytes(b"wasm-test")
        (self.root / "web-build" / "build-info.json").write_text(
            json.dumps(self.build_manifest("web")), encoding="utf-8"
        )
        (self.root / "web-build" / "web-validation-info.json").write_text(
            json.dumps(
                {
                    "product": "Taijifu Masters",
                    "publisher": "Tehkné Solutions",
                    "web_experience": {"responsive_shell": True},
                }
            ),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp.cleanup()

    def build_manifest(self, platform: str) -> dict:
        return {
            "schema": kit.BUILD_SCHEMA,
            "product": "Taijifu Masters",
            "signature": "Tehkné Solutions",
            "channel": "external-playtest",
            "version": "0.2.1-playtest",
            "build_id": "0.2.1-playtest+abc123",
            "git_sha": "abc123def456",
            "platform": platform,
            "telemetry": {
                "schema": kit.TELEMETRY_SCHEMA,
                "privacy": "local_only",
                "automatic_upload": False,
            },
            "files": [],
            "totals": {"file_count": 1, "size_bytes": 10},
        }

    def run_kit(self) -> int:
        return kit.run(
            [
                "--project-root",
                str(self.root),
                "--output-dir",
                str(self.output),
                "--stage-dir",
                str(self.stage),
            ]
        )

    def test_builds_traceable_playtest_kit(self) -> None:
        self.assertEqual(self.run_kit(), 0)
        kit_zip = self.output / "Taijifu-Masters-External-Playtest-Kit-0.2.1-playtest.zip"
        kit_checksum = kit_zip.with_suffix(".zip.sha256")
        self.assertTrue(kit_zip.is_file())
        self.assertTrue(kit_checksum.is_file())
        self.assertEqual(kit.validate_checksum(kit_zip, kit_checksum), kit.sha256(kit_zip))

        expected_entries = {
            f"builds/windows/{kit.WINDOWS_ZIP_NAME}",
            f"builds/windows/{kit.WINDOWS_ZIP_NAME}.sha256",
            f"builds/web/{kit.WEB_ZIP_NAME}",
            f"builds/web/{kit.WEB_ZIP_NAME}.sha256",
            "docs/FIRST-PLAYABLE-PLAYTEST.md",
            "docs/FIRST-PLAYABLE-PLAYTEST-AGGREGATION.md",
            "tools/aggregate_first_playable_reports.py",
            "manifests/windows-build-info.json",
            "manifests/web-build-info.json",
            "manifests/web-validation-info.json",
            "manifests/kit-info.json",
            "README-PLAYTEST.txt",
        }
        with zipfile.ZipFile(kit_zip) as archive:
            names = set(archive.namelist())
            self.assertTrue(expected_entries.issubset(names))
            manifest = json.loads(
                archive.read("manifests/kit-info.json").decode("utf-8")
            )
            readme = archive.read("README-PLAYTEST.txt").decode("utf-8")
            web_zip_bytes = archive.read(f"builds/web/{kit.WEB_ZIP_NAME}")

        self.assertEqual(manifest["schema"], kit.KIT_SCHEMA)
        self.assertEqual(manifest["version"], "0.2.1-playtest")
        self.assertEqual(manifest["signature"], "Tehkné Solutions")
        self.assertEqual(manifest["telemetry_schema"], kit.TELEMETRY_SCHEMA)
        self.assertEqual(manifest["privacy"], "local_only_no_automatic_upload")
        self.assertGreaterEqual(manifest["totals"]["file_count"], 11)
        self.assertIn("Nenhum relatório é enviado automaticamente", readme)
        self.assertEqual(
            hashlib.sha256(web_zip_bytes).hexdigest(),
            manifest["build_checksums"]["web_sha256"],
        )

        with zipfile.ZipFile(self.stage / "builds" / "web" / kit.WEB_ZIP_NAME) as web_archive:
            self.assertIn("index.html", web_archive.namelist())
            self.assertIn("build-info.json", web_archive.namelist())

    def test_rejects_tampered_windows_checksum(self) -> None:
        self.windows_checksum.write_text(
            f"{'0' * 64}  {kit.WINDOWS_ZIP_NAME}\n", encoding="utf-8"
        )
        self.assertEqual(self.run_kit(), 2)
        self.assertFalse(
            (
                self.output
                / "Taijifu-Masters-External-Playtest-Kit-0.2.1-playtest.zip"
            ).exists()
        )

    def test_rejects_nonportable_checksum_reference(self) -> None:
        self.windows_checksum.write_text(
            f"{kit.sha256(self.windows_zip)}  /tmp/{kit.WINDOWS_ZIP_NAME}\n",
            encoding="utf-8",
        )
        self.assertEqual(self.run_kit(), 2)


if __name__ == "__main__":
    unittest.main()
