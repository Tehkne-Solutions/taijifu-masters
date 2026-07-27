const { test, expect } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173';
const storageKey = 'taijifu.web.preferences.v1';

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

async function setPreferencesBeforeLoad(page, preferences) {
  await page.addInitScript(({ key, value }) => {
    localStorage.setItem(key, JSON.stringify(value));
  }, { key: storageKey, value: preferences });
}

async function clearPreferencesBeforeLoad(page) {
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
  await page.waitForFunction(() => Boolean(window.taijifuGodotBridge?.ready), null, { timeout: 120_000 });

  return { canvas, shell, enterButton };
}

async function completeFirstRunTutorial(page, enterButton) {
  await expect(enterButton).toHaveText('Começar treinamento');
  await enterButton.click();

  const dialog = page.locator('#taijifu-web-dialog');
  await expect(dialog).toBeVisible();
  await expect(page.locator('#taijifu-tutorial-view')).toBeVisible();
  await expect(page.locator('#taijifu-tutorial-status')).toHaveText('Passo 1 de 3');
  await expect(page.locator('.taijifu-tutorial-step[data-step="0"]')).toBeVisible();
  await expect(page.locator('.taijifu-binding[data-keyboard]').first()).toHaveText('A / D');

  const next = page.locator('#taijifu-tutorial-next');
  await next.click();
  await expect(page.locator('#taijifu-tutorial-status')).toHaveText('Passo 2 de 3');
  await next.click();
  await expect(page.locator('#taijifu-tutorial-status')).toHaveText('Passo 3 de 3');
  await expect(next).toHaveText('Concluir e jogar');
  await next.click();

  await expect(dialog).toBeHidden();
  await expect(page.locator('body')).toHaveClass(/taijifu-entered/);
}

async function assertGodotPaused(page, expected) {
  await page.waitForFunction(
    (value) => Boolean(window.taijifuGodotPaused) === value,
    expected,
    { timeout: 10_000 }
  );
  const paused = await page.evaluate(() => window.taijifuGodotBridge?.paused);
  expect(paused).toBe(expected);
}

async function remapAction(page, actionId, code) {
  const button = page.getByTestId(`remap-${actionId}`);
  await expect(button).toBeVisible();
  await button.click();
  await expect(button).toHaveClass(/is-capturing/);
  await page.keyboard.press(code.replace('Key', '').toLowerCase());
  await expect(page.getByTestId(`remap-${actionId}`).locator('span')).toHaveText(code.slice(-1));
}

test.describe('desktop', () => {
  test.use({ viewport: { width: 1280, height: 720 } });

  test('pausa o Godot, remapeia e conclui treino prático', async ({ page }, testInfo) => {
    const { pageErrors, failedRequests } = collectRuntimeFailures(page);
    await clearPreferencesBeforeLoad(page);
    const { canvas, shell, enterButton } = await openAndWaitForArena(page);

    await completeFirstRunTutorial(page, enterButton);
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
    await expect(enterButton).toHaveText('Voltar à arena');
    await assertGodotPaused(page, true);

    await page.getByTestId('open-settings').click();
    await expect(page.locator('#taijifu-settings-view')).toBeVisible();
    await page.locator('#taijifu-setting-contrast').check();
    await page.locator('#taijifu-setting-large-ui').check();
    await page.locator('#taijifu-setting-motion').check();
    await page.locator('#taijifu-setting-touch-scale').fill('120');
    await page.locator('#taijifu-setting-touch-opacity').fill('65');
    await remapAction(page, 'p1_attack', 'KeyJ');

    await expect(page.locator('body')).toHaveClass(/taijifu-high-contrast/);
    await expect(page.locator('body')).toHaveClass(/taijifu-large-ui/);
    await expect(page.locator('body')).toHaveClass(/taijifu-reduced-motion/);

    const mappedInGodot = await page.evaluate(() => {
      try { return JSON.parse(window.taijifuGodotBindingsJson || '{}').p1_attack; }
      catch (_error) { return ''; }
    });
    expect(mappedInGodot).toBe('KeyJ');

    const saved = await page.evaluate((key) => JSON.parse(localStorage.getItem(key) || '{}'), storageKey);
    expect(saved.tutorialCompleted).toBeTruthy();
    expect(saved.keyboardBindings.p1_attack).toBe('KeyJ');
    expect(saved.touchScale).toBe(120);
    expect(saved.touchOpacity).toBe(65);

    await page.locator('#taijifu-settings-practice').click();
    await expect(page.locator('#taijifu-web-dialog')).toBeHidden();
    await expect(page.locator('#taijifu-practice')).toBeVisible();
    await assertGodotPaused(page, false);

    for (const key of ['a', 'w', 'j', 'r', 'c']) {
      await page.keyboard.press(key);
      await page.waitForTimeout(180);
    }
    await expect(page.locator('#taijifu-practice-binding')).toHaveText('✓');
    await expect(page.locator('#taijifu-practice')).toBeHidden({ timeout: 4_000 });

    const completed = await page.evaluate((key) => JSON.parse(localStorage.getItem(key) || '{}').practiceCompleted, storageKey);
    expect(completed).toBeTruthy();

    await page.locator('#taijifu-menu').click();
    await assertGodotPaused(page, true);
    await page.screenshot({
      path: testInfo.outputPath('taijifu-web-pause-remap-practice.png'),
      fullPage: true
    });
    await enterButton.click();
    await assertGodotPaused(page, false);

    expect(failedRequests, 'Nenhum recurso obrigatório deve falhar').toEqual([]);
    expect(pageErrors, 'O runtime não deve lançar exceções JavaScript').toEqual([]);
  });
});

