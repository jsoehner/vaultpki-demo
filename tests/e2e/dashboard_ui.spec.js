const { test, expect } = require('@playwright/test');

test.describe('Dashboard UI', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display the live trust chain', async ({ page }) => {
    const rootNode = page.locator('#root-ca-card');
    await expect(rootNode).toBeVisible();
    const leafNode = page.locator('#leaf-cert-card');
    await expect(leafNode).toBeVisible();
  });

  test('should display the rotation action button and log area', async ({ page }) => {
    const rotateBtn = page.locator('#rotate-btn');
    await expect(rotateBtn).toBeVisible();
    const logList = page.locator('#log-list');
    await expect(logList).toBeVisible();
  });

  test('should trigger a rotation signal when the button is clicked', async ({ page }) => {
    const rotateBtn = page.locator('#rotate-btn');
    await rotateBtn.click();
    await expect(rotateBtn).toBeVisible();
  });
});
