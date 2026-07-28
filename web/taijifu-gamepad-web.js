(() => {
  'use strict';

  const ACTIONS = [
    ['jump', 'Pular'], ['dodge', 'Esquiva'], ['attack', 'Golpe'],
    ['push', 'Empurrão'], ['grab', 'Agarrão'], ['block', 'Guarda/aparo'],
    ['element', 'Elemento'], ['echo', 'Eco'], ['swap', 'Trocar arma']
  ];

  const BUTTON_NAMES = {
    0: 'A / Cruz', 1: 'B / Círculo', 2: 'X / Quadrado', 3: 'Y / Triângulo',
    4: 'LB / L1', 5: 'RB / R1', 8: 'Select / View', 9: 'Start / Menu',
    10: 'L3', 11: 'R3', 12: 'D-pad ↑', 13: 'D-pad ↓', 14: 'D-pad ←', 15: 'D-pad →'
  };

  const ui = {
    root: null,
    player: null,
    device: null,
    deadzone: null,
    deadzoneValue: null,
    curve: null,
    trigger: null,
    triggerValue: null,
    haptics: null,
    vibration: null,
    vibrationValue: null,
    bindings: null,
    status: null,
    meters: null
  };

  const state = {
    ready: false,
    player: 1,
    data: null,
    captureSuffix: null,
    captureBaseline: new Set(),
    captureFrame: 0,
    refreshTimer: 0
  };

  function parseResult(value) {
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch (_error) { return null; }
    }
    return value && typeof value === 'object' ? value : null;
  }

  function invoke(payload = { command: 'get_state' }) {
    try {
      if (typeof window.taijifuGamepadExperienceCommand === 'function') {
        return parseResult(window.taijifuGamepadExperienceCommand(JSON.stringify(payload)));
      }
      if (typeof window.taijifuGamepadExperienceState === 'function') {
        return parseResult(window.taijifuGamepadExperienceState());
      }
    } catch (error) {
      console.warn('Taijifu Gamepad Web: comando indisponível.', error);
    }
    return null;
  }

  function buttonName(index) {
    return BUTTON_NAMES[index] || `Botão ${index}`;
  }

  function playerData() {
    const key = String(state.player);
    return {
      base: state.data?.base_profile?.players?.[key] || {},
      tuning: state.data?.profile?.players?.[key] || {}
    };
  }

  function connectedGamepads() {
    return Array.from(navigator.getGamepads?.() || []).filter(Boolean);
  }

  function injectStyle() {
    if (document.getElementById('taijifu-gamepad-web-style')) return;
    const style = document.createElement('style');
    style.id = 'taijifu-gamepad-web-style';
    style.textContent = `
      .taijifu-gamepad-fieldset{border-color:rgba(177,132,255,.30)!important}
      .taijifu-gamepad-head{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px}
      .taijifu-gamepad-control{display:grid;gap:5px;color:rgba(220,233,247,.75);font-size:11px;font-weight:800}
      .taijifu-gamepad-control select,.taijifu-gamepad-control input[type=range]{width:100%}
      .taijifu-gamepad-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:10px 0}
      .taijifu-gamepad-binding{display:flex;align-items:center;justify-content:space-between;gap:8px;min-height:42px;padding:8px 10px;border:1px solid rgba(159,211,255,.18);border-radius:10px;color:#eaf5ff;background:rgba(7,17,32,.70);font:inherit;cursor:pointer;text-align:left}
      .taijifu-gamepad-binding span{min-width:78px;padding:5px 7px;border-radius:7px;color:#e5c8ff;background:rgba(177,132,255,.10);font-size:10px;font-weight:900;text-align:center}
      .taijifu-gamepad-binding.is-capturing{border-color:#88efb8;box-shadow:0 0 0 2px rgba(136,239,184,.12)}
      .taijifu-gamepad-actions{display:flex;flex-wrap:wrap;gap:7px;margin-top:10px}
      .taijifu-gamepad-status{margin:8px 0 0;color:rgba(206,225,243,.68);font-size:11px;line-height:1.45}
      .taijifu-gamepad-meters{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:8px 0;color:rgba(211,226,241,.65);font-size:10px;text-align:center}
      .taijifu-gamepad-meter{padding:6px;border-radius:8px;background:rgba(112,161,205,.08)}
      @media(max-width:720px){.taijifu-gamepad-head,.taijifu-gamepad-grid{grid-template-columns:1fr}.taijifu-gamepad-meters{grid-template-columns:repeat(2,1fr)}}
    `;
    document.head.appendChild(style);
  }

  function injectPanel() {
    if (document.getElementById('taijifu-gamepad-web-panel')) return true;
    const settings = document.getElementById('taijifu-settings-view');
    const footer = settings?.querySelector('.taijifu-settings-footer');
    if (!settings || !footer) return false;

    const fieldset = document.createElement('fieldset');
    fieldset.id = 'taijifu-gamepad-web-panel';
    fieldset.className = 'taijifu-settings-group taijifu-gamepad-fieldset';
    fieldset.dataset.testid = 'gamepad-web-panel';
    fieldset.innerHTML = `
      <legend>Gamepads, resposta e dojo real</legend>
      <div class="taijifu-gamepad-head">
        <label class="taijifu-gamepad-control">Jogador<select id="taijifu-gamepad-player"><option value="1">Jogador 1</option><option value="2">Jogador 2</option></select></label>
        <label class="taijifu-gamepad-control">Dispositivo<select id="taijifu-gamepad-device"></select></label>
        <label class="taijifu-gamepad-control">Zona morta <output id="taijifu-gamepad-deadzone-value">0,25</output><input id="taijifu-gamepad-deadzone" type="range" min="0.15" max="0.55" step="0.01"></label>
        <label class="taijifu-gamepad-control">Curva analógica<select id="taijifu-gamepad-curve"><option value="linear">Linear</option><option value="precision">Precisão</option><option value="aggressive">Agressiva</option></select></label>
        <label class="taijifu-gamepad-control">Limiar L2/R2 <output id="taijifu-gamepad-trigger-value">0,55</output><input id="taijifu-gamepad-trigger" type="range" min="0.25" max="0.90" step="0.01"></label>
        <label class="taijifu-gamepad-control">Intensidade da vibração <output id="taijifu-gamepad-vibration-value">85%</output><input id="taijifu-gamepad-vibration" type="range" min="0" max="1" step="0.05"></label>
      </div>
      <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Vibração por impacto</strong><small>Acerto, defesa, aparo, quebra de postura, agarrão e eco possuem padrões próprios.</small></span><span class="taijifu-setting-control"><input id="taijifu-gamepad-haptics" type="checkbox"></span></label>
      <div id="taijifu-gamepad-meters" class="taijifu-gamepad-meters"></div>
      <div id="taijifu-gamepad-bindings" class="taijifu-gamepad-grid" data-testid="gamepad-bindings"></div>
      <div class="taijifu-gamepad-actions">
        <button id="taijifu-gamepad-calibrate-stick" class="taijifu-dialog-action" type="button">Calibrar analógico</button>
        <button id="taijifu-gamepad-calibrate-triggers" class="taijifu-dialog-action" type="button">Calibrar gatilhos</button>
        <button id="taijifu-gamepad-test-vibration" class="taijifu-dialog-action" type="button">Testar vibração</button>
        <button id="taijifu-gamepad-fundamentals" class="taijifu-dialog-action" type="button">Dojo fundamental</button>
        <button id="taijifu-gamepad-advanced" class="taijifu-dialog-action" data-role="primary" type="button">Dojo avançado</button>
        <button id="taijifu-gamepad-reset" class="taijifu-dialog-action" type="button">Restaurar gamepads</button>
      </div>
      <p id="taijifu-gamepad-status" class="taijifu-gamepad-status">Aguardando a ponte nativa do Godot.</p>
    `;
    settings.insertBefore(fieldset, footer);

    ui.root = fieldset;
    ui.player = document.getElementById('taijifu-gamepad-player');
    ui.device = document.getElementById('taijifu-gamepad-device');
    ui.deadzone = document.getElementById('taijifu-gamepad-deadzone');
    ui.deadzoneValue = document.getElementById('taijifu-gamepad-deadzone-value');
    ui.curve = document.getElementById('taijifu-gamepad-curve');
    ui.trigger = document.getElementById('taijifu-gamepad-trigger');
    ui.triggerValue = document.getElementById('taijifu-gamepad-trigger-value');
    ui.haptics = document.getElementById('taijifu-gamepad-haptics');
    ui.vibration = document.getElementById('taijifu-gamepad-vibration');
    ui.vibrationValue = document.getElementById('taijifu-gamepad-vibration-value');
    ui.bindings = document.getElementById('taijifu-gamepad-bindings');
    ui.status = document.getElementById('taijifu-gamepad-status');
    ui.meters = document.getElementById('taijifu-gamepad-meters');
    bindEvents();
    return true;
  }

  function bindEvents() {
    ui.player.addEventListener('change', () => {
      state.player = Number(ui.player.value) || 1;
      render();
    });
    ui.device.addEventListener('change', () => execute({ command: 'set_device', player: state.player, device: Number(ui.device.value) }));
    ui.deadzone.addEventListener('change', () => execute({ command: 'set_deadzone', player: state.player, deadzone: Number(ui.deadzone.value) }));
    ui.curve.addEventListener('change', saveTuning);
    ui.trigger.addEventListener('change', saveTuning);
    ui.haptics.addEventListener('change', saveTuning);
    ui.vibration.addEventListener('change', saveTuning);
    ui.bindings.addEventListener('click', (event) => {
      const button = event.target.closest('.taijifu-gamepad-binding[data-suffix]');
      if (button) beginCapture(button.dataset.suffix);
    });
    document.getElementById('taijifu-gamepad-calibrate-stick').addEventListener('click', () => execute({ command: 'calibrate_stick', player: state.player }, 'Analógico calibrado.'));
    document.getElementById('taijifu-gamepad-calibrate-triggers').addEventListener('click', () => execute({ command: 'calibrate_triggers', player: state.player }, 'Gatilhos calibrados.'));
    document.getElementById('taijifu-gamepad-test-vibration').addEventListener('click', () => execute({ command: 'test_vibration', player: state.player }, 'Padrão de vibração enviado.'));
    document.getElementById('taijifu-gamepad-reset').addEventListener('click', () => execute({ command: 'reset' }, 'Perfis de gamepad restaurados.'));
    document.getElementById('taijifu-gamepad-fundamentals').addEventListener('click', () => startTraining('start_fundamentals'));
    document.getElementById('taijifu-gamepad-advanced').addEventListener('click', () => startTraining('start_advanced'));
  }

  function saveTuning() {
    execute({
      command: 'set_tuning',
      player: state.player,
      curve: ui.curve.value,
      trigger_threshold: Number(ui.trigger.value),
      haptics_enabled: ui.haptics.checked,
      vibration_scale: Number(ui.vibration.value)
    }, 'Resposta do controle atualizada.');
  }

  function execute(payload, message = '') {
    const result = invoke(payload);
    if (result) {
      state.data = result;
      render();
      if (message) ui.status.textContent = message;
    } else {
      ui.status.textContent = 'A ponte de gamepad ainda não respondeu.';
    }
  }

  function startTraining(command) {
    document.getElementById('taijifu-dialog-close')?.click();
    if (!window.taijifuWebShell?.entered) window.taijifuWebShell?.enter?.();
    window.taijifuWebMenu?.close?.();
    window.setTimeout(() => invoke({ command }), 140);
  }

  function render() {
    if (!ui.root || !state.data) return;
    const { base, tuning } = playerData();
    ui.player.value = String(state.player);
    renderDevices(Number(base.device ?? state.player - 1));
    ui.deadzone.value = String(Number(base.deadzone ?? 0.25));
    ui.deadzoneValue.textContent = Number(ui.deadzone.value).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    ui.curve.value = tuning.response_curve || 'linear';
    ui.trigger.value = String(Number(tuning.trigger_threshold ?? 0.55));
    ui.triggerValue.textContent = Number(ui.trigger.value).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    ui.haptics.checked = tuning.haptics_enabled !== false;
    ui.vibration.value = String(Number(tuning.vibration_scale ?? 0.85));
    ui.vibrationValue.textContent = `${Math.round(Number(ui.vibration.value) * 100)}%`;
    renderBindings(base.buttons || {});
    renderMeters(Number(base.device ?? state.player - 1));
    const advanced = state.data.advanced_training || {};
    const fundamentalDone = Boolean(state.data.base_profile?.real_training_completed);
    ui.status.textContent = `P${state.player}: L2 = Elemento, R2 = Golpe. Dojo fundamental ${fundamentalDone ? 'concluído' : 'pendente'}; avançado ${advanced.completed ? 'concluído' : 'pendente'}.`;
  }

  function renderDevices(selected) {
    const devices = state.data.devices || [];
    const options = [{ id: -1, name: 'Qualquer controle conectado' }, ...devices];
    if (selected >= 0 && !options.some((item) => Number(item.id) === selected)) {
      options.push({ id: selected, name: `Dispositivo ${selected} não detectado` });
    }
    ui.device.innerHTML = options.map((device) => `<option value="${device.id}">${device.id >= 0 ? `#${device.id} • ` : ''}${device.name}</option>`).join('');
    ui.device.value = String(selected);
  }

  function renderBindings(buttons) {
    ui.bindings.innerHTML = ACTIONS.map(([suffix, label]) => {
      const index = Number(buttons[suffix] ?? 0);
      const capturing = state.captureSuffix === suffix;
      return `<button class="taijifu-gamepad-binding${capturing ? ' is-capturing' : ''}" type="button" data-suffix="${suffix}" data-testid="gamepad-${suffix}"><strong>${label}</strong><span>${capturing ? 'Pressione…' : buttonName(index)}</span></button>`;
    }).join('');
  }

  function renderMeters(deviceId) {
    const device = (state.data.devices || []).find((item) => Number(item.id) === deviceId);
    const values = device || { left_x: 0, left_y: 0, left_trigger: 0, right_trigger: 0 };
    ui.meters.innerHTML = [
      ['Eixo X', values.left_x], ['Eixo Y', values.left_y],
      ['L2', values.left_trigger], ['R2', values.right_trigger]
    ].map(([label, value]) => `<span class="taijifu-gamepad-meter"><strong>${label}</strong><br>${Number(value || 0).toFixed(2)}</span>`).join('');
  }

  function beginCapture(suffix) {
    state.captureSuffix = suffix;
    state.captureBaseline = new Set();
    for (const gamepad of connectedGamepads()) {
      gamepad.buttons.forEach((button, index) => { if (button.pressed || button.value > 0.5) state.captureBaseline.add(`${gamepad.index}:${index}`); });
    }
    ui.status.textContent = 'Pressione um botão novo no controle. Start/Menu e Guide são reservados.';
    renderBindings(playerData().base.buttons || {});
    cancelAnimationFrame(state.captureFrame);
    state.captureFrame = requestAnimationFrame(pollCapture);
  }

  function pollCapture() {
    if (!state.captureSuffix) return;
    for (const gamepad of connectedGamepads()) {
      for (let index = 0; index < gamepad.buttons.length; index += 1) {
        const button = gamepad.buttons[index];
        const token = `${gamepad.index}:${index}`;
        if ((button.pressed || button.value > 0.5) && !state.captureBaseline.has(token) && ![9, 16].includes(index)) {
          const suffix = state.captureSuffix;
          state.captureSuffix = null;
          execute({ command: 'set_binding', player: state.player, suffix, button: index, device: gamepad.index }, `${suffix} remapeado para ${buttonName(index)}.`);
          return;
        }
      }
    }
    state.captureFrame = requestAnimationFrame(pollCapture);
  }

  function refresh() {
    const data = invoke({ command: 'get_state' });
    if (data) {
      state.ready = true;
      state.data = data;
      render();
    }
  }

  function boot() {
    injectStyle();
    if (!injectPanel()) {
      window.setTimeout(boot, 120);
      return;
    }
    refresh();
    state.refreshTimer = window.setInterval(() => {
      if (!state.captureSuffix) refresh();
    }, 650);
  }

  window.taijifuGamepadWeb = {
    refresh,
    invoke,
    get state() { return state.data; }
  };

  boot();
})();
