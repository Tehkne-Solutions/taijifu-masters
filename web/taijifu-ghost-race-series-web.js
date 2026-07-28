// TAIJIFU_GHOST_RACE_SERIES_WEB
(() => {
  const call = (command) => {
    if (!window.taijifuGhostRaceSeriesCommand) return null;
    try { return JSON.parse(window.taijifuGhostRaceSeriesCommand(JSON.stringify({ command }))); }
    catch (_) { return null; }
  };
  const panel = document.createElement('section');
  panel.id = 'taijifu-ghost-race-series';
  panel.style.cssText = 'position:fixed;right:18px;bottom:180px;z-index:40;width:280px;padding:14px;border:1px solid #8f7745;background:rgba(22,18,14,.94);color:#f3e7c5;font:14px system-ui;border-radius:10px;box-shadow:0 8px 30px #0008';
  panel.innerHTML = '<strong>Série contra fantasma</strong><div data-state style="margin:8px 0">Nenhuma série ativa.</div><div style="display:flex;gap:6px;flex-wrap:wrap"><button data-cmd="start_best_of_3">Melhor de 3</button><button data-cmd="start_best_of_5">Melhor de 5</button><button data-cmd="next_round">Próxima</button><button data-cmd="rematch">Revanche</button></div>';
  panel.addEventListener('click', (event) => {
    const button = event.target.closest('[data-cmd]');
    if (button) call(button.dataset.cmd);
  });
  document.body.appendChild(panel);
  const render = () => {
    let state = null;
    try { state = JSON.parse(window.taijifuGhostRaceSeriesStateJson || '{}'); } catch (_) {}
    const el = panel.querySelector('[data-state]');
    if (!state || !state.ready) { el.textContent = 'Carregando série...'; return; }
    if (state.active) {
      el.innerHTML = `<b>${state.target_name}</b><br>Melhor de ${state.best_of} · rodada ${state.round_number}<br>Jogador ${state.player_wins} × ${state.ghost_wins} Fantasma${state.ties ? `<br>Empates: ${state.ties}` : ''}`;
    } else if (state.last_series && state.last_series.outcome) {
      const s = state.last_series;
      el.innerHTML = `<b>${s.outcome === 'venceu' ? 'Série vencida' : 'Série perdida'}</b><br>${s.player_wins} × ${s.ghost_wins} contra ${s.target_name}`;
    } else el.textContent = 'Escolha um fantasma e inicie uma série.';
  };
  setInterval(render, 300);
  render();
})();