#!/usr/bin/env python3
"""Synthesises the background music into assets/music as 16-bit mono WAVs.

Two seamless loops of deliberately mismatched lengths: a 40 s harmonic pad and
a 27 s motif of bells over it. 40 and 27 share no factors, so the pair only
lines up again every 18 minutes - long enough that the bed reads as endless
rather than as a loop. Nothing here is sampled, so the music ships with the app
without third-party licensing, exactly like `tool/gen_sfx.py`.

Both files are also quietest exactly at their own loop point. The WAVs join
seamlessly, but audioplayers does not: on Apple platforms it waits for an
end-of-item notification, hops to the main actor and awaits a seek before
resuming, which is a real gap on every lap that nothing in this file can close.
Putting the trough of each loop's existing swell on the seam means that gap
falls where the music is already receding, and the other loop - a different
length, so never seamed at the same moment - is still playing over it.

Everything is written to wrap: partials are snapped to whole cycles per loop,
filters are run in twice so their state is settled at the seam, and note tails
that run off the end are added back onto the front. Play the file end-to-end
and the join is inaudible.
"""

import math
import os
import random
import struct
import wave

from pitch import note

# Pads and bells live well under 11 kHz, so half rate costs nothing audible
# and halves what ships in the bundle.
SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "music")

# Pitched through tool/pitch.py, the same table the effects use, so the pad
# and a placed piece are never a semitone apart.
PAD_SECONDS = 40.0
MOTIF_SECONDS = 27.0

# --- oscillator --------------------------------------------------------------
# A table lookup rather than math.sin per partial: the pad alone is ~30 million
# samples of oscillator, which is the difference between seconds and minutes.
_BITS = 12
_SIZE = 1 << _BITS
_MASK = _SIZE - 1
_SINE = [math.sin(2.0 * math.pi * i / _SIZE) for i in range(_SIZE)]


def osc(n, freq, phase=0.0):
    """Fixed-frequency sine. Phase is in turns, not radians."""
    step = freq / SR * _SIZE
    ph = phase * _SIZE
    out = [0.0] * n
    for i in range(n):
        out[i] = _SINE[int(ph) & _MASK]
        ph += step
    return out


def cycles(freq, seconds):
    """Snap a frequency to a whole number of cycles per loop.

    A partial that does not close an exact number of cycles inside the buffer
    steps discontinuously at the seam and clicks. Snapping moves it by at most
    1/(2*seconds) Hz - 0.016 Hz across the pad - which no one can hear.
    """
    return max(1, round(freq * seconds)) / seconds


# --- buffers -----------------------------------------------------------------
def add_wrapped(buf, start, sig, gain=1.0):
    """Mix `sig` in at `start`, wrapping anything past the end onto the front.

    This is what makes a decaying note loop-safe: the sample after the last one
    in the buffer is the sample the note would have played next, because the
    loop puts them side by side.
    """
    n = len(buf)
    start %= n
    for i, v in enumerate(sig):
        buf[(start + i) % n] += v * gain


def lowpass_loop(sig, cutoff):
    """One-pole low-pass with its state settled at the loop point.

    Filtering from a cold start leaves the opening samples darker than the ones
    that will really precede them once it repeats. Running two laps and keeping
    the second removes the seam.
    """
    n = len(sig)
    if isinstance(cutoff, list):
        coef = [1.0 - math.exp(-2.0 * math.pi * fc / SR) for fc in cutoff]
    else:
        coef = [1.0 - math.exp(-2.0 * math.pi * cutoff / SR)] * n
    out = [0.0] * n
    y = 0.0
    for lap in range(2):
        for i in range(n):
            y += coef[i] * (sig[i] - y)
            if lap:
                out[i] = y
    return out


def highpass_loop(sig, cutoff):
    n = len(sig)
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    out = [0.0] * n
    y = 0.0
    prev = sig[-1]
    for lap in range(2):
        for i in range(n):
            y = a * (y + sig[i] - prev)
            prev = sig[i]
            if lap:
                out[i] = y
    return out


def write(name, samples, peak):
    """Normalise and write. Deliberately no fade - a fade would be the seam."""
    hi = max(abs(s) for s in samples) or 1.0
    gain = peak / hi
    rms = math.sqrt(sum((s * gain) ** 2 for s in samples) / len(samples))
    data = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s * gain))
        data += struct.pack("<h", int(v * 32767))
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(data))
    print(
        "%-12s %5.1f s  peak %.2f  rms %.3f  %6.0f KB"
        % (name, len(samples) / SR, peak, rms, os.path.getsize(path) / 1024)
    )


