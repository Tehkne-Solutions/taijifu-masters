(() => {
  'use strict';

  const ui = {};
  const state = { last: null, package: null, shareCode: '' };

  function parse(value) {
    if (typeof value === 'string') {
      try { return JSON.parse(value); } catch (_error) { return null; }
    }
    return value && typeof value === 'object' ? value : null;
  }

  function invoke(payload = { command: 'get_state' }) {
    try {
      if (typeof window.taijifuGhostSharingCommand === 'function') {
        return parse(window.taijifuGhostSharingCommand(JSON.stringify(payload)));
      }
      if (typeof window.taijifuGhostSharingState === 'function') {
        return parse(window.taijifuGhostSharingState());
      }
    } catch (error) {
      console.warn('Taijifu Ghost Sharing: ponte indisponível.', error);
    }
    return parse(window.taijifuGhostSharingStateJson);
  }

  function injectStyle() {
    if (document.getElementById('taijifu-ghost-sharing-style')) return;
    const style = document.createElement('style');
    style.id = 'taijifu-ghost-sharing-style';
    style.textContent = `
      .taijifu-sharing-fieldset{border-color:rgba(240,206,116,.34)!important}
      .taijifu-sharing-actions{display:flex;flex-wrap:wrap;gap:7px;margin:9px 0}
      .taijifu-sharing-code{width:100%;min-height:92px;resize:vertical;box-sizing:border-box;padding:10px;border:1px solid rgba(134,206,240,.2);border-radius:10px;color:#dff5ff;background:rgba(3,12,23,.74);font:10px/1.45 ui-monospace,SFMono-Regular,Consolas,monospace}
      .taijifu-sharing-row{display:flex;align-items:center;justify-content:space-between;gap:12px;margin:8px 0;color:rgba(215,232,245,.72);font-size:10px}
      .taijifu-sharing-result{margin:8px 0 0;padding:9px 10px;border-radius:10px;color:rgba(222,238,249,.76);background:rgba(102,178,224,.07);font-size:10px;line-height:1.45}
      .taijifu-sharing-result[data-ok="true"]{border-left:3px solid #8fe8ff}.taijifu-sharing-result[data-ok="false"]{border-left:3px solid #f0a27b}
      @media(max-width:760px){.taijifu-sharing-row{align-items:flex-start;flex-direction:column}}
    `;
    document.head.appendChild(style);
  }

  function injectPanel() {
    if (document.getElementById('taijifu-ghost-sharing-panel')) return true;
    const mastery = document.getElementById('taijifu-input-ghost-panel');
    const settings = document.getElementById('taijifu-settings-view');
    const footer = settings?.querySelector('.taijifu-settings-footer');
    if (!settings || !footer) return false;

    const fieldset = document.createElement('fieldset');
    fieldset.id = 'taijifu-ghost-sharing-panel';
    fieldset.className = 'taijifu-settings-group taijifu-sharing-fieldset';
    fieldset.dataset.testid = 'ghost-sharing-panel';
    fieldset.innerHTML = `
      <legend>Compartilhar fantasmas e desafios</legend>
      <p class="taijifu-ghost-status">Exporte seu melhor replay ou importe um código recebido. Fantasmas são apenas visuais e não carregam recompensas, inventário ou ranking.</p>
      <div class="taijifu-sharing-actions">
        <button id="taijifu-sharing-export" class="taijifu-dialog-action" data-role="primary" type="button">Gerar código</button>
        <button id="taijifu-sharing-copy" class="taijifu-dialog-action" type="button">Copiar código</button>
        <button id="taijifu-sharing-download" class="taijifu-dialog-action" type="button">Baixar JSON</button>
      </div>
      <textarea id="taijifu-sharing-code" class="taijifu-sharing-code" spellcheck="false" placeholder="O código exportado aparece aqui. Para importar, cole um código recebido."></textarea>
      <div class="taijifu-sharing-row">
        <label><input id="taijifu-sharing-replace" type="checkbox"> substituir meu melhor replay mesmo quando o importado for inferior</label>
        <button id="taijifu-sharing-import" class="taijifu-dialog-action" type="button">Importar código</button>
      </div>
      <div id="taijifu-sharing-result" class="taijifu-sharing-result" data-ok="true">Aguardando o runtime de compartilhamento.</div>
    `;
    settings.insertBefore(fieldset, mastery?.nextSibling || footer);

    ui.root = fieldset;
    ui.export = document.getElementById('taijifu-sharing-export');
    ui.copy = document.getElementById('taijifu-sharing-copy');
    ui.download = document.getElementById('taijifu-sharing-download');
    ui.code = document.getElementById('taijifu-sharing-code');
    ui.replace = document.getElementById('taijifu-sharing-replace');
    ui.import = document.getElementById('taijifu-sharing-import');
    ui.result = document.getElementById('taijifu-sharing-result');

    ui.export.addEventListener('click', exportBest);
    ui.copy.addEventListener('click', copyCode);
    ui.download.addEventListener('click', downloadPackage);
    ui.import.addEventListener('click', importCode);
    return true;
  }

  function showResult(result) {
    const normalized = result?.ok === undefined ? { ok: true, message: 'Runtime conectado.', data: result || {} } : result;
    state.last = normalized;
    ui.result.dataset.ok = String(Boolean(normalized.ok));
    const challenge = normalized.data?.challenge;
    const details = challenge ? ` Pontuação ${Number(challenge.score || 0).toLocaleString('pt-BR')}, precisão ${Math.round(Number(challenge.accuracy || 0) * 100)}%, elo ${Number(challenge.max_chain || 0)}.` : '';
    ui.result.textContent = `${normalized.message || 'Operação concluída.'}${details}`;
  }

  function exportBest() {
    const result = invoke({ command: 'export_best' });
    showResult(result || { ok: false, message: 'O runtime não respondeu.' });
    const data = result?.data || {};
    state.shareCode = String(data.share_code || '');
    state.package = data.package || null;
    if (state.shareCode) ui.code.value = state.shareCode;
  }

  async function copyCode() {
    const code = ui.code.value.trim();
    if (!code) return showResult({ ok: false, message: 'Gere ou cole um código antes de copiar.' });
    try {
      await navigator.clipboard.writeText(code);
      showResult({ ok: true, message: 'Código copiado para a área de transferência.' });
    } catch (_error) {
      ui.code.focus();
      ui.code.select();
      const copied = document.execCommand?.('copy');
      showResult({ ok: Boolean(copied), message: copied ? 'Código copiado.' : 'Selecione e copie o código manualmente.' });
    }
  }

  function downloadPackage() {
    if (!state.package) exportBest();
    if (!state.package) return;
    const blob = new Blob([JSON.stringify(state.package, null, 2)], { type: 'application/json' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `taijifu-ghost-${Date.now()}.json`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(link.href);
    showResult({ ok: true, message: 'Pacote JSON preparado para download.' });
  }

  function importCode() {
    const code = ui.code.value.trim();
    if (!code) return showResult({ ok: false, message: 'Cole um código de compartilhamento.' });
    const result = invoke({ command: 'import_code', code, replace_best: ui.replace.checked });
    showResult(result || { ok: false, message: 'O runtime não respondeu.' });
    window.dispatchEvent(new CustomEvent('taijifu:ghost-imported', { detail: result || {} }));
  }

  function refresh() {
    if (!injectPanel()) return;
    const current = invoke();
    if (!state.last && current) showResult({ ok: true, message: current.has_best ? 'Melhor fantasma disponível para exportação.' : 'Grave uma tentativa para habilitar a exportação.' });
    ui.export.disabled = !current?.has_best;
    ui.download.disabled = !state.package && !current?.has_best;
  }

  function boot() {
    injectStyle();
    const timer = window.setInterval(() => {
      refresh();
      if (ui.root && window.taijifuGhostSharingReady) window.clearInterval(timer);
    }, 350);
    window.setInterval(refresh, 1200);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true });
  else boot();
})();
