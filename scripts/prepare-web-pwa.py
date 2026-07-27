#!/usr/bin/env python3
"""Cria a PWA e injeta a experiência Web responsiva após o export do Godot."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
from pathlib import Path


def fail(message: str) -> None:
    print(f"[taijifu-pwa] ERRO: {message}", file=sys.stderr)
    raise SystemExit(1)


def copy_required(source: Path, target: Path) -> None:
    if not source.is_file():
        fail(f"arquivo Web obrigatório ausente: {source}")
    shutil.copy2(source, target)


def asset_fingerprint(paths: list[Path]) -> str:
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()[:16]


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    output = Path(sys.argv[1] if len(sys.argv) > 1 else root / "web-build").resolve()
    index = output / "index.html"
    if not index.is_file():
        fail("index.html não existe antes do pós-processamento")

    web_source = root / "web"
    source_targets = {
        web_source / "taijifu-web-icon.svg": output / "taijifu-web-icon.svg",
        web_source / "offline.html": output / "offline.html",
        web_source / "taijifu-web-shell.css": output / "taijifu-web-shell.css",
        web_source / "taijifu-web-shell.js": output / "taijifu-web-shell.js",
    }
    for source, target in source_targets.items():
        copy_required(source, target)

    manifest = {
        "name": "Taijifu Masters",
        "short_name": "Taijifu",
        "description": "Batalhas técnicas Tai, Ji e Fu em arenas manga 2D.",
        "id": "./",
        "start_url": "./",
        "scope": "./",
        "display": "standalone",
        "orientation": "landscape",
        "background_color": "#050810",
        "theme_color": "#070b14",
        "lang": "pt-BR",
        "categories": ["games", "entertainment", "sports"],
        "icons": [
            {
                "src": "taijifu-web-icon.svg",
                "sizes": "any",
                "type": "image/svg+xml",
                "purpose": "any maskable",
            }
        ],
    }
    manifest_path = output / "manifest.webmanifest"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    asset_paths = sorted(
        (
            path
            for path in output.iterdir()
            if path.is_file()
            and path.name not in {"taijifu.service.worker.js", "build-info.json"}
        ),
        key=lambda path: path.name,
    )
    fingerprint = asset_fingerprint(asset_paths)
    build_sha = (
        os.environ.get("VERCEL_GIT_COMMIT_SHA")
        or os.environ.get("GITHUB_SHA")
        or fingerprint
    )
    cache_name = f"taijifu-{build_sha}"[:72]
    asset_names = [path.name for path in asset_paths]

    service_worker = f"""const CACHE_NAME = {json.dumps(cache_name)};
const CORE_ASSETS = {json.dumps(['./' + name for name in asset_names], ensure_ascii=False, indent=2)};

self.addEventListener('install', (event) => {{
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CORE_ASSETS)));
  self.skipWaiting();
}});

self.addEventListener('activate', (event) => {{
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((key) => key.startsWith('taijifu-') && key !== CACHE_NAME).map((key) => caches.delete(key))
    ))
  );
  self.clients.claim();
}});

self.addEventListener('fetch', (event) => {{
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (event.request.mode === 'navigate') {{
    event.respondWith(
      fetch(event.request)
        .then((response) => {{
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put('./index.html', copy));
          return response;
        }})
        .catch(() => caches.match('./index.html').then((cached) => cached || caches.match('./offline.html')))
    );
    return;
  }}

  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request).then((response) => {{
      if (response.ok) {{
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
      }}
      return response;
    }}))
  );
}});
"""
    worker_path = output / "taijifu.service.worker.js"
    worker_path.write_text(service_worker, encoding="utf-8")

    head_injection = """
<!-- TAIJIFU_WEB_SHELL_HEAD -->
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" href="taijifu-web-icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="taijifu-web-icon.svg">
<link rel="stylesheet" href="taijifu-web-shell.css">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Taijifu Masters">
<!-- /TAIJIFU_WEB_SHELL_HEAD -->
""".strip()

    body_injection = """
