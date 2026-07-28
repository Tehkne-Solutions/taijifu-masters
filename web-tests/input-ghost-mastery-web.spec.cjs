const { test, expect } = require('@playwright/test');

const baseURL = process.env.BASE_URL || 'http://127.0.0.1:4173';
const preferenceKey = 'taijifu.web.preferences.v1';

test.setTimeout(150_000);

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
  await page.addInitScript(({ key }) => {
    localStorage.setItem(key, JSON.stringify({
      tutorialCompleted: true,
      practiceCompleted: true,
      highContrast: false,
      reducedMotion: false,
      largeUi: false,
      leftHanded: false,
      haptics: false,
      touchScale: 100,
      touchOpacity: 88,
      touchVisibility: 'auto'
    }));
  }, { key: preferenceKey });

  const response = await page.goto(baseURL, { waitUntil: 'domcontentloaded', timeout: 120_000 });
  expect(response).not.toBeNull();
  expect(response.status()).toBeLessThan(400);
  await expect(page.locator('canvas#canvas, canvas').first()).toBeVisible({ timeout: 120_000 });
  await expect(page.getByTestId('enter-arena')).toBeEnabled({ timeout: 120_000 });
  await page.waitForFunction(() => Boolean(window.taijifuGhostMasteryReady), null, { timeout: 120_000 });
  await page.waitForFunction(() => Boolean(window.taijifuGhostMasteryWeb?.state), null, { timeout: 30_000 });
}

async function startRealBattle(page) {
  await page.getByTestId('enter-arena').click();
  await expect(page.locator('body')).toHaveClass(/taijifu-entered/);
  await page.waitForTimeout(250);
  await page.keyboard.press('f');
  await page.waitForTimeout(180);
  await page.keyboard.press('Numpad1');
  await page.waitForTimeout(3200);
}

async function openGhostPanel(page) {
  await page.locator('#taijifu-menu').click();
  await page.getByTestId('open-settings').click();
  const panel = page.getByTestId('input-ghost-mastery-panel');
  await expect(panel).toBeVisible();
  return panel;
}

test('grava inputs, salva fantasma e mostra certificações', async ({ page }, testInfo) => {
  const pageErrors = [];
  const failedRequests = [];
  page.on('pageerror', (error) => pageErrors.push(error.message));
  page.on('requestfailed', (request) => {
    if (!request.url().endsWith('/favicon.ico')) failedRequests.push(request.url());
  });

  await openBuild(page);
  await startRealBattle(page);
  await openGhostPanel(page);

  await expect(page.locator('#taijifu-certifications .taijifu-cert-card')).toHaveCount(3);
  await expect(page.locator('#taijifu-ghost-summary .taijifu-ghost-card')).toHaveCount(4);
  await page.locator('#taijifu-ghost-record').click();

  await page.waitForFunction(() => Boolean(window.taijifuGhostMasteryWeb?.state?.recording?.active), null, { timeout: 15_000 });
  await expect(page.locator('#taijifu-ghost-live')).toBeVisible();
  await expect(page.locator('#taijifu-ghost-live-title')).toContainText('REC');

  await page.keyboard.down('d');
  await page.waitForTimeout(280);
  await page.keyboard.up('d');
  await page.keyboard.press('f');
  await page.waitForTimeout(720);
  await page.keyboard.press('f');
  await page.waitForTimeout(520);
  await page.keyboard.press('r');
  await page.waitForTimeout(180);

  await page.locator('#taijifu-ghost-live-stop').click();
  await page.waitForFunction(() => {
    const data = window.taijifuGhostMasteryWeb?.state;
    return data && !data.recording?.active && data.best?.available && data.best?.frame_count > 10;
  }, null, { timeout: 20_000 });
  await expect(page.locator('#taijifu-ghost-live')).toBeHidden();

  const stateAfterRecording = await page.evaluate(() => window.taijifuGhostMasteryWeb.state);
  expect(stateAfterRecording.recording.frame_count).toBeGreaterThan(10);
  expect(stateAfterRecording.best.available).toBeTruthy();
  expect(stateAfterRecording.comparison.available).toBeTruthy();
  expect(Object.keys(stateAfterRecording.styles)).toEqual(expect.arrayContaining(['tai', 'ji', 'fu']));

  await openGhostPanel(page);
  await expect(page.locator('#taijifu-ghost-play')).toBeEnabled();
  const challengeCount = await page.locator('#taijifu-technique-challenges .taijifu-challenge').count();
  expect(challengeCount).toBeGreaterThanOrEqual(1);
  await expect(page.locator('#taijifu-weapon-mastery')).toBeVisible();
  await expect(page.locator('#taijifu-certifications')).toContainText('Tai');
  await expect(page.locator('#taijifu-certifications')).toContainText('Ji');
  await expect(page.locator('#taijifu-certifications')).toContainText('Fu');

  await page.locator('#taijifu-ghost-play').click();
  await page.waitForFunction(() => Boolean(window.taijifuGhostMasteryWeb?.state?.playback?.active), null, { timeout: 15_000 });
  await expect(page.locator('#taijifu-ghost-live-title')).toContainText('FANTASMA');
  await page.waitForTimeout(360);
  await page.locator('#taijifu-ghost-live-stop').click();
  await page.waitForFunction(() => !window.taijifuGhostMasteryWeb?.state?.playback?.active, null, { timeout: 10_000 });

  await openGhostPanel(page);
  await page.screenshot({
    path: testInfo.outputPath('taijifu-input-ghost-certifications-panel.png'),
    fullPage: true
  });

  expect(pageErrors).toEqual([]);
  expect(failedRequests).toEqual([]);
});
