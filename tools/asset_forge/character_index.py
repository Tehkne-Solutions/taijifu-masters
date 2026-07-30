#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path

SCHEMA = "taijifu/character-production-index/v1"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build consolidated Taijifu character production index")
    parser.add_argument("--characters", type=Path, default=Path("asset-forge/characters"))
    parser.add_argument("--boards", type=Path, default=Path("artifacts/asset-forge/boards"))
    parser.add_argument("--budgets", type=Path, default=Path("artifacts/asset-forge/budgets"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/asset-forge/index"))
    args = parser.parse_args()

    entries = []
    for dna_path in sorted(args.characters.glob("*.json")):
        try:
            dna = json.loads(dna_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        character_id = dna.get("id", dna_path.stem)
        pack_id = dna.get("pack_id", "unknown")
        board_path = args.boards / character_id / "board.json"
        budget_path = args.budgets / f"{pack_id}.json"
        board = json.loads(board_path.read_text(encoding="utf-8")) if board_path.exists() else {}
        budget = json.loads(budget_path.read_text(encoding="utf-8")) if budget_path.exists() else {}
        entries.append({
            "id": character_id,
            "name": dna.get("name", character_id),
            "pack_id": pack_id,
            "progress": board.get("progress", 0),
            "current_stage": board.get("current_stage", "dna"),
            "blockers": board.get("blockers", ["production_board_missing"]),
            "budget_ok": budget.get("ok"),
            "board": str(board_path),
            "budget": str(budget_path),
        })

    report = {"schema": SCHEMA, "characters": entries, "count": len(entries)}
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "index.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    rows = []
    for item in entries:
        blockers = ", ".join(item["blockers"]) if item["blockers"] else "nenhum"
        budget = "OK" if item["budget_ok"] is True else "BLOQUEADO" if item["budget_ok"] is False else "AGUARDANDO"
        rows.append(
            "<tr>"
            f"<td>{html.escape(item['name'])}</td>"
            f"<td>{html.escape(item['pack_id'])}</td>"
            f"<td>{item['progress']}%</td>"
            f"<td>{html.escape(str(item['current_stage']))}</td>"
            f"<td>{html.escape(budget)}</td>"
            f"<td>{html.escape(blockers)}</td>"
            "</tr>"
        )
    page = f"""<!doctype html><html lang='pt-BR'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>Taijifu Production Index</title><style>body{{font-family:system-ui;margin:0;background:#0e1117;color:#e6edf3}}main{{max-width:1200px;margin:auto;padding:32px}}table{{width:100%;border-collapse:collapse;background:#161b22}}th,td{{padding:12px;border:1px solid #30363d;text-align:left}}th{{background:#21262d}}code{{color:#79c0ff}}</style></head><body><main><h1>Taijifu Character Production Index</h1><p>{len(entries)} personagem(ns) rastreado(s).</p><table><thead><tr><th>Personagem</th><th>Pack</th><th>Progresso</th><th>Etapa</th><th>Budget</th><th>Blockers</th></tr></thead><tbody>{''.join(rows)}</tbody></table></main></body></html>"""
    (args.output / "index.html").write_text(page, encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
