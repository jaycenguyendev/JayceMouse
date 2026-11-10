"""Synthesises an original soundtrack and sound effects for the launch video.

Everything is generated from scratch (no samples), so the result is free to use.
Reads out/sfx.json (written by render.mjs) and writes out/audio.wav.
"""
import json
import wave
from pathlib import Path

import numpy as np

SR = 48000
DURATION = 30.0
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
GRID = 1.5  # first downbeat, so scene changes at 3.5 s and the CTA at 25.5 s land on bar lines
N = int(SR * DURATION)
rng = np.random.default_rng(7)
OUT = Path(__file__).parent / "out"


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def place(buf, start, sig, pan=0.0):
    """Adds a mono or stereo signal into a stereo buffer at `start` seconds."""
    i = int(start * SR)
    if i >= buf.shape[0]:
        return
    if sig.ndim == 1:
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        sig = np.stack([sig * left * 1.414, sig * right * 1.414], axis=1)
    j = min(buf.shape[0], i + sig.shape[0])
    if i < 0:
        sig, i = sig[-i:], 0
    buf[i:j] += sig[: j - i]


def one_pole_lp(x, cutoff):
    """Time-varying one-pole low-pass; cutoff may be a scalar or per-sample array."""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for k in range(x.shape[0]):
        acc += a[k] * (x[k] - acc)
        y[k] = acc
    return y


def highpass(x, cutoff):
    return x - one_pole_lp(x, cutoff)


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def reverb(x, seconds=2.2, decay=0.55, wet=0.3):
    """Stereo convolution reverb with a synthetic exponential-noise impulse response."""
    n = int(seconds * SR)
    tt = np.arange(n) / SR
    out = x.copy()
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-tt / decay)
        ir = one_pole_lp(ir, 5200)
        ir /= np.sqrt(np.sum(ir ** 2))
        size = 1 << int(np.ceil(np.log2(x.shape[0] + n)))
        y = np.fft.irfft(np.fft.rfft(x[:, ch], size) * np.fft.rfft(ir, size), size)[: x.shape[0]]
        out[:, ch] = x[:, ch] * (1 - wet) + y * wet * 1.6
    return out


# ---------------------------------------------------------------- music

CHORDS = {
    "Am9": ([57, 60, 64, 67, 71], 45),
    "Fmaj9": ([53, 57, 60, 64, 67], 41),
    "Cadd9": ([55, 60, 64, 67, 74], 48),
    "G6": ([55, 59, 62, 64, 69], 43),
}
PROGRESSION = ["Am9", "Fmaj9", "Cadd9", "G6"]


def chord_for_bar(b):
    if b < 0:
        return "Am9"
    if b == 12:
        return "Fmaj9"
    if b >= 13:
        return "Cadd9"
    return PROGRESSION[b % 4]


def bar_start(b):
    return GRID + b * BAR


def saw_voice(freq, seconds, brightness=7.0, detune_cents=0.0):
    tt = t_axis(seconds)
    f = freq * 2 ** (detune_cents / 1200)
    sig = np.zeros_like(tt)
    for h in range(1, 14):
        if f * h > 9000:
            break
        sig += np.sin(2 * np.pi * f * h * tt + h * 0.7) / h * np.exp(-h / brightness)
    return sig


def env_adsr(seconds, a, r):
    n = int(seconds * SR)
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na) ** 1.5
    e[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    return e


def pad_layer(music):
    layer = np.zeros_like(music)
    # Pre-roll swell on Am9 before the first downbeat.
    segments = [(0.0, GRID, "Am9", 1.2)]
    for b in range(0, 14):
        start = bar_start(b)
        length = BAR if b < 13 else DURATION - start
        segments.append((start, length, chord_for_bar(b), 0.35))
    for start, length, name, attack in segments:
        notes, _ = CHORDS[name]
        seconds = length + 0.6
        e = env_adsr(seconds, attack, 0.9)
        bright = 4.0 if start < 3.5 else (8.0 if start >= 25.5 else 6.0)
        left = sum(saw_voice(midi(n), seconds, bright, -7) for n in notes)
        right = sum(saw_voice(midi(n), seconds, bright, +7) for n in notes)
        place(layer, start, np.stack([left * e, right * e], axis=1) * 0.05)
    return layer


def bass_layer(music):
    layer = np.zeros_like(music)
    for b in range(1, 14):
        _, root = CHORDS[chord_for_bar(b)]
        f = midi(root)
        hits = [0, 1.5, 2, 3.5] if b not in (11, 13) else [0]
        for beat in hits:
            start = bar_start(b) + beat * BEAT
            seconds = (BEAT * 1.4) if b not in (11, 13) else BAR * (0.95 if b == 11 else 1.0)
            tt = t_axis(seconds)
            e = np.exp(-tt * (2.5 if seconds > 1 else 5)) * np.minimum(1, tt * 200)
            sig = np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * 2 * f * tt) + 0.12 * np.sin(2 * np.pi * 3 * f * tt)
            place(layer, start, np.tanh(sig * 1.4) * e * 0.32)
    return layer


def pluck(freq, seconds=0.32):
    tt = t_axis(seconds)
    sig = np.zeros_like(tt)
    for h in (1, 3, 5, 7):
        sig += np.sin(2 * np.pi * freq * h * tt) / (h * h) * np.exp(-tt * (9 + h * 4))
    return sig * np.minimum(1, tt * 400)


def arp_layer(music):
    layer = np.zeros_like(music)
    pattern = [0, 2, 4, 3, 1, 3, 2, 4]
    for b in range(0, 14):
        notes, _ = CHORDS[chord_for_bar(b)]
        steps = 16 if b < 13 else 8
        for s in range(steps):
            start = bar_start(b) + s * BEAT / 4
            if b == 11 and start >= 24.0:
                continue
            note = notes[pattern[s % 8]] + 12
            vel = (0.55 if s % 4 == 0 else 0.35) * (0.6 if b == 0 else 1.0)
            place(layer, start, pluck(midi(note)) * vel * 0.16, pan=0.35 * np.sin(s * 1.3))
    return layer


def kick():
    tt = t_axis(0.45)
    f = 48 + 110 * np.exp(-tt * 32)
    phase = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(phase) * np.exp(-tt * 7.5)
    click = noise(0.45) * np.exp(-tt * 300) * 0.15
    return np.tanh((body + click) * 1.6)


def clap():
    tt = t_axis(0.35)
    n = highpass(one_pole_lp(noise(0.35), 2600), 900)
    e = np.zeros_like(tt)
    for off in (0, 0.011, 0.022):
        e += np.where(tt >= off, np.exp(-(tt - off) * 60), 0)
    e += np.where(tt >= 0.03, np.exp(-(tt - 0.03) * 14), 0) * 0.6
    return n * e * 0.55


def hat(open_=False):
    seconds = 0.22 if open_ else 0.06
    tt = t_axis(seconds)
    n = highpass(noise(seconds), 7000)
    return n * np.exp(-tt * (18 if open_ else 70)) * 0.22


def drum_layers(music):
    drums = np.zeros_like(music)
    side = np.zeros(music.shape[0])
    k, c = kick(), clap()
    for b in range(1, 14):
        for beat in range(4):
            start = bar_start(b) + beat * BEAT
            if b == 11 and start >= 24.0:
                continue
            if b == 13 and beat > 0:
                continue
            place(drums, start, k * 0.9)
            i = int(start * SR)
            j = min(side.shape[0], i + int(0.3 * SR))
            side[i:j] = np.maximum(side[i:j], np.exp(-np.arange(j - i) / SR * 9))
            if beat in (1, 3) and b != 13:
                place(drums, start, c * 0.8, pan=0.05)
            if b != 13:
                place(drums, start + BEAT / 2, hat(open_=(beat == 3)) , pan=0.25)
                place(drums, start + BEAT / 4 * 3, hat() * 0.5, pan=-0.2)
    # Snare roll into the CTA drop.
    roll_start = 24.5
    steps = 16
    for s in range(steps):
        start = roll_start + s * (1.0 / steps)
        place(drums, start, c * (0.15 + 0.6 * s / steps), pan=0.0)
    return drums, side


def build_music():
    music = np.zeros((N, 2))
    pad = pad_layer(music)
    arp = arp_layer(music)
    bass = bass_layer(music)
    drums, side = drum_layers(music)
    duck = (1 - 0.45 * side)[:, None]
    tonal = reverb(pad * duck + arp, seconds=2.6, decay=0.7, wet=0.32)
    music = tonal + bass * duck + reverb(drums, seconds=1.2, decay=0.25, wet=0.12)
    tt = np.arange(N) / SR
    shape = np.ones(N)
    shape *= np.clip(tt / 1.2, 0, 1) ** 0.7
    shape *= np.where(tt > 29.4, np.clip(1 - (tt - 29.4) / 0.6, 0, 1), 1)
    return music * shape[:, None]


# ---------------------------------------------------------------- sound effects

def sfx_whoosh(seconds=0.6, f0=400, f1=2600, peak=0.45):
    tt = t_axis(seconds)
    x = tt / seconds
    cutoff = f0 + (f1 - f0) * np.sin(np.pi * np.clip(x / (peak * 2), 0, 1) / 2)
    n = highpass(one_pole_lp(noise(seconds), cutoff), 200)
    e = np.where(x < peak, (x / peak) ** 2, ((1 - x) / (1 - peak)) ** 1.6)
    left = n * e
    right = np.roll(n, 90) * e
    pan = np.linspace(-0.6, 0.6, tt.shape[0])
    return np.stack([left * (1 - pan) * 0.9, right * (1 + pan) * 0.9], axis=1)


