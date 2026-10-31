#!/usr/bin/env python3
"""Generates the placeholder sound effects into audio/sfx and audio/ui (needs numpy).

Run from the repo root:  python3 tools/generate_sounds.py
To use real sounds later, just replace the .wav files (same names); the game loads them by path
(see scripts/audio_manager.gd). Re-running this script overwrites any replaced file, so don't.
"""
import os
import wave

import numpy as np

RATE = 44100
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(seconds, attack=0.002, decay=20.0):
    t = t_axis(seconds)
    return np.minimum(t / attack, 1.0) * np.exp(-decay * t)


def tone(freq, seconds, decay=20.0, attack=0.002):
    t = t_axis(seconds)
    return np.sin(2 * np.pi * freq * t) * env(seconds, attack, decay)


def sweep(f0, f1, seconds, decay=8.0, attack=0.002):
    t = t_axis(seconds)
    freq = f0 + (f1 - f0) * (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase) * env(seconds, attack, decay)


def noise(seconds, decay=40.0):
    return rng.uniform(-1, 1, int(RATE * seconds)) * env(seconds, 0.0005, decay)


def lowpass(x, alpha):
    out = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        out[i] = acc
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def delay(x, seconds):
    return np.concatenate([np.zeros(int(RATE * seconds)), x])


def save(path, x, peak=0.85):
    x = x / max(np.abs(x).max(), 1e-6) * peak
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((x * 32767).astype("<i2").tobytes())
    print("wrote", path)


root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
sfx = lambda name: os.path.join(root, "sfx", name + ".wav")
ui = lambda name: os.path.join(root, "ui", name + ".wav")

# --- Game sounds -------------------------------------------------------------------------
# Plastic "clack": a sharp click plus two quickly dying hard tones.
save(sfx("clack_plastic"), mix(0.6 * noise(0.03, 160), tone(1900, 0.09, 60), 0.7 * tone(2850, 0.07, 80), 0.4 * tone(1150, 0.1, 50)))
# Wall / pin: a lower, rounder "tock".
save(sfx("clack_wall"), mix(0.4 * noise(0.03, 120), tone(820, 0.14, 38), 0.6 * tone(1350, 0.1, 55), 0.5 * sweep(300, 180, 0.12, 30)))
# Explosion: a low sweep down with a rumble of low-passed noise.
save(sfx("boom"), mix(sweep(130, 38, 0.9, 5.0, 0.004), 0.9 * lowpass(noise(0.9, 4.5), 0.06), 0.4 * noise(0.06, 60)))
# Implosion: a sweep UP that swells, then a short thump.
swell = sweep(70, 520, 0.45, -3.0, 0.02) * np.linspace(0.2, 1.0, int(RATE * 0.45))
save(sfx("implosion"), mix(swell, 0.4 * lowpass(noise(0.45, -2.5), 0.1) * np.linspace(0.1, 1.0, int(RATE * 0.45)),
                           delay(0.9 * tone(70, 0.2, 18), 0.43)))
# Knocked off the table: a small falling pop.
save(sfx("fall_pop"), mix(sweep(780, 190, 0.28, 11.0), 0.5 * noise(0.012, 200)))
# Flick release: a soft snap with a little air.
save(sfx("flick"), mix(0.55 * lowpass(noise(0.1, 38), 0.35), 0.5 * tone(1500, 0.05, 90), 0.3 * sweep(700, 1700, 0.06, 45)))

# --- Menu and UI -------------------------------------------------------------------------
save(ui("tap"), tone(1250, 0.05, 70))
save(ui("confirm"), mix(tone(660, 0.12, 22), delay(tone(990, 0.16, 20), 0.07)))
save(ui("back"), mix(tone(620, 0.1, 26), delay(tone(440, 0.14, 24), 0.06)))
save(ui("purchase"), mix(tone(1320, 0.28, 10), delay(tone(1760, 0.34, 8), 0.09), 0.25 * noise(0.01, 200)))
save(ui("reveal"), mix(*[delay(0.8 * tone(f, 0.22, 11), 0.07 * i) for i, f in enumerate([784, 988, 1175, 1568])]))
fan = [delay(tone(f, 0.38, 6, 0.004), s) for f, s in [(523, 0.0), (659, 0.16), (784, 0.32)]]
chord = mix(*[delay(tone(f, 0.9, 3.2, 0.006), 0.5) for f in (523, 659, 784, 1047)])
save(ui("fanfare"), mix(*fan, chord))