# --- pad ---------------------------------------------------------------------
# Am9 - Fmaj7 - Cmaj7 - G6. Four chords that share most of their notes, so the
# wash drifts between them instead of stepping. It never resolves, which is the
# point: resolution asks for attention, and this plays under someone thinking.
CHORDS = (
    (("a3", "c4", "e4", "g4", "b4"), "a2"),
    (("f3", "a3", "c4", "e4"), "f2"),
    (("c4", "e4", "g4", "b4"), "c2"),
    (("g3", "b3", "d4", "e4"), "g2"),
)

# Long enough that no chord ever quite arrives.
CROSSFADE = 4.5


def chord_window(n, index, count, cross_n):
    """cos^2 window over one chord's slot. Neighbours sum to exactly 1.

    cos^2 + sin^2 = 1 across the overlap, so the wash holds a constant level
    through every change rather than dipping at each one.
    """
    seg = n / count
    half = seg / 2.0
    flat = half - cross_n / 2.0
    span = int(seg + cross_n)
    start = int(index * seg - cross_n / 2.0)
    out = [0.0] * span
    for i in range(span):
        d = abs((start + i) - (index + 0.5) * seg)
        if d <= flat:
            out[i] = 1.0
        elif d < half + cross_n / 2.0:
            x = (d - flat) / cross_n
            out[i] = math.cos(math.pi * x / 2.0) ** 2
    return out, start


def pad():
    n = int(PAD_SECONDS * SR)
    cross_n = CROSSFADE * SR
    buf = [0.0] * n
    bass = [0.0] * n

    for index, (voicing, root) in enumerate(CHORDS):
        window, start = chord_window(n, index, len(CHORDS), cross_n)
        span = len(window)
        voice = [0.0] * span
        for pitch in voicing:
            base = note(pitch)
            # Two slightly detuned copies per note. The beating between them is
            # what stops a stack of sines sounding like a test tone.
            for cents, level in ((0.0, 1.0), (2.6, 0.85), (-2.1, 0.7)):
                f = cycles(base * 2.0 ** (cents / 1200.0), PAD_SECONDS)
                for harmonic, amp in ((1, 1.0), (2, 0.24), (3, 0.09), (4, 0.035)):
                    wave_ = osc(span, cycles(f * harmonic, PAD_SECONDS), phase=(harmonic * 0.11 + level) % 1.0)
                    a = amp * level / len(voicing)
                    for i in range(span):
                        voice[i] += wave_[i] * a
        for i in range(span):
            voice[i] *= window[i]
        add_wrapped(buf, start, voice, 0.5)

        # Root an octave and a half down, soft, so the harmony has a floor.
        # Weighted to the fundamental on purpose: the octave lands at 130-220 Hz,
        # which is exactly where `drop` carries 94% of its energy, and the pad
        # has no business crowding the sound a placement makes.
        f = cycles(note(root), PAD_SECONDS)
        low = osc(span, f)
        second = osc(span, cycles(f * 2, PAD_SECONDS))
        for i in range(span):
            low[i] = (low[i] + second[i] * 0.18) * window[i]
        add_wrapped(bass, start, low, 0.42)

    # Slow filter breathing, two full sweeps per loop so it wraps.
    sweep = [1500.0 + 900.0 * math.sin(2.0 * math.pi * 2.0 * i / n) for i in range(n)]
    buf = lowpass_loop(buf, sweep)

    # A quiet band of air over the top. The noise is one loop long and the
    # filters are settled, so it wraps with everything else.
    #
    # Kept very low on purpose. This is broadband noise sitting at 2-6 kHz,
    # which is exactly where every click in the game lives, and it masks them
    # long before it adds anything a listener would miss.
    rng = random.Random(1731)
    air = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    air = lowpass_loop(highpass_loop(air, 2000.0), 6000.0)
    swell = [0.5 - 0.5 * math.cos(2.0 * math.pi * 3.0 * i / n) for i in range(n)]

    out = [0.0] * n
    for i in range(n):
        # One breath per loop, shallow, with its trough on the seam: the
        # wash should move, not pulse, and the quietest instant should be
        # the one the player is most likely to interrupt.
        tremolo = 0.88 - 0.12 * math.cos(2.0 * math.pi * i / n)
        out[i] = buf[i] * tremolo + bass[i] * 0.55 + air[i] * swell[i] * 0.02
    # Nothing below the lowest note in the progression is music, and rumble
    # here only eats the headroom that `drop` needs.
    return highpass_loop(out, 58.0)


# --- motif -------------------------------------------------------------------
# C major pentatonic plus B: every one of these sits comfortably over all four
# chords, so the bells can float free of the harmony instead of tracking it.
MOTIF_NOTES = ("e4", "g4", "a4", "c5", "d5", "e5", "g5", "a5", "c6", "d6")


