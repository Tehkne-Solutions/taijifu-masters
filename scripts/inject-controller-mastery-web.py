#!/usr/bin/env python3
"""Copia e injeta o editor Web de maestria de controles e combos."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"[taijifu-controller-mastery] ERRO: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    output = Path(sys.argv[1] if len(sys.argv) > 1 else root / "web-build").resolve()
    index = output / "index.html"
    source = root / "web" / "taijifu-controller-mastery-web.js"
    target = output / source.name

    if not index.is_file():
        fail(f"index.html ausente em {output}")
    if not source.is_file():
        fail(f"runtime Web ausente: {source}")

    shutil.copy2(source, target)
    html = index.read_text(encoding="utf-8", errors="strict")
    marker = "TAIJIFU_CONTROLLER_MASTERY_WEB"
    if marker not in html:
        injection = (
            "<!-- TAIJIFU_CONTROLLER_MASTERY_WEB -->\n"
            '<script src="taijifu-controller-mastery-web.js"></script>\n'
            "<!-- /TAIJIFU_CONTROLLER_MASTERY_WEB -->"
        )
        html = html.replace("</body>", f"{injection}\n</body>")
        index.write_text(html, encoding="utf-8")

    print(f"[taijifu-controller-mastery] Runtime: {target.name}")


if __name__ == "__main__":
    main()
