// TAIJIFU_MULTI_GHOST_RACE_WEB
(() => {
  const call = (command) => {
    if (!window.taijifuMultiGhostRaceCommand) return null;
    try { return JSON.parse(window.taijifuMultiGhostRaceCommand(JSON.stringify({ command }))); }
    catch (_) { return null; }
  };
  const panel = document.createElement('section');
  panel.id = 'taijifu-multi-ghost-race';
  panel.style.cssText = 'position:fixed;left:18px;bottom:18px;z-index:42;width:320px;padding:14px;border:1px solid #8f7745;background:rgba(22,18,14,.96);color:#f3e7c5;font:14px system-ui;border-radius:10px;box-shadow:0 8px 30px #0008';
  panel.innerHTML = '<strong>Corrida multirrival</strong><div data-state style="margin:8px 0">Escolha o tamanho da disputa.</div><div data-board style="margin:8px 0;padding:8px;background:#0003;border-radius:6px"></div><div style="display:flex;gap:6px;flex-wrap:wrap"><button data-cmd="start_2">2 rivais</button><button data-cmd="start_3">3 rivais</button><button data-cmd="finish">Finalizar</button><button data-cmd="cancel">Cancelar</button></div>';
  panel.addEventListener('click', (event) => {
    const button = event.target.closest('[data-cmd]');
    if (button) call(button.dataset.cmd);
  });
  document.body.appendChild(panel);
  const render = () => {
    let state = null;
    try { state = JSON.parse(window.taijifuMultiGhostRaceStateJson || '{}'); } catch (_) {}
    const stateEl = panel.querySelector('[data-state]');
    const board = panel.querySelector('[data-board]');
    if (!state || !state.ready) { stateEl.textContent = 'Carregando...'; board.textContent = ''; return; }
    if (state.active) {
      stateEl.textContent = `Em disputa · ${Math.ceil((state.remaining_ms || 0) / 1000)}s restantes`;
    } else if (state.last_result && state.last_result.position) {
      stateEl.textContent = `${state.last_result.position}º lugar de ${state.last_result.field_size}`;
    } else stateEl.textContent = 'Escolha o tamanho da disputa.';
    const rows = state.standings || (state.last_result && state.last_result.standings) || [];
    board.innerHTML = rows.length ? rows.map(row => `<div style="display:flex;justify-content:space-between;gap:8px"><span>${row.position}º ${row.name}${row.is_player ? ' (você)' : ''}</span><b>${row.score || 0}</b></div>`).join('') : 'Sem classificação ativa.';
  };
  setInterval(render, 300);
  render();
})();