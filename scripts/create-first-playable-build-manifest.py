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
ASSET_CONTRACT_PATH = Path("config/v2-arena-intake-contract.json")
EXPECTED_ASSET_SNAPSHOT = {
    "tag": "assets-first-playable-v1.0.0",
    "commit": "b6767d9d30fb2980de5d0a57a8a4c414b854cad5",
    "archive": "TAIJIFU_FIRST_PLAYABLE_ASSETS_v1.0.0.zip",
    "archive_sha256": "69b6b4641fb93bffa81555926887d44a0dfed5edaa4368b8a58a62f689bd58d2",
    "content_sha256": "b2b4e8e274cd1a819d3062c237907132b4067c3aac4a33ef2d7230e73f565eec",
    "fighter_frames": 89,
    "fighter_animations": 20,
    "stage": "mountain_dojo_night",
    "stage_layers": 3,
}


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


def asset_snapshot(root: Path) -> dict:
    contract_path = root / ASSET_CONTRACT_PATH
    if not contract_path.is_file():
        raise SystemExit(f"Missing First Playable asset contract: {contract_path}")
    contract = json.loads(contract_path.read_text(encoding="utf-8"))
    if contract.get("signature") != SIGNATURE:
        raise SystemExit("Invalid First Playable asset contract signature")

    snapshot_contract = contract.get("snapshot_contract") or {}
    actual = {
        "tag": contract.get("source_ref"),
        "commit": contract.get("source_commit"),
        "archive": contract.get("source_release_asset"),
        "archive_sha256": contract.get("source_release_sha256"),
        "content_sha256": contract.get("source_content_sha256"),
        "fighter_frames": snapshot_contract.get("fighter_frames"),
        "fighter_animations": snapshot_contract.get("fighter_animations"),
        "stage": contract.get("arena_id"),
        "stage_layers": snapshot_contract.get("stage_layers"),
    }
    if actual != EXPECTED_ASSET_SNAPSHOT:
        raise SystemExit(
            "First Playable asset snapshot diverged from frozen build baseline: "
            + json.dumps(actual, sort_keys=True)
        )
    return {
        "schema": "tehkne/taijifu-first-playable-asset-snapshot/v1",
        "signature": SIGNATURE,
        **actual,
        "immutable": bool((contract.get("import_policy") or {}).get("immutable_source_ref")),
        "source_pin_verified_by_build_gate": True,
    }


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
    snapshot = asset_snapshot(root)
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
        "asset_snapshot": snapshot,
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
            "canonical_89_frame_fighter_runtime",
            "mountain_dojo_night",
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
    print(json.dumps({
        **manifest["totals"],
        "asset_snapshot": snapshot["tag"],
        "fighter_frames": snapshot["fighter_frames"],
        "stage": snapshot["stage"],
    }, ensure_ascii=False))
    print(destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
