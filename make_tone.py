#!/usr/bin/env python3
"""Genera i toni di prova per l'analizzatore, in mas/test-tones/.

Sono i file con cui ho tarato e verificato l'app: tre toni puri a 1000, 60 e 8000 Hz
(ampiezza 0,30 = −10,5 dBFS) e una scarica di rumore rosa per riempire tutte le bande.

    python3 make_tone.py
    afplay mas/test-tones/cal-test.wav
"""

import array
import math
import os
import random
import wave

SR = 48000
AMPLITUDE = 0.30            # = -10,5 dBFS: la banda che contiene il tono deve leggere ~-10,5
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "mas", "test-tones")


def write(name, frames):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames.tobytes())
    print(f"{path}  ({len(frames)/SR:.1f} s)")


def tone(freq, dur, amp=AMPLITUDE, fade=0.15):
    """Tono puro con sfumatura ai bordi, per non sentire i click."""
    frames = array.array("h")
    for i in range(int(SR * dur)):
        t = i / SR
        env = min(1.0, t / fade, (dur - t) / fade)
        frames.append(int(amp * env * 32767 * math.sin(2 * math.pi * freq * t)))
    return frames


def sequence(segments):
    out = array.array("h")
    for freq, dur in segments:
        out.extend(tone(freq, dur))
    return out


def pink_noise(dur, amp=0.45, seed=7):
    """Rumore rosa grezzo (un polo): tutte le bande hanno qualcosa da mostrare."""
    random.seed(seed)
    frames = array.array("h")
    prev = 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        env = min(1.0, t / 0.2, (dur - t) / 0.2)
        prev = 0.97 * prev + 0.03 * random.uniform(-1, 1)
        v = max(-1.0, min(1.0, prev * 8.0))
        frames.append(int(v * amp * env * 32767))
    return frames


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # i tre toni usati per la taratura: uno per volta, così si legge chiaramente quale banda si accende
    write("cal-test.wav", sequence([(1000, 4.0), (60, 4.0), (8000, 4.0)]))
    write("tone-440.wav", tone(440.0, 8.0))
    write("noise.wav", pink_noise(6.0))
