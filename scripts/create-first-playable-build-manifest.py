#!/usr/bin/env python3
"""Generate a traceable manifest for Taijifu Masters external playtest builds."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "tehkne/taijifu-first-playable-build/v1"
TELEMETRY_SCHEMA = "tehkne/taijifu-match-telemetry/v3"
EXPECTED_MAIN_SCENE = "res://scenes/vertical_slice/first_playable_menu.tscn"
SIGNATURE = "Tehkné Solutions"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def project_value(project_file: Path, key: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}=\"([^\"]+)\"$", re.MULTILINE)
    match = pattern.search(project_file.read_text(encoding="utf-8"))
    if not match:
        raise RuntimeError(f"Missing {key} in {project_file}")
    return match.group(1)


def git_sha(root: Path) -> str:
    explicit = os.environ.get("GITHUB_SHA") or os.environ.get("BUILD_GIT_SHA")
    if explicit:
        return explicit
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def collect_files(output_dir: Path) -> list[dict]:
    files: list[dict] = []
    for path in sorted(output_dir.rglob("*")):
        if not path.is_file() or path.name == "build-info.json":
            continue
        files.append(
            {
                "path": path.relative_to(output_dir).as_posix(),
                "size_bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
        )
    return files


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", required=True, choices=["web", "windows"])
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    root = args.project_root.resolve()
    output_dir = args.output_dir.resolve()
    project_file = root / "project.godot"
    if not output_dir.is_dir():
        raise SystemExit(f"Output directory does not exist: {output_dir}")

    version = project_value(project_file, "config/version")
    main_scene = project_value(project_file, "run/main_scene")
    if main_scene != EXPECTED_MAIN_SCENE:
        raise SystemExit(f"Unexpected main scene: {main_scene}")

    files = collect_files(output_dir)
    if not files:
        raise SystemExit(f"No build files found in {output_dir}")

    commit = git_sha(root)
    manifest = {
        "schema": SCHEMA,
        "product": "Taijifu Masters",
        "signature": SIGNATURE,
        "channel": "external-playtest",
        "version": version,
        "build_id": f"{version}+{commit[:12]}",
        "git_sha": commit,
        "platform": args.platform,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "main_scene": main_scene,
        "battle_scene": "res://scenes/vertical_slice/first_playable.tscn",
        "telemetry": {
            "schema": TELEMETRY_SCHEMA,
            "storage": "user://telemetry",
            "privacy": "local_only",
            "automatic_upload": False,
            "post_match_balance_feedback": True,
            "report_copy": True,
        },
        "features": [
            "first_playable_menu",
            "lian_wu_vs_training_rival",
            "triple_path_ruins",
            "tactical_ai_three_difficulties",
            "pause_result_rematch_flow",
            "local_playtest_telemetry",
            "post_match_balance_feedback",
            "offline_report_aggregation",
        ],
        "files": files,
        "totals": {
            "file_count": len(files),
            "size_bytes": sum(item["size_bytes"] for item in files),
        },
    }
    destination = output_dir / "build-info.json"
    destination.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest["totals"], ensure_ascii=False))
    print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
