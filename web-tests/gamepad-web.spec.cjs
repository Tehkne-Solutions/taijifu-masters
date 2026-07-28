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
  await page.waitForFunction(() => Boolean(window.taijifuGamepadExperienceReady), null, { timeout: 120_000 });
  await page.waitForFunction(() => Boolean(window.taijifuGamepadWeb?.state), null, { timeout: 20_000 });
}

test('configura curvas, gatilhos e vibração pela interface Web', async ({ page }, testInfo) => {
  const pageErrors = [];
  const failedRequests = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('requestfailed', (request) => {
    if (!request.url().endsWith('/favicon.ico')) failedRequests.push(request.url());
  });

  await openBuild(page);
  await page.getByTestId('open-settings').click();

  const panel = page.getByTestId('gamepad-web-panel');
  await expect(panel).toBeVisible();
  await expect(page.getByTestId('gamepad-bindings')).toBeVisible();
  await expect(page.getByTestId('gamepad-attack')).toContainText('X / Quadrado');

  await page.locator('#taijifu-gamepad-player').selectOption('1');
  await page.locator('#taijifu-gamepad-device').selectOption('-1');
  await page.locator('#taijifu-gamepad-deadzone').fill('0.32');
  await page.locator('#taijifu-gamepad-deadzone').dispatchEvent('change');
  await page.locator('#taijifu-gamepad-curve').selectOption('precision');
  await page.locator('#taijifu-gamepad-trigger').fill('0.66');
  await page.locator('#taijifu-gamepad-trigger').dispatchEvent('change');
  await page.locator('#taijifu-gamepad-haptics').uncheck();
  await page.locator('#taijifu-gamepad-vibration').fill('0.45');
  await page.locator('#taijifu-gamepad-vibration').dispatchEvent('change');

  await page.waitForFunction(() => {
    const raw = window.taijifuGamepadExperienceState?.();
    const state = typeof raw === 'string' ? JSON.parse(raw) : raw;
    const base = state?.base_profile?.players?.['1'];
    const tuning = state?.profile?.players?.['1'];
    return base?.device === -1 && Math.abs(base?.deadzone - 0.32) < 0.001 &&
      tuning?.response_curve === 'precision' && Math.abs(tuning?.trigger_threshold - 0.66) < 0.001 &&
      tuning?.haptics_enabled === false && Math.abs(tuning?.vibration_scale - 0.45) < 0.001;
  }, null, { timeout: 15_000 });

  await expect(page.locator('#taijifu-gamepad-deadzone-value')).toHaveText('0,32');
  await expect(page.locator('#taijifu-gamepad-trigger-value')).toHaveText('0,66');
  await expect(page.locator('#taijifu-gamepad-vibration-value')).toHaveText('45%');
  await expect(page.locator('#taijifu-gamepad-status')).toContainText('L2 = Elemento, R2 = Golpe');

  await page.screenshot({
    path: testInfo.outputPath('taijifu-gamepad-web-panel.png'),
    fullPage: true
  });

  expect(pageErrors).toEqual([]);
  expect(failedRequests).toEqual([]);
});
