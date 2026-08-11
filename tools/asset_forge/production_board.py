#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "taijifu/character-production-board/v1"
STAGES = [
    "dna",
    "contracts",
    "sources",
    "processing",
    "technical_validation",
    "visual_review",
    "perceptual_gate",
    "approval",
    "godot_integration",
    "release",
]


def read_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def stage(ok: bool, state: str, detail: str, evidence: list[str] | None = None) -> dict:
    return {"ok": ok, "state": state, "detail": detail, "evidence": evidence or []}


def build_board(dna_path: Path, root: Path) -> dict:
    root = root.resolve()
    dna_path = dna_path if dna_path.is_absolute() else root / dna_path
    dna_path = dna_path.resolve()
    dna = read_json(dna_path)
    if not dna:
        raise ValueError(f"DNA ausente ou inválido: {dna_path}")

    character_id = dna["id"]
    pack_id = dna.get("pack_id", f"pack_01_{character_id}_base")
    sources = dna.get("sources", [])
    source_dir = root / "asset-forge" / "intake" / pack_id / "sources"
    missing_sources = [name for name in sources if not (source_dir / name).is_file()]

    contract_paths = [
        root / "asset-forge" / "packs" / f"{pack_id}.json",
        root / "asset-forge" / "intake" / f"{pack_id}.json",
        root / "asset-forge" / "review" / f"{pack_id}.json",
        root / "asset-forge" / "release" / f"{pack_id}.json",
    ]
    missing_contracts = [str(path.relative_to(root)) for path in contract_paths if not path.exists()]

    artifacts = root / "artifacts" / "asset-forge"
    review_dir = artifacts / "review" / pack_id
    release_report = read_json(artifacts / f"{pack_id}__release-pipeline.json")
    perceptual = read_json(review_dir / "perceptual-report.json")
    approval = read_json(review_dir / "approval.json")

    generated_dir = root / "assets" / "tgap" / pack_id
    processed = generated_dir.exists() and any(generated_dir.rglob("*.png"))
    technical_ok = bool(release_report and any(s.get("ok") for s in release_report.get("steps", [])))
    visual_ready = (review_dir / "index.html").exists()
    perceptual_ok = bool(perceptual and perceptual.get("ok"))
    approval_ok = bool(approval and approval.get("decision") == "approved")
    godot_ok = (generated_dir / "manifest.json").exists()
    released = bool(release_report and release_report.get("ready"))

    stages = {
        "dna": stage(True, "done", "Character DNA válido", [str(dna_path.relative_to(root))]),
        "contracts": stage(not missing_contracts, "done" if not missing_contracts else "blocked", "Contratos materializados" if not missing_contracts else f"Faltam {len(missing_contracts)} contratos", missing_contracts),
        "sources": stage(not missing_sources, "done" if not missing_sources else "blocked", "Fontes físicas recebidas" if not missing_sources else f"Faltam {len(missing_sources)} fontes", missing_sources),
        "processing": stage(processed, "done" if processed else "waiting", "PNGs processados" if processed else "Aguardando fontes e execução do pipeline"),
        "technical_validation": stage(technical_ok, "done" if technical_ok else "waiting", "Validação técnica registrada" if technical_ok else "Sem validação técnica aprovada"),
        "visual_review": stage(visual_ready, "ready" if visual_ready else "waiting", "Página de revisão disponível" if visual_ready else "Revisão visual ainda não gerada"),
        "perceptual_gate": stage(perceptual_ok, "done" if perceptual_ok else "waiting", "Gate perceptual aprovado" if perceptual_ok else "Gate perceptual pendente"),
        "approval": stage(approval_ok, "done" if approval_ok else "waiting", "Aprovação assinada" if approval_ok else "Aprovação humana pendente"),
        "godot_integration": stage(godot_ok, "done" if godot_ok else "waiting", "Manifest TGAP disponível" if godot_ok else "Integração Godot pendente"),
        "release": stage(released, "done" if released else "blocked", "Bundle oficial liberado" if released else "Release bloqueado"),
    }

    completed = sum(1 for item in stages.values() if item["ok"])
    blockers = [name for name, item in stages.items() if item["state"] == "blocked"]
    return {
        "schema": SCHEMA,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "character_id": character_id,
        "character_name": dna.get("name", character_id),
        "pack_id": pack_id,
        "progress": {"completed": completed, "total": len(STAGES), "percent": round(completed / len(STAGES) * 100)},
        "current_stage": next((name for name in STAGES if not stages[name]["ok"]), "complete"),
        "blockers": blockers,
        "stages": stages,
    }


def render_html(board: dict) -> str:
    cards = []
    for name in STAGES:
        item = board["stages"][name]
        evidence = "".join(f"<li>{html.escape(value)}</li>" for value in item["evidence"])
        cards.append(
            f'<section class="card {item["state"]}"><h2>{html.escape(name.replace("_", " ").title())}</h2>'
            f'<strong>{html.escape(item["state"].upper())}</strong><p>{html.escape(item["detail"])}</p>'
            f'{f"<ul>{evidence}</ul>" if evidence else ""}</section>'
        )
    return f"""<!doctype html><html lang='pt-BR'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Production Board — {html.escape(board['character_name'])}</title><style>
body{{font-family:system-ui,sans-serif;background:#10151d;color:#edf2f7;margin:0;padding:32px}}main{{max-width:1180px;margin:auto}}header{{display:flex;justify-content:space-between;gap:24px;align-items:end;flex-wrap:wrap}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px;margin-top:24px}}.card{{background:#18212d;border:1px solid #344255;border-radius:14px;padding:18px}}.done{{border-color:#3e8e62}}.blocked{{border-color:#b95252}}.waiting{{border-color:#8a7442}}.ready{{border-color:#467eb5}}strong{{font-size:.75rem;letter-spacing:.12em}}p,li{{color:#b8c3d1}}progress{{width:320px;max-width:100%;height:18px}}</style></head><body><main>
<header><div><small>{html.escape(board['pack_id'])}</small><h1>{html.escape(board['character_name'])}</h1><p>Etapa atual: <b>{html.escape(board['current_stage'])}</b></p></div><div><b>{board['progress']['percent']}%</b><br><progress max='100' value='{board['progress']['percent']}'></progress></div></header>
<div class='grid'>{''.join(cards)}</div></main></body></html>"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Taijifu character production board")
    parser.add_argument("dna", type=Path)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    try:
        board = build_board(args.dna, args.root)
    except (ValueError, KeyError) as exc:
        print(json.dumps({"schema": SCHEMA, "ok": False, "error": str(exc)}, ensure_ascii=False))
        return 14

    root = args.root.resolve()
    output = args.output or root / "artifacts" / "asset-forge" / "boards" / board["character_id"]
    output = output if output.is_absolute() else root / output
    output.mkdir(parents=True, exist_ok=True)
    (output / "board.json").write_text(json.dumps(board, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (output / "index.html").write_text(render_html(board), encoding="utf-8")
    print(json.dumps(board, ensure_ascii=False))
    return 0 if not args.strict or not board["blockers"] else 15


if __name__ == "__main__":
    raise SystemExit(main())
