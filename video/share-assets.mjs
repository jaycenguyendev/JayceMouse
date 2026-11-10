// Renders the link-preview image (docs/media/og-image.jpg, 1200x630) from the CTA frame
// and the home-screen icon (docs/media/apple-touch-icon.png, 180x180).
import puppeteer from 'puppeteer-core';
import { pathToFileURL, fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const media = path.join(here, '..', 'docs', 'media');
const CHROME = process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--force-color-profile=srgb'] });
const page = await browser.newPage();

// 1920x1008 has the same 1.905 ratio as 1200x630, so the CTA frame scales down without distortion.
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 0.625 });
await page.goto(pathToFileURL(path.join(here, 'scenes.html')).href, { waitUntil: 'networkidle0' });
await page.evaluate(() => window.ready);
await page.evaluate(() => {
  window.renderAt(27.4);
  for (const id of ['cursor', 'ripple']) document.getElementById(id).style.display = 'none';
});
await page.screenshot({ path: path.join(media, 'og-image.jpg'), type: 'jpeg', quality: 88, clip: { x: 0, y: 36, width: 1920, height: 1008 } });

await page.setViewport({ width: 180, height: 180, deviceScaleFactor: 1 });
await page.setContent(`<html><body style="margin:0;background:transparent">
  <div style="width:180px;height:180px;background:linear-gradient(120deg,#735cfa,#1abdeb);display:grid;place-items:center">
    <div style="position:relative;width:62px;height:104px;border-radius:32px;background:#fff">
      <div style="position:absolute;left:27px;top:16px;width:8px;height:24px;border-radius:4px;background:#735cfa"></div>
    </div>
  </div></body></html>`);
await page.screenshot({ path: path.join(media, 'apple-touch-icon.png') });

await browser.close();
console.log('Wrote docs/media/og-image.jpg and docs/media/apple-touch-icon.png');