<!-- TAIJIFU_WEB_SHELL_BODY -->
<section id="taijifu-shell" class="taijifu-shell" data-state="loading" aria-label="Inicialização do Taijifu Masters">
  <div class="taijifu-shell-card">
    <div class="taijifu-mark" aria-hidden="true">太極</div>
    <p class="taijifu-kicker">Tai • Ji • Fu</p>
    <h1 class="taijifu-title">Taijifu Masters</h1>
    <p class="taijifu-subtitle">Combate técnico golpe a golpe, domínio elemental e evolução marcial em arenas vivas.</p>
    <div class="taijifu-loader" aria-live="polite">
      <div class="taijifu-loader-track" role="progressbar" aria-label="Carregamento do jogo" aria-valuemin="0" aria-valuemax="100">
        <div id="taijifu-load-fill" class="taijifu-loader-fill"></div>
      </div>
      <div class="taijifu-loader-meta">
        <span id="taijifu-load-status">Preparando o dojo</span>
        <span id="taijifu-load-percent">3%</span>
      </div>
    </div>
    <button id="taijifu-enter" class="taijifu-enter" type="button" disabled aria-busy="true" data-testid="enter-arena">Carregando arena</button>
    <p class="taijifu-device-hint">Desktop: teclado ou gamepad • Celular/tablet: controles touch em modo paisagem</p>
  </div>
</section>

<nav class="taijifu-toolbar" aria-label="Ferramentas do jogo Web">
  <button id="taijifu-install" class="taijifu-tool-button" type="button" hidden>Instalar</button>
  <button id="taijifu-fullscreen" class="taijifu-tool-button" type="button">Tela cheia</button>
</nav>

<section id="taijifu-orientation" class="taijifu-orientation" aria-label="Orientação recomendada">
  <div class="taijifu-orientation-card">
    <span class="taijifu-orientation-icon" aria-hidden="true">▯</span>
    <strong>Gire o dispositivo</strong>
    <span>O Taijifu Masters foi desenhado para batalhas em modo paisagem.</span>
  </div>
</section>

<section id="taijifu-touch-controls" class="taijifu-touch-controls" aria-label="Controles touch do Jogador 1">
  <div class="taijifu-touch-cluster taijifu-touch-movement">
    <button class="taijifu-touch-button taijifu-touch-up" type="button" data-key="KeyW" aria-label="Pular">Pulo</button>
    <button class="taijifu-touch-button taijifu-touch-left" type="button" data-key="KeyA" aria-label="Mover para esquerda">◀</button>
    <button class="taijifu-touch-button taijifu-touch-down" type="button" data-key="KeyS" aria-label="Abaixar ou queda rápida">▼</button>
    <button class="taijifu-touch-button taijifu-touch-right" type="button" data-key="KeyD" aria-label="Mover para direita">▶</button>
  </div>

  <div class="taijifu-touch-cluster taijifu-touch-actions">
    <button class="taijifu-touch-button" type="button" data-key="KeyQ" aria-label="Esquiva">Esquiva</button>
    <button class="taijifu-touch-button" type="button" data-key="KeyG" aria-label="Empurrão">Push</button>
    <button class="taijifu-touch-button" type="button" data-key="KeyR" aria-label="Defender e aparar">Guarda</button>
    <button class="taijifu-touch-button" type="button" data-key="KeyC" aria-label="Técnica elemental">Elemento</button>
    <button class="taijifu-touch-button" type="button" data-key="KeyF" data-role="primary" aria-label="Técnica principal">Golpe</button>
    <button id="taijifu-touch-more" class="taijifu-touch-button" type="button" aria-label="Mais técnicas" aria-expanded="false">Mais</button>
  </div>

  <div class="taijifu-touch-secondary" aria-label="Técnicas adicionais">
    <button class="taijifu-touch-button" type="button" data-key="KeyE" aria-label="Agarrão">Agarra</button>
    <button class="taijifu-touch-button" type="button" data-key="KeyH" aria-label="Executar eco">Eco</button>
    <button class="taijifu-touch-button" type="button" data-key="KeyV" aria-label="Trocar arma">Arma</button>
  </div>
</section>

<script src="taijifu-web-shell.js"></script>
<!-- /TAIJIFU_WEB_SHELL_BODY -->
""".strip()

    html = index.read_text(encoding="utf-8", errors="strict")
    if "TAIJIFU_WEB_SHELL_HEAD" not in html:
        html = html.replace("</head>", f"{head_injection}\n</head>")
    if "TAIJIFU_WEB_SHELL_BODY" not in html:
        html = html.replace("</body>", f"{body_injection}\n</body>")
    index.write_text(html, encoding="utf-8")

    print(f"[taijifu-pwa] Manifesto: {manifest_path.name}")
    print(f"[taijifu-pwa] Service worker: {worker_path.name}")
    print("[taijifu-pwa] Shell responsivo: taijifu-web-shell.css + taijifu-web-shell.js")
    print(f"[taijifu-pwa] Cache: {cache_name}")


if __name__ == "__main__":
    main()
