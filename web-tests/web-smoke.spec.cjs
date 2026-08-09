const { test, expect } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173';
const storageKey = 'taijifu.web.preferences.v2';

test.setTimeout(120_000);

test.use({
  launchOptions: {
    args: [
      '--use-gl=swiftshader',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--autoplay-policy=no-user-gesture-required'
    ]
  }
});

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

async function resetWebPreferences(page) {
  await page.addInitScript((key) => localStorage.removeItem(key), storageKey);
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

  // C64.1: do not spend another two minutes waiting on an impossible API shape.
  // The raw Godot flag and the compatibility facade must become ready together.
  await page.waitForFunction(() => Boolean(window.taijifuGodotBridgeReady), null, { timeout: 30_000 });
  await page.waitForFunction(() => Boolean(window.taijifuGodotBridge?.ready), null, { timeout: 10_000 });

  const bridgeContract = await page.evaluate(() => ({
    ready: window.taijifuGodotBridge?.ready,
    paused: window.taijifuGodotBridge?.paused,
    version: window.taijifuGodotBridge?.version,
    contract: window.taijifuGodotBridge?.contract,
    signature: window.taijifuGodotBridge?.signature,
    rawReady: window.taijifuGodotBridgeReady,
    hasPause: typeof window.taijifuGodotBridge?.setPaused === 'function',
    hasApply: typeof window.taijifuGodotBridge?.applyBindings === 'function',
    hasReset: typeof window.taijifuGodotBridge?.resetBindings === 'function'
  }));
  expect(bridgeContract).toEqual({
    ready: true,
    paused: false,
    version: 1,
    contract: 'sprint0-essential-shell-v1',
    signature: 'Tehkné Solutions',
    rawReady: true,
    hasPause: true,
    hasApply: true,
    hasReset: true
  });

  return { canvas, shell, enterButton };
}

async function assertGodotPaused(page, expected) {
  await page.waitForFunction(
    (value) => Boolean(window.taijifuGodotPaused) === value && Boolean(window.taijifuGodotBridge?.paused) === value,
    expected,
    { timeout: 10_000 }
  );
}

async function completeCurrentTutorial(page) {
  await page.getByTestId('open-tutorial').click();
  const dialog = page.locator('#taijifu-web-dialog');
  const status = page.locator('#taijifu-tutorial-status');
  const next = page.locator('#taijifu-tutorial-next');

  await expect(dialog).toBeVisible();
  await expect(page.locator('#taijifu-tutorial-view')).toBeVisible();
  await expect(status).toHaveText('1 / 3');
  await expect(page.locator('.taijifu-tutorial-step[data-step="0"]')).toBeVisible();
  await expect(page.locator('.taijifu-binding[data-keyboard]').first()).toHaveText('A / D');

  await next.click();
  await expect(status).toHaveText('2 / 3');
  await next.click();
  await expect(status).toHaveText('3 / 3');
  await expect(next).toHaveText('Jogar');
  await next.click();

  await expect(dialog).toBeHidden();
  await expect(page.locator('body')).toHaveClass(/taijifu-entered/);
}

