#!/usr/bin/env python3
"""Synthesises the game's sound effects into assets/sfx as 16-bit mono WAVs.

Everything here is generated from scratch (no sampled material), so the audio
ships with the app without third-party licensing.

Every pitched layer is written in note names from `tool/pitch.py`, the same
table `tool/gen_music.py` builds the pad from, because these sounds are heard
over sustained music and an effect a semitone off the pad reads as a mistake.
The old round numbers - 1250, 320, 480 - were 35 to 50 cents from any note,
which is close enough to nothing to sound untuned once a pad is holding a
chord underneath.

One thing to know before retuning anything here: with envelopes this fast the
pitch you hear is where a glide STARTS, not where it ends. `drop` sweeps G3 to
C2, but it is 40 dB down by the time it reaches C2 - 94% of its energy is in
120-260 Hz, around the G. The landing is felt as weight, not heard as a note.
So the opening pitch is the one that has to be in key; the fall is a gesture.

`blocked` is the one sound deliberately left out of key. It means no.
"""

import math
import os
import random
import struct
import wave

from pitch import describe, is_in_key, note

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sfx")


def write(name, samples, peak=0.85):
    frames = len(samples)
    # Trim DC drift and normalise to a predictable peak.
    hi = max(abs(s) for s in samples) or 1.0
    gain = peak / hi
    fade = min(int(0.006 * SR), frames // 4)
    data = bytearray()
    for i, s in enumerate(samples):
        v = s * gain
        if i < fade:
            v *= i / fade
        if i > frames - fade:
            v *= max(0.0, (frames - i) / fade)
        v = max(-1.0, min(1.0, v))
        data += struct.pack("<h", int(v * 32767))
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(data))
    print("%-14s %5.0f ms  %6d bytes" % (name, frames / SR * 1000, os.path.getsize(path)))


def env(n, attack, decay, curve=2.0):
    """Percussive envelope: linear attack, exponential-ish decay."""
    a = max(1, int(attack * SR))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1, (n - a))
            out.append(max(0.0, (1.0 - t) ** curve) * math.exp(-t * decay))
    return out


def lowpass(sig, cutoff):
    """One-pole low-pass; cutoff may be a scalar or a per-sample list."""
    out = []
    y = 0.0
    for i, x in enumerate(sig):
        fc = cutoff[i] if isinstance(cutoff, list) else cutoff
        a = 1.0 - math.exp(-2.0 * math.pi * fc / SR)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    out = []
    y = 0.0
    prev = 0.0
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    for x in sig:
        y = a * (y + x - prev)
        prev = x
        out.append(y)
    return out


