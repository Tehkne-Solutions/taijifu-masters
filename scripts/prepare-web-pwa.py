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
        web_source / "taijifu-web-menu.css": output / "taijifu-web-menu.css",
        web_source / "taijifu-web-menu.js": output / "taijifu-web-menu.js",
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
<link rel="stylesheet" href="taijifu-web-menu.css">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="Taijifu Masters">
<!-- /TAIJIFU_WEB_SHELL_HEAD -->
""".strip()

    body_injection = """
<!-- TAIJIFU_WEB_SHELL_BODY -->
<section id="taijifu-shell" class="taijifu-shell" data-state="loading" data-mode="launch" aria-label="Menu Web do Taijifu Masters">
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
    <div class="taijifu-menu-actions">
      <button id="taijifu-enter" class="taijifu-enter" type="button" disabled aria-busy="true" data-testid="enter-arena">Carregando arena</button>
      <div class="taijifu-secondary-actions">
        <button id="taijifu-tutorial-open" class="taijifu-secondary-button" type="button" data-testid="open-tutorial">Tutorial</button>
        <button id="taijifu-settings-open" class="taijifu-secondary-button" type="button" data-testid="open-settings">Configurações</button>
      </div>
    </div>
    <p class="taijifu-device-hint">Desktop: teclado ou gamepad • Celular/tablet: controles touch em modo paisagem</p>
  </div>
</section>

<nav class="taijifu-toolbar" aria-label="Ferramentas do jogo Web">
  <button id="taijifu-menu" class="taijifu-tool-button" type="button">Menu</button>
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

