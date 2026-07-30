from __future__ import annotations

import json
from pathlib import Path

from tools.asset_forge.production_board import STAGES, build_board, render_html


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_board_reports_real_blockers(tmp_path: Path) -> None:
    dna_path = tmp_path / "asset-forge/characters/test_master.json"
    write_json(
        dna_path,
        {
            "schema": "taijifu/character-dna/v1",
            "id": "test_master",
            "name": "Test Master",
            "pack_id": "pack_90_test_master_base",
            "sources": ["master_raw.png", "turnaround_raw.png"],
        },
    )

    board = build_board(dna_path, tmp_path)

    assert board["progress"]["total"] == len(STAGES)
    assert board["current_stage"] == "contracts"
    assert board["stages"]["sources"]["state"] == "blocked"
    assert board["stages"]["release"]["ok"] is False
    assert "contracts" in board["blockers"]
    assert "sources" in board["blockers"]


def test_board_advances_when_evidence_exists(tmp_path: Path) -> None:
    dna_path = tmp_path / "asset-forge/characters/test_master.json"
    pack_id = "pack_90_test_master_base"
    write_json(dna_path, {"id": "test_master", "name": "Test Master", "pack_id": pack_id, "sources": ["master_raw.png"]})

    for section in ("packs", "intake", "review", "release"):
        write_json(tmp_path / f"asset-forge/{section}/{pack_id}.json", {"pack_id": pack_id})
    source = tmp_path / f"asset-forge/intake/{pack_id}/sources/master_raw.png"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_bytes(b"png")

    board = build_board(dna_path, tmp_path)

    assert board["stages"]["contracts"]["ok"] is True
    assert board["stages"]["sources"]["ok"] is True
    assert board["current_stage"] == "processing"
    assert "Production Board" in render_html(board)
    assert "Test Master" in render_html(board)
