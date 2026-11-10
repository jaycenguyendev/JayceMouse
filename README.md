# JayceMouse

**Turn any mouse into a trackpad — for $0.** Smooth scrolling, trackpad-style gestures and fully custom buttons for macOS.

[**Website**](https://jaycemouse.vercel.app/) · [**Download**](https://jaycemouse.vercel.app/download) · [**Watch the 30-second demo**](https://jaycemouse.vercel.app/#watch)

[![JayceMouse launch video — click to watch](docs/media/jaycemouse-launch-poster.jpg)](https://jaycemouse.vercel.app/#watch)

A modern macOS mouse enhancer inspired by [Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) by Noah Nuebling.
Independent implementation written from scratch (SwiftUI + CGEventTap); it shares no code or assets with Mac Mouse Fix and has no licensing/trial system.

## Install
Requires macOS 14 or later (Apple Silicon and Intel).

1. [Download the latest zip](https://jaycemouse.vercel.app/download) (or pick a version from [Releases](../../releases)) and unzip it.
2. Drag **JayceMouse.app** into your **Applications** folder.
3. The app is not notarized by Apple, so macOS blocks the first launch with a message like
   *"JayceMouse" Not Opened — Apple could not verify "JayceMouse" is free of malware*.
   **Do not click "Move to Trash"** (click **Done**) and allow the app once, using either way:
   - **System Settings → Privacy & Security**, scroll down to the Security section and click **Open Anyway** next to
     *"JayceMouse" was blocked*, then confirm with your password or Touch ID. The button only appears after you have
     tried to open the app once. On macOS 15 and later, right-click → Open no longer bypasses this.
   - Or run this in Terminal (it removes the download quarantine flag) and open the app normally:
     ```bash
     xattr -dr com.apple.quarantine /Applications/JayceMouse.app
     ```
4. When asked, turn JayceMouse on in **System Settings → Privacy & Security → Accessibility**. Nothing works until you do.

Updating: replace the app with the new version. Because releases are ad-hoc signed, macOS forgets the Accessibility permission after an update. Remove JayceMouse from the Accessibility list with the minus button, then add it back (or toggle it off and on).

To confirm the zip was built by this repository's release workflow (and not tampered with), run, with the [GitHub CLI](https://cli.github.com/):
```bash
gh attestation verify JayceMouse.zip --repo jaycenguyendev/JayceMouse
```
Releases from v1.0.1 on carry this attestation. The `.sha256` files next to each zip only catch a corrupted download.

## Features
- **Smooth scrolling**: off / low / regular / high, speed low/medium/high with tick acceleration, natural direction, trackpad-style scroll phases.
- **Scroll modifiers**: ⇧ horizontal, ⌃ quick, ⌥ precise, ⌘ zoom.
- **Button remaps**: click, double click, triple click, hold, click & drag, click & scroll; optional keyboard modifiers or a held second button.
- **Actions**: Mission Control, App Exposé, Launchpad, Show Desktop, Spotlight, Siri, Notification Center, Do Not Disturb, Look Up, Smart Zoom, Spaces left/right, Back/Forward, media/volume/brightness keys, custom keyboard shortcut, middle click.
- **Gestures**: Desktop & Launchpad scroll, Scroll & Navigate (two-finger swipe), Spaces & Mission Control (three-finger swipe), scroll to switch Spaces / zoom.
- **Pointer**: sensitivity and acceleration via the system HID acceleration setting (restored on quit).
- **General**: menu bar item, launch at login, kill switches, lock pointer during drag, 3-/5-button presets.

## Support
JayceMouse is free and always will be. If it made your mouse feel better, you can buy me a coffee ☕ by scanning this
code with any Vietnamese banking app (Napas 247 / VietQR):

<img src="docs/media/donate-qr.png" width="200" alt="Napas 247 QR code to buy the developer a coffee">

Starring the repo and [reporting issues](../../issues) helps too.

## Build from source
Requires Swift 6 toolchain (Command Line Tools are enough; Xcode is not required).

```bash
Scripts/build-app.sh           # builds build/JayceMouse.app
swift run CoreSelfTest         # logic tests (remap engine, scroll physics, config)
Scripts/release.sh 1.0.0       # universal build + dist/JayceMouse-1.0.0.zip
```

Pushing a tag like `v1.0.0` runs `.github/workflows/release.yml`, which builds the zip and attaches it to a GitHub release.

Open `build/JayceMouse.app` and grant **Accessibility** access when asked.
For development, the permission is tied to the code signature: an ad-hoc build changes on every rebuild, so you must re-toggle it in
System Settings after rebuilding. Set `SIGN_IDENTITY="<your self-signed cert>"` for a stable identity.

## Known approximations
- Three-finger swipe fires discrete Spaces/Mission Control actions rather than following the finger live.
- Two-finger swipe sends scroll phases and a Back/Forward shortcut on long horizontal drags, not true navigation-swipe events.
- Zoom uses ⌘+/⌘−; Smart Zoom posts a private gesture event and may not work in every app.
- Pointer acceleration uses a single system scalar, not MMF's custom acceleration tables.
- Not included: licensing/payments, auto-update, localization, per-app profiles.

Dev tip: `JAYCEMOUSE_SNAPSHOT_DIR=/path .build/debug/JayceMouse` renders every page to PNG and quits.
