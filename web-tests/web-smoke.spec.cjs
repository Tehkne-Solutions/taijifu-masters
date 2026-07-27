const { test, expect } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173';

const launchOptions = {
  args: [
    '--use-gl=swiftshader',
    '--enable-webgl',
    '--ignore-gpu-blocklist',
    '--autoplay-policy=no-user-gesture-required'
  ]
};

function collectRuntimeFailures(page) {
  const pageErrors = [];
  const failedRequests = [];

  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('requestfailed', (request) => {
    if (!request.url().endsWith('/favicon.ico')) {
      failedRequests.push(`${request.method()} ${request.url()} — ${request.failure()?.errorText || 'falha'}`);
    }
  });

  return { pageErrors, failedRequests };
}

async function openAndWaitForArena(page) {
  const response = await page.goto(baseURL, {
    waitUntil: 'domcontentloaded',
    timeout: 120_000
  });

  expect(response, 'A resposta principal deve existir').not.toBeNull();
  expect(response.status(), 'index.html deve responder com sucesso').toBeLessThan(400);

  const canvas = page.locator('canvas#canvas, canvas').first();
  await expect(canvas).toBeVisible({ timeout: 120_000 });
  await page.waitForFunction(() => {
    const element = document.querySelector('canvas#canvas, canvas');
    return Boolean(element && element.width >= 640 && element.height >= 360);
  }, null, { timeout: 120_000 });

  const shell = page.locator('#taijifu-shell');
  const enterButton = page.getByTestId('enter-arena');
  await expect(shell).toBeVisible();
  await expect(enterButton).toBeEnabled({ timeout: 120_000 });
  await expect(page.locator('#taijifu-load-percent')).toHaveText('100%');

  return { canvas, shell, enterButton };
}

test.describe('desktop', () => {
  test.use({
    launchOptions,
    viewport: { width: 1280, height: 720 }
  });

  test('carrega o jogo e entra na arena', async ({ page }, testInfo) => {
    const { pageErrors, failedRequests } = collectRuntimeFailures(page);
    const { canvas, shell, enterButton } = await openAndWaitForArena(page);

    await enterButton.click();
    await expect(page.locator('body')).toHaveClass(/taijifu-entered/);
    await expect(shell).toHaveAttribute('aria-hidden', 'true');
    await expect(page.locator('#taijifu-fullscreen')).toBeVisible();

    const dimensions = await canvas.evaluate((element) => ({
      width: element.width,
      height: element.height,
      clientWidth: element.clientWidth,
      clientHeight: element.clientHeight
    }));

    expect(dimensions.width).toBeGreaterThanOrEqual(640);
    expect(dimensions.height).toBeGreaterThanOrEqual(360);
    expect(dimensions.clientWidth).toBeLessThanOrEqual(1280);
    expect(dimensions.clientHeight).toBeLessThanOrEqual(720);

    await page.waitForTimeout(2_500);
    expect(failedRequests, 'Nenhum recurso obrigatório deve falhar').toEqual([]);
    expect(pageErrors, 'O runtime não deve lançar exceções JavaScript').toEqual([]);

    await page.screenshot({
      path: testInfo.outputPath('taijifu-web-desktop.png'),
      fullPage: true
    });
  });
});

test.describe('mobile touch', () => {
  test.use({
    launchOptions,
    viewport: { width: 844, height: 390 },
    hasTouch: true,
    isMobile: true,
    deviceScaleFactor: 1,
    userAgent: 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/150 Mobile Safari/537.36'
  });

  test('exibe controles touch e protege a orientação', async ({ page }, testInfo) => {
    const { pageErrors, failedRequests } = collectRuntimeFailures(page);
    const { enterButton } = await openAndWaitForArena(page);

    await enterButton.click();
    await expect(page.locator('body')).toHaveClass(/taijifu-entered/);

    const touchControls = page.locator('#taijifu-touch-controls');
    await expect(touchControls).toBeVisible();
    await expect(page.locator('.taijifu-touch-button[data-key="KeyF"]')).toBeVisible();

    const leftButton = page.locator('.taijifu-touch-button[data-key="KeyA"]');
    await leftButton.dispatchEvent('pointerdown', {
      pointerId: 1,
      pointerType: 'touch',
      isPrimary: true,
      buttons: 1
    });
    await leftButton.dispatchEvent('pointerup', {
      pointerId: 1,
      pointerType: 'touch',
      isPrimary: true,
      buttons: 0
    });

    const touchEvents = await page.evaluate(() => window.__taijifuTouchEvents || []);
    expect(touchEvents.some((event) => event.type === 'keydown' && event.code === 'KeyA')).toBeTruthy();
    expect(touchEvents.some((event) => event.type === 'keyup' && event.code === 'KeyA')).toBeTruthy();

    await page.setViewportSize({ width: 390, height: 844 });
    await expect(page.locator('#taijifu-orientation')).toBeVisible();

    await page.setViewportSize({ width: 844, height: 390 });
    await expect(page.locator('#taijifu-orientation')).toBeHidden();

    expect(failedRequests, 'Nenhum recurso obrigatório deve falhar no mobile').toEqual([]);
    expect(pageErrors, 'O runtime mobile não deve lançar exceções JavaScript').toEqual([]);

    await page.screenshot({
      path: testInfo.outputPath('taijifu-web-mobile-touch.png'),
      fullPage: true
    });
  });
});
