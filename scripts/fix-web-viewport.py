#!/usr/bin/env python3
"""Centraliza o canvas Godot no viewport Web após o pós-processamento."""

from __future__ import annotations

import sys
from pathlib import Path


STYLE_MARKER = "TAIJIFU_WEB_VIEWPORT_FIX"
STYLE = f"""
<!-- {STYLE_MARKER} -->
<style>
html, body {{
  width: 100% !important;
  height: 100% !important;
  margin: 0 !important;
  overflow: hidden !important;
}}

#canvas {{
  position: fixed !important;
  left: 50% !important;
  top: 50% !important;
  right: auto !important;
  bottom: auto !important;
  transform: translate(-50%, -50%) !important;
  width: min(100vw, calc(100vh * 1.7777778)) !important;
  height: min(100vh, calc(100vw / 1.7777778)) !important;
  max-width: 100vw !important;
  max-height: 100vh !important;
  margin: 0 !important;
}}
</style>
<!-- /{STYLE_MARKER} -->
""".strip()


def main() -> None:
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "web-build").resolve()
    index = output / "index.html"
    if not index.is_file():
        raise SystemExit(f"index.html não encontrado: {index}")

    source = index.read_text(encoding="utf-8")
    if STYLE_MARKER in source:
        return
    if "</head>" not in source:
        raise SystemExit("index.html não contém </head>")

    index.write_text(source.replace("</head>", STYLE + "\n</head>", 1), encoding="utf-8")
    print("[taijifu-web] Canvas centralizado no viewport")


if __name__ == "__main__":
    main()

# Tehkné Solutions