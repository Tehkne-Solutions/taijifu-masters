(() => {
  'use strict';

  const PATH_LABELS = { tai: 'Tai', ji: 'Ji', fu: 'Fu' };
  const TIER_LABELS = ['Iniciado', 'Fundamento', 'Domínio', 'Mestria'];
  const ui = {};
  const state = { data: null, refreshTimer: 0, pendingCommand: null };

  function parse(value) {
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch (_error) { return null; }
    }
    return value && typeof value === 'object' ? value : null;
  }

  function snapshot() {
    return parse(window.taijifuGhostMasteryStateJson);
  }

  function invoke(payload = { command: 'get_state' }) {
    let result = null;
    try {
      if (typeof window.taijifuGhostMasteryCommand === 'function') {
        result = parse(window.taijifuGhostMasteryCommand(JSON.stringify(payload)));
      }
      if (!result && typeof window.taijifuGhostMasteryState === 'function') {
        result = parse(window.taijifuGhostMasteryState());
      }
    } catch (error) {
      console.warn('Taijifu Input Ghost Mastery: ponte indisponível.', error);
    }
    return result || snapshot();
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    })[character]);
  }

  function number(value, digits = 0) {
    return Number(value || 0).toLocaleString('pt-BR', {
      minimumFractionDigits: digits,
      maximumFractionDigits: digits
    });
  }

  function signed(value, suffix = '') {
    const numeric = Number(value || 0);
    const prefix = numeric > 0 ? '+' : '';
    return `${prefix}${number(numeric, Number.isInteger(numeric) ? 0 : 2)}${suffix}`;
  }

  function injectStyle() {
    if (document.getElementById('taijifu-ghost-mastery-style')) return;
    const style = document.createElement('style');
    style.id = 'taijifu-ghost-mastery-style';
    style.textContent = `
      .taijifu-ghost-fieldset{border-color:rgba(105,228,255,.34)!important}
      .taijifu-ghost-actions{display:flex;flex-wrap:wrap;gap:7px;margin:9px 0}
      .taijifu-ghost-summary{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px;margin:9px 0}
      .taijifu-ghost-card{padding:9px;border-radius:11px;background:rgba(89,196,235,.08);text-align:center}
      .taijifu-ghost-card strong{display:block;color:#9feaff;font-size:16px}.taijifu-ghost-card span{color:rgba(215,232,245,.62);font-size:9px;letter-spacing:.08em;text-transform:uppercase}
      .taijifu-comparison{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:9px 0}
      .taijifu-comparison-panel{padding:10px;border:1px solid rgba(133,211,244,.14);border-radius:12px;background:rgba(5,14,27,.58)}
      .taijifu-comparison-panel h4{margin:0 0 7px;color:#d9f4ff;font-size:11px;text-transform:uppercase}.taijifu-comparison-line{display:flex;justify-content:space-between;gap:10px;padding:3px 0;color:rgba(215,231,245,.7);font-size:10px}.taijifu-comparison-line strong{color:#f2d78d}
      .taijifu-cert-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin:10px 0}
      .taijifu-cert-card{padding:11px;border:1px solid rgba(255,215,120,.18);border-radius:13px;background:linear-gradient(145deg,rgba(18,31,49,.86),rgba(8,18,31,.82))}.taijifu-cert-card h4{margin:0;color:#f2d78d;font-size:16px}.taijifu-cert-rank{display:inline-block;margin:5px 0 8px;padding:4px 7px;border-radius:999px;color:#07111d;background:#9feaff;font-size:9px;font-weight:900;letter-spacing:.08em}.taijifu-cert-progress{height:5px;border-radius:999px;background:rgba(255,255,255,.08);overflow:hidden}.taijifu-cert-progress i{display:block;height:100%;background:linear-gradient(90deg,#65d7ff,#f0ce74)}.taijifu-cert-meta{margin-top:7px;color:rgba(211,228,242,.65);font-size:9px;line-height:1.45}
      .taijifu-challenges{display:grid;gap:6px;max-height:190px;overflow:auto;margin:8px 0}.taijifu-challenge{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;padding:8px 9px;border-radius:10px;background:rgba(118,177,226,.07)}.taijifu-challenge strong{color:#dcefff;font-size:11px}.taijifu-challenge small{display:block;margin-top:2px;color:rgba(207,225,240,.56);font-size:9px}.taijifu-challenge em{align-self:center;padding:4px 7px;border-radius:999px;color:#07111d;background:#f0ce74;font-size:9px;font-style:normal;font-weight:900}
      .taijifu-weapon-row{display:flex;justify-content:space-between;gap:12px;padding:9px 10px;border-radius:11px;background:rgba(240,206,116,.07);color:rgba(219,234,246,.7);font-size:10px}.taijifu-weapon-row strong{color:#f0d58c}
      .taijifu-ghost-status{margin:8px 0 0;color:rgba(210,229,244,.68);font-size:10px;line-height:1.45}
      .taijifu-ghost-live{position:fixed;left:50%;bottom:max(18px,env(safe-area-inset-bottom));z-index:980;display:flex;align-items:center;gap:10px;transform:translateX(-50%);padding:9px 12px;border:1px solid rgba(116,225,255,.42);border-radius:999px;color:#e9f8ff;background:rgba(4,13,25,.92);box-shadow:0 18px 50px rgba(0,0,0,.45);backdrop-filter:blur(14px)}.taijifu-ghost-live[hidden]{display:none}.taijifu-ghost-live strong{color:#8fe8ff;font-size:11px}.taijifu-ghost-live span{font-size:10px;color:rgba(216,233,246,.72)}.taijifu-ghost-live button{border:0;border-radius:999px;padding:6px 10px;color:#07111d;background:#f0ce74;font:inherit;font-size:10px;font-weight:900;cursor:pointer}
      @media(max-width:760px){.taijifu-ghost-summary{grid-template-columns:repeat(2,1fr)}.taijifu-cert-grid,.taijifu-comparison{grid-template-columns:1fr}.taijifu-ghost-live{bottom:calc(max(12px,env(safe-area-inset-bottom)) + 138px);max-width:calc(100vw - 190px)}}
    `;
    document.head.appendChild(style);
  }

  function injectPanel() {
    if (document.getElementById('taijifu-input-ghost-panel')) return true;
    const settings = document.getElementById('taijifu-settings-view');
    const footer = settings?.querySelector('.taijifu-settings-footer');
    if (!settings || !footer) return false;

    const fieldset = document.createElement('fieldset');
    fieldset.id = 'taijifu-input-ghost-panel';
    fieldset.className = 'taijifu-settings-group taijifu-ghost-fieldset';
    fieldset.dataset.testid = 'input-ghost-mastery-panel';
    fieldset.innerHTML = `
      <legend>Fantasma, desafios e certificações Tai · Ji · Fu</legend>
      <div class="taijifu-ghost-actions">
        <button id="taijifu-ghost-record" class="taijifu-dialog-action" data-role="primary" type="button">Gravar tentativa</button>
        <button id="taijifu-ghost-play" class="taijifu-dialog-action" type="button">Reproduzir melhor</button>
        <button id="taijifu-ghost-clear" class="taijifu-dialog-action" type="button">Limpar recorde</button>
      </div>
      <label class="taijifu-setting-row"><span class="taijifu-setting-copy"><strong>Overlay de treino</strong><small>Mostra gravação, fantasma, inputs e resultado sobre a arena.</small></span><span class="taijifu-setting-control"><input id="taijifu-ghost-overlay" type="checkbox"></span></label>
      <div id="taijifu-ghost-summary" class="taijifu-ghost-summary"></div>
      <div id="taijifu-ghost-comparison" class="taijifu-comparison"></div>
      <div id="taijifu-weapon-mastery" class="taijifu-weapon-row"></div>
      <div id="taijifu-certifications" class="taijifu-cert-grid"></div>
      <h4 style="margin:11px 0 5px;color:#dcefff;font-size:11px">Desafios por técnica</h4>
      <div id="taijifu-technique-challenges" class="taijifu-challenges"></div>
      <p id="taijifu-ghost-status" class="taijifu-ghost-status">Aguardando o runtime de gravação.</p>
    `;
    settings.insertBefore(fieldset, footer);

    const live = document.createElement('aside');
    live.id = 'taijifu-ghost-live';
    live.className = 'taijifu-ghost-live';
    live.hidden = true;
    live.innerHTML = '<strong id="taijifu-ghost-live-title">REC</strong><span id="taijifu-ghost-live-copy">0,0 s</span><button id="taijifu-ghost-live-stop" type="button">Parar</button>';
    document.body.appendChild(live);

    ui.root = fieldset;
    ui.record = document.getElementById('taijifu-ghost-record');
    ui.play = document.getElementById('taijifu-ghost-play');
    ui.clear = document.getElementById('taijifu-ghost-clear');
    ui.overlay = document.getElementById('taijifu-ghost-overlay');
    ui.summary = document.getElementById('taijifu-ghost-summary');
    ui.comparison = document.getElementById('taijifu-ghost-comparison');
    ui.weapon = document.getElementById('taijifu-weapon-mastery');
    ui.certifications = document.getElementById('taijifu-certifications');
    ui.challenges = document.getElementById('taijifu-technique-challenges');
    ui.status = document.getElementById('taijifu-ghost-status');
    ui.live = live;
    ui.liveTitle = document.getElementById('taijifu-ghost-live-title');
    ui.liveCopy = document.getElementById('taijifu-ghost-live-copy');
    ui.liveStop = document.getElementById('taijifu-ghost-live-stop');
    bindEvents();
    return true;
  }

  function bindEvents() {
    ui.record.addEventListener('click', startRecording);
    ui.play.addEventListener('click', playBest);
    ui.clear.addEventListener('click', () => execute({ command: 'clear_best' }, 'Recorde e fantasma removidos.'));
    ui.overlay.addEventListener('change', () => execute({ command: 'set_overlay', enabled: ui.overlay.checked }));
    ui.liveStop.addEventListener('click', () => {
      if (state.data?.recording?.active) execute({ command: 'stop_recording' }, 'Tentativa gravada e comparada.');
      else execute({ command: 'stop_playback' }, 'Fantasma encerrado.');
    });
  }

  function enterArena() {
    document.getElementById('taijifu-dialog-close')?.click();
    if (!window.taijifuWebShell?.entered) window.taijifuWebShell?.enter?.();
    window.taijifuWebMenu?.close?.();
    window.taijifuGodotBridge?.setPaused?.(false);
  }

  function confirmArenaCommand(payload, predicate, successMessage, initialResult = null) {
    if (state.pendingCommand) window.clearTimeout(state.pendingCommand);
    if (initialResult) {
      state.data = initialResult;
      render();
      if (predicate(initialResult)) {
        state.pendingCommand = null;
        if (ui.status) ui.status.textContent = successMessage;
        return;
      }
    }
    let attempts = 0;
    const run = () => {
      attempts += 1;
      const shouldSend = attempts === 1 || attempts === 4;
      const result = invoke(shouldSend ? payload : { command: 'get_state' });
      if (result) {
        state.data = result;
        render();
      }
      if (predicate(result || state.data)) {
        state.pendingCommand = null;
        if (ui.status) ui.status.textContent = successMessage;
        return;
      }
      if (attempts >= 10) {
        state.pendingCommand = null;
        if (ui.status) ui.status.textContent = 'O runtime não confirmou a ação. Abra o menu e tente novamente.';
        return;
      }
      state.pendingCommand = window.setTimeout(run, 180);
    };
    state.pendingCommand = window.setTimeout(run, 180);
  }

  function startRecording() {
    const initial = invoke({ command: 'start_recording' });
    if (initial) {
      state.data = initial;
      render();
    }
    enterArena();
    confirmArenaCommand(
      { command: 'start_recording' },
      (data) => Boolean(data?.recording?.active),
      'Gravação iniciada. F6 também encerra.',
      initial
    );
  }

  function playBest() {
    const initial = invoke({ command: 'play_best' });
    if (initial) {
      state.data = initial;
      render();
    }
    enterArena();
    confirmArenaCommand(
      { command: 'play_best' },
      (data) => Boolean(data?.playback?.active),
      'Fantasma do melhor combo iniciado.',
      initial
    );
  }

  function execute(payload, message = '') {
    const result = invoke(payload);
    if (result) {
      state.data = result;
      render();
      if (message && ui.status) ui.status.textContent = message;
    } else if (ui.status) {
      ui.status.textContent = 'A ponte de fantasma ainda não respondeu.';
    }
    return result;
  }

  function render() {
    if (!ui.root || !state.data) return;
    const recording = state.data.recording || {};
    const best = state.data.best || {};
    const playback = state.data.playback || {};
    const currentSummary = recording.summary || {};
    const bestSummary = best.summary || {};
    ui.overlay.checked = state.data.show_overlay !== false;
    ui.record.textContent = recording.active ? 'Gravando…' : 'Gravar tentativa';
    ui.record.disabled = Boolean(recording.active);
    ui.play.disabled = !best.available || Boolean(playback.active);
    ui.clear.disabled = !best.available;

    renderSummary(currentSummary, bestSummary);
    renderComparison(state.data.comparison || {});
    renderWeapon(state.data.weapon_mastery || {});
    renderCertifications(state.data.certifications || {}, state.data.styles || {});
    renderChallenges(state.data.challenges || {});
    renderLive(recording, playback);

    const sessions = Number(state.data.sessions || 0);
    if (recording.active) ui.status.textContent = `Gravando tentativa ${sessions + 1} • ${recording.frame_count || 0} frames.`;
    else if (playback.active) ui.status.textContent = `Fantasma em reprodução • ${(Number(playback.elapsed_ms || 0) / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 1 })} s.`;
    else ui.status.textContent = best.available ? `Recorde disponível • ${best.frame_count || 0} frames • ${sessions} sessões.` : 'Grave uma tentativa para criar seu primeiro fantasma.';
  }

  function renderSummary(current, best) {
    const source = Object.keys(current).length ? current : best;
    const cards = [
      ['Pontuação', Number(source.score || 0)],
      ['Precisão', `${Math.round(Number(source.accuracy || 0) * 100)}%`],
      ['Elo máximo', Number(source.max_chain || 0)],
      ['Link médio', `${Math.round(Number(source.average_link_ms || 0))} ms`]
    ];
    ui.summary.innerHTML = cards.map(([label, value]) => `<div class="taijifu-ghost-card"><strong>${escapeHtml(value)}</strong><span>${escapeHtml(label)}</span></div>`).join('');
  }

  function renderComparison(comparison) {
    const current = comparison.current || {};
    const best = comparison.best || {};
    if (!comparison.available) {
      ui.comparison.innerHTML = '<div class="taijifu-comparison-panel"><h4>Comparação</h4><div class="taijifu-comparison-line"><span>Estado</span><strong>aguardando duas tentativas</strong></div></div>';
      return;
    }
    const deltas = comparison.deltas || {};
    const panel = (title, data) => `
      <div class="taijifu-comparison-panel"><h4>${title}</h4>
        <div class="taijifu-comparison-line"><span>Pontos</span><strong>${number(data.score)}</strong></div>
        <div class="taijifu-comparison-line"><span>Precisão</span><strong>${Math.round(Number(data.accuracy || 0) * 100)}%</strong></div>
        <div class="taijifu-comparison-line"><span>Elo</span><strong>${number(data.max_chain)}</strong></div>
        <div class="taijifu-comparison-line"><span>Link</span><strong>${number(data.average_link_ms)} ms</strong></div>
      </div>`;
    ui.comparison.innerHTML = panel('Tentativa atual', current) + panel('Melhor tentativa', best) + `
      <div class="taijifu-comparison-panel" style="grid-column:1/-1"><h4>Variação</h4>
        <div class="taijifu-comparison-line"><span>Pontuação</span><strong>${signed(deltas.score)}</strong></div>
        <div class="taijifu-comparison-line"><span>Precisão</span><strong>${signed(Number(deltas.accuracy || 0) * 100, '%')}</strong></div>
        <div class="taijifu-comparison-line"><span>Elo</span><strong>${signed(deltas.max_chain)}</strong></div>
        <div class="taijifu-comparison-line"><span>Link menor é melhor</span><strong>${signed(deltas.average_link_ms, ' ms')}</strong></div>
      </div>`;
  }

  function renderWeapon(weapon) {
    const current = weapon.current || {};
    if (!weapon.current_weapon) {
      ui.weapon.innerHTML = '<span>Maestria da arma</span><strong>Aguardando lutador</strong>';
      return;
    }
    ui.weapon.innerHTML = `<span>Arma atual: <strong>${escapeHtml(weapon.current_weapon)}</strong></span><span>${escapeHtml(current.stage_label || 'DESCONHECIDA')} • <strong>${number(current.xp)} XP</strong></span>`;
  }

  function renderCertifications(certifications, styles) {
    ui.certifications.innerHTML = ['tai', 'ji', 'fu'].map((path) => {
      const cert = certifications[path] || {};
      const style = styles[path] || {};
      const ratio = Math.max(0, Math.min(1, Number(style.xp || 0) / 300));
      const special = cert.requirements?.special || {};
      return `<article class="taijifu-cert-card" data-path="${path}">
        <h4>${PATH_LABELS[path]}</h4><span class="taijifu-cert-rank">${escapeHtml(cert.label || 'EM FORMAÇÃO')}</span>
        <div class="taijifu-cert-progress"><i style="width:${Math.round(ratio * 100)}%"></i></div>
        <div class="taijifu-cert-meta">${number(style.xp)} XP • ${number(style.hits)} acertos • elo ${number(style.best_chain)}<br>${escapeHtml(special.current || '')}<br>Meta: ${escapeHtml(special.label || '')}</div>
      </article>`;
    }).join('');
  }

  function renderChallenges(challenges) {
    const items = Object.values(challenges).sort((a, b) => Number(b.tier || 0) - Number(a.tier || 0) || Number(b.attempts || 0) - Number(a.attempts || 0)).slice(0, 12);
    if (!items.length) {
      ui.challenges.innerHTML = '<div class="taijifu-challenge"><div><strong>Nenhuma técnica registrada</strong><small>Use golpes na arena para abrir desafios individuais.</small></div><em>0/3</em></div>';
      return;
    }
    ui.challenges.innerHTML = items.map((challenge) => {
      const attempts = Number(challenge.attempts || 0);
      const hits = Number(challenge.hits || 0);
      const accuracy = Math.round((hits / Math.max(1, attempts)) * 100);
      const tier = Math.max(0, Math.min(3, Number(challenge.tier || 0)));
      return `<div class="taijifu-challenge"><div><strong>${escapeHtml(challenge.display_name || challenge.technique_id)}</strong><small>${PATH_LABELS[challenge.path] || challenge.path} • ${hits}/${attempts} acertos • ${accuracy}% • elo ${number(challenge.best_chain)}</small></div><em>${TIER_LABELS[tier]}</em></div>`;
    }).join('');
  }

  function renderLive(recording, playback) {
    const active = Boolean(recording.active || playback.active);
    ui.live.hidden = !active;
    if (!active) return;
    if (recording.active) {
      ui.liveTitle.textContent = '● REC';
      ui.liveCopy.textContent = `${number(Number(recording.elapsed_ms || 0) / 1000, 1)} s • ${recording.frame_count || 0} frames`;
      ui.liveStop.textContent = 'Salvar tentativa';
    } else {
      ui.liveTitle.textContent = '◇ FANTASMA';
      const actions = Array.isArray(playback.actions) ? playback.actions.join(', ') : '';
      ui.liveCopy.textContent = `${number(Number(playback.elapsed_ms || 0) / 1000, 1)} / ${number(Number(playback.duration_ms || 0) / 1000, 1)} s${actions ? ` • ${actions}` : ''}`;
      ui.liveStop.textContent = 'Encerrar replay';
    }
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
    state.refreshTimer = window.setInterval(refresh, 300);
  }

  window.taijifuGhostMasteryWeb = {
    refresh,
    invoke,
    startRecording,
    playBest,
    get state() { return state.data; }
  };

  boot();
})();
