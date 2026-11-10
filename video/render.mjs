// Renders scenes.html frame by frame into out/video.mp4 and writes the sound cue sheet to out/sfx.json.
// Usage: node render.mjs            full 60 fps render
//        node render.mjs --stills 1.2,5,9.4   PNG stills at the given seconds for review
import puppeteer from 'puppeteer-core';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdirSync, writeFileSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(here, 'out');
mkdirSync(out, { recursive: true });

const FPS = 60;
const CHROME = process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const stillsArg = process.argv.indexOf('--stills');

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--hide-scrollbars', '--force-color-profile=srgb', '--disable-gpu-vsync', '--font-render-hinting=none'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(path.join(here, 'scenes.html')).href, { waitUntil: 'networkidle0' });
await page.evaluate(() => window.ready);

const duration = await page.evaluate(() => window.DURATION);
writeFileSync(path.join(out, 'sfx.json'), JSON.stringify(await page.evaluate(() => window.SFX), null, 2));

if (stillsArg !== -1) {
  const times = (process.argv[stillsArg + 1] || '0').split(',').map(Number);
  mkdirSync(path.join(out, 'stills'), { recursive: true });
  for (const t of times) {
    await page.evaluate(t => window.renderAt(t), t);
    await page.screenshot({ path: path.join(out, 'stills', `t${t.toFixed(2)}.png`) });
  }
  console.log(`Wrote ${times.length} stills`);
} else {
  const frames = Math.round(duration * FPS);
  const ffmpeg = spawn('ffmpeg', [
    '-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '16', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
    path.join(out, 'video.mp4'),
  ], { stdio: ['pipe', 'inherit', 'inherit'] });
  const started = Date.now();
  for (let i = 0; i < frames; i++) {
    await page.evaluate(t => window.renderAt(t), i / FPS);
    const jpg = await page.screenshot({ type: 'jpeg', quality: 96, optimizeForSpeed: true });
    if (!ffmpeg.stdin.write(jpg)) await once(ffmpeg.stdin, 'drain');
    if (i % 120 === 0) console.log(`frame ${i}/${frames} (${((Date.now() - started) / 1000).toFixed(0)}s)`);
  }
  ffmpeg.stdin.end();
  await once(ffmpeg, 'close');
  console.log(`Rendered ${frames} frames to out/video.mp4`);
}
await browser.close();
