(() => {
  'use strict';

  const shell = document.getElementById('taijifu-shell');
  const enterButton = document.getElementById('taijifu-enter');
  const statusLabel = document.getElementById('taijifu-load-status');
  const progressLabel = document.getElementById('taijifu-load-percent');
  const progressFill = document.getElementById('taijifu-load-fill');
  const progressTrack = progressFill?.parentElement || null;
  const fullscreenButton = document.getElementById('taijifu-fullscreen');
  const installButton = document.getElementById('taijifu-install');
  const touchControls = document.getElementById('taijifu-touch-controls');
  const moreButton = document.getElementById('taijifu-touch-more');
  const canvas = document.getElementById('canvas') || document.querySelector('canvas');

  if (!shell || !enterButton || !canvas) {
    console.warn('Taijifu Web Shell: elementos obrigatórios ausentes.');
    return;
  }

  const keyMap = {
    KeyA: { key: 'a', keyCode: 65 },
    KeyD: { key: 'd', keyCode: 68 },
    KeyW: { key: 'w', keyCode: 87 },
    KeyS: { key: 's', keyCode: 83 },
    KeyQ: { key: 'q', keyCode: 81 },
    KeyF: { key: 'f', keyCode: 70 },
    KeyG: { key: 'g', keyCode: 71 },
    KeyE: { key: 'e', keyCode: 69 },
    KeyC: { key: 'c', keyCode: 67 },
    KeyH: { key: 'h', keyCode: 72 },
    KeyR: { key: 'r', keyCode: 82 },
    KeyV: { key: 'v', keyCode: 86 }
  };

  const state = {
    ready: false,
    entered: false,
    progress: 3,
    deferredInstallPrompt: null,
    pressedKeys: new Set()
  };

  window.__taijifuTouchEvents = window.__taijifuTouchEvents || [];

  function updateProgress(value, message) {
    const clean = Math.max(3, Math.min(100, Math.round(value)));
    state.progress = clean;
    if (progressFill) progressFill.style.width = `${clean}%`;
    if (progressLabel) progressLabel.textContent = `${clean}%`;
    if (progressTrack) progressTrack.setAttribute('aria-valuenow', String(clean));
    if (statusLabel && message) statusLabel.textContent = message;
  }

  function markReady() {
    if (state.ready) return;
    state.ready = true;
    updateProgress(100, 'Arena pronta');
    enterButton.disabled = false;
    enterButton.textContent = 'Entrar na arena';
    enterButton.setAttribute('aria-busy', 'false');
    shell.dataset.state = 'ready';
  }

  function focusCanvas() {
    canvas.setAttribute('tabindex', '0');
    canvas.focus({ preventScroll: true });
  }

  function enterArena() {
    if (!state.ready || state.entered) return;
    state.entered = true;
    document.body.classList.add('taijifu-entered');
    shell.setAttribute('aria-hidden', 'true');
    focusCanvas();

    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (AudioContextClass) {
        const context = new AudioContextClass();
        context.resume().finally(() => context.close());
      }
    } catch (_error) {
      // O áudio do Godot será liberado na próxima interação, quando necessário.
    }
  }

  function createKeyboardEvent(type, code) {
    const definition = keyMap[code];
    if (!definition) return null;
    const event = new KeyboardEvent(type, {
      key: definition.key,
      code,
      bubbles: true,
      cancelable: true,
      repeat: false
    });
    for (const property of ['keyCode', 'which']) {
      try {
        Object.defineProperty(event, property, { get: () => definition.keyCode });
      } catch (_error) {
        // Navegadores modernos podem manter propriedades somente leitura.
      }
    }
    return event;
  }

  function dispatchKey(code, pressed) {
    if (!keyMap[code]) return;
    if (pressed && state.pressedKeys.has(code)) return;
    if (!pressed && !state.pressedKeys.has(code)) return;

    if (pressed) state.pressedKeys.add(code);
    else state.pressedKeys.delete(code);

    const type = pressed ? 'keydown' : 'keyup';
    const event = createKeyboardEvent(type, code);
    if (event) canvas.dispatchEvent(event);

    window.__taijifuTouchEvents.push({
      type,
      code,
      at: Date.now()
    });
    if (window.__taijifuTouchEvents.length > 80) {
      window.__taijifuTouchEvents.splice(0, window.__taijifuTouchEvents.length - 80);
    }
  }

  function releaseAllKeys() {
    for (const code of Array.from(state.pressedKeys)) {
      dispatchKey(code, false);
    }
  }

  function bindTouchButton(button) {
    const code = button.dataset.key;
    if (!code || !keyMap[code]) return;

    const press = (event) => {
      event.preventDefault();
      focusCanvas();
      button.classList.add('is-pressed');
      try {
        button.setPointerCapture(event.pointerId);
      } catch (_error) {
        // Nem todos os navegadores expõem captura de ponteiro em botões.
      }
      dispatchKey(code, true);
    };

    const release = (event) => {
      event.preventDefault();
      button.classList.remove('is-pressed');
      dispatchKey(code, false);
      try {
        button.releasePointerCapture(event.pointerId);
      } catch (_error) {
        // A captura pode já ter sido liberada pelo navegador.
      }
    };

    button.addEventListener('pointerdown', press, { passive: false });
    button.addEventListener('pointerup', release, { passive: false });
    button.addEventListener('pointercancel', release, { passive: false });
    button.addEventListener('lostpointercapture', () => {
      button.classList.remove('is-pressed');
      dispatchKey(code, false);
    });
    button.addEventListener('contextmenu', (event) => event.preventDefault());
  }

  async function toggleFullscreen() {
    try {
      if (document.fullscreenElement) {
        await document.exitFullscreen();
      } else {
        await document.documentElement.requestFullscreen({ navigationUI: 'hide' });
      }
      focusCanvas();
    } catch (error) {
      console.warn('Taijifu Web Shell: fullscreen indisponível.', error);
    }
  }

  async function installPwa() {
    const prompt = state.deferredInstallPrompt;
    if (!prompt) return;
    prompt.prompt();
    await prompt.userChoice;
    state.deferredInstallPrompt = null;
    installButton.hidden = true;
  }

  function watchGodotLoader() {
    let syntheticProgress = 3;
    const timer = window.setInterval(() => {
      const godotStatus = document.getElementById('status');
      const godotProgress = document.getElementById('status-progress');

      if (!godotStatus || !document.body.contains(godotStatus)) {
        window.clearInterval(timer);
        markReady();
        return;
      }

      let measured = 0;
      if (godotProgress) {
        const current = Number(godotProgress.value || 0);
        const total = Number(godotProgress.max || 0);
        if (current > 0 && total > 0) measured = (current / total) * 100;
      }

      syntheticProgress = Math.min(92, syntheticProgress + (syntheticProgress < 55 ? 1.6 : 0.55));
      updateProgress(Math.max(measured, syntheticProgress), 'Carregando técnicas e arenas');
    }, 140);

    window.setTimeout(() => {
      if (!state.ready && canvas.width >= 640 && canvas.height >= 360) markReady();
    }, 120000);
  }

  enterButton.addEventListener('click', enterArena);
  fullscreenButton?.addEventListener('click', toggleFullscreen);
  installButton?.addEventListener('click', installPwa);
  moreButton?.addEventListener('click', () => {
    touchControls?.classList.toggle('taijifu-more-open');
    moreButton.setAttribute(
      'aria-expanded',
      String(touchControls?.classList.contains('taijifu-more-open') || false)
    );
  });

  document.querySelectorAll('.taijifu-touch-button[data-key]').forEach(bindTouchButton);
  canvas.addEventListener('pointerdown', focusCanvas);
  window.addEventListener('blur', releaseAllKeys);
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) releaseAllKeys();
  });

  window.addEventListener('keydown', (event) => {
    if (!state.entered && state.ready && (event.code === 'Enter' || event.code === 'Space')) {
      event.preventDefault();
      enterArena();
    }
  });

  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    state.deferredInstallPrompt = event;
    if (installButton) installButton.hidden = false;
  });

  window.addEventListener('appinstalled', () => {
    state.deferredInstallPrompt = null;
    if (installButton) installButton.hidden = true;
  });

  document.addEventListener('fullscreenchange', () => {
    if (fullscreenButton) {
      fullscreenButton.textContent = document.fullscreenElement ? 'Sair da tela cheia' : 'Tela cheia';
    }
  });

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('./taijifu.service.worker.js').catch((error) => {
        console.warn('Taijifu PWA: service worker não registrado.', error);
      });
    });
  }

  window.taijifuWebShell = {
    get ready() { return state.ready; },
    get entered() { return state.entered; },
    enter: enterArena,
    sendKey: dispatchKey,
    releaseAllKeys
  };

  watchGodotLoader();
})();
