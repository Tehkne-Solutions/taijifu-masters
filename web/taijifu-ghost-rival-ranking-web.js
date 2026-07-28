// TAIJIFU_GHOST_RIVAL_RANKING_WEB
(() => {
  const panel = document.createElement('section');
  panel.id = 'taijifu-ghost-rival-ranking';
  panel.style.cssText = 'position:fixed;left:18px;bottom:18px;z-index:39;width:320px;max-height:420px;overflow:auto;padding:14px;border:1px solid #75633f;background:rgba(18,16,13,.96);color:#f3e7c5;font:13px system-ui;border-radius:10px;box-shadow:0 8px 30px #0008';
  panel.innerHTML = '<strong>Ranking local de rivais</strong><div data-summary style="margin:8px 0;color:#cdbb8c">Carregando...</div><div data-board></div>';
  document.body.appendChild(panel);

  const render = () => {
    let state = null;
    try { state = JSON.parse(window.taijifuGhostRivalRankingStateJson || '{}'); } catch (_) {}
    const summary = panel.querySelector('[data-summary]');
    const board = panel.querySelector('[data-board]');
    if (!state || !state.ready) {
      summary.textContent = 'Carregando ranking...';
      board.innerHTML = '';
      return;
    }
    const rows = Array.isArray(state.leaderboard) ? state.leaderboard : [];
    summary.textContent = `${state.tracked_rivals || 0} rivais registrados`;
    if (!rows.length) {
      board.innerHTML = '<div style="opacity:.75">Conclua uma série para inaugurar o ranking.</div>';
      return;
    }
    board.innerHTML = rows.slice(0, 10).map((row) => {
      const rate = Math.round(Number(row.win_rate || 0) * 100);
      const marker = row.rank === 1 ? '★' : row.rank;
      return `<div style="display:grid;grid-template-columns:28px 1fr auto;gap:8px;align-items:center;padding:7px 0;border-top:1px solid #ffffff14"><b>${marker}</b><span><b>${row.name || 'Fantasma'}</b><br><small>${row.series_won || 0}V/${row.series_lost || 0}D · ${rate}% · ${row.sweeps || 0} varridas</small></span><b>${row.rating || 1000}</b></div>`;
    }).join('');
  };

  setInterval(render, 500);
  render();
})();