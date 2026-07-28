const { test, expect } = require('@playwright/test');

test('painel de compartilhamento exporta e importa código', async ({ page }) => {
  await page.addInitScript(() => {
    const recording = {
      summary: { score: 720, accuracy: 0.75, max_chain: 4 },
      frames: [{ t: 0, position: [0, 0] }, { t: 400, position: [40, 0] }]
    };
    const packageData = {
      kind: 'taijifu-ghost', version: 1, recording,
      challenge: { score: 720, accuracy: 0.75, max_chain: 4 }, checksum: 'test'
    };
    window.taijifuGhostSharingReady = true;
    window.taijifuGhostSharingStateJson = JSON.stringify({ ready: true, has_best: true });
    window.taijifuGhostSharingState = () => JSON.stringify({ ready: true, has_best: true });
    window.taijifuGhostSharingCommand = (payload) => {
      const request = JSON.parse(payload);
      if (request.command === 'export_best') {
        return JSON.stringify({ ok: true, message: 'Fantasma exportado com sucesso.', data: { share_code: 'VEFJSklGVQ==', package: packageData, challenge: packageData.challenge } });
      }
      if (request.command === 'import_code') {
        return JSON.stringify({ ok: true, message: 'Fantasma importado para comparação, sem substituir o recorde local.', data: { replaced_best: false, challenge: packageData.challenge } });
      }
      return JSON.stringify({ ready: true, has_best: true });
    };
  });

  await page.goto('/');
  await page.evaluate(() => {
    const settings = document.createElement('section');
    settings.id = 'taijifu-settings-view';
    settings.innerHTML = '<div class="taijifu-settings-footer"></div>';
    document.body.appendChild(settings);
  });
  await page.addScriptTag({ url: '/taijifu-ghost-sharing-web.js' });

  const panel = page.getByTestId('ghost-sharing-panel');
  await expect(panel).toBeVisible();
  await page.getByRole('button', { name: 'Gerar código' }).click();
  await expect(page.locator('#taijifu-sharing-code')).toHaveValue('VEFJSklGVQ==');
  await page.getByRole('button', { name: 'Importar código' }).click();
  await expect(page.locator('#taijifu-sharing-result')).toContainText('sem substituir o recorde local');
  await expect(page.locator('#taijifu-sharing-replace')).not.toBeChecked();
});
