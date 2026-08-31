#!/usr/bin/env python3
"""The one tuning table shared by the sound effects and the music.

Quadcraft is in C major, and has been since before it had music: `win` is a
literal C-E-G-C arpeggio, so the key was already decided by the sound that
mattered most. `tool/gen_sfx.py` and `tool/gen_music.py` both pitch their
material through this module, in note names rather than round numbers, so an
effect and the pad cannot drift apart by accident.

Round numbers were the original problem. 1250 Hz is 8 cents from D#6, 320 Hz is
49 cents from D#4 - close enough to nothing to read as untuned once something
sustained is playing underneath it.
"""

import math

_SEMITONE = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}

# The notes the pad and the motif actually hold. PENTATONIC is the safer set:
# C D E G A sit consonantly over every chord in the progression, while F and B
# belong to only some of them.
IN_KEY = ("c", "d", "e", "f", "g", "a", "b")
PENTATONIC = ("c", "d", "e", "g", "a")


def note(name):
    """"a3" -> 220.0, "c#3" -> 138.59. Equal temperament, A4 = 440."""
    step = _SEMITONE[name[0]] + (1 if "#" in name else 0)
    octave = int(name[-1])
    return 440.0 * 2.0 ** ((step - 9) / 12.0 + (octave - 4))


def is_in_key(name):
    return name[0] in IN_KEY and "#" not in name


def describe(*names):
    """"g3 -> c2 (-1900c)" for the generators to print as they work."""
    freqs = [note(n) for n in names]
    span = 1200 * math.log2(freqs[-1] / freqs[0]) if len(freqs) > 1 else 0
    tail = " %+.0fc" % span if len(freqs) > 1 else ""
    return " ".join(n.upper() for n in names) + tail
