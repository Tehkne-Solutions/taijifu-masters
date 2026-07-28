(() => {
  'use strict';

  const parse = (value) => {
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch (_error) { return null; }
    }
    return value && typeof value === 'object' ? value : null;
  };

  const invoke = (command = 'get_state') => {
    try {
      if (typeof window.taijifuGhostRaceCommand === 'function') {
        return parse(window.taijifuGhostRaceCommand(JSON.stringify({ command })));
      }
      if (typeof window.taijifuGhostRaceState === 'function') {
        return parse(window.taijifuGhostRaceState());
      }
    } catch (error) {
      console.warn('Taijifu Ghost Race: ponte indisponível.', error);
    }
    return parse(window.taijifuGhostRaceStateJson);
  };

  function style() {
    if (document.getElementById('taijifu-ghost-race-style')) return;
    const node = document.createElement('style');
    node.id = 'taijifu-ghost-race-style';
    node.textContent = `
      .taijifu-race-panel{border-color:rgba(255,196,96,.38)!important}
      .taijifu-race-score{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;margin:10px 0}
      .taijifu-race-card{padding:10px;border-radius:10px;background:rgba(4,15,27,.76);border:1px solid rgba(141,211,245,.15);text-align:center}
      .taijifu-race-card strong{display:block;color:#f5d98d;font-size:15px}.taijifu-race-card span{font-size:9px;color:rgba(220,236,246,.64)}
      .taijifu-race-result{padding:10px;border-radius:10px;background:rgba(106,190,230,.08);font-size:11px;line-height:1.45}
      .taijifu-race-result[data-outcome="venceu"]{border-left:3px solid #8ff0b0}.taijifu-race-result[data-outcome="perdeu"]{border-left:3px solid #ef9b7e}.taijifu-race-result[data-outcome="empatou"]{border-left:3px solid #f2d987}
      @media(max-width:760px){.taijifu-race-score{grid-template-columns:repeat(2,minmax(0,1fr))}}
    `;
    document.head.appendChild(node);
  }

  function mount() {
    if (document.getElementById('taijifu-ghost-race-panel')) return true;
    const library = document.getElementById('taijifu-ghost-library-panel');
    const settings = document.getElementById('taijifu-settings-view');
    const footer = settings?.querySelector('.taijifu-settings-footer');
    if (!settings || !footer) return false;

    const fieldset = document.createElement('fieldset');
    fieldset.id = 'taijifu-ghost-race-panel';
    fieldset.className = 'taijifu-settings-group taijifu-race-panel';
    fieldset.dataset.testid = 'ghost-race-panel';
    fieldset.innerHTML = `
      <legend>Corrida contra fantasma</legend>
      <p class="taijifu-ghost-status">Dispute contra o desafio selecionado com cronômetro e pontuação ao vivo.</p>
      <div class="taijifu-race-score">
        <div class="taijifu-race-card"><strong id="taijifu-race-time">0.0 s</strong><span>tempo restante</span></div>
        <div class="taijifu-race-card"><strong id="taijifu-race-player">0</strong><span>sua pontuação</span></div>
        <div class="taijifu-race-card"><strong id="taijifu-race-target">0</strong><span>alvo</span></div>
        <div class="taijifu-race-card"><strong id="taijifu-race-delta">0</strong><span>diferença</span></div>
      </div>
      <div class="taijifu-sharing-actions">
        <button id="taijifu-race-start" class="taijifu-dialog-action" data-role="primary" type="button">Iniciar corrida</button>
        <button id="taijifu-race-finish" class="taijifu-dialog-action" type="button">Encerrar agora</button>
        <button id="taijifu-race-cancel" class="taijifu-dialog-action" type="button">Cancelar</button>
      </div>
      <div id="taijifu-race-result" class="taijifu-race-result">Selecione um fantasma na biblioteca e entre na arena.</div>
    `;
    footer.parentNode.insertBefore(fieldset, footer);
    library?.insertAdjacentElement('afterend', fieldset);

    fieldset.querySelector('#taijifu-race-start').addEventListener('click', () => show(invoke('start_selected')));
    fieldset.querySelector('#taijifu-race-finish').addEventListener('click', () => show(invoke('finish')));
    fieldset.querySelector('#taijifu-race-cancel').addEventListener('click', () => show(invoke('cancel')));
    return true;
  }

  function show(response) {
    const result = document.getElementById('taijifu-race-result');
    if (!result || !response) return;
    result.textContent = response.message || 'Estado atualizado.';
    const outcome = response.data?.outcome || response.last_result?.outcome || '';
    result.dataset.outcome = outcome;
    refresh();
  }

  function refresh() {
    if (!mount()) return;
    const state = invoke('get_state') || {};
    const player = state.player || {};
    const challenge = state.target?.challenge || {};
    document.getElementById('taijifu-race-time').textContent = `${((state.remaining_ms || 0) / 1000).toFixed(1)} s`;
    document.getElementById('taijifu-race-player').textContent = String(player.score || 0);
    document.getElementById('taijifu-race-target').textContent = String(challenge.score || 0);
    const delta = Number(state.score_delta || 0);
    document.getElementById('taijifu-race-delta').textContent = `${delta > 0 ? '+' : ''}${delta}`;
    const result = document.getElementById('taijifu-race-result');
    if (state.active) {
      result.textContent = `Corrida ativa • precisão ${Math.round(Number(player.accuracy || 0) * 100)}% • elo ${player.max_chain || 0}`;
      result.dataset.outcome = '';
    } else if (state.last_result?.outcome) {
      const outcome = state.last_result.outcome;
      result.textContent = `Resultado: ${outcome} • diferença ${state.last_result.score_delta > 0 ? '+' : ''}${state.last_result.score_delta || 0} pontos.`;
      result.dataset.outcome = outcome;
    }
  }

  style();
  const timer = window.setInterval(refresh, 250);
  window.addEventListener('beforeunload', () => window.clearInterval(timer));
  document.addEventListener('DOMContentLoaded', refresh, { once: true });
  refresh();
})();
