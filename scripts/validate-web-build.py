#!/usr/bin/env python3
"""Valida o pacote Web exportado pelo Godot antes do deploy."""

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


def main() -> None:
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "web-build").resolve()
    if not output.is_dir():
        fail(f"diretório de saída inexistente: {output}")

    index = output / "index.html"
    if not index.is_file():
        fail("index.html não foi gerado")

    wasm = first_match(output, ("*.wasm",))
    pack = first_match(output, ("*.pck",))
    runtime_js = first_match(output, ("index.js", "*.js"))
    service_worker = first_match(output, ("*.service.worker.js", "*service*worker*.js"))
    manifest = first_match(output, ("*.manifest.json", "manifest.json", "*.webmanifest"))
    offline = first_match(output, ("*.offline.html", "offline.html"))

    required = {
        "WebAssembly": wasm,
        "pacote PCK": pack,
        "runtime JavaScript": runtime_js,
        "service worker da PWA": service_worker,
        "manifesto da PWA": manifest,
        "página offline": offline,
    }
    missing = [label for label, path in required.items() if path is None]
    if missing:
        fail("artefatos ausentes: " + ", ".join(missing))

    assert wasm is not None
    assert pack is not None
    assert runtime_js is not None
    assert service_worker is not None
    assert manifest is not None
    assert offline is not None

    if wasm.stat().st_size < 100_000:
        fail(f"arquivo WASM anormalmente pequeno: {wasm.stat().st_size} bytes")
    if pack.stat().st_size < 1_000:
        fail(f"arquivo PCK anormalmente pequeno: {pack.stat().st_size} bytes")

    html = index.read_text(encoding="utf-8", errors="replace")
    for asset in (wasm, pack, runtime_js):
        if asset.name not in html:
            fail(f"index.html não referencia {asset.name}")
    if "<canvas" not in html.lower():
        fail("index.html não contém o canvas do Godot")

    metadata = {
        "product": "Taijifu Masters",
        "publisher": "Tehkné Solutions",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "git_sha": os.environ.get("VERCEL_GIT_COMMIT_SHA")
        or os.environ.get("GITHUB_SHA")
        or "local",
        "files": {
            "index": index.name,
            "wasm": wasm.name,
            "pack": pack.name,
            "runtime": runtime_js.name,
            "service_worker": service_worker.name,
            "manifest": manifest.name,
            "offline": offline.name,
        },
        "sizes": {
            "wasm_bytes": wasm.stat().st_size,
            "pack_bytes": pack.stat().st_size,
        },
    }
    (output / "build-info.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("[taijifu-web] Artefatos validados:")
    for label, path in required.items():
        assert path is not None
        print(f"  - {label}: {path.name} ({path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