test.describe('mobile touch', () => {
  test.use({
    viewport: { width: 844, height: 390 },
    hasTouch: true,
    isMobile: true,
    deviceScaleFactor: 1,
    userAgent: 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/150 Mobile Safari/537.36'
  });

  test('aplica remapeamento ao touch e mantém pausa real', async ({ page }, testInfo) => {
    const { pageErrors, failedRequests } = collectRuntimeFailures(page);
    await setPreferencesBeforeLoad(page, {
      tutorialCompleted: true,
      highContrast: false,
      reducedMotion: false,
      largeUi: false,
      leftHanded: false,
      haptics: false,
      touchScale: 100,
      touchOpacity: 88,
      touchVisibility: 'auto'
    });
    const { enterButton } = await openAndWaitForArena(page);

    await page.getByTestId('open-tutorial').click();
    await expect(page.locator('#taijifu-tutorial-device')).toContainText('tela touch');
    await expect(page.locator('.taijifu-binding[data-keyboard]').first()).toHaveText('◀ / ▶');
    await page.locator('#taijifu-dialog-close').click();

    await enterButton.click();
    await expect(page.locator('body')).toHaveClass(/taijifu-entered/);
    await assertGodotPaused(page, false);

    await page.locator('#taijifu-menu').click();
    await assertGodotPaused(page, true);
    await page.getByTestId('open-settings').click();
    await page.locator('#taijifu-setting-left-handed').check();
    await page.locator('#taijifu-setting-touch-visibility').selectOption('always');
    await page.locator('#taijifu-setting-touch-scale').fill('125');
    await page.locator('#taijifu-setting-touch-opacity').fill('55');
    await remapAction(page, 'p1_attack', 'KeyJ');
    await page.locator('#taijifu-dialog-close').click();
    await enterButton.click();
    await assertGodotPaused(page, false);

    await expect(page.locator('body')).toHaveClass(/taijifu-left-handed/);
    await expect(page.locator('body')).toHaveClass(/taijifu-touch-always/);
    await expect(page.locator('.taijifu-touch-button[data-action="p1_attack"]')).toHaveAttribute('data-key', 'KeyJ');
    await expect(page.locator('.taijifu-touch-button[data-action="p1_swap"]')).toHaveAttribute('data-key', 'KeyT');

    const attackButton = page.locator('.taijifu-touch-button[data-action="p1_attack"]');
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
    expect(touchEvents.some((event) => event.type === 'keydown' && event.code === 'KeyJ')).toBeTruthy();
    expect(touchEvents.some((event) => event.type === 'keyup' && event.code === 'KeyJ')).toBeTruthy();

    await page.setViewportSize({ width: 390, height: 844 });
    await expect(page.locator('#taijifu-orientation')).toBeVisible();
    await page.setViewportSize({ width: 844, height: 390 });
    await expect(page.locator('#taijifu-orientation')).toBeHidden();

    await page.screenshot({
      path: testInfo.outputPath('taijifu-web-mobile-remapped-touch.png'),
      fullPage: true
    });

    expect(failedRequests, 'Nenhum recurso obrigatório deve falhar no mobile').toEqual([]);
    expect(pageErrors, 'O runtime mobile não deve lançar exceções JavaScript').toEqual([]);
  });
});
