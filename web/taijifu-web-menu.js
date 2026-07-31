(() => {
  'use strict';

  const STORAGE_KEY = 'taijifu.web.preferences.v2';
  const shell = document.getElementById('taijifu-shell');
  const enterButton = document.getElementById('taijifu-enter');
  const menuButton = document.getElementById('taijifu-menu');
  const tutorialButton = document.getElementById('taijifu-tutorial-open');
  const settingsButton = document.getElementById('taijifu-settings-open');
  const dialog = document.getElementById('taijifu-web-dialog');
  const dialogPanel = dialog?.querySelector('.taijifu-dialog-panel');
  const dialogTitle = document.getElementById('taijifu-dialog-title');
  const dialogKicker = document.getElementById('taijifu-dialog-kicker');
  const dialogClose = document.getElementById('taijifu-dialog-close');
  const tutorialView = document.getElementById('taijifu-tutorial-view');
  const settingsView = document.getElementById('taijifu-settings-view');
  const tutorialStatus = document.getElementById('taijifu-tutorial-status');
  const tutorialPrevious = document.getElementById('taijifu-tutorial-previous');
  const tutorialNext = document.getElementById('taijifu-tutorial-next');
  const announcer = document.getElementById('taijifu-announcer');

  if (!shell || !enterButton || !dialog || !tutorialView || !settingsView) {
    console.warn('Taijifu UI: estrutura Web incompleta.');
    return;
  }

  const preferences = loadPreferences();
  let tutorialStep = 0;
  let activeView = null;
  let lastFocus = null;

  function loadPreferences() {
    try {
      return {
        tutorialSeen: false,
        reducedMotion: false,
        highContrast: false,
        ...(JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}'))
      };
    } catch (_error) {
      return { tutorialSeen: false, reducedMotion: false, highContrast: false };
    }
  }

  function savePreferences() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(preferences)); } catch (_error) { /* non-blocking */ }
  }

  function announce(message) {
    if (!announcer) return;
    announcer.textContent = '';
    window.setTimeout(() => { announcer.textContent = message; }, 16);
  }

  function injectGameUi() {
    if (document.getElementById('taijifu-fighting-ui-v2')) return;
    const style = document.createElement('style');
    style.id = 'taijifu-fighting-ui-v2';
    style.textContent = `
      :root{--tj-ink:#080b0d;--tj-panel:rgba(12,16,17,.94);--tj-line:rgba(222,190,112,.3);--tj-gold:#e2bd68;--tj-bone:#f4efe2;--tj-muted:#a8aca8;--tj-jade:#5cae91;--tj-danger:#c56552}
      body.taijifu-overlay-open{overflow:hidden}
      .taijifu-web-dialog{position:fixed!important;inset:0!important;z-index:2000!important;display:grid!important;place-items:center!important;padding:24px!important;background:rgba(0,0,0,.58)!important;backdrop-filter:blur(8px)!important}
      .taijifu-web-dialog[hidden]{display:none!important}
      .taijifu-dialog-panel{position:relative!important;width:min(680px,calc(100vw - 32px))!important;max-height:min(78vh,680px)!important;overflow:hidden!important;border:1px solid var(--tj-line)!important;border-radius:14px!important;background:linear-gradient(145deg,rgba(24,28,26,.98),rgba(8,11,12,.98))!important;box-shadow:0 28px 90px rgba(0,0,0,.72)!important;color:var(--tj-bone)!important}
      .taijifu-dialog-header{position:sticky!important;top:0!important;z-index:5!important;display:flex!important;align-items:center!important;justify-content:space-between!important;gap:16px!important;padding:18px 20px 14px!important;border-bottom:1px solid rgba(226,189,104,.18)!important;background:rgba(8,11,12,.98)!important}
      .taijifu-dialog-kicker{margin:0 0 4px!important;color:var(--tj-gold)!important;font-size:10px!important;font-weight:900!important;letter-spacing:.18em!important;text-transform:uppercase!important}
      .taijifu-dialog-title{margin:0!important;font-size:clamp(22px,3vw,30px)!important;line-height:1.05!important;letter-spacing:-.025em!important}
      .taijifu-dialog-close{position:relative!important;z-index:10!important;flex:0 0 auto!important;display:grid!important;place-items:center!important;width:44px!important;height:44px!important;border:1px solid rgba(226,189,104,.35)!important;border-radius:10px!important;color:var(--tj-bone)!important;background:rgba(255,255,255,.04)!important;font-size:26px!important;line-height:1!important;cursor:pointer!important}
      .taijifu-dialog-close:hover,.taijifu-dialog-close:focus-visible{border-color:var(--tj-gold)!important;background:rgba(226,189,104,.12)!important;outline:none!important}
      .taijifu-dialog-content{max-height:calc(min(78vh,680px) - 78px)!important;overflow:auto!important;padding:18px 20px 20px!important;scrollbar-width:thin!important;scrollbar-color:rgba(226,189,104,.42) transparent!important}
      .taijifu-tutorial-device,.taijifu-tutorial-step>p{display:none!important}
      .taijifu-tutorial-step h3{margin:0 0 14px!important;color:var(--tj-bone)!important;font-size:18px!important}
      .taijifu-binding-grid{display:grid!important;grid-template-columns:repeat(2,minmax(0,1fr))!important;gap:10px!important}
      .taijifu-binding-card{display:grid!important;grid-template-columns:54px 1fr!important;align-items:center!important;gap:12px!important;min-height:72px!important;padding:10px 12px!important;border:1px solid rgba(226,189,104,.18)!important;border-radius:10px!important;background:rgba(255,255,255,.025)!important}
      .taijifu-binding{display:grid!important;place-items:center!important;min-height:46px!important;border:1px solid rgba(226,189,104,.42)!important;border-radius:8px!important;color:var(--tj-gold)!important;background:rgba(226,189,104,.06)!important;font-size:12px!important;font-weight:900!important}
      .taijifu-binding-card strong{display:block!important;color:var(--tj-bone)!important;font-size:13px!important}.taijifu-binding-card small{display:none!important}
      .taijifu-tutorial-footer,.taijifu-settings-footer{position:sticky!important;bottom:-20px!important;display:grid!important;grid-template-columns:1fr auto 1fr!important;align-items:center!important;gap:12px!important;margin:20px -20px -20px!important;padding:14px 20px!important;border-top:1px solid rgba(226,189,104,.15)!important;background:rgba(8,11,12,.98)!important}
      .taijifu-tutorial-footer button,.taijifu-settings-footer button,.taijifu-game-skip{min-height:42px!important;padding:0 16px!important;border:1px solid rgba(226,189,104,.3)!important;border-radius:9px!important;color:var(--tj-bone)!important;background:rgba(255,255,255,.04)!important;font-weight:850!important;cursor:pointer!important}
      #taijifu-tutorial-next{justify-self:end!important;color:#181205!important;background:var(--tj-gold)!important;border-color:var(--tj-gold)!important}
      #taijifu-tutorial-previous{justify-self:start!important}.taijifu-game-skip{grid-column:1/-1!important;width:100%!important;margin-top:10px!important;border-color:rgba(92,174,145,.45)!important;color:#dff7ed!important;background:rgba(92,174,145,.1)!important}
      body.taijifu-overlay-open [class*="ghost-race"],body.taijifu-overlay-open [id*="ghost-race"],body.taijifu-overlay-open [class*="ghost-history"],body.taijifu-overlay-open [id*="ghost-history"]{visibility:hidden!important;pointer-events:none!important}
      .taijifu-shell-card{border-color:rgba(226,189,104,.26)!important;background:linear-gradient(145deg,rgba(18,21,19,.95),rgba(8,10,11,.97))!important;box-shadow:0 24px 90px rgba(0,0,0,.7)!important}
      .taijifu-mark{color:var(--tj-gold)!important}.taijifu-kicker{color:var(--tj-gold)!important}.taijifu-title{color:var(--tj-bone)!important}.taijifu-subtitle,.taijifu-device-hint{color:var(--tj-muted)!important}
      .taijifu-enter{border-color:var(--tj-gold)!important;color:#171204!important;background:var(--tj-gold)!important}.taijifu-secondary-button,.taijifu-tool-button{border-color:rgba(226,189,104,.25)!important;color:var(--tj-bone)!important;background:rgba(10,13,13,.82)!important}
      @media(max-width:720px){.taijifu-web-dialog{padding:10px!important}.taijifu-dialog-panel{width:100%!important;max-height:92vh!important}.taijifu-dialog-content{max-height:calc(92vh - 72px)!important;padding:14px!important}.taijifu-binding-grid{grid-template-columns:1fr!important}.taijifu-dialog-title{font-size:22px!important}.taijifu-tutorial-footer,.taijifu-settings-footer{margin:16px -14px -14px!important;padding:12px 14px!important}}
    `;
    document.head.appendChild(style);

    const footer = tutorialView.querySelector('.taijifu-tutorial-footer');
    if (footer && !document.getElementById('taijifu-tutorial-skip')) {
      const skip = document.createElement('button');
      skip.id = 'taijifu-tutorial-skip';
      skip.className = 'taijifu-game-skip';
      skip.type = 'button';
      skip.textContent = 'Pular treinamento e jogar';
      skip.addEventListener('click', () => enterArena(true));
      footer.appendChild(skip);
    }
  }

  function setPaused(paused) {
    try { window.taijifuGodotSetPaused?.(Boolean(paused)); } catch (_error) { /* bridge optional */ }
  }

  function showView(view) {
    activeView = view;
    lastFocus = document.activeElement;
    dialog.hidden = false;
    dialog.setAttribute('aria-hidden', 'false');
    document.body.classList.add('taijifu-overlay-open');
    tutorialView.hidden = view !== 'tutorial';
    settingsView.hidden = view !== 'settings';
    if (view === 'tutorial') {
      tutorialStep = 0;
      if (dialogKicker) dialogKicker.textContent = 'Guia rápido';
      if (dialogTitle) dialogTitle.textContent = 'Controles essenciais';
      renderTutorial();
      dialogClose?.focus({ preventScroll: true });
    } else {
      if (dialogKicker) dialogKicker.textContent = 'Opções';
      if (dialogTitle) dialogTitle.textContent = 'Controles e acessibilidade';
      dialogClose?.focus({ preventScroll: true });
    }
    setPaused(Boolean(window.taijifuWebShell?.entered));
  }

  function closeDialog() {
    dialog.hidden = true;
    dialog.setAttribute('aria-hidden', 'true');
    document.body.classList.remove('taijifu-overlay-open');
    activeView = null;
    setPaused(document.body.classList.contains('taijifu-menu-open'));
    if (lastFocus instanceof HTMLElement && document.body.contains(lastFocus)) lastFocus.focus({ preventScroll: true });
  }

  function renderTutorial() {
    const steps = [...tutorialView.querySelectorAll('.taijifu-tutorial-step')];
    steps.forEach((step, index) => { step.hidden = index !== tutorialStep; });
    if (tutorialStatus) tutorialStatus.textContent = `${tutorialStep + 1} / ${steps.length}`;
    if (tutorialPrevious) tutorialPrevious.disabled = tutorialStep === 0;
    if (tutorialNext) tutorialNext.textContent = tutorialStep === steps.length - 1 ? 'Jogar' : 'Próximo';
  }

  function nextTutorial() {
    const steps = tutorialView.querySelectorAll('.taijifu-tutorial-step');
    if (tutorialStep < steps.length - 1) {
      tutorialStep += 1;
      renderTutorial();
      return;
    }
    enterArena(true);
  }

  function previousTutorial() {
    if (tutorialStep === 0) return;
    tutorialStep -= 1;
    renderTutorial();
  }

  function enterArena(markTutorialSeen = false) {
    if (markTutorialSeen) {
      preferences.tutorialSeen = true;
      savePreferences();
    }
    closeDialog();
    if (window.taijifuWebShell?.entered) {
      closeMenu();
      return;
    }
    window.taijifuWebShell?.enter?.();
    shell.setAttribute('aria-hidden', 'true');
    announce('Arena iniciada.');
  }

  function openMenu() {
    if (!window.taijifuWebShell?.entered) return;
    window.taijifuWebShell?.releaseAllKeys?.();
    document.body.classList.add('taijifu-menu-open');
    shell.dataset.mode = 'menu';
    shell.setAttribute('aria-hidden', 'false');
    setPaused(true);
    enterButton.textContent = 'Voltar à luta';
    enterButton.focus({ preventScroll: true });
  }

  function closeMenu() {
    document.body.classList.remove('taijifu-menu-open');
    shell.dataset.mode = 'launch';
    shell.setAttribute('aria-hidden', String(Boolean(window.taijifuWebShell?.entered)));
    setPaused(false);
    window.setTimeout(() => document.getElementById('canvas')?.focus({ preventScroll: true }), 0);
  }

  injectGameUi();

  enterButton.addEventListener('click', () => enterArena(false));
  menuButton?.addEventListener('click', openMenu);
  tutorialButton?.addEventListener('click', () => showView('tutorial'));
  settingsButton?.addEventListener('click', () => showView('settings'));
  dialogClose?.addEventListener('click', closeDialog);
  tutorialPrevious?.addEventListener('click', previousTutorial);
  tutorialNext?.addEventListener('click', nextTutorial);

  dialog.addEventListener('pointerdown', (event) => {
    if (event.target === dialog) closeDialog();
  });
  dialogPanel?.addEventListener('pointerdown', (event) => event.stopPropagation());

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
    }
  }, { capture: true });

  const observer = new MutationObserver(() => {
    if (!window.taijifuWebShell?.ready) return;
    enterButton.textContent = window.taijifuWebShell.entered ? 'Voltar à luta' : 'Entrar na arena';
  });
  observer.observe(shell, { attributes: true, attributeFilter: ['data-state', 'data-mode'] });

  window.taijifuWebMenu = { open: openMenu, close: closeMenu, tutorial: () => showView('tutorial'), settings: () => showView('settings') };
})();

// Tehkné Solutions
