#!/usr/bin/env python3
"""Cria manifesto, service worker e integração PWA após o export Web do Godot."""

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


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    output = Path(sys.argv[1] if len(sys.argv) > 1 else root / "web-build").resolve()
    index = output / "index.html"
    if not index.is_file():
        fail("index.html não existe antes do pós-processamento")

    icon_source = root / "web" / "taijifu-web-icon.svg"
    offline_source = root / "web" / "offline.html"
    if not icon_source.is_file() or not offline_source.is_file():
        fail("fontes da PWA não foram encontradas")

    icon_target = output / "taijifu-web-icon.svg"
    offline_target = output / "offline.html"
    shutil.copy2(icon_source, icon_target)
    shutil.copy2(offline_source, offline_target)

    manifest = {
        "name": "Taijifu Masters",
        "short_name": "Taijifu",
        "description": "Batalhas técnicas Tai, Ji e Fu em arenas manga 2D.",
        "id": "./index.html",
        "start_url": "./index.html",
        "scope": "./",
        "display": "standalone",
        "orientation": "landscape",
        "background_color": "#070b14",
        "theme_color": "#070b14",
        "lang": "pt-BR",
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

    asset_names = sorted(
        path.name
        for path in output.iterdir()
        if path.is_file() and path.name not in {"taijifu.service.worker.js", "build-info.json"}
    )
    fingerprint = hashlib.sha256("\n".join(asset_names).encode("utf-8")).hexdigest()[:12]
    cache_name = f"taijifu-{os.environ.get('VERCEL_GIT_COMMIT_SHA') or os.environ.get('GITHUB_SHA') or fingerprint}"
    cache_name = cache_name[:64]

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

    html = index.read_text(encoding="utf-8", errors="strict")
    head_injection = """
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" href="taijifu-web-icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="taijifu-web-icon.svg">
<meta name="mobile-web-app-capable" content="yes">
""".strip()
    registration = """
<script>
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./taijifu.service.worker.js').catch((error) => {
      console.warn('Taijifu PWA: service worker não registrado.', error);
    });
  });
}
</script>
""".strip()

    if "manifest.webmanifest" not in html:
        html = html.replace("</head>", f"{head_injection}\n</head>")
    if "taijifu.service.worker.js" not in html:
        html = html.replace("</body>", f"{registration}\n</body>")
    index.write_text(html, encoding="utf-8")

    print(f"[taijifu-pwa] Manifesto: {manifest_path.name}")
    print(f"[taijifu-pwa] Service worker: {worker_path.name}")
    print(f"[taijifu-pwa] Cache: {cache_name}")


if __name__ == "__main__":
    main()
