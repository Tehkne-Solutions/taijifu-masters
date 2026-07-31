#!/usr/bin/env python3
"""Valida o pacote Web essencial do Taijifu Masters antes do deploy."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def fail(message: str) -> None:
    print(f"[taijifu-web] ERRO: {message}", file=sys.stderr)
    raise SystemExit(1)


def first_match(root: Path, patterns: tuple[str, ...]) -> Path | None:
    for pattern in patterns:
        matches = sorted(root.glob(pattern))
        if matches:
            return matches[0]
    return None


def require_markers(source: str, markers: tuple[str, ...], label: str) -> None:
    for marker in markers:
        if marker not in source:
            fail(f"{label} não contém o contrato obrigatório: {marker}")


def main() -> None:
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "web-build").resolve()
    if not output.is_dir():
        fail(f"diretório de saída inexistente: {output}")

    index = output / "index.html"
    wasm = first_match(output, ("*.wasm",))
    pack = first_match(output, ("*.pck",))
    runtime_js = first_match(output, ("index.js", "*.js"))
    service_worker = first_match(output, ("*.service.worker.js", "*service*worker*.js"))
    manifest = first_match(output, ("*.webmanifest", "manifest.json"))
    offline = output / "offline.html"
    shell_css = output / "taijifu-web-shell.css"
    shell_js = output / "taijifu-web-shell.js"
    menu_css = output / "taijifu-web-menu.css"
    menu_js = output / "taijifu-web-menu.js"

    required = {
        "index.html": index if index.is_file() else None,
        "WebAssembly": wasm,
        "pacote PCK": pack,
        "runtime JavaScript": runtime_js,
        "service worker": service_worker,
        "manifesto PWA": manifest,
        "página offline": offline if offline.is_file() else None,
        "CSS do shell": shell_css if shell_css.is_file() else None,
        "JS do shell": shell_js if shell_js.is_file() else None,
        "CSS do menu": menu_css if menu_css.is_file() else None,
        "JS do menu": menu_js if menu_js.is_file() else None,
    }
    missing = [label for label, path in required.items() if path is None]
    if missing:
        fail("artefatos ausentes: " + ", ".join(missing))

    assert wasm and pack and runtime_js and service_worker and manifest
    if wasm.stat().st_size < 100_000:
        fail(f"arquivo WASM anormalmente pequeno: {wasm.stat().st_size} bytes")
    if pack.stat().st_size < 1_000:
        fail(f"arquivo PCK anormalmente pequeno: {pack.stat().st_size} bytes")
    if shell_css.stat().st_size < 2_000 or shell_js.stat().st_size < 4_000:
        fail("shell Web incompleto")
    if menu_css.stat().st_size < 3_000 or menu_js.stat().st_size < 6_000:
        fail("menu Web essencial incompleto")

    html = index.read_text(encoding="utf-8", errors="replace")
    require_markers(
        html,
        (
            "TAIJIFU_WEB_SHELL_HEAD",
            "TAIJIFU_WEB_SHELL_BODY",
            '<canvas',
            'id="taijifu-shell"',
            'id="taijifu-enter"',
            'id="taijifu-menu"',
            'id="taijifu-web-dialog"',
            'id="taijifu-dialog-close"',
        ),
        "index.html",
    )
    for asset in (wasm, pack, runtime_js, shell_css, shell_js, menu_css, menu_js):
        if asset.name not in html:
            fail(f"index.html não referencia {asset.name}")

    shell_source = shell_js.read_text(encoding="utf-8", errors="replace")
    require_markers(
        shell_source,
        ("taijifu:input", "releaseAllKeys", "enter", "ready"),
        "runtime do shell",
    )

    menu_source = menu_js.read_text(encoding="utf-8", errors="replace")
    require_markers(
        menu_source,
        (
            "enterArena",
            "openMenu",
            "closeMenu",
            "closeDialog",
            "taijifuGodotSetPaused",
            "Escape",
            "Pular treinamento e jogar",
            "Tehkné Solutions",
        ),
        "menu Web",
    )

    manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
    if manifest_data.get("display") != "standalone":
        fail("manifesto PWA não está em modo standalone")
    if manifest_data.get("orientation") != "landscape":
        fail("manifesto PWA não exige orientação paisagem")
    if manifest_data.get("lang") != "pt-BR":
        fail("manifesto PWA não está identificado como pt-BR")

    metadata = {
        "product": "Taijifu Masters",
        "publisher": "Tehkné Solutions",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "git_sha": os.environ.get("VERCEL_GIT_COMMIT_SHA")
        or os.environ.get("GITHUB_SHA")
        or "local",
        "web_contract": "sprint0-essential-shell-v1",
        "features": {
            "godot_canvas": True,
            "direct_arena_entry": True,
            "pause_menu": True,
            "closable_dialog": True,
            "keyboard_escape": True,
            "responsive_shell": True,
            "pwa": True,
        },
    }
    (output / "build-info.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("[taijifu-web] Validação essencial concluída")


if __name__ == "__main__":
    main()
