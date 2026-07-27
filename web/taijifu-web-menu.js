(() => {
  'use strict';

  const STORAGE_KEY = 'taijifu.web.preferences.v1';
  const defaults = {
    tutorialCompleted: false,
    highContrast: false,
    reducedMotion: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches || false,
    largeUi: false,
    leftHanded: false,
    haptics: true,
    touchScale: 100,
    touchOpacity: 88,
    touchVisibility: 'auto'
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
    device: detectDevice()
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

  function loadPreferences() {
    try {
      const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
      return sanitizePreferences({ ...defaults, ...stored });
    } catch (_error) {
      return { ...defaults };
    }
  }

  function sanitizePreferences(value) {
    const visibilityOptions = ['auto', 'always', 'hidden'];
    return {
      tutorialCompleted: Boolean(value.tutorialCompleted),
      highContrast: Boolean(value.highContrast),
      reducedMotion: Boolean(value.reducedMotion),
      largeUi: Boolean(value.largeUi),
      leftHanded: Boolean(value.leftHanded),
      haptics: value.haptics !== false,
      touchScale: Math.max(80, Math.min(130, Number(value.touchScale) || 100)),
      touchOpacity: Math.max(35, Math.min(100, Number(value.touchOpacity) || 88)),
      touchVisibility: visibilityOptions.includes(value.touchVisibility) ? value.touchVisibility : 'auto'
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
    window.setTimeout(() => {
      announcer.textContent = message;
    }, 20);
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
    syncSettingsForm();
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
    document.body.classList.add('taijifu-menu-open');
    shell.dataset.mode = 'menu';
    shell.setAttribute('aria-hidden', 'false');
    updateLaunchButton();
    enterButton.focus({ preventScroll: true });
    announce('Menu Web aberto. A batalha continua ao fundo.');
  }

  function closeMenu() {
    document.body.classList.remove('taijifu-menu-open');
    shell.dataset.mode = 'launch';
    shell.setAttribute('aria-hidden', String(Boolean(window.taijifuWebShell?.entered)));
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
      settingsBindings.highContrast?.focus({ preventScroll: true });
    }
  }

  function closeDialog() {
    dialog.hidden = true;
    dialog.setAttribute('aria-hidden', 'true');
    state.activeView = null;
    const focusTarget = state.lastFocus;
    if (focusTarget instanceof HTMLElement && document.body.contains(focusTarget)) {
      focusTarget.focus({ preventScroll: true });
    }
  }

  function configureTutorialForDevice() {
    state.device = detectDevice();
    const descriptions = {
      keyboard: 'Detectamos teclado. Use as teclas indicadas; um gamepad conectado continua disponível pelo mapeamento nativo do Godot.',
      touch: 'Detectamos tela touch. Os mesmos princípios aparecem nos botões virtuais posicionados nas laterais da arena.',
      gamepad: 'Detectamos gamepad. O tutorial mostra as ações por função; use os botões equivalentes configurados pelo jogo.'
    };
    if (tutorialDevice) tutorialDevice.textContent = descriptions[state.device];

    document.querySelectorAll('.taijifu-binding[data-keyboard]').forEach((element) => {
      const label = element.dataset[state.device] || element.dataset.keyboard || '';
      element.textContent = label;
    });
  }

  function showTutorialStep() {
    const steps = Array.from(document.querySelectorAll('.taijifu-tutorial-step'));
    steps.forEach((step, index) => {
      step.hidden = index !== state.tutorialStep;
    });
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

    settingsBindings.touchScale?.addEventListener('input', () => {
      updatePreference('touchScale', Number(settingsBindings.touchScale.value));
    });
    settingsBindings.touchOpacity?.addEventListener('input', () => {
      updatePreference('touchOpacity', Number(settingsBindings.touchOpacity.value));
    });
    settingsBindings.touchVisibility?.addEventListener('change', () => {
      updatePreference('touchVisibility', settingsBindings.touchVisibility.value);
    });
  }

  function resetPreferences() {
    const tutorialCompleted = state.preferences.tutorialCompleted;
    state.preferences = { ...defaults, tutorialCompleted };
    applyPreferences();
    savePreferences();
    announce('Preferências restauradas.');
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

  enterButton.addEventListener('click', interceptEnter, { capture: true });
  menuButton?.addEventListener('click', openMenu);
  tutorialButton?.addEventListener('click', () => openDialog('tutorial', { mode: 'manual' }));
  settingsButton?.addEventListener('click', () => openDialog('settings'));
  dialogClose?.addEventListener('click', closeDialog);
  tutorialPrevious?.addEventListener('click', previousTutorialStep);
  tutorialNext?.addEventListener('click', nextTutorialStep);
  resetButton?.addEventListener('click', resetPreferences);
  replayTutorialButton?.addEventListener('click', () => openDialog('tutorial', { mode: 'manual' }));

  dialog.addEventListener('pointerdown', (event) => {
    if (event.target === dialog) closeDialog();
  });

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

  window.addEventListener('keydown', (event) => {
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
    }
  }, { capture: true });

  const observer = new MutationObserver(() => updateLaunchButton());
  observer.observe(shell, { attributes: true, attributeFilter: ['data-state'] });

  bindSettings();
  applyPreferences();
  updateLaunchButton();

  window.taijifuWebMenu = {
    open: openMenu,
    close: closeMenu,
    openTutorial: () => openDialog('tutorial', { mode: 'manual' }),
    openSettings: () => openDialog('settings'),
    get preferences() { return { ...state.preferences }; },
    reset: resetPreferences
  };
})();
