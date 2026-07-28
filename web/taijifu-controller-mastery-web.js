(() => {
  'use strict';

  const ACTIONS = [
    ['jump', 'Pular'], ['dodge', 'Esquiva'], ['attack', 'Golpe'],
    ['push', 'Empurrão'], ['grab', 'Agarrão'], ['block', 'Guarda/aparo'],
    ['element', 'Elemento'], ['echo', 'Eco'], ['swap', 'Trocar arma']
  ];

  const ui = {};
  const state = {
    player: 1,
    data: null,
    points: [0, 0.16, 0.44, 0.76, 1],
    dragging: null,
    refreshTimer: 0
  };

  function parse(value) {
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch (_error) { return null; }
    }
    return value && typeof value === 'object' ? value : null;
  }

  function snapshot() {
    return parse(window.taijifuControllerMasteryStateJson);
  }

  function invoke(payload = { command: 'get_state' }) {
    let result = null;
    try {
      if (typeof window.taijifuControllerMasteryCommand === 'function') {
        result = parse(window.taijifuControllerMasteryCommand(JSON.stringify(payload)));
      }
      if (!result && typeof window.taijifuControllerMasteryState === 'function') {
        result = parse(window.taijifuControllerMasteryState());
      }
    } catch (error) {
      console.warn('Taijifu Controller Mastery: ponte indisponível.', error);
    }
    return result || snapshot();
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    })[character]);
  }

  function playerState() {
    return state.data?.players?.[String(state.player)] || { device: state.player - 1, guid: '', profile: {} };
  }

  function injectStyle() {
    if (document.getElementById('taijifu-controller-mastery-style')) return;
    const style = document.createElement('style');
    style.id = 'taijifu-controller-mastery-style';
    style.textContent = `
      .taijifu-mastery-fieldset{border-color:rgba(255,197,91,.34)!important}
      .taijifu-mastery-head{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-bottom:10px}
      .taijifu-mastery-control{display:grid;gap:5px;color:rgba(221,233,245,.76);font-size:11px;font-weight:800}
      .taijifu-mastery-control select,.taijifu-mastery-control input[type=range]{width:100%}
      .taijifu-mastery-profile{margin:4px 0 10px;padding:8px 10px;border-radius:10px;color:rgba(220,235,249,.72);background:rgba(255,197,91,.07);font-size:10px;line-height:1.45}
      .taijifu-curve-editor{display:grid;grid-template-columns:minmax(0,1fr) 170px;gap:12px;align-items:center;margin:10px 0;padding:10px;border:1px solid rgba(135,204,255,.17);border-radius:13px;background:rgba(5,14,27,.64)}
      .taijifu-curve-svg{width:100%;min-height:180px;touch-action:none;overflow:visible}
      .taijifu-curve-grid{stroke:rgba(170,210,244,.12);stroke-width:1}.taijifu-curve-line{fill:none;stroke:#f0c56c;stroke-width:4;stroke-linecap:round;stroke-linejoin:round}
      .taijifu-curve-point{fill:#071426;stroke:#8ed7ff;stroke-width:4;cursor:grab}.taijifu-curve-point:active{cursor:grabbing;stroke:#86efb7}
      .taijifu-curve-values{display:grid;gap:7px}.taijifu-curve-value{display:grid;grid-template-columns:38px 1fr 42px;gap:6px;align-items:center;color:rgba(218,233,247,.72);font-size:10px}.taijifu-curve-value output{text-align:right;color:#f0d58c;font-weight:900}
      .taijifu-mastery-triggers{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin:10px 0}
      .taijifu-mastery-options{display:grid;gap:6px;margin:8px 0}
      .taijifu-mastery-actions{display:flex;flex-wrap:wrap;gap:7px;margin-top:10px}
      .taijifu-mastery-metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px;margin-top:10px}
      .taijifu-mastery-metric{padding:9px 8px;border-radius:10px;background:rgba(120,177,226,.08);text-align:center}.taijifu-mastery-metric strong{display:block;color:#f0d58c;font-size:16px}.taijifu-mastery-metric span{color:rgba(211,226,240,.62);font-size:9px;text-transform:uppercase;letter-spacing:.08em}
      .taijifu-mastery-status{margin:9px 0 0;color:rgba(210,228,245,.68);font-size:11px;line-height:1.45}
      @media(max-width:760px){.taijifu-mastery-head,.taijifu-mastery-triggers{grid-template-columns:1fr}.taijifu-curve-editor{grid-template-columns:1fr}.taijifu-mastery-metrics{grid-template-columns:repeat(2,1fr)}}
    `;
    document.head.appendChild(style);
  }

  function injectPanel() {
    if (document.getElementById('taijifu-controller-mastery-panel')) return true;
    const settings = document.getElementById('taijifu-settings-view');
    const footer = settings?.querySelector('.taijifu-settings-footer');
    if (!settings || !footer) return false;

    const options = ACTIONS.map(([id, label]) => `<option value="${id}">${label}</option>`).join('');
    const fieldset = document.createElement('fieldset');
    fieldset.id = 'taijifu-controller-mastery-panel';
    fieldset.className = 'taijifu-settings-group taijifu-mastery-fieldset';
    fieldset.dataset.testid = 'controller-mastery-panel';
    fieldset.innerHTML = `
      <legend>Maestria, curva personalizada e combos</legend>
      <div class="taijifu-mastery-head">
        <label class="taijifu-mastery-control">Jogador<select id="taijifu-mastery-player"><option value="1">Jogador 1</option><option value="2">Jogador 2</option></select></label>
        <label class="taijifu-mastery-control">Controle / perfil<select id="taijifu-mastery-device"></select></label>
      </div>
      <p id="taijifu-mastery-profile" class="taijifu-mastery-profile">Perfil automático aguardando o GUID do controle.</p>
      <div class="taijifu-curve-editor">
        <svg id="taijifu-curve-svg" class="taijifu-curve-svg" viewBox="0 0 360 160" role="img" aria-label="Editor visual da curva de resposta">
          <path class="taijifu-curve-grid" d="M10 10V150H350M10 115H350M10 80H350M10 45H350M95 10V150M180 10V150M265 10V150" />
          <path id="taijifu-curve-line" class="taijifu-curve-line" d="" />
          <circle class="taijifu-curve-point" data-index="1" r="9" tabindex="0" />
          <circle class="taijifu-curve-point" data-index="2" r="9" tabindex="0" />
          <circle class="taijifu-curve-point" data-index="3" r="9" tabindex="0" />
        </svg>
        <div id="taijifu-curve-values" class="taijifu-curve-values"></div>
      </div>
      <div class="taijifu-mastery-triggers">
        <label class="taijifu-mastery-control">L2 executa<select id="taijifu-mastery-left-trigger">${options}</select></label>
        <label class="taijifu-mastery-control">R2 executa<select id="taijifu-mastery-right-trigger">${options}</select></label>
        <label class="taijifu-mastery-control">Limiar dos gatilhos <output id="taijifu-mastery-trigger-value">0,55</output><input id="taijifu-mastery-trigger" type="range" min="0.20" max="0.92" step="0.01"></label>
        <label class="taijifu-mastery-control">Início da janela de cancelamento <output id="taijifu-mastery-cancel-value">68%</output><input id="taijifu-mastery-cancel" type="range" min="0.35" max="0.95" step="0.01"></label>
      </div>
      <div class="taijifu-mastery-options">
        <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Assistência de cancelamento</strong><small>Guarda ataques, esquiva, eco ou troca de arma pressionados no fim da recuperação.</small></span><span class="taijifu-setting-control"><input id="taijifu-mastery-cancel-assist" type="checkbox"></span></label>
        <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Exibir janelas técnicas</strong><small>Mostra aparo, startup, ativo, recuperação e abertura de cancelamento na arena.</small></span><span class="taijifu-setting-control"><input id="taijifu-mastery-windows" type="checkbox"></span></label>
      </div>
      <div class="taijifu-mastery-actions">
        <button id="taijifu-mastery-save" class="taijifu-dialog-action" data-role="primary" type="button">Salvar perfil</button>
        <button id="taijifu-mastery-dojo" class="taijifu-dialog-action" type="button">Dojo de combos</button>
        <button id="taijifu-mastery-reset" class="taijifu-dialog-action" type="button">Restaurar perfil</button>
      </div>
      <div id="taijifu-mastery-metrics" class="taijifu-mastery-metrics"></div>
      <p id="taijifu-mastery-status" class="taijifu-mastery-status">Aguardando o runtime de maestria.</p>
    `;
    settings.insertBefore(fieldset, footer);

    ui.root = fieldset;
    ui.player = document.getElementById('taijifu-mastery-player');
    ui.device = document.getElementById('taijifu-mastery-device');
    ui.profile = document.getElementById('taijifu-mastery-profile');
    ui.svg = document.getElementById('taijifu-curve-svg');
    ui.line = document.getElementById('taijifu-curve-line');
    ui.values = document.getElementById('taijifu-curve-values');
    ui.leftTrigger = document.getElementById('taijifu-mastery-left-trigger');
    ui.rightTrigger = document.getElementById('taijifu-mastery-right-trigger');
    ui.trigger = document.getElementById('taijifu-mastery-trigger');
    ui.triggerValue = document.getElementById('taijifu-mastery-trigger-value');
    ui.cancel = document.getElementById('taijifu-mastery-cancel');
    ui.cancelValue = document.getElementById('taijifu-mastery-cancel-value');
    ui.cancelAssist = document.getElementById('taijifu-mastery-cancel-assist');
    ui.windows = document.getElementById('taijifu-mastery-windows');
    ui.metrics = document.getElementById('taijifu-mastery-metrics');
    ui.status = document.getElementById('taijifu-mastery-status');
    bindEvents();
    return true;
  }

  function bindEvents() {
    ui.player.addEventListener('change', () => {
      state.player = Number(ui.player.value) || 1;
      render();
    });
    ui.device.addEventListener('change', () => execute({ command: 'assign_device', player: state.player, device: Number(ui.device.value) }, 'Controle associado e perfil GUID carregado.'));
    ui.trigger.addEventListener('input', updateLabels);
    ui.cancel.addEventListener('input', updateLabels);
    document.getElementById('taijifu-mastery-save').addEventListener('click', saveProfile);
    document.getElementById('taijifu-mastery-reset').addEventListener('click', () => execute({ command: 'reset_device', player: state.player }, 'Perfil do controle restaurado.'));
    document.getElementById('taijifu-mastery-dojo').addEventListener('click', startDojo);
    ui.windows.addEventListener('change', () => execute({ command: 'set_windows', enabled: ui.windows.checked }));

    ui.svg.addEventListener('pointerdown', (event) => {
      const point = event.target.closest('.taijifu-curve-point[data-index]');
      if (!point) return;
      state.dragging = Number(point.dataset.index);
      point.setPointerCapture?.(event.pointerId);
      updatePointFromPointer(event);
    });
    ui.svg.addEventListener('pointermove', (event) => {
      if (state.dragging !== null) updatePointFromPointer(event);
    });
    ui.svg.addEventListener('pointerup', () => {
      if (state.dragging !== null) {
        state.dragging = null;
        saveCurveOnly();
      }
    });
    ui.svg.addEventListener('pointercancel', () => { state.dragging = null; });
  }

  function updatePointFromPointer(event) {
    const index = state.dragging;
    if (index === null || index < 1 || index > 3) return;
    const rect = ui.svg.getBoundingClientRect();
    const y = ((event.clientY - rect.top) / Math.max(1, rect.height)) * 160;
    let value = Math.max(0, Math.min(1, (150 - y) / 140));
    value = Math.max(state.points[index - 1], Math.min(state.points[index + 1], value));
    state.points[index] = Number(value.toFixed(3));
    renderCurve();
  }

  function saveCurveOnly() {
    execute({ command: 'set_curve', player: state.player, points: state.points }, 'Curva personalizada salva no perfil do controle.');
  }

  function saveProfile() {
    const curveResult = invoke({ command: 'set_curve', player: state.player, points: state.points });
    const triggerResult = invoke({
      command: 'set_triggers', player: state.player,
      left_action: ui.leftTrigger.value, right_action: ui.rightTrigger.value,
      threshold: Number(ui.trigger.value)
    });
    const cancelResult = invoke({
      command: 'set_cancel', player: state.player,
      threshold: Number(ui.cancel.value), enabled: ui.cancelAssist.checked
    });
    state.data = cancelResult || triggerResult || curveResult || snapshot();
    render();
    ui.status.textContent = 'Perfil por modelo/GUID atualizado.';
  }

  function startDojo() {
    document.getElementById('taijifu-dialog-close')?.click();
    if (!window.taijifuWebShell?.entered) window.taijifuWebShell?.enter?.();
    window.taijifuWebMenu?.close?.();
    window.setTimeout(() => invoke({ command: 'start_dojo' }), 140);
  }

  function execute(payload, message = '') {
    const result = invoke(payload);
    if (result) {
      state.data = result;
      render();
      if (message) ui.status.textContent = message;
    } else {
      ui.status.textContent = 'A ponte de maestria ainda não respondeu.';
    }
  }

  function render() {
    if (!ui.root || !state.data) return;
    const current = playerState();
    const deviceProfile = current.profile || {};
    ui.player.value = String(state.player);
    renderDevices(Number(current.device ?? state.player - 1));
    state.points = sanitizePoints(deviceProfile.curve_points);
    ui.leftTrigger.value = deviceProfile.left_trigger_action || 'element';
    ui.rightTrigger.value = deviceProfile.right_trigger_action || 'attack';
    ui.trigger.value = String(Number(deviceProfile.trigger_threshold ?? 0.55));
    ui.cancel.value = String(Number(deviceProfile.cancel_threshold ?? 0.68));
    ui.cancelAssist.checked = deviceProfile.cancel_assist !== false;
    ui.windows.checked = state.data.show_windows !== false;
    ui.profile.innerHTML = `<strong>${escapeHtml(deviceProfile.name || 'Controle')}</strong><br>GUID: <code>${escapeHtml(current.guid || 'perfil de slot')}</code>`;
    updateLabels();
    renderCurve();
    renderMetrics();
    const dojo = state.data.dojo || {};
    const raw = state.data.raw_metrics || {};
    ui.status.textContent = `Dojo ${dojo.active ? `ativo • etapa ${Number(dojo.stage) + 1}/4` : (dojo.completed ? 'concluído' : 'pendente')} • ${raw.last_event || 'edite a curva ou inicie o treino.'}`;
  }

  function sanitizePoints(value) {
    const source = Array.isArray(value) ? value : [0, 0.16, 0.44, 0.76, 1];
    const points = [0, 0.16, 0.44, 0.76, 1];
    for (let index = 1; index <= 3; index += 1) {
      points[index] = Math.max(points[index - 1], Math.min(1, Number(source[index] ?? points[index])));
    }
    points[4] = 1;
    return points;
  }

  function renderDevices(selected) {
    const devices = state.data.devices || [];
    const options = [{ id: -1, name: 'Qualquer controle / perfil de slot', guid: '' }, ...devices];
    if (selected >= 0 && !options.some((item) => Number(item.id) === selected)) {
      options.push({ id: selected, name: `Dispositivo ${selected} não detectado`, guid: '' });
    }
    ui.device.innerHTML = options.map((device) => `<option value="${Number(device.id)}">${Number(device.id) >= 0 ? `#${Number(device.id)} • ` : ''}${escapeHtml(device.name)}</option>`).join('');
    ui.device.value = String(selected);
  }

  function renderCurve() {
    const coordinates = state.points.map((value, index) => [10 + index * 85, 150 - value * 140]);
    ui.line.setAttribute('d', `M${coordinates.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(' L')}`);
    ui.svg.querySelectorAll('.taijifu-curve-point').forEach((circle) => {
      const index = Number(circle.dataset.index);
      circle.setAttribute('cx', coordinates[index][0]);
      circle.setAttribute('cy', coordinates[index][1]);
      circle.setAttribute('aria-label', `Ponto ${index}: ${Math.round(state.points[index] * 100)}%`);
    });
    ui.values.innerHTML = [1, 2, 3].map((index) => `
      <label class="taijifu-curve-value"><span>${index * 25}%</span><input type="range" data-curve-index="${index}" min="0" max="1" step="0.01" value="${state.points[index]}"><output>${Math.round(state.points[index] * 100)}%</output></label>
    `).join('');
    ui.values.querySelectorAll('input[data-curve-index]').forEach((input) => {
      input.addEventListener('input', () => {
        const index = Number(input.dataset.curveIndex);
        const value = Math.max(state.points[index - 1], Math.min(state.points[index + 1], Number(input.value)));
        state.points[index] = Number(value.toFixed(3));
        renderCurve();
      }, { once: true });
      input.addEventListener('change', saveCurveOnly, { once: true });
    });
  }

  function updateLabels() {
    ui.triggerValue.textContent = Number(ui.trigger.value || 0.55).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    ui.cancelValue.textContent = `${Math.round(Number(ui.cancel.value || 0.68) * 100)}%`;
  }

  function renderMetrics() {
    const metrics = state.data.metrics || {};
    const cards = [
      ['Elo máximo', Number(metrics.max_chain || 0)],
      ['Precisão', `${Math.round(Number(metrics.accuracy || 0) * 100)}%`],
      ['Link médio', `${Math.round(Number(metrics.average_link_ms || 0))} ms`],
      ['Consistência', `${Math.round(Number(metrics.consistency_ms || 0))} ms`],
      ['Aparos', Number(metrics.parries || 0)],
      ['Cancels', Number(metrics.cancel_success || 0)],
      ['Cancel médio', `${Math.round(Number(metrics.average_cancel_ms || 0))} ms`],
      ['Tentativas', Number(metrics.attempts || 0)]
    ];
    ui.metrics.innerHTML = cards.map(([label, value]) => `<div class="taijifu-mastery-metric"><strong>${escapeHtml(value)}</strong><span>${escapeHtml(label)}</span></div>`).join('');
  }

  function refresh() {
    const data = invoke({ command: 'get_state' });
    if (data) {
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
    state.refreshTimer = window.setInterval(refresh, 650);
  }

  window.taijifuControllerMasteryWeb = {
    refresh,
    invoke,
    get state() { return state.data; },
    get points() { return [...state.points]; }
  };

  boot();
})();