def noise(n, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def tone(n, f0, f1=None, harmonics=(1.0,), phase=0.0):
    f1 = f0 if f1 is None else f1
    out = []
    ph = phase
    for i in range(n):
        t = i / max(1, n - 1)
        f = f0 * (f1 / f0) ** t
        ph += 2.0 * math.pi * f / SR
        v = 0.0
        for k, amp in enumerate(harmonics, start=1):
            v += amp * math.sin(ph * k)
        out.append(v)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def apply(sig, e):
    return [s * e[i] for i, s in enumerate(sig)]


# --- rotate: crisp mechanical detent -----------------------------------------
def rotate():
    n = int(0.10 * SR)
    click = apply(highpass(noise(n, 11), 1800), env(n, 0.0004, 26, 3.0))
    body = apply(tone(n, note("e6"), note("a5")), env(n, 0.001, 18))
    sub = apply(tone(n, note("e4"), note("a3")), env(n, 0.001, 22))
    return mix([c * 0.55 for c in click], [b * 0.45 for b in body], [s * 0.3 for s in sub])


# --- cut: quick scissor snip -------------------------------------------------
def cut():
    n = int(0.22 * SR)
    cutoff = [7000 - 4200 * (i / n) for i in range(n)]
    hiss = apply(lowpass(highpass(noise(n, 23), 900), cutoff), env(n, 0.0008, 14, 2.2))
    second = [0.0] * n
    off = int(0.045 * SR)
    snip2 = apply(highpass(noise(n - off, 1600), 1200), env(n - off, 0.0005, 30, 3.0))
    for i, v in enumerate(snip2):
        second[off + i] = v * 0.7
    ring = apply(tone(n, note("c7"), note("g6")), env(n, 0.001, 26))
    return mix([h * 0.8 for h in hiss], second, [r * 0.25 for r in ring])


# --- drop: weighted thud with a small snap ----------------------------------
def drop():
    n = int(0.26 * SR)
    thud = apply(
        tone(n, note("g3"), note("c2"), harmonics=(1.0, 0.25)),
        env(n, 0.002, 9),
    )
    snap = apply(highpass(noise(n, 37), 2400), env(n, 0.0004, 34, 3.0))
    wood = apply(tone(n, note("c5"), note("e4")), env(n, 0.001, 20))
    return mix(thud, [s * 0.28 for s in snap], [w * 0.22 for w in wood])


# --- paint: airy whoosh ------------------------------------------------------
def paint():
    n = int(0.38 * SR)
    cutoff = [700 + 5200 * math.sin(math.pi * (i / n)) for i in range(n)]
    air = lowpass(highpass(noise(n, 51), 400), cutoff)
    shaped = [air[i] * (math.sin(math.pi * (i / n)) ** 1.6) for i in range(n)]
    shimmer = apply(
        tone(n, note("d5"), note("g6"), harmonics=(1.0, 0.4, 0.2)),
        env(n, 0.05, 5),
    )
    return mix([s * 0.9 for s in shaped], [s * 0.16 for s in shimmer])


# --- win: warm bell arpeggio ------------------------------------------------
def win():
    total = int(1.25 * SR)
    out = [0.0] * total
    # C5 E5 G5 C6 - simple, bright, resolved. The reference the rest of
    # the game, and the pad, are tuned to.
    for idx, freq in enumerate(note(p) for p in ("c5", "e5", "g5", "c6")):
        start = int(idx * 0.085 * SR)
        n = total - start
        bell = apply(
            tone(n, freq, freq * 0.998, harmonics=(1.0, 0.42, 0.18, 0.08)),
            env(n, 0.006, 4.2, 1.4),
        )
        for i, v in enumerate(bell):
            out[start + i] += v * (0.85 if idx < 3 else 1.0)
    sparkle = apply(highpass(noise(total, 71), 5000), env(total, 0.01, 7, 2.0))
    return mix(out, [s * 0.10 for s in sparkle])


# --- tap: soft UI tick ------------------------------------------------------
def tap():
    n = int(0.07 * SR)
    # Weighted towards the click rather than the body. A 70 ms sine at 880 Hz
    # is the easiest thing in the game for a sustained pad to swallow, and this
    # is the sound that confirms a button was pressed.
    click = apply(highpass(noise(n, 83), 2600), env(n, 0.0004, 40, 3.0))
    body = apply(tone(n, note("a6"), note("e6")), env(n, 0.0008, 30))
    return mix([c * 0.62 for c in click], [b * 0.5 for b in body])


# --- pickup: rising blip when a drag starts ---------------------------------
def pickup():
    n = int(0.11 * SR)
    blip = apply(
        tone(n, note("b4"), note("b5"), harmonics=(1.0, 0.2)),
        env(n, 0.004, 12),
    )
    return [b * 0.8 for b in blip]


# --- blocked: dull refusal --------------------------------------------------
# Eb and Bb, the only pitches in the game outside the key. Note that being out
# of key is not by itself enough to grate: roughness is a matter of absolute
# distance in Hz, so a tritone parked an octave below the pad is smoother than
# an in-key note sitting inside it. These land in the register where the pad's
# own notes are, which is the only place a wrong note is felt as one.
def blocked():
    n = int(0.20 * SR)
    buzz = apply(
        tone(n, note("d#3"), note("a#2"), harmonics=(1.0, 0.5, 0.3)),
        env(n, 0.003, 11),
    )
    grit = apply(lowpass(noise(n, 97), 900), env(n, 0.002, 16))
    return mix(buzz, [g * 0.35 for g in grit])


# What each verb says, musically. Printed on every run so the reasoning stays
# in front of whoever regenerates these, rather than only in the commit that
# introduced it.
VOICING = (
    ("rotate", ("e6", "a5"), "falling fifth, doubled two octaves down"),
    ("cut", ("c7", "g6"), "falling fourth - down reads as severed"),
    ("drop", ("g3", "c2"), "opens on the dominant; the fall is weight"),
    ("paint", ("d5", "g6"), "rising - up reads as spreading"),
    ("win", ("c5", "e5", "g5", "c6"), "the tonic chord, and the key itself"),
    ("tap", ("a6", "e6"), "falling fourth, above the bells"),
    ("pickup", ("b4", "b5"), "leading tone: held, not yet placed"),
    ("blocked", ("d#3", "a#2"), "out of key, and close enough to beat"),
)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("rotate.wav", rotate(), peak=0.7)
    write("cut.wav", cut(), peak=0.72)
    write("drop.wav", drop(), peak=0.8)
    write("paint.wav", paint(), peak=0.62)
    write("win.wav", win(), peak=0.8)
    write("tap.wav", tap(), peak=0.72)
    write("pickup.wav", pickup(), peak=0.5)
    write("blocked.wav", blocked(), peak=0.6)
    print()
    for name, names, why in VOICING:
        flag = "" if all(is_in_key(n) for n in names) else "  <- out of key"
        print("%-9s %-22s %s%s" % (name, describe(*names), why, flag))
