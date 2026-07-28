#!/usr/bin/env python3
from __future__ import annotations
import shutil, sys
from pathlib import Path

def main() -> None:
    root = Path(__file__).resolve().parents[1]
    output = Path(sys.argv[1] if len(sys.argv) > 1 else root / "web-build").resolve()
    index = output / "index.html"
    source = root / "web" / "taijifu-ghost-race-web.js"
    target = output / source.name
    if not index.is_file() or not source.is_file():
        raise SystemExit("Artefatos da corrida contra fantasma ausentes.")
    shutil.copy2(source, target)
    html = index.read_text(encoding="utf-8")
    marker = "TAIJIFU_GHOST_RACE_WEB"
    if marker not in html:
        injection = f'<!-- {marker} -->\n<script src="{source.name}"></script>\n<!-- /{marker} -->'
        html = html.replace("</body>", f"{injection}\n</body>")
        index.write_text(html, encoding="utf-8")
    print(f"[taijifu-ghost-race-web] Runtime: {target.name}")

if __name__ == "__main__":
    main()
