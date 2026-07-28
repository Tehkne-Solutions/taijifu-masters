(() => {
  const id = 'taijifu-ghost-race-history-panel';
  const ensure = () => {
    if (document.getElementById(id)) return;
    const panel = document.createElement('section');
    panel.id = id;
    panel.innerHTML = `
      <style>
        #${id}{position:fixed;right:18px;bottom:18px;z-index:9998;width:min(390px,calc(100vw - 36px));max-height:48vh;overflow:auto;background:rgba(8,16,29,.94);border:1px solid rgba(124,197,255,.3);border-radius:14px;padding:14px;color:#eaf7ff;font:13px/1.45 system-ui;box-shadow:0 16px 44px rgba(0,0,0,.35)}
        #${id} h3{margin:0 0 10px;font-size:15px} #${id} .row{padding:9px 0;border-top:1px solid rgba(255,255,255,.08)}
        #${id} .muted{opacity:.72} #${id} strong{color:#9fddff}
      </style>
      <h3>Histórico contra fantasmas</h3><div data-list class="muted">Nenhuma tentativa registrada.</div>`;
    document.body.appendChild(panel);
  };
  const read = () => {
    try {
      if (window.taijifuGhostRaceHistoryState) {
        return JSON.parse(window.taijifuGhostRaceHistoryState()) || { records: [] };
      }
      if (window.taijifuGhostRaceHistoryStateJson) {
        return JSON.parse(window.taijifuGhostRaceHistoryStateJson) || { records: [] };
      }
    } catch (_) {}
    return { records: [] };
  };
  const render = () => {
    ensure();
    const list = document.querySelector(`#${id} [data-list]`);
    if (!list) return;
    const snapshot = read() || { records: [] };
    const records = Array.isArray(snapshot.records) ? snapshot.records : [];
    if (!records.length) { list.className='muted'; list.textContent='Nenhuma tentativa registrada.'; return; }
    list.className='';
    list.innerHTML = records.map(r => `<div class="row"><strong>${r.target_id || 'Fantasma'}</strong><br>${r.wins||0}V · ${r.losses||0}D · ${r.ties||0}E · melhor ${r.best_score||0} pts<br><span class="muted">${Math.round((r.win_rate||0)*100)}% vitórias · precisão ${Math.round((r.best_accuracy||0)*100)}% · elo ${r.best_chain||0}</span></div>`).join('');
  };
  window.addEventListener('DOMContentLoaded', () => { render(); setInterval(render, 1000); });
})();
