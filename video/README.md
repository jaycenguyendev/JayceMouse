# JayceMouse launch video

A 30-second, 1080p60 motion-graphics launch video, rendered from code.

- `scenes.html` — every scene, driven by `renderAt(t)` so each frame is deterministic. Also defines the sound cue sheet (`window.SFX`).
- `render.mjs` — opens the page in headless Chrome, captures each frame and encodes `out/video.mp4`.
- `audio.py` — synthesises an original soundtrack and all sound effects (no samples), writes `out/audio.wav`.
- `build.sh` — runs all of the above and muxes `out/JayceMouse-launch.mp4` (−14 LUFS for social).

```bash
./build.sh                               # full render, about 3–4 minutes
node render.mjs --stills 2.5,17.3,26.6   # PNG stills in out/stills for quick review
```

Requires Node 20+, Python 3 with NumPy, ffmpeg and Google Chrome.

Scene timeline (seconds): hook $129 → $0 (0–3.5), smooth scrolling (3.5–7), install steps (7–16),
live trackpad gestures on a laptop (16–25.5), call to action (25.5–30).