def sfx_pop():
    tt = t_axis(0.16)
    f = 260 + 700 * np.exp(-tt * 45)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 28) * np.minimum(1, tt * 2000)


def sfx_tick():
    tt = t_axis(0.03)
    return (np.sin(2 * np.pi * 2900 * tt) * 0.5 + highpass(noise(0.03), 3000)) * np.exp(-tt * 260) * 0.5


def sfx_click():
    tt = t_axis(0.08)
    a = (highpass(noise(0.08), 2500) * 0.8 + np.sin(2 * np.pi * 1900 * tt) * 0.6) * np.exp(-tt * 180)
    b = np.zeros_like(a)
    shift = int(0.045 * SR)
    b[shift:] = a[: a.shape[0] - shift] * 0.45
    return a + b


def sfx_toggle():
    tt = t_axis(0.18)
    f = np.where(tt < 0.06, 620, 930)
    blip = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 18) * 0.5
    out = blip.copy()
    out[: int(0.08 * SR)] += sfx_click()[: int(0.08 * SR)] * 0.7
    return out


def bell(freq, seconds=1.4, decay=3.0):
    tt = t_axis(seconds)
    sig = np.zeros_like(tt)
    for ratio, amp, d in ((1, 1, 1), (2.0, 0.45, 1.6), (2.76, 0.3, 2.2), (5.4, 0.12, 3.5)):
        sig += np.sin(2 * np.pi * freq * ratio * tt) * amp * np.exp(-tt * decay * d)
    return sig * np.minimum(1, tt * 800) * 0.4


def sfx_success():
    out = np.zeros(int(1.6 * SR))
    for k, note in enumerate((76, 83)):
        s = bell(midi(note), 1.4)
        i = int(k * 0.09 * SR)
        out[i : i + s.shape[0]] += s
    return out


def sfx_shimmer():
    out = np.zeros(int(2.0 * SR))
    for k, note in enumerate((84, 88, 91, 96, 100)):
        s = bell(midi(note), 1.5, decay=2.2) * 0.6
        i = int(k * 0.045 * SR)
        out[i : i + s.shape[0]] += s
    return out


def sfx_impact():
    tt = t_axis(2.2)
    f = 34 + 90 * np.exp(-tt * 14)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 2.2)
    crash = one_pole_lp(noise(2.2), 6000) * np.exp(-tt * 3.5) * 0.35
    hit = highpass(noise(2.2), 1500) * np.exp(-tt * 30) * 0.4
    return np.tanh((boom * 1.2 + crash + hit) * 1.3)


def sfx_riser(seconds=1.5):
    tt = t_axis(seconds)
    x = tt / seconds
    n = one_pole_lp(noise(seconds), 400 + 9000 * x ** 2)
    sweep = np.sin(2 * np.pi * np.cumsum(180 + 1100 * x ** 2) / SR) * 0.3
    return (n * 0.8 + sweep) * x ** 2.2


def sfx_drop():
    tt = t_axis(0.35)
    f = 70 + 160 * np.exp(-tt * 30)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 14)
    out = thud.copy()
    p = sfx_pop() * 0.5
    out[: p.shape[0]] += p
    return out


def make_sfx(kind):
    return {
        "whoosh": lambda: sfx_whoosh(0.6),
        "swoosh": lambda: sfx_whoosh(0.45, 600, 4200, 0.35),
        "swoosh-up": lambda: sfx_whoosh(0.7, 300, 5200, 0.6),
        "swipe": lambda: sfx_whoosh(0.28, 1500, 7000, 0.3),
        "pop": sfx_pop,
        "tick": sfx_tick,
        "click": sfx_click,
        "toggle": sfx_toggle,
        "success": sfx_success,
        "shimmer": sfx_shimmer,
        "impact": sfx_impact,
        "riser": sfx_riser,
        "drop": sfx_drop,
    }[kind]()


def build_sfx(cues):
    bus = np.zeros((N, 2))
    for cue in cues:
        sig = make_sfx(cue["type"])
        place(bus, cue["t"], sig * cue.get("gain", 1.0), pan=cue.get("pan", 0.0))
    return reverb(bus, seconds=1.4, decay=0.35, wet=0.18)


# ---------------------------------------------------------------- mix

def normalise(x, peak_db):
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * 10 ** (peak_db / 20)


def main():
    cues = json.loads((OUT / "sfx.json").read_text())
    music = normalise(build_music(), -7.0)
    sfx = normalise(build_sfx(cues), -4.0)
    mix = music + sfx
    mix = np.tanh(mix * 1.15) / np.tanh(1.15)
    mix = normalise(mix, -1.0)
    pcm = (np.clip(mix, -1, 1) * 32767).astype("<i2")
    with wave.open(str(OUT / "audio.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"Wrote out/audio.wav ({DURATION:.0f}s, {len(cues)} sound cues)")


if __name__ == "__main__":
    main()
