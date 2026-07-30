#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build(repo: Path, config_path: Path) -> dict[str, Any]:
    cfg = load_json(config_path)
    out = repo / cfg["output_dir"]
    out.mkdir(parents=True, exist_ok=True)
    assets = []
    missing = []
    for item in cfg["assets"]:
        source = repo / item["path"]
        record = dict(item)
        record["exists"] = source.is_file()
        if source.is_file():
            record["sha256"] = sha256(source)
            record["uri"] = source.resolve().as_uri()
        else:
            missing.append(item["path"])
        assets.append(record)

    cards = []
    for item in assets:
        title = html.escape(item.get("label", item["path"]))
        if item["exists"]:
            img = f'<img class="asset" src="{html.escape(item["uri"])}" alt="{title}">'
            state = '<span class="ok">presente</span>'
        else:
            img = '<div class="missing">ARQUIVO AUSENTE</div>'
            state = '<span class="blocked">ausente</span>'
        cards.append(f'''<article class="card" data-group="{html.escape(item.get("group", "other"))}">
<header><strong>{title}</strong>{state}</header>
<div class="viewport checker">{img}</div>
<code>{html.escape(item["path"])}</code>
</article>''')

    checklist = "".join(
        f'<label><input type="checkbox" name="{html.escape(key)}"> {html.escape(label)}</label>'
        for key, label in cfg["checklist"].items()
    )
    page = f'''<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Revisão — {html.escape(cfg["pack_id"])}</title>
<style>
:root{{--bg:#10141b;--panel:#18202b;--text:#eef4ff;--muted:#9eb0c8;--accent:#4ea1ff}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:14px system-ui,sans-serif}}
main{{max-width:1500px;margin:auto;padding:24px}}h1{{margin:0 0 6px}}.muted{{color:var(--muted)}}
.toolbar{{position:sticky;top:0;z-index:3;display:flex;gap:12px;align-items:center;padding:12px;background:#10141bee;backdrop-filter:blur(10px)}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}}.card{{background:var(--panel);border:1px solid #2b394a;border-radius:12px;padding:12px}}
.card header{{display:flex;justify-content:space-between;gap:12px;margin-bottom:8px}}.viewport{{height:360px;overflow:auto;display:grid;place-items:center;border-radius:8px}}
.checker{{background-color:#fff;background-image:linear-gradient(45deg,#bbb 25%,transparent 25%),linear-gradient(-45deg,#bbb 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#bbb 75%),linear-gradient(-45deg,transparent 75%,#bbb 75%);background-size:24px 24px;background-position:0 0,0 12px,12px -12px,-12px 0}}
.asset{{max-width:100%;max-height:100%;transform-origin:center;image-rendering:auto}}.missing{{color:#8b1d1d;font-weight:800}}.ok{{color:#74d99f}}.blocked{{color:#ff8585}}
.review{{margin-top:24px;background:var(--panel);padding:18px;border-radius:12px}}.checks{{display:grid;gap:9px;margin:14px 0}}button{{padding:10px 14px;border:0;border-radius:8px;font-weight:700;cursor:pointer}}
code{{display:block;color:var(--muted);margin-top:8px;overflow-wrap:anywhere}}
</style></head><body><main>
<h1>Revisão visual — {html.escape(cfg["pack_id"])}</h1>
<p class="muted">A página é evidência de inspeção, não aprovação automática. Ausentes: {len(missing)}.</p>
<div class="toolbar"><label>Zoom <input id="zoom" type="range" min="25" max="400" value="100"></label><button id="toggle">Alternar fundo</button><button id="reset">Resetar</button></div>
<section class="grid">{''.join(cards)}</section>
<section class="review"><h2>Checklist humano</h2><div class="checks">{checklist}</div>
<label>Revisor <input id="reviewer" autocomplete="name"></label>
<label>Observações <textarea id="notes" rows="4"></textarea></label>
<p><button id="export">Gerar approval-draft.json</button></p>
</section></main>
<script>
const imgs=[...document.querySelectorAll('.asset')]; const zoom=document.querySelector('#zoom');
zoom.oninput=()=>imgs.forEach(i=>i.style.transform=`scale(${{zoom.value/100}})`);
document.querySelector('#toggle').onclick=()=>document.querySelectorAll('.viewport').forEach(v=>v.classList.toggle('checker'));
document.querySelector('#reset').onclick=()=>{{zoom.value=100;zoom.oninput();}};
document.querySelector('#export').onclick=()=>{{
 const checks={{}}; document.querySelectorAll('.checks input').forEach(i=>checks[i.name]=i.checked);
 const payload={{schema:'taijifu/asset-forge-approval-draft/v1',pack_id:{json.dumps(cfg['pack_id'])},reviewer:document.querySelector('#reviewer').value,notes:document.querySelector('#notes').value,checks,source_manifest:{json.dumps(str(Path(cfg['output_dir']) / 'review-manifest.json'))}}};
 const blob=new Blob([JSON.stringify(payload,null,2)],{{type:'application/json'}}); const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download='approval-draft.json'; a.click(); URL.revokeObjectURL(a.href);
}};
</script></body></html>'''
    index = out / "index.html"
    index.write_text(page, encoding="utf-8")
    manifest = {
        "schema": "taijifu/asset-forge-review-manifest/v1",
        "pack_id": cfg["pack_id"],
        "ready_for_review": not missing,
        "missing": missing,
        "assets": assets,
        "page": str(index.relative_to(repo)),
    }
    dump_json(out / "review-manifest.json", manifest)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    result = build(args.repo.resolve(), args.config.resolve())
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["ready_for_review"] or not args.strict else 8


if __name__ == "__main__":
    raise SystemExit(main())
