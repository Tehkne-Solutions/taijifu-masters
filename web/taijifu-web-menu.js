(() => {
  'use strict';

  const STORAGE_KEY = 'taijifu.web.preferences.v1';
  const DEFAULT_BINDINGS = {
    p1_left: 'KeyA', p1_right: 'KeyD', p1_down: 'KeyS', p1_jump: 'KeyW',
    p1_dodge: 'KeyQ', p1_attack: 'KeyF', p1_push: 'KeyG', p1_grab: 'KeyE',
    p1_echo: 'KeyH', p1_block: 'KeyR', p1_element: 'KeyC', p1_swap: 'KeyT',
    p2_left: 'ArrowLeft', p2_right: 'ArrowRight', p2_down: 'ArrowDown', p2_jump: 'ArrowUp',
    p2_dodge: 'Numpad0', p2_attack: 'Numpad1', p2_push: 'Numpad2', p2_block: 'Numpad3',
    p2_grab: 'Numpad4', p2_echo: 'Numpad5', p2_element: 'Numpad6', p2_swap: 'Numpad7'
  };

  const ACTIONS = [
    { id: 'p1_left', player: 1, label: 'Mover esquerda' },
    { id: 'p1_right', player: 1, label: 'Mover direita' },
    { id: 'p1_down', player: 1, label: 'Queda rápida' },
    { id: 'p1_jump', player: 1, label: 'Pular' },
    { id: 'p1_dodge', player: 1, label: 'Esquiva' },
    { id: 'p1_attack', player: 1, label: 'Golpe' },
    { id: 'p1_push', player: 1, label: 'Empurrão' },
    { id: 'p1_grab', player: 1, label: 'Agarrão' },
    { id: 'p1_echo', player: 1, label: 'Eco' },
    { id: 'p1_block', player: 1, label: 'Guarda/aparo' },
    { id: 'p1_element', player: 1, label: 'Elemento' },
    { id: 'p1_swap', player: 1, label: 'Trocar arma' },
    { id: 'p2_left', player: 2, label: 'Mover esquerda' },
    { id: 'p2_right', player: 2, label: 'Mover direita' },
    { id: 'p2_down', player: 2, label: 'Queda rápida' },
    { id: 'p2_jump', player: 2, label: 'Pular' },
    { id: 'p2_dodge', player: 2, label: 'Esquiva' },
    { id: 'p2_attack', player: 2, label: 'Golpe' },
    { id: 'p2_push', player: 2, label: 'Empurrão' },
    { id: 'p2_grab', player: 2, label: 'Agarrão' },
    { id: 'p2_echo', player: 2, label: 'Eco' },
    { id: 'p2_block', player: 2, label: 'Guarda/aparo' },
    { id: 'p2_element', player: 2, label: 'Elemento' },
    { id: 'p2_swap', player: 2, label: 'Trocar arma' }
  ];

  const SUPPORTED_CODES = new Set([
    ...Array.from({ length: 26 }, (_, index) => `Key${String.fromCharCode(65 + index)}`),
    ...Array.from({ length: 10 }, (_, index) => `Digit${index}`),
    ...Array.from({ length: 10 }, (_, index) => `Numpad${index}`),
    'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown',
    'Space', 'Tab', 'ShiftLeft', 'ShiftRight',
    'ControlLeft', 'ControlRight', 'AltLeft', 'AltRight'
  ]);

  const PRACTICE_STEPS = [
    { actions: ['p1_left', 'p1_right'], title: 'Controle a distância', copy: 'Mova-se para qualquer lado e sinta a resposta da arena.' },
    { actions: ['p1_jump'], title: 'Mude de altura', copy: 'Salte para explorar plataformas e linhas de ataque.' },
    { actions: ['p1_attack'], title: 'Execute sua técnica', copy: 'Use o golpe principal da build equipada.' },
    { actions: ['p1_block'], title: 'Proteja a postura', copy: 'Ative a guarda; o aparo depende do tempo correto.' },
    { actions: ['p1_element'], title: 'Ative seu elemento', copy: 'Conclua o treino usando a técnica elemental.' }
  ];

  const defaults = {
    tutorialCompleted: false,
    practiceCompleted: false,
    highContrast: false,
    reducedMotion: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches || false,
    largeUi: false,
    leftHanded: false,
    haptics: true,
    touchScale: 100,
    touchOpacity: 88,
    touchVisibility: 'auto',
    keyboardBindings: { ...DEFAULT_BINDINGS }
  };

  const shell = document.getElementById('taijifu-shell');
  const enterButton = document.getElementById('taijifu-enter');
  const menuButton = document.getElementById('taijifu-menu');
  const tutorialButton = document.getElementById('taijifu-tutorial-open');
  const settingsButton = document.getElementById('taijifu-settings-open');
  const dialog = document.getElementById('taijifu-web-dialog');
  const dialogTitle = document.getElementById('taijifu-dialog-title');
  const dialogKicker = document.getElementById('taijifu-dialog-kicker');
  const dialogClose = document.getElementById('taijifu-dialog-close');
  const tutorialView = document.getElementById('taijifu-tutorial-view');
  const settingsView = document.getElementById('taijifu-settings-view');
  const tutorialDevice = document.getElementById('taijifu-tutorial-device');
  const tutorialStatus = document.getElementById('taijifu-tutorial-status');
  const tutorialPrevious = document.getElementById('taijifu-tutorial-previous');
  const tutorialNext = document.getElementById('taijifu-tutorial-next');
  const resetButton = document.getElementById('taijifu-settings-reset');
  const replayTutorialButton = document.getElementById('taijifu-settings-tutorial');
  const announcer = document.getElementById('taijifu-announcer');
  const touchControls = document.getElementById('taijifu-touch-controls');

  if (!shell || !enterButton || !dialog || !tutorialView || !settingsView) {
    console.warn('Taijifu Web Menu: elementos obrigatórios ausentes.');
    return;
  }

  const state = {
    preferences: loadPreferences(),
    tutorialStep: 0,
    tutorialMode: 'manual',
    activeView: null,
    lastFocus: null,
    device: detectDevice(),
    remapPlayer: 1,
    captureAction: null,
    bridgeReady: false,
    bridgePaused: false,
    practiceActive: false,
    practiceStep: 0
  };

  const settingsBindings = {
    highContrast: document.getElementById('taijifu-setting-contrast'),
    reducedMotion: document.getElementById('taijifu-setting-motion'),
    largeUi: document.getElementById('taijifu-setting-large-ui'),
    leftHanded: document.getElementById('taijifu-setting-left-handed'),
    haptics: document.getElementById('taijifu-setting-haptics'),
    touchScale: document.getElementById('taijifu-setting-touch-scale'),
    touchOpacity: document.getElementById('taijifu-setting-touch-opacity'),
    touchVisibility: document.getElementById('taijifu-setting-touch-visibility')
  };

  const valueLabels = {
    touchScale: document.getElementById('taijifu-touch-scale-value'),
    touchOpacity: document.getElementById('taijifu-touch-opacity-value')
  };

  let remapPlayerSelect = null;
  let remapGrid = null;
  let remapStatus = null;
  let practiceOverlay = null;
  let practiceTitle = null;
  let practiceCopy = null;
  let practiceBinding = null;
  let practiceProgress = null;
  let pauseBadge = null;

  function loadPreferences() {
    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
      return sanitizePreferences({ ...defaults, ...stored });
    } catch (_error) {
      return sanitizePreferences(defaults);
    }
  }

  function sanitizeBindings(value) {
    const source = value && typeof value === 'object' ? value : {};
    const result = {};
    for (const action of ACTIONS) {
      const candidate = String(source[action.id] || DEFAULT_BINDINGS[action.id]);
      result[action.id] = SUPPORTED_CODES.has(candidate) ? candidate : DEFAULT_BINDINGS[action.id];
    }
    return result;
  }

  function sanitizePreferences(value) {
    const visibilityOptions = ['auto', 'always', 'hidden'];
    return {
      tutorialCompleted: Boolean(value.tutorialCompleted),
      practiceCompleted: Boolean(value.practiceCompleted),
      highContrast: Boolean(value.highContrast),
      reducedMotion: Boolean(value.reducedMotion),
      largeUi: Boolean(value.largeUi),
      leftHanded: Boolean(value.leftHanded),
      haptics: value.haptics !== false,
      touchScale: Math.max(80, Math.min(130, Number(value.touchScale) || 100)),
      touchOpacity: Math.max(35, Math.min(100, Number(value.touchOpacity) || 88)),
      touchVisibility: visibilityOptions.includes(value.touchVisibility) ? value.touchVisibility : 'auto',
      keyboardBindings: sanitizeBindings(value.keyboardBindings)
    };
  }

  function savePreferences() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state.preferences));
    } catch (_error) {
      announce('As preferências não puderam ser salvas neste navegador.');
    }
  }

  function detectDevice() {
    const touch = Boolean(
      navigator.maxTouchPoints > 0 ||
      window.matchMedia?.('(pointer: coarse)').matches ||
      'ontouchstart' in window
    );
    const gamepad = Boolean(Array.from(navigator.getGamepads?.() || []).find(Boolean));
    if (touch) return 'touch';
    if (gamepad) return 'gamepad';
    return 'keyboard';
  }

  function announce(message) {
    if (!announcer) return;
    announcer.textContent = '';
    window.setTimeout(() => { announcer.textContent = message; }, 20);
  }

  function formatCode(code) {
    const labels = {
      ArrowLeft: '←', ArrowRight: '→', ArrowUp: '↑', ArrowDown: '↓',
      Space: 'Espaço', Tab: 'Tab', ShiftLeft: 'Shift', ShiftRight: 'Shift',
      ControlLeft: 'Ctrl', ControlRight: 'Ctrl', AltLeft: 'Alt', AltRight: 'Alt'
    };
    if (labels[code]) return labels[code];
    if (/^Key[A-Z]$/.test(code)) return code.slice(-1);
    if (/^Digit[0-9]$/.test(code)) return code.slice(-1);
    if (/^Numpad[0-9]$/.test(code)) return `Num ${code.slice(-1)}`;
    return code;
  }

  function injectAdvancedUi() {
    if (document.getElementById('taijifu-remap-grid')) return;

    const style = document.createElement('style');
    style.id = 'taijifu-bridge-styles';
    style.textContent = `
      .taijifu-pause-badge{display:none;align-items:center;padding:0 11px;border:1px solid rgba(255,214,112,.45);border-radius:999px;color:#ffe08a;background:rgba(44,31,8,.78);font-size:10px;font-weight:900;letter-spacing:.1em;text-transform:uppercase}
      body.taijifu-menu-open .taijifu-pause-badge{display:flex}
      .taijifu-remap-toolbar{display:flex;align-items:center;justify-content:space-between;gap:12px;margin-bottom:12px}
      .taijifu-remap-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}
      .taijifu-remap-button{display:flex;align-items:center;justify-content:space-between;gap:10px;min-height:44px;padding:8px 11px;border:1px solid rgba(142,215,255,.22);border-radius:11px;color:#eaf5ff;background:rgba(7,17,32,.78);font:inherit;cursor:pointer;text-align:left}
      .taijifu-remap-button strong{font-size:12px}.taijifu-remap-button span{min-width:62px;padding:5px 8px;border-radius:8px;color:#f5d77a;background:rgba(245,215,122,.09);font-size:11px;font-weight:900;text-align:center}
      .taijifu-remap-button.is-capturing{border-color:#79efb1;box-shadow:0 0 0 2px rgba(121,239,177,.12)}
      .taijifu-remap-status{margin:10px 0 0;color:rgba(199,218,238,.68);font-size:11px;line-height:1.45}
      .taijifu-practice{position:fixed;left:50%;bottom:max(22px,env(safe-area-inset-bottom));z-index:940;width:min(560px,calc(100vw - 30px));transform:translateX(-50%);pointer-events:none}
      .taijifu-practice[hidden]{display:none}.taijifu-practice-card{display:grid;grid-template-columns:1fr auto;gap:8px 14px;padding:15px 17px;border:1px solid rgba(245,215,122,.42);border-radius:16px;color:#edf7ff;background:rgba(5,12,23,.9);box-shadow:0 18px 55px rgba(0,0,0,.44);backdrop-filter:blur(14px)}
      .taijifu-practice-kicker{margin:0;color:#8ed7ff;font-size:10px;font-weight:900;letter-spacing:.13em;text-transform:uppercase}.taijifu-practice h3{margin:3px 0 2px;font-size:17px}.taijifu-practice p{grid-column:1;margin:0;color:rgba(215,231,247,.7);font-size:12px}.taijifu-practice-binding{grid-column:2;grid-row:1/3;align-self:center;min-width:72px;padding:10px;border-radius:12px;color:#07101b;background:#f5d77a;font-size:13px;font-weight:900;text-align:center}.taijifu-practice-footer{grid-column:1/3;display:flex;align-items:center;justify-content:space-between;margin-top:4px;color:rgba(210,228,245,.62);font-size:10px}.taijifu-practice-skip{pointer-events:auto;border:0;color:#cfe6f8;background:transparent;font:inherit;font-weight:800;cursor:pointer}
      @media(max-width:720px){.taijifu-remap-grid{grid-template-columns:1fr}.taijifu-practice{bottom:calc(max(14px,env(safe-area-inset-bottom)) + 138px);width:min(430px,calc(100vw - 190px))}.taijifu-practice-card{padding:10px 12px}.taijifu-practice h3{font-size:14px}.taijifu-practice p{display:none}}
    `;
    document.head.appendChild(style);

    const footer = settingsView.querySelector('.taijifu-settings-footer');
    const fieldset = document.createElement('fieldset');
    fieldset.className = 'taijifu-settings-group';
    fieldset.innerHTML = `
      <legend>Remapeamento do teclado</legend>
      <div class="taijifu-remap-toolbar">
        <span class="taijifu-setting-copy"><strong>Jogador</strong><small>Gamepads não são alterados.</small></span>
        <span class="taijifu-setting-control"><select id="taijifu-remap-player"><option value="1">Jogador 1</option><option value="2">Jogador 2</option></select></span>
      </div>
      <div id="taijifu-remap-grid" class="taijifu-remap-grid" data-testid="remap-grid"></div>
      <p id="taijifu-remap-status" class="taijifu-remap-status">Selecione uma ação e pressione uma nova tecla. Conflitos são trocados automaticamente.</p>
      <button id="taijifu-remap-reset" class="taijifu-dialog-action" type="button">Restaurar teclas</button>
    `;
    settingsView.insertBefore(fieldset, footer);
    remapPlayerSelect = document.getElementById('taijifu-remap-player');
    remapGrid = document.getElementById('taijifu-remap-grid');
    remapStatus = document.getElementById('taijifu-remap-status');

    const practiceButton = document.createElement('button');
    practiceButton.id = 'taijifu-settings-practice';
    practiceButton.className = 'taijifu-dialog-action';
    practiceButton.type = 'button';
    practiceButton.textContent = 'Treino prático';
    footer?.prepend(practiceButton);

    const toolbar = document.querySelector('.taijifu-toolbar');
    pauseBadge = document.createElement('span');
    pauseBadge.className = 'taijifu-pause-badge';
    pauseBadge.textContent = 'Arena pausada';
    toolbar?.prepend(pauseBadge);

    practiceOverlay = document.createElement('section');
    practiceOverlay.id = 'taijifu-practice';
    practiceOverlay.className = 'taijifu-practice';
    practiceOverlay.hidden = true;
    practiceOverlay.innerHTML = `
      <div class="taijifu-practice-card">
        <div><p class="taijifu-practice-kicker">Treino prático</p><h3 id="taijifu-practice-title">Controle a distância</h3></div>
        <span id="taijifu-practice-binding" class="taijifu-practice-binding">A / D</span>
        <p id="taijifu-practice-copy">Execute a ação indicada dentro da arena.</p>
        <footer class="taijifu-practice-footer"><span id="taijifu-practice-progress">Passo 1 de 5</span><button id="taijifu-practice-skip" class="taijifu-practice-skip" type="button">Encerrar treino</button></footer>
      </div>
    `;
    document.body.appendChild(practiceOverlay);
    practiceTitle = document.getElementById('taijifu-practice-title');
    practiceCopy = document.getElementById('taijifu-practice-copy');
    practiceBinding = document.getElementById('taijifu-practice-binding');
    practiceProgress = document.getElementById('taijifu-practice-progress');

    remapPlayerSelect?.addEventListener('change', () => {
      state.remapPlayer = Number(remapPlayerSelect.value) || 1;
      renderRemapGrid();
    });
    remapGrid?.addEventListener('click', (event) => {
      const button = event.target.closest('.taijifu-remap-button[data-action]');
      if (button) beginCapture(button.dataset.action);
    });
    document.getElementById('taijifu-remap-reset')?.addEventListener('click', resetKeyboardBindings);
    practiceButton.addEventListener('click', startPractice);
    document.getElementById('taijifu-practice-skip')?.addEventListener('click', stopPractice);
  }

  function syncTouchBindings() {
    const byLabel = {
      'Pulo': 'p1_jump', '◀': 'p1_left', '▼': 'p1_down', '▶': 'p1_right',
      'Esquiva': 'p1_dodge', 'Push': 'p1_push', 'Guarda': 'p1_block',
      'Elemento': 'p1_element', 'Golpe': 'p1_attack', 'Agarra': 'p1_grab',
      'Eco': 'p1_echo', 'Arma': 'p1_swap'
    };
    document.querySelectorAll('.taijifu-touch-button[data-key]').forEach((button) => {
      const action = button.dataset.action || byLabel[button.textContent.trim()];
      if (!action) return;
      button.dataset.action = action;
      button.dataset.key = state.preferences.keyboardBindings[action] || DEFAULT_BINDINGS[action];
    });
  }

  function applyPreferences() {
    const prefs = state.preferences;
    document.body.classList.toggle('taijifu-high-contrast', prefs.highContrast);
    document.body.classList.toggle('taijifu-reduced-motion', prefs.reducedMotion);
    document.body.classList.toggle('taijifu-large-ui', prefs.largeUi);
    document.body.classList.toggle('taijifu-left-handed', prefs.leftHanded);
    document.body.classList.toggle('taijifu-touch-always', prefs.touchVisibility === 'always');
    document.body.classList.toggle('taijifu-touch-hidden', prefs.touchVisibility === 'hidden');
    document.documentElement.style.setProperty('--taijifu-touch-scale', String(prefs.touchScale / 100));
    document.documentElement.style.setProperty('--taijifu-touch-opacity', String(prefs.touchOpacity / 100));
    document.documentElement.style.setProperty('--taijifu-ui-scale', prefs.largeUi ? '1.12' : '1');
    syncTouchBindings();
    syncSettingsForm();
    renderRemapGrid();
    if (state.bridgeReady) applyBindingsToGodot();
  }

  function syncSettingsForm() {
    const prefs = state.preferences;
    for (const key of ['highContrast', 'reducedMotion', 'largeUi', 'leftHanded', 'haptics']) {
      if (settingsBindings[key]) settingsBindings[key].checked = Boolean(prefs[key]);
    }
    if (settingsBindings.touchScale) settingsBindings.touchScale.value = String(prefs.touchScale);
    if (settingsBindings.touchOpacity) settingsBindings.touchOpacity.value = String(prefs.touchOpacity);
    if (settingsBindings.touchVisibility) settingsBindings.touchVisibility.value = prefs.touchVisibility;
    if (valueLabels.touchScale) valueLabels.touchScale.textContent = `${prefs.touchScale}%`;
    if (valueLabels.touchOpacity) valueLabels.touchOpacity.textContent = `${prefs.touchOpacity}%`;
  }

  function setGodotPaused(paused) {
    state.bridgePaused = Boolean(paused);
    try {
      if (typeof window.taijifuGodotSetPaused === 'function') {
        window.taijifuGodotSetPaused(Boolean(paused));
      }
    } catch (error) {
      console.warn('Taijifu Web Bridge: não foi possível alterar a pausa.', error);
    }
    if (pauseBadge) pauseBadge.textContent = paused ? 'Arena pausada' : 'Arena ativa';
  }

  function applyBindingsToGodot() {
    try {
      if (typeof window.taijifuGodotApplyBindings === 'function') {
        window.taijifuGodotApplyBindings(JSON.stringify(state.preferences.keyboardBindings));
      }
    } catch (error) {
      console.warn('Taijifu Web Bridge: não foi possível aplicar o remapeamento.', error);
    }
  }

  function watchGodotBridge() {
    const timer = window.setInterval(() => {
      if (!window.taijifuGodotBridgeReady) return;
      state.bridgeReady = true;
      applyBindingsToGodot();
      window.clearInterval(timer);
      window.dispatchEvent(new CustomEvent('taijifu:bridge-ready'));
    }, 100);
  }

  function updateLaunchButton() {
    const shellApi = window.taijifuWebShell;
    if (!shellApi?.ready) return;
    if (shellApi.entered && document.body.classList.contains('taijifu-menu-open')) {
      enterButton.textContent = 'Voltar à arena';
      return;
    }
    enterButton.textContent = state.preferences.tutorialCompleted ? 'Entrar na arena' : 'Começar treinamento';
  }

  function openMenu() {
    const shellApi = window.taijifuWebShell;
    if (!shellApi?.entered) return;
    shellApi.releaseAllKeys?.();
    setGodotPaused(true);
    document.body.classList.add('taijifu-menu-open');
    shell.dataset.mode = 'menu';
    shell.setAttribute('aria-hidden', 'false');
    updateLaunchButton();
    enterButton.focus({ preventScroll: true });
    announce('Menu Web aberto. Arena pausada.');
  }

  function closeMenu() {
    document.body.classList.remove('taijifu-menu-open');
    shell.dataset.mode = 'launch';
    shell.setAttribute('aria-hidden', String(Boolean(window.taijifuWebShell?.entered)));
    setGodotPaused(false);
    window.setTimeout(() => document.getElementById('canvas')?.focus({ preventScroll: true }), 0);
  }

  function openDialog(view, options = {}) {
    state.lastFocus = document.activeElement;
    state.activeView = view;
    dialog.hidden = false;
    dialog.setAttribute('aria-hidden', 'false');
    tutorialView.hidden = view !== 'tutorial';
    settingsView.hidden = view !== 'settings';

    if (view === 'tutorial') {
      state.tutorialMode = options.mode || 'manual';
      state.tutorialStep = 0;
      if (dialogKicker) dialogKicker.textContent = 'Treinamento inicial';
      if (dialogTitle) dialogTitle.textContent = 'Domine o fluxo da batalha';
      configureTutorialForDevice();
      showTutorialStep();
      tutorialNext?.focus({ preventScroll: true });
    } else {
      if (dialogKicker) dialogKicker.textContent = 'Preferências locais';
      if (dialogTitle) dialogTitle.textContent = 'Acessibilidade e controles';
      syncSettingsForm();
      renderRemapGrid();
      settingsBindings.highContrast?.focus({ preventScroll: true });
    }
  }

  function closeDialog() {
    dialog.hidden = true;
    dialog.setAttribute('aria-hidden', 'true');
    state.activeView = null;
    state.captureAction = null;
    const focusTarget = state.lastFocus;
    if (focusTarget instanceof HTMLElement && document.body.contains(focusTarget)) {
      focusTarget.focus({ preventScroll: true });
    }
  }

  function actionForTutorialCard(card) {
    const title = card.querySelector('strong')?.textContent || '';
    const titleMap = {
      'Mover': 'p1_left', 'Saltar': 'p1_jump', 'Queda rápida': 'p1_down',
      'Empurrar': 'p1_push', 'Golpe': 'p1_attack', 'Esquiva': 'p1_dodge',
      'Guarda e aparo': 'p1_block', 'Agarrão': 'p1_grab', 'Elemento': 'p1_element',
      'Eco': 'p1_echo', 'Trocar arma': 'p1_swap'
    };
    return titleMap[title] || null;
  }

  function configureTutorialForDevice() {
    state.device = detectDevice();
    const descriptions = {
      keyboard: 'Detectamos teclado. As teclas abaixo respeitam o remapeamento salvo.',
      touch: 'Detectamos tela touch. Os botões virtuais usam as mesmas ações configuradas para o Jogador 1.',
      gamepad: 'Detectamos gamepad. O mapeamento nativo permanece ativo e não é alterado pelas teclas personalizadas.'
    };
    if (tutorialDevice) tutorialDevice.textContent = descriptions[state.device];

    document.querySelectorAll('.taijifu-binding-card').forEach((card) => {
      const element = card.querySelector('.taijifu-binding[data-keyboard]');
      if (!element) return;
      const action = element.dataset.action || actionForTutorialCard(card);
      if (action) element.dataset.action = action;
      if (state.device === 'keyboard' && action) {
        if (action === 'p1_left') {
          element.textContent = `${formatCode(state.preferences.keyboardBindings.p1_left)} / ${formatCode(state.preferences.keyboardBindings.p1_right)}`;
        } else {
          element.textContent = formatCode(state.preferences.keyboardBindings[action]);
        }
      } else {
        element.textContent = element.dataset[state.device] || element.dataset.keyboard || '';
      }
    });
  }

  function showTutorialStep() {
    const steps = Array.from(document.querySelectorAll('.taijifu-tutorial-step'));
    steps.forEach((step, index) => { step.hidden = index !== state.tutorialStep; });
    if (tutorialStatus) tutorialStatus.textContent = `Passo ${state.tutorialStep + 1} de ${steps.length}`;
    if (tutorialPrevious) tutorialPrevious.disabled = state.tutorialStep === 0;
    if (tutorialNext) {
      const last = state.tutorialStep === steps.length - 1;
      tutorialNext.textContent = last
        ? (state.tutorialMode === 'first-run' ? 'Concluir e jogar' : 'Concluir')
        : 'Próximo';
    }
  }

  function nextTutorialStep() {
    const steps = document.querySelectorAll('.taijifu-tutorial-step');
    if (state.tutorialStep < steps.length - 1) {
      state.tutorialStep += 1;
      showTutorialStep();
      announce(`Passo ${state.tutorialStep + 1} do treinamento.`);
      return;
    }
    state.preferences.tutorialCompleted = true;
    savePreferences();
    closeDialog();
    updateLaunchButton();
    announce('Treinamento concluído.');
    if (state.tutorialMode === 'first-run') {
      window.taijifuWebShell?.enter?.();
      closeMenu();
    }
  }

  function previousTutorialStep() {
    if (state.tutorialStep <= 0) return;
    state.tutorialStep -= 1;
    showTutorialStep();
    announce(`Passo ${state.tutorialStep + 1} do treinamento.`);
  }

  function updatePreference(key, value) {
    state.preferences = sanitizePreferences({ ...state.preferences, [key]: value });
    applyPreferences();
    savePreferences();
    announce('Preferência atualizada.');
  }

  function bindSettings() {
    const booleanBindings = {
      highContrast: settingsBindings.highContrast,
      reducedMotion: settingsBindings.reducedMotion,
      largeUi: settingsBindings.largeUi,
      leftHanded: settingsBindings.leftHanded,
      haptics: settingsBindings.haptics
    };
    for (const [key, input] of Object.entries(booleanBindings)) {
      input?.addEventListener('change', () => updatePreference(key, input.checked));
    }
    settingsBindings.touchScale?.addEventListener('input', () => updatePreference('touchScale', Number(settingsBindings.touchScale.value)));
    settingsBindings.touchOpacity?.addEventListener('input', () => updatePreference('touchOpacity', Number(settingsBindings.touchOpacity.value)));
    settingsBindings.touchVisibility?.addEventListener('change', () => updatePreference('touchVisibility', settingsBindings.touchVisibility.value));
  }

  function resetPreferences() {
    const tutorialCompleted = state.preferences.tutorialCompleted;
    const practiceCompleted = state.preferences.practiceCompleted;
    state.preferences = sanitizePreferences({ ...defaults, tutorialCompleted, practiceCompleted });
    applyPreferences();
    savePreferences();
    announce('Preferências restauradas.');
  }

  function renderRemapGrid() {
    if (!remapGrid) return;
    const actions = ACTIONS.filter((action) => action.player === state.remapPlayer);
    remapGrid.innerHTML = actions.map((action) => {
      const code = state.preferences.keyboardBindings[action.id];
      const capturing = state.captureAction === action.id;
      return `<button class="taijifu-remap-button${capturing ? ' is-capturing' : ''}" type="button" data-action="${action.id}" data-testid="remap-${action.id}"><strong>${action.label}</strong><span>${capturing ? 'Pressione…' : formatCode(code)}</span></button>`;
    }).join('');
  }

  function beginCapture(actionId) {
    state.captureAction = actionId;
    if (remapStatus) remapStatus.textContent = 'Pressione uma tecla permitida. Esc cancela.';
    renderRemapGrid();
  }

  function applyCapturedCode(code) {
    const actionId = state.captureAction;
    if (!actionId || !SUPPORTED_CODES.has(code)) return false;
    const bindings = { ...state.preferences.keyboardBindings };
    const previousCode = bindings[actionId];
    const conflictingAction = Object.keys(bindings).find((id) => id !== actionId && bindings[id] === code);
    bindings[actionId] = code;
    if (conflictingAction) bindings[conflictingAction] = previousCode;
    state.preferences.keyboardBindings = sanitizeBindings(bindings);
    state.captureAction = null;
    applyPreferences();
    savePreferences();
    configureTutorialForDevice();
    if (remapStatus) remapStatus.textContent = conflictingAction
      ? 'Teclas trocadas para evitar conflito.'
      : 'Nova tecla aplicada.';
    announce('Remapeamento aplicado.');
    return true;
  }

  function resetKeyboardBindings() {
    state.preferences.keyboardBindings = { ...DEFAULT_BINDINGS };
    state.captureAction = null;
    applyPreferences();
    savePreferences();
    try { window.taijifuGodotResetBindings?.(); } catch (_error) { /* fallback já aplicado */ }
    if (remapStatus) remapStatus.textContent = 'Teclas padrão restauradas.';
    announce('Teclas restauradas.');
  }

  function practiceExpectedCodes(step) {
    return step.actions.map((action) => state.preferences.keyboardBindings[action]).filter(Boolean);
  }

  function renderPractice() {
    if (!practiceOverlay || !state.practiceActive) return;
    const step = PRACTICE_STEPS[state.practiceStep];
    const codes = practiceExpectedCodes(step);
    practiceTitle.textContent = step.title;
    practiceCopy.textContent = step.copy;
    practiceBinding.textContent = codes.map(formatCode).join(' / ');
    practiceProgress.textContent = `Passo ${state.practiceStep + 1} de ${PRACTICE_STEPS.length}`;
  }

  function startPractice() {
    closeDialog();
    state.preferences.tutorialCompleted = true;
    savePreferences();
    if (!window.taijifuWebShell?.entered) window.taijifuWebShell?.enter?.();
    closeMenu();
    state.practiceActive = true;
    state.practiceStep = 0;
    practiceOverlay.hidden = false;
    renderPractice();
    announce('Treino prático iniciado. Execute a ação indicada.');
  }

  function stopPractice() {
    state.practiceActive = false;
    if (practiceOverlay) practiceOverlay.hidden = true;
    announce('Treino prático encerrado.');
  }

  function handlePracticeInput(code) {
    if (!state.practiceActive) return;
    const expected = practiceExpectedCodes(PRACTICE_STEPS[state.practiceStep]);
    if (!expected.includes(code)) return;
    state.practiceStep += 1;
    if (state.practiceStep >= PRACTICE_STEPS.length) {
      state.preferences.practiceCompleted = true;
      savePreferences();
      if (practiceTitle) practiceTitle.textContent = 'Fluxo básico concluído';
      if (practiceCopy) practiceCopy.textContent = 'Continue treinando distância, leitura e tempo de resposta.';
      if (practiceBinding) practiceBinding.textContent = '✓';
      if (practiceProgress) practiceProgress.textContent = 'Treino completo';
      announce('Treino prático concluído.');
      window.setTimeout(stopPractice, 1400);
      return;
    }
    renderPractice();
    announce(`Passo ${state.practiceStep + 1} do treino prático.`);
  }

  function interceptEnter(event) {
    const shellApi = window.taijifuWebShell;
    if (!shellApi?.ready) return;
    if (shellApi.entered) {
      event.preventDefault();
      event.stopImmediatePropagation();
      closeMenu();
      return;
    }
    if (!state.preferences.tutorialCompleted) {
      event.preventDefault();
      event.stopImmediatePropagation();
      openDialog('tutorial', { mode: 'first-run' });
    }
  }

  injectAdvancedUi();
  syncTouchBindings();

  enterButton.addEventListener('click', interceptEnter, { capture: true });
  menuButton?.addEventListener('click', openMenu);
  tutorialButton?.addEventListener('click', () => openDialog('tutorial', { mode: 'manual' }));
  settingsButton?.addEventListener('click', () => openDialog('settings'));
  dialogClose?.addEventListener('click', closeDialog);
  tutorialPrevious?.addEventListener('click', previousTutorialStep);
  tutorialNext?.addEventListener('click', nextTutorialStep);
  resetButton?.addEventListener('click', resetPreferences);
  replayTutorialButton?.addEventListener('click', () => openDialog('tutorial', { mode: 'manual' }));

  dialog.addEventListener('pointerdown', (event) => { if (event.target === dialog) closeDialog(); });

  document.querySelectorAll('.taijifu-touch-button[data-key]').forEach((button) => {
    button.addEventListener('pointerdown', () => {
      if (!state.preferences.haptics || typeof navigator.vibrate !== 'function') return;
      navigator.vibrate(button.dataset.role === 'primary' ? 18 : 10);
    }, { passive: true });
  });

  window.addEventListener('gamepadconnected', () => {
    state.device = 'gamepad';
    if (state.activeView === 'tutorial') configureTutorialForDevice();
  });

  window.addEventListener('taijifu:input', (event) => {
    if (event.detail?.type === 'keydown') handlePracticeInput(event.detail.code);
  });

  window.addEventListener('keydown', (event) => {
    if (state.captureAction) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (event.code === 'Escape') {
        state.captureAction = null;
        if (remapStatus) remapStatus.textContent = 'Remapeamento cancelado.';
        renderRemapGrid();
        return;
      }
      if (!applyCapturedCode(event.code) && remapStatus) {
        remapStatus.textContent = 'Tecla não permitida. Use letras, números, setas ou modificadores.';
      }
      return;
    }

    if (event.code === 'Escape' && !dialog.hidden) {
      event.preventDefault();
      event.stopImmediatePropagation();
      closeDialog();
      return;
    }
    if (event.code === 'Escape' && document.body.classList.contains('taijifu-menu-open')) {
      event.preventDefault();
      event.stopImmediatePropagation();
      closeMenu();
      return;
    }
    if ((event.code === 'Enter' || event.code === 'Space') && !window.taijifuWebShell?.entered && !state.preferences.tutorialCompleted) {
      event.preventDefault();
      event.stopImmediatePropagation();
      if (window.taijifuWebShell?.ready && dialog.hidden) openDialog('tutorial', { mode: 'first-run' });
      return;
    }
    if (!event.repeat) handlePracticeInput(event.code);
  }, { capture: true });

  const observer = new MutationObserver(() => updateLaunchButton());
  observer.observe(shell, { attributes: true, attributeFilter: ['data-state'] });

  bindSettings();
  applyPreferences();
  updateLaunchButton();
  watchGodotBridge();

  window.taijifuGodotBridge = {
    get ready() { return state.bridgeReady; },
    get paused() { return Boolean(window.taijifuGodotPaused ?? state.bridgePaused); },
    get bindings() { return { ...state.preferences.keyboardBindings }; },
    setPaused: setGodotPaused,
    applyBindings: (bindings) => {
      state.preferences.keyboardBindings = sanitizeBindings(bindings);
      applyPreferences();
      savePreferences();
    },
    resetBindings: resetKeyboardBindings,
    getState: () => {
      try {
        const raw = window.taijifuGodotGetState?.();
        return typeof raw === 'string' ? JSON.parse(raw) : raw;
      } catch (_error) {
        return { ready: state.bridgeReady, paused: state.bridgePaused, bindings: { ...state.preferences.keyboardBindings } };
      }
    }
  };

  window.taijifuWebMenu = {
    open: openMenu,
    close: closeMenu,
    openTutorial: () => openDialog('tutorial', { mode: 'manual' }),
    openSettings: () => openDialog('settings'),
    startPractice,
    get preferences() { return JSON.parse(JSON.stringify(state.preferences)); },
    reset: resetPreferences
  };
})();
