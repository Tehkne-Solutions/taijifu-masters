const { test, expect } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173';

test.use({
  launchOptions: {
    args: [
      '--use-gl=swiftshader',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
      '--autoplay-policy=no-user-gesture-required'
    ]
  },
  viewport: { width: 1280, height: 720 }
});

test('carrega o build Web do Taijifu Masters', async ({ page }, testInfo) => {
  const pageErrors = [];
  const failedRequests = [];

  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('requestfailed', (request) => {
    if (!request.url().endsWith('/favicon.ico')) {
      failedRequests.push(`${request.method()} ${request.url()} — ${request.failure()?.errorText || 'falha'}`);
    }
  });

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

  await page.waitForTimeout(8_000);

  const dimensions = await canvas.evaluate((element) => ({
    width: element.width,
    height: element.height,
    clientWidth: element.clientWidth,
    clientHeight: element.clientHeight
  }));

  expect(dimensions.width).toBeGreaterThanOrEqual(640);
  expect(dimensions.height).toBeGreaterThanOrEqual(360);
  expect(failedRequests, 'Nenhum recurso obrigatório deve falhar').toEqual([]);
  expect(pageErrors, 'O runtime não deve lançar exceções JavaScript').toEqual([]);

  await page.screenshot({
    path: testInfo.outputPath('taijifu-web-smoke.png'),
    fullPage: true
  });
});