test.describe('desktop essential shell', () => {
  test.use({ viewport: { width: 1280, height: 720 } });

  test('carrega Godot, conclui tutorial, pausa e mantém bridge de input', async ({ page }, testInfo) => {
    const { pageErrors, failedRequests } = collectRuntimeFailures(page);
    await resetWebPreferences(page);
    const { canvas, shell, enterButton } = await openAndWaitForArena(page);

    await completeCurrentTutorial(page);
    await expect(shell).toHaveAttribute('aria-hidden', 'true');
    await assertGodotPaused(page, false);

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

    await page.locator('#taijifu-menu').click();
    await expect(page.locator('body')).toHaveClass(/taijifu-menu-open/);
    await expect(enterButton).toHaveText('Voltar à luta');
    await assertGodotPaused(page, true);

    await page.getByTestId('open-settings').click();
    await expect(page.locator('#taijifu-web-dialog')).toBeVisible();
    await expect(page.locator('#taijifu-settings-view')).toBeVisible();
    await expect(page.locator('#taijifu-setting-contrast')).toBeVisible();
    await expect(page.locator('#taijifu-setting-touch-scale')).toBeVisible();
    await page.locator('#taijifu-dialog-close').click();
    await expect(page.locator('#taijifu-web-dialog')).toBeHidden();
    await assertGodotPaused(page, true);

    // Remapping remains a Godot runtime capability even though Sprint 0 no longer
    // exposes the deprecated remapper/practice panels in the essential shell.
    await page.evaluate(() => window.taijifuGodotBridge.applyBindings({ p1_attack: 'KeyJ' }));
    await page.waitForFunction(() => window.taijifuGodotBridge?.bindings?.p1_attack === 'KeyJ', null, { timeout: 10_000 });
    await page.evaluate(() => window.taijifuGodotBridge.resetBindings());
    await page.waitForFunction(() => window.taijifuGodotBridge?.bindings?.p1_attack === 'KeyF', null, { timeout: 10_000 });

    await page.screenshot({
      path: testInfo.outputPath('taijifu-web-essential-desktop.png'),
      fullPage: true
    });

    await enterButton.click();
    await expect(page.locator('body')).not.toHaveClass(/taijifu-menu-open/);
    await assertGodotPaused(page, false);

    expect(failedRequests, 'Nenhum recurso obrigatório deve falhar').toEqual([]);
    expect(pageErrors, 'O runtime não deve lançar exceções JavaScript').toEqual([]);
  });
});

test.describe('mobile essential shell', () => {
  test.use({
    viewport: { width: 844, height: 390 },
    hasTouch: true,
    isMobile: true,
    deviceScaleFactor: 1,
    userAgent: 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/150 Mobile Safari/537.36'
  });

  test('entra na arena, envia touch e protege orientação', async ({ page }, testInfo) => {
    const { pageErrors, failedRequests } = collectRuntimeFailures(page);
    await resetWebPreferences(page);
    const { enterButton } = await openAndWaitForArena(page);

    await enterButton.click();
    await expect(page.locator('body')).toHaveClass(/taijifu-entered/);
    await assertGodotPaused(page, false);

    const attackButton = page.locator('.taijifu-touch-button[data-key="KeyF"]');
    await expect(attackButton).toBeVisible();
    await attackButton.dispatchEvent('pointerdown', {
      pointerId: 1,
      pointerType: 'touch',
      isPrimary: true,
      buttons: 1
    });
    await attackButton.dispatchEvent('pointerup', {
      pointerId: 1,
      pointerType: 'touch',
      isPrimary: true,
      buttons: 0
    });

    const touchEvents = await page.evaluate(() => window.__taijifuTouchEvents || []);
    expect(touchEvents.some((event) => event.type === 'keydown' && event.code === 'KeyF')).toBeTruthy();
    expect(touchEvents.some((event) => event.type === 'keyup' && event.code === 'KeyF')).toBeTruthy();

    await page.setViewportSize({ width: 390, height: 844 });
    await expect(page.locator('#taijifu-orientation')).toBeVisible();
    await page.setViewportSize({ width: 844, height: 390 });
    await expect(page.locator('#taijifu-orientation')).toBeHidden();

    await page.locator('#taijifu-menu').click();
    await assertGodotPaused(page, true);
    await enterButton.click();
    await assertGodotPaused(page, false);

    await page.screenshot({
      path: testInfo.outputPath('taijifu-web-essential-mobile.png'),
      fullPage: true
    });

    expect(failedRequests, 'Nenhum recurso obrigatório deve falhar no mobile').toEqual([]);
    expect(pageErrors, 'O runtime mobile não deve lançar exceções JavaScript').toEqual([]);
  });
});

// Tehkné Solutions
