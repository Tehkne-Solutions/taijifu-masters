#!/usr/bin/env python3
"""Restaura a interface JavaScript consolidada da ponte Web ↔ Godot no export."""

from __future__ import annotations

import sys
from pathlib import Path


MARKER = "TAIJIFU_GODOT_BRIDGE_FACADE"
FACADE = f"""
<!-- {MARKER} -->
<script>
(() => {{
  'use strict';

  if (window.taijifuGodotBridge) return;

  function parseJson(value, fallback) {{
    if (typeof value !== 'string' || value.length === 0) return fallback;
    try {{ return JSON.parse(value); }} catch (_error) {{ return fallback; }}
  }}

  window.taijifuGodotBridge = Object.freeze({{
    get ready() {{ return Boolean(window.taijifuGodotBridgeReady); }},
    get paused() {{ return Boolean(window.taijifuGodotPaused); }},
    get version() {{ return Number(window.taijifuGodotBridgeVersion || 0); }},
    get bindings() {{ return parseJson(window.taijifuGodotBindingsJson, {{}}); }},

    setPaused(value) {{
      if (typeof window.taijifuGodotSetPaused !== 'function') return false;
      window.taijifuGodotSetPaused(Boolean(value));
      return true;
    }},

    applyBindings(bindings) {{
      if (typeof window.taijifuGodotApplyBindings !== 'function') return {{}};
      return parseJson(window.taijifuGodotApplyBindings(JSON.stringify(bindings || {{}})), {{}});
    }},

    resetBindings() {{
      if (typeof window.taijifuGodotResetBindings !== 'function') return {{}};
      return parseJson(window.taijifuGodotResetBindings(), {{}});
    }},

    getState() {{
      if (typeof window.taijifuGodotGetState === 'function') {{
        return parseJson(window.taijifuGodotGetState(), {{}});
      }}
      return {{
        version: Number(window.taijifuGodotBridgeVersion || 0),
        ready: Boolean(window.taijifuGodotBridgeReady),
        paused: Boolean(window.taijifuGodotPaused),
        bindings: parseJson(window.taijifuGodotBindingsJson, {{}})
      }};
    }}
  }});
}})();
</script>
<!-- /{MARKER} -->
""".strip()


def main() -> None:
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "web-build").resolve()
    index = output / "index.html"
    if not index.is_file():
        raise SystemExit(f"index.html não encontrado: {index}")

    source = index.read_text(encoding="utf-8")
    if MARKER in source:
        print("[taijifu-web] Façade Web ↔ Godot já presente")
        return
    if "</body>" not in source:
        raise SystemExit("index.html não contém </body>")

    index.write_text(source.replace("</body>", FACADE + "\n</body>", 1), encoding="utf-8")
    print("[taijifu-web] Façade Web ↔ Godot restaurada")


if __name__ == "__main__":
    main()

# Tehkné Solutions
