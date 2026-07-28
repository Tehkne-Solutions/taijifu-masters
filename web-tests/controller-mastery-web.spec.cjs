const { test, expect } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173';

test.setTimeout(120_000);

test.use({
  viewport: { width: 1280, height: 720 },
  launchOptions: {
    args: [
      '--use-gl=swiftshader',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--autoplay-policy=no-user-gesture-required'
    ]
  }
});

async function openBuild(page) {
  const response = await page.goto(baseURL, { waitUntil: 'domcontentloaded', timeout: 120_000 });
  expect(response).not.toBeNull();
  expect(response.status()).toBeLessThan(400);
  await expect(page.locator('canvas#canvas, canvas').first()).toBeVisible({ timeout: 120_000 });
  await expect(page.getByTestId('enter-arena')).toBeEnabled({ timeout: 120_000 });
  await page.waitForFunction(() => Boolean(window.taijifuControllerMasteryReady), null, { timeout: 120_000 });
  await page.waitForFunction(() => Boolean(window.taijifuControllerMasteryWeb?.state), null, { timeout: 20_000 });
}

test('edita curva, gatilhos e cancelamento por perfil do controle', async ({ page }, testInfo) => {
  const pageErrors = [];
  const failedRequests = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('requestfailed', (request) => {
    if (!request.url().endsWith('/favicon.ico')) failedRequests.push(request.url());
  });

  await openBuild(page);
  await page.getByTestId('open-settings').click();

  const panel = page.getByTestId('controller-mastery-panel');
  await expect(panel).toBeVisible();
  await expect(page.locator('#taijifu-curve-svg')).toBeVisible();
  await expect(page.locator('.taijifu-curve-point')).toHaveCount(3);
  await expect(page.locator('#taijifu-mastery-profile')).toContainText('GUID:');

  await page.locator('#taijifu-mastery-player').selectOption('1');
  await page.locator('#taijifu-mastery-device').selectOption('-1');

  const middlePoint = page.locator('.taijifu-curve-point[data-index="2"]');
  const box = await middlePoint.boundingBox();
  expect(box).not.toBeNull();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2, box.y - 24, { steps: 6 });
  await page.mouse.up();

  await page.locator('#taijifu-mastery-left-trigger').selectOption('block');
  await page.locator('#taijifu-mastery-right-trigger').selectOption('swap');
  await page.locator('#taijifu-mastery-trigger').fill('0.61');
  await page.locator('#taijifu-mastery-cancel').fill('0.74');
  await page.locator('#taijifu-mastery-cancel-assist').uncheck();
  await page.locator('#taijifu-mastery-windows').check();
  await page.locator('#taijifu-mastery-save').click();

  await page.waitForFunction(() => {
    const state = window.taijifuControllerMasteryWeb?.state;
    const player = state?.players?.['1'];
    const profile = player?.profile;
    return player?.guid === 'slot:1' &&
      Array.isArray(profile?.curve_points) && profile.curve_points.length === 5 &&
      profile.left_trigger_action === 'block' && profile.right_trigger_action === 'swap' &&
      Math.abs(profile.trigger_threshold - 0.61) < 0.001 &&
      Math.abs(profile.cancel_threshold - 0.74) < 0.001 && profile.cancel_assist === false;
  }, null, { timeout: 20_000 });

  await expect(page.locator('#taijifu-mastery-trigger-value')).toHaveText('0,61');
  await expect(page.locator('#taijifu-mastery-cancel-value')).toHaveText('74%');
  await expect(page.locator('#taijifu-mastery-status')).toContainText('Perfil por modelo/GUID atualizado');
  await expect(page.locator('#taijifu-mastery-metrics .taijifu-mastery-metric')).toHaveCount(8);

  const points = await page.evaluate(() => window.taijifuControllerMasteryWeb.points);
  expect(points[0]).toBe(0);
  expect(points[4]).toBe(1);
  expect(points[2]).toBeGreaterThanOrEqual(points[1]);
  expect(points[2]).toBeLessThanOrEqual(points[3]);

  await page.screenshot({
    path: testInfo.outputPath('taijifu-controller-mastery-panel.png'),
    fullPage: true
  });

  expect(pageErrors).toEqual([]);
  expect(failedRequests).toEqual([]);
});
