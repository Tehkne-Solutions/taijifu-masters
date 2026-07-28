(() => {
  'use strict';

  const ui = {};
  const state = { data: null };

  function parse(value) {
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch (_error) { return null; }
    }
    return value && typeof value === 'object' ? value : null;
  }

  function invoke(payload = { command: 'get_state' }) {
    try {
      if (typeof window.taijifuGhostLibraryCommand === 'function') {
        return parse(window.taijifuGhostLibraryCommand(JSON.stringify(payload)));
      }
      if (typeof window.taijifuGhostLibraryState === 'function') {
        return parse(window.taijifuGhostLibraryState());
      }
    } catch (error) {
      console.warn('Taijifu Ghost Library: ponte indisponível.', error);
    }
    return parse(window.taijifuGhostLibraryStateJson);
  }

  function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>'"]/g, (character) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;'
    })[character]);
  }

  function injectStyle() {
    if (document.getElementById('taijifu-ghost-library-style')) return;
    const style = document.createElement('style');
    style.id = 'taijifu-ghost-library-style';
    style.textContent = `
      .taijifu-library-fieldset{border-color:rgba(153,220,176,.34)!important}
      .taijifu-library-head{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:8px 0}
      .taijifu-library-list{display:grid;gap:7px;max-height:260px;overflow:auto;margin:9px 0}
      .taijifu-library-empty{padding:14px;border-radius:11px;text-align:center;color:rgba(214,232,244,.58);background:rgba(105,181,142,.06);font-size:10px}
      .taijifu-library-item{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;padding:10px;border:1px solid rgba(145,217,177,.14);border-radius:12px;background:rgba(7,20,25,.64)}
      .taijifu-library-item[data-selected="true"]{border-color:rgba(143,232,185,.55);box-shadow:inset 3px 0 #8fe8b9}
      .taijifu-library-item strong{display:block;color:#e5fff1;font-size:11px}.taijifu-library-item small{display:block;margin-top:4px;color:rgba(208,230,219,.58);font-size:9px}
      .taijifu-library-actions{display:flex;align-items:center;flex-wrap:wrap;gap:6px}.taijifu-library-actions button{font-size:9px}
      .taijifu-library-status{margin-top:8px;color:rgba(216,236,225,.7);font-size:10px}
      @media(max-width:760px){.taijifu-library-item{grid-template-columns:1fr}.taijifu-library-head{align-items:flex-start;flex-direction:column}}
    `;
    document.head.appendChild(style);
  }

  function injectPanel() {
    if (document.getElementById('taijifu-ghost-library-panel')) return true;
    const sharing = document.getElementById('taijifu-ghost-sharing-panel');
    const settings = document.getElementById('taijifu-settings-view');
    const footer = settings?.querySelector('.taijifu-settings-footer');
    if (!settings || !footer) return false;

    const fieldset = document.createElement('fieldset');
    fieldset.id = 'taijifu-ghost-library-panel';
    fieldset.className = 'taijifu-settings-group taijifu-library-fieldset';
    fieldset.dataset.testid = 'ghost-library-panel';
    fieldset.innerHTML = `
      <legend>Biblioteca local de fantasmas</legend>
      <div class="taijifu-library-head">
        <p class="taijifu-ghost-status">Guarde até 24 desafios importados, selecione um adversário e reproduza-o sem alterar seu melhor replay.</p>
        <button id="taijifu-library-save-code" class="taijifu-dialog-action" data-role="primary" type="button">Salvar código atual</button>
      </div>
      <div id="taijifu-library-list" class="taijifu-library-list"></div>
      <p id="taijifu-library-status" class="taijifu-library-status">Aguardando biblioteca.</p>
    `;
    settings.insertBefore(fieldset, footer);

    ui.root = fieldset;
    ui.list = document.getElementById('taijifu-library-list');
    ui.status = document.getElementById('taijifu-library-status');
    ui.save = document.getElementById('taijifu-library-save-code');
    ui.save.addEventListener('click', saveCurrentCode);
    ui.list.addEventListener('click', onListClick);
    return true;
  }

  function saveCurrentCode() {
    const code = document.getElementById('taijifu-sharing-code')?.value?.trim() || '';
    if (!code) {
      ui.status.textContent = 'Cole ou gere um código no painel de compartilhamento antes de salvar.';
      return;
    }
    const result = invoke({ command: 'import_code', code });
    ui.status.textContent = result?.message || 'Não foi possível salvar o fantasma.';
    refresh();
  }

  function onListClick(event) {
    const button = event.target.closest('button[data-command]');
    if (!button) return;
    const id = button.dataset.id || '';
    const command = button.dataset.command;
    const result = invoke(command === 'play_selected' ? { command } : { command, id });
    ui.status.textContent = result?.message || 'Ação concluída.';
    if (command === 'play_selected' && result?.ok) {
      document.getElementById('taijifu-dialog-close')?.click();
      window.taijifuWebShell?.enter?.();
      window.taijifuWebMenu?.close?.();
      window.taijifuGodotBridge?.setPaused?.(false);
    }
    refresh();
  }

  function render() {
    const data = state.data || {};
    const items = Array.isArray(data.items) ? data.items : [];
    ui.save.disabled = !window.taijifuGhostLibraryReady;
    if (!items.length) {
      ui.list.innerHTML = '<div class="taijifu-library-empty">Nenhum fantasma salvo. Importe um código e escolha “Salvar código atual”.</div>';
      ui.status.textContent = `0 de ${Number(data.max_items || 24)} fantasmas salvos.`;
      return;
    }
    ui.list.innerHTML = items.map((item) => {
      const challenge = item.challenge || {};
      const selected = item.id === data.selected_id;
      return `
        <article class="taijifu-library-item" data-selected="${selected}">
          <div><strong>${escapeHtml(item.name || 'Fantasma')}</strong><small>${Number(challenge.score || 0)} pts · precisão ${Math.round(Number(challenge.accuracy || 0) * 100)}% · elo ${Number(challenge.max_chain || 0)} · ${escapeHtml(item.checksum || '')}</small></div>
          <div class="taijifu-library-actions">
            <button class="taijifu-dialog-action" data-command="select" data-id="${escapeHtml(item.id)}" type="button">${selected ? 'Selecionado' : 'Selecionar'}</button>
            <button class="taijifu-dialog-action" data-role="primary" data-command="play_selected" data-id="${escapeHtml(item.id)}" type="button">Correr contra</button>
            <button class="taijifu-dialog-action" data-command="remove" data-id="${escapeHtml(item.id)}" type="button">Remover</button>
          </div>
        </article>`;
    }).join('');
    ui.status.textContent = `${items.length} de ${Number(data.max_items || 24)} fantasmas salvos.`;
  }

  function refresh() {
    const result = invoke({ command: 'get_state' });
    if (result) state.data = result;
    render();
  }

  function boot() {
    injectStyle();
    if (!injectPanel()) {
      window.setTimeout(boot, 180);
      return;
    }
    refresh();
    window.setInterval(refresh, 900);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true });
  else boot();
})();