def bell(seconds, freq, decay):
    n = int(seconds * SR)
    out = [0.0] * n
    # Slightly stretched partials: struck metal, not a sine.
    for ratio, amp, spread in (
        (1.0, 1.0, 1.0),
        (2.01, 0.38, 1.35),
        (3.03, 0.17, 1.7),
        (4.98, 0.08, 2.2),
        (6.94, 0.035, 2.8),
    ):
        partial = osc(n, freq * ratio, phase=ratio * 0.37 % 1.0)
        # Higher partials die first, which is what makes a strike read as one
        # event that softens rather than a chord that stops.
        d = decay * spread
        attack = max(1, int(0.008 * SR))
        for i in range(n):
            e = math.exp(-i / SR * d)
            if i < attack:
                e *= i / attack
            out[i] += partial[i] * amp * e
    return out


# How far apart the bells fall. Sparse and uneven: regular spacing would turn
# them into a metronome and make the loop obvious.
SPACINGS = (1.1, 1.4, 1.9, 2.3, 2.3, 3.1)


def bell_schedule():
    """Strike times whose gaps add up to exactly one loop.

    This closing-the-circle constraint is the whole function. Filling the loop
    by walking forward until you run out of room leaves the wrap-around gap as
    whatever happens to be left over, and left-over is not a musical value: at
    27 s it came to 0.50 s against a minimum spacing of 1.10 s, which dropped
    two bells on top of each other once per loop. The loop was seamless as a
    waveform and still audibly broke, because the rhythm did not repeat even
    though the samples did.

    So schedules are re-rolled until the remainder is itself a legal gap, and
    the whole ring is then rotated to put the loop point in the middle of the
    widest silence. Rotating a closed ring of gaps preserves every one of them,
    and it means the restart - which the player cannot make gapless anyway -
    lands where the fewest bells are speaking.
    """
    for attempt in range(10000):
        rng = random.Random(90210 + attempt)
        gaps, total = [], 0.0
        while total + max(SPACINGS) < MOTIF_SECONDS:
            gap = rng.choice(SPACINGS)
            gaps.append(gap)
            total += gap
        remaining = MOTIF_SECONDS - total
        if not min(SPACINGS) <= remaining <= max(SPACINGS):
            continue
        gaps.append(remaining)

        times, t = [], 0.0
        for gap in gaps:
            times.append(t)
            t += gap
        widest = max(range(len(gaps)), key=lambda i: gaps[i])
        shift = times[widest] + gaps[widest] / 2.0
        return sorted((x - shift) % MOTIF_SECONDS for x in times), rng
    raise AssertionError("no bell schedule closes the loop")


def motif():
    n = int(MOTIF_SECONDS * SR)
    buf = [0.0] * n
    times, rng = bell_schedule()

    strikes = [
        (t, MOTIF_NOTES[rng.randrange(len(MOTIF_NOTES))], rng.uniform(0.45, 1.0))
        for t in times
    ]

    for start, pitch, level in strikes:
        freq = cycles(note(pitch), MOTIF_SECONDS)
        # Long tails, wrapped by add_wrapped - a bell struck near the end of
        # the loop keeps ringing over the top of the loop's beginning.
        voice = bell(5.0, freq, 1.15)
        add_wrapped(buf, int(start * SR), voice, level * 0.5)

    # Three echo taps at prime-ish spacings, each darker than the last. Cheaper
    # than a reverb and, wrapped, just as seamless.
    tail = [0.0] * n
    for delay, gain in ((0.53, 0.34), (0.97, 0.20), (1.63, 0.11)):
        add_wrapped(tail, int(delay * SR), buf, gain)
    tail = lowpass_loop(tail, 2600.0)

    out = [0.0] * n
    for i in range(n):
        out[i] = buf[i] + tail[i]
    out = lowpass_loop(out, 7200.0)
    # Receding into its own seam, for the same reason as the pad.
    return [v * (0.90 - 0.10 * math.cos(2.0 * math.pi * i / n)) for i, v in enumerate(out)]


def check_schedule():
    """The rhythm has to repeat, not just the samples.

    Printed and asserted on every run because this failed silently once: the
    waveform looped perfectly and the music still broke audibly, because the
    gap across the seam was half the shortest gap anywhere else.
    """
    times, _ = bell_schedule()
    gaps = [
        (times[(i + 1) % len(times)] - times[i]) % MOTIF_SECONDS
        for i in range(len(times))
    ]
    seam = (MOTIF_SECONDS - times[-1]) + times[0]
    assert abs(sum(gaps) - MOTIF_SECONDS) < 1e-6, "gaps do not close the loop"
    assert min(gaps) >= min(SPACINGS) - 1e-6, "a gap is shorter than allowed"
    print(
        "bells        %d strikes  gaps %.1f-%.1fs  seam gap %.1fs (widest)"
        % (len(times), min(gaps), max(gaps), seam)
    )


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("pad.wav", pad(), peak=0.62)
    write("motif.wav", motif(), peak=0.5)
    check_schedule()
