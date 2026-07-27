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

  const state = {
    ready: false,
    entered: false,
    progress: 3,
    deferredInstallPrompt: null,
    pressedKeys: new Set()
  };

  window.__taijifuTouchEvents = window.__taijifuTouchEvents || [];

  function keyDefinition(code) {
    if (/^Key[A-Z]$/.test(code)) {
      const letter = code.slice(-1);
      return { key: letter.toLowerCase(), keyCode: letter.charCodeAt(0) };
    }
    if (/^Digit[0-9]$/.test(code)) {
      const digit = code.slice(-1);
      return { key: digit, keyCode: digit.charCodeAt(0) };
    }
    if (/^Numpad[0-9]$/.test(code)) {
      const digit = Number(code.slice(-1));
      return { key: String(digit), keyCode: 96 + digit };
    }
    const fixed = {
      ArrowLeft: { key: 'ArrowLeft', keyCode: 37 },
      ArrowUp: { key: 'ArrowUp', keyCode: 38 },
      ArrowRight: { key: 'ArrowRight', keyCode: 39 },
      ArrowDown: { key: 'ArrowDown', keyCode: 40 },
      Space: { key: ' ', keyCode: 32 },
      Enter: { key: 'Enter', keyCode: 13 },
      Tab: { key: 'Tab', keyCode: 9 },
      ShiftLeft: { key: 'Shift', keyCode: 16 },
      ShiftRight: { key: 'Shift', keyCode: 16 },
      ControlLeft: { key: 'Control', keyCode: 17 },
      ControlRight: { key: 'Control', keyCode: 17 },
      AltLeft: { key: 'Alt', keyCode: 18 },
      AltRight: { key: 'Alt', keyCode: 18 }
    };
    return fixed[code] || null;
  }

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
    const definition = keyDefinition(code);
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

  function emitInputEvent(type, code, source = 'touch') {
    const detail = { type, code, source, at: Date.now() };
    window.__taijifuTouchEvents.push(detail);
    if (window.__taijifuTouchEvents.length > 100) {
      window.__taijifuTouchEvents.splice(0, window.__taijifuTouchEvents.length - 100);
    }
    window.dispatchEvent(new CustomEvent('taijifu:input', { detail }));
  }

  function dispatchKey(code, pressed, source = 'touch') {
    if (!keyDefinition(code)) return;
    if (pressed && state.pressedKeys.has(code)) return;
    if (!pressed && !state.pressedKeys.has(code)) return;

    if (pressed) state.pressedKeys.add(code);
    else state.pressedKeys.delete(code);

    const type = pressed ? 'keydown' : 'keyup';
    const event = createKeyboardEvent(type, code);
    if (event) canvas.dispatchEvent(event);
    emitInputEvent(type, code, source);
  }

  function releaseAllKeys() {
    for (const code of Array.from(state.pressedKeys)) {
      dispatchKey(code, false, 'system');
    }
  }

  function bindTouchButton(button) {
    const press = (event) => {
      const code = button.dataset.key;
      if (!code || !keyDefinition(code)) return;
      event.preventDefault();
      focusCanvas();
      button.dataset.activeCode = code;
      button.classList.add('is-pressed');
      try {
        button.setPointerCapture(event.pointerId);
      } catch (_error) {
        // Nem todos os navegadores expõem captura de ponteiro em botões.
      }
      dispatchKey(code, true, 'touch');
    };

    const release = (event) => {
      const code = button.dataset.activeCode || button.dataset.key;
      if (!code) return;
      event.preventDefault();
      button.classList.remove('is-pressed');
      dispatchKey(code, false, 'touch');
      delete button.dataset.activeCode;
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
      const code = button.dataset.activeCode || button.dataset.key;
      button.classList.remove('is-pressed');
      if (code) dispatchKey(code, false, 'touch');
      delete button.dataset.activeCode;
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
    releaseAllKeys,
    focus: focusCanvas,
    keyDefinition
  };

  watchGodotLoader();
})();
