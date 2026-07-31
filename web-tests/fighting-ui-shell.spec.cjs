const { test, expect } = require('@playwright/test');

test.describe('Taijifu fighting UI shell', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.evaluate(() => localStorage.clear());
    await page.reload();
  });

  test('entra na arena sem tutorial obrigatório', async ({ page }) => {
    const enter = page.getByTestId('enter-arena');
    await expect(enter).toBeVisible();
    await enter.click();
    await expect(page.locator('#taijifu-web-dialog')).toBeHidden();
  });

  test('tutorial fecha por botão, fundo e Escape', async ({ page }) => {
    await page.getByTestId('open-tutorial').click();
    const dialog = page.locator('#taijifu-web-dialog');
    await expect(dialog).toBeVisible();
    await page.locator('#taijifu-dialog-close').click();
    await expect(dialog).toBeHidden();

    await page.getByTestId('open-tutorial').click();
    await page.keyboard.press('Escape');
    await expect(dialog).toBeHidden();
  });

  test('oferece ação explícita para pular treinamento', async ({ page }) => {
    await page.getByTestId('open-tutorial').click();
    await expect(page.locator('#taijifu-tutorial-skip')).toHaveText('Pular treinamento e jogar');
  });
});

// Tehkné Solutions