<section id="taijifu-web-dialog" class="taijifu-web-dialog" hidden aria-hidden="true">
  <div class="taijifu-dialog-panel" role="dialog" aria-modal="true" aria-labelledby="taijifu-dialog-title">
    <header class="taijifu-dialog-header">
      <div>
        <p id="taijifu-dialog-kicker" class="taijifu-dialog-kicker">Taijifu Masters</p>
        <h2 id="taijifu-dialog-title" class="taijifu-dialog-title">Treinamento</h2>
      </div>
      <button id="taijifu-dialog-close" class="taijifu-dialog-close" type="button" aria-label="Fechar">×</button>
    </header>
    <div class="taijifu-dialog-content">
      <section id="taijifu-tutorial-view" class="taijifu-dialog-view" hidden>
        <p id="taijifu-tutorial-device" class="taijifu-tutorial-device"></p>

        <article class="taijifu-tutorial-step" data-step="0">
          <h3>Movimento é posicionamento</h3>
          <p>Controle distância, altura e plataformas. O melhor golpe começa antes do contato, quando você obriga o rival a ocupar uma posição desfavorável.</p>
          <div class="taijifu-binding-grid">
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="A / D" data-touch="◀ / ▶" data-gamepad="Direcional">A / D</span><div><strong>Mover</strong><small>Aproxime, recue e reposicione.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="W" data-touch="Pulo" data-gamepad="Botão de salto">W</span><div><strong>Saltar</strong><small>Suba em plataformas e altere a linha de ataque.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="S" data-touch="▼" data-gamepad="Direcional para baixo">S</span><div><strong>Queda rápida</strong><small>Desça e interrompa trajetórias previsíveis.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="G" data-touch="Push" data-gamepad="Empurrão">G</span><div><strong>Empurrar</strong><small>Use o ambiente e force erros de equilíbrio.</small></div></div>
          </div>
        </article>

        <article class="taijifu-tutorial-step" data-step="1" hidden>
          <h3>Técnica supera repetição</h3>
          <p>Alternar ataque, esquiva e guarda cria ritmo. Golpes previsíveis são punidos; aparos e contra-ataques dependem do momento correto.</p>
          <div class="taijifu-binding-grid">
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="F" data-touch="Golpe" data-gamepad="Ataque principal">F</span><div><strong>Golpe</strong><small>Técnica principal da build equipada.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="Q" data-touch="Esquiva" data-gamepad="Esquiva">Q</span><div><strong>Esquiva</strong><small>Evite dano e mude o ângulo do combate.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="R" data-touch="Guarda" data-gamepad="Defesa">R</span><div><strong>Guarda e aparo</strong><small>Defenda ou neutralize no instante exato.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="E" data-touch="Agarra" data-gamepad="Agarrão">E</span><div><strong>Agarrão</strong><small>Quebre defesas passivas e controle espaço.</small></div></div>
          </div>
        </article>

        <article class="taijifu-tutorial-step" data-step="2" hidden>
          <h3>Construa sua assinatura</h3>
          <p>Elementos, armas e ecos ampliam as possibilidades. Combine recursos sem abandonar os fundamentos de distância, leitura e tempo.</p>
          <div class="taijifu-binding-grid">
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="C" data-touch="Elemento" data-gamepad="Técnica elemental">C</span><div><strong>Elemento</strong><small>Ative a técnica elemental selecionada.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="H" data-touch="Eco" data-gamepad="Eco">H</span><div><strong>Eco</strong><small>Execute a habilidade armazenada.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="V" data-touch="Arma" data-gamepad="Troca de arma">V</span><div><strong>Trocar arma</strong><small>Adapte alcance, ritmo e especialidade.</small></div></div>
            <div class="taijifu-binding-card"><span class="taijifu-binding" data-keyboard="F9" data-touch="Menu Web" data-gamepad="Menu Web">F9</span><div><strong>Perfis e evolução</strong><small>As vitórias pertencem ao jogador, não só ao personagem.</small></div></div>
          </div>
        </article>

        <footer class="taijifu-tutorial-footer">
          <button id="taijifu-tutorial-previous" class="taijifu-dialog-action" type="button">Anterior</button>
          <span id="taijifu-tutorial-status" class="taijifu-tutorial-status">Passo 1 de 3</span>
          <button id="taijifu-tutorial-next" class="taijifu-dialog-action" data-role="primary" type="button">Próximo</button>
        </footer>
      </section>

      <section id="taijifu-settings-view" class="taijifu-dialog-view" hidden>
        <p class="taijifu-settings-intro">As preferências ficam apenas neste navegador e são aplicadas imediatamente, sem alterar as regras competitivas.</p>

        <fieldset class="taijifu-settings-group">
          <legend>Acessibilidade visual</legend>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Alto contraste</strong><small>Reforça contornos, textos e contraste do canvas.</small></span><span class="taijifu-setting-control"><input id="taijifu-setting-contrast" type="checkbox"></span></label>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Interface ampliada</strong><small>Aumenta textos e ferramentas da camada Web.</small></span><span class="taijifu-setting-control"><input id="taijifu-setting-large-ui" type="checkbox"></span></label>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Movimento reduzido</strong><small>Remove transições e animações não essenciais.</small></span><span class="taijifu-setting-control"><input id="taijifu-setting-motion" type="checkbox"></span></label>
        </fieldset>

        <fieldset class="taijifu-settings-group">
          <legend>Controles touch</legend>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Exibição</strong><small>Automática, sempre visível ou oculta.</small></span><span class="taijifu-setting-control"><select id="taijifu-setting-touch-visibility"><option value="auto">Automática</option><option value="always">Sempre</option><option value="hidden">Oculta</option></select></span></label>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Tamanho dos controles</strong><small>Ajuste entre 80% e 130%.</small></span><span class="taijifu-setting-control"><input id="taijifu-setting-touch-scale" type="range" min="80" max="130" step="5"><output id="taijifu-touch-scale-value" class="taijifu-setting-value">100%</output></span></label>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Opacidade</strong><small>Reduza a interferência visual sobre a arena.</small></span><span class="taijifu-setting-control"><input id="taijifu-setting-touch-opacity" type="range" min="35" max="100" step="5"><output id="taijifu-touch-opacity-value" class="taijifu-setting-value">88%</output></span></label>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Modo canhoto</strong><small>Troca movimento e ações entre os lados.</small></span><span class="taijifu-setting-control"><input id="taijifu-setting-left-handed" type="checkbox"></span></label>
          <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Resposta tátil</strong><small>Usa vibração curta quando o navegador permitir.</small></span><span class="taijifu-setting-control"><input id="taijifu-setting-haptics" type="checkbox"></span></label>
        </fieldset>

        <footer class="taijifu-settings-footer">
          <button id="taijifu-settings-tutorial" class="taijifu-dialog-action" type="button">Rever tutorial</button>
          <button id="taijifu-settings-reset" class="taijifu-dialog-action" type="button">Restaurar padrões</button>
          <button class="taijifu-dialog-action" data-role="primary" type="button" onclick="document.getElementById('taijifu-dialog-close').click()">Concluir</button>
        </footer>
      </section>
    </div>
  </div>
</section>

<div id="taijifu-announcer" class="taijifu-screen-reader" aria-live="polite" aria-atomic="true"></div>

<script src="taijifu-web-shell.js"></script>
<script src="taijifu-web-menu.js"></script>
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
    print("[taijifu-pwa] Menu e acessibilidade: taijifu-web-menu.css + taijifu-web-menu.js")
    print(f"[taijifu-pwa] Cache: {cache_name}")


if __name__ == "__main__":
    main()
