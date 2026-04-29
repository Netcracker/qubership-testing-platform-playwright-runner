import { test, expect } from '@playwright/test';

test('smoke: about:blank loads', async ({ page }) => {
  await page.goto('about:blank');
  // about:blank always has an empty title — just assert the page is reachable
  expect(await page.title()).toBe('');
});

test('smoke: basic assertion passes', () => {
  expect(1 + 1).toBe(2);
});
