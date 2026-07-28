#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "web-build"
index = out / "index.html"
source = root / "web" / "taijifu-multi-ghost-race-web.js"
marker = "TAIJIFU_MULTI_GHOST_RACE_WEB"
html = index.read_text(encoding="utf-8")
if marker not in html:
    html = html.replace("</body>", f"<script>\n{source.read_text(encoding='utf-8')}\n</script>\n</body>")
    index.write_text(html, encoding="utf-8")
print("multi-ghost-race web injected")