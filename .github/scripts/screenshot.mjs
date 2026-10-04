import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const url = process.env.SITE_URL ?? 'https://p-a.dev';
const date = new Date().toISOString().slice(0, 10);
const out = `_screenshots/${date}.png`;

mkdirSync('_screenshots', { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 1280, height: 800 },
  deviceScaleFactor: 2,
});
await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
await page.screenshot({ path: out, fullPage: true });
await browser.close();

console.log(`Saved ${out}`);
