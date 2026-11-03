# Generates the game's sound effects (the "Bubble Pop" set in assets/audio) from scratch with numpy.
# Needs Python 3 and numpy. Writes WAV masters; the shipping .ogg files are encoded from them with
# ffmpeg, as described in tools/audio/README.md.

"""Render audition sketches for three Thumb Party sound palettes.

Every cue is synthesised from scratch with numpy (no samples, no libraries
beyond numpy) so the whole thing is reproducible and licence-clean.

Output:
  final/palette-b-bubble-pop-wav/  the chosen direction, mastered PCM masters
  archive/palette-a-toy-box/       kept for A/B testing with players
  archive/palette-c-picnic-band/
  tours/                           one file per palette, cues in game order

Cue files carry the exact names the game looks up (hit.wav, success.wav, ...).
The shipping copies in final/palette-b-bubble-pop/ are Ogg Vorbis, encoded from
these masters with ffmpeg. Mono, 44.1 kHz: the TV app decodes both formats and
asset_manifest.findSound() accepts either.
"""

import os
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(20261102)
OUT = os.path.dirname(os.path.abspath(__file__))

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(name):
    """'C5' / 'F#4' / 'Bb3' -> frequency."""
    letter, rest = name[0], name[1:]
    semi = 0
    if rest and rest[0] in "#b":
        semi = 1 if rest[0] == "#" else -1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + NOTE[letter] + semi
    return 440.0 * 2 ** ((midi - 69) / 12)


# --------------------------------------------------------------------------
# primitives
# --------------------------------------------------------------------------
def bandnoise(n, lo, hi):
    """White noise through a soft band-pass, via the FFT (short buffers only)."""
    n = max(int(n), 16)
    spec = np.fft.rfft(rng.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    mask = np.ones_like(fr)
    if lo:
        mask *= 1.0 / (1.0 + (lo / np.maximum(fr, 1e-3)) ** 4)
    if hi:
        mask *= 1.0 / (1.0 + (fr / hi) ** 4)
    return np.fft.irfft(spec * mask, n)


def mallet(f, dur=0.8, amp=1.0, decay=0.45, tone=1.0):
    """Marimba / kalimba style struck bar: a few fast-decaying partials."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, a, k in ((1, 1.0, 1.0), (1.997, 0.14, 0.55),
                        (3.93, 0.085 * tone, 0.32), (9.2, 0.02 * tone, 0.14)):
        out += a * np.exp(-t / (decay * k + 1e-4)) * np.sin(2 * np.pi * f * ratio * t)
    out *= np.clip(t / 0.0025, 0, 1)
    m = min(n, int(0.005 * SR))
    if m > 16:
        click = bandnoise(m, 1200, 5200) * np.exp(-np.arange(m) / SR / 0.0012)
        out[:m] += 0.10 * tone * click
    return amp * out * 0.45


def mallet_glide(f0, f1, dur=0.35, amp=1.0, decay=0.30, tone=1.0):
    """Same bar, bending from f0 to f1 (a soft 'nope')."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t / decay) * np.clip(t / 0.004, 0, 1)
    out = np.sin(ph) + 0.18 * np.sin(2 * ph) * np.exp(-t / (decay * 0.6))
    return amp * out * env * 0.5


def bell(f, dur=1.0, amp=1.0):
    """Glockenspiel / soft chime."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, a, k in ((1, 1.0, 0.55), (2.0, 0.30, 0.40), (2.76, 0.22, 0.30),
                        (5.4, 0.10, 0.18), (8.93, 0.04, 0.10)):
        out += a * np.exp(-t / (dur * k + 1e-4)) * np.sin(2 * np.pi * f * ratio * t)
    return amp * out * np.clip(t / 0.001, 0, 1) * 0.35


def pluck(f, dur=0.6, amp=1.0, damp=0.9955, bright=0.35):
    """Karplus-Strong: ukulele / nylon-string pluck."""
    n = int(dur * SR)
    size = max(2, int(round(SR / f)))
    buf = rng.uniform(-1, 1, size)
    # Soften the excitation several times: a nylon string, not a snare.
    # Without this the loop keeps a hissy 6-10 kHz edge that a TV speaker
    # turns into an unpleasant fizz.
    for _ in range(6):
        buf = 0.5 * (buf + np.roll(buf, 1))
    out = np.empty(n)
    idx = 0
    for i in range(n):
        cur = buf[idx]
        out[i] = cur
        buf[idx] = damp * (bright * cur + (1 - bright) * buf[(idx + 1) % size])
        idx = (idx + 1) % size
    env = np.exp(-np.arange(n) / SR / (dur * 0.55))
    return amp * out * env * 0.8


def thump(f0=190, f1=95, dur=0.16, amp=1.0):
    """Soft body hit: a fast downward sine sweep."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.clip(t / 0.002, 0, 1) * np.exp(-t / (dur * 0.30))
    return amp * np.sin(ph) * env


def bubble(f0, f1, dur=0.09, amp=1.0):
    """Cartoon water-drop / bloop: rising sine chirp."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.clip(t / 0.003, 0, 1) * np.exp(-t / (dur * 0.55))
    return amp * np.sin(ph) * env


def popnote(f, dur=0.35, amp=1.0, decay=0.42):
    """Rounded synth pluck: sine plus a little odd-harmonic sparkle."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.004, 0, 1) * np.exp(-t / decay)
    out = (np.sin(2 * np.pi * f * t)
           + 0.28 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t / (decay * 0.45))
           + 0.09 * np.sin(2 * np.pi * 5 * f * t) * np.exp(-t / (decay * 0.25)))
    return amp * out * env * 0.55


def whistle(seq, amp=1.0, glide=0.035, vib_hz=5.5, vib_cent=6.0, breath=0.05):
    """Legato sine whistle. seq = [(‘C5’, 0.15), ...] or [(440.0, 0.15), ...]."""
    parts = []
    prev = None
    for note, dur in seq:
        f = hz(note) if isinstance(note, str) else note
        n = int(dur * SR)
        t = np.arange(n) / SR
        freq = np.full(n, f)
        if prev is not None and glide > 0:
            g = max(1, int(min(glide, dur * 0.5) * SR))
            freq[:g] = np.linspace(prev, f, g)
        vib = 1 + (2 ** (vib_cent / 1200) - 1) * np.sin(2 * np.pi * vib_hz * t)
        ph = 2 * np.pi * np.cumsum(freq * vib) / SR
        env = np.clip(t / 0.012, 0, 1)
        parts.append(np.sin(ph) * env)
        prev = f
    sig = np.concatenate(parts)
    sig *= 0.55
    if breath:
        nz = bandnoise(len(sig), 1800, 5200)
        sig += breath * nz / (np.abs(nz).max() + 1e-9)
    last = min(len(sig), int(0.02 * SR))
    sig[-last:] *= np.linspace(1, 0, last)
    return amp * sig


def clap(dur=0.18, amp=1.0):
    """Soft hand clap: three short noise bursts plus a body tone."""
    n = int(dur * SR)
    out = np.zeros(n)
    for k, offset in enumerate((0.0, 0.010, 0.021)):
        m = int(0.05 * SR)
        nz = bandnoise(m, 700, 4200) * np.exp(-np.arange(m) / SR / 0.011)
        i = int(offset * SR)
        out[i:i + m] += (0.9 - 0.22 * k) * nz
    body = thump(220, 130, 0.12, 0.35)
    out[:len(body)] += body
    return amp * out * 0.5


def woodblock(dur=0.06, amp=1.0, f=1150):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = bandnoise(n, 800, 3300) * np.exp(-t / 0.004)
    body = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.007)
    return amp * (0.55 * nz + 0.55 * body)


def shaker(dur=0.07, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = bandnoise(n, 1200, 4200)
    env = np.clip(t / 0.004, 0, 1) * np.exp(-t / 0.013)
    return amp * 0.7 * nz * env


def whoosh(dur=0.45, amp=1.0, lo=250, hi=2600):
    """Noise swell with a moving band, for the dash."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    steps = 6
    for i in range(steps):
        seg = n // steps
        a, b = i * seg, (i + 1) * seg if i < steps - 1 else n
        center = lo * (hi / lo) ** (i / (steps - 1))
        out[a:b] = bandnoise(b - a, center * 0.6, center * 1.5)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return amp * out * env * 0.55


def room(sig, wet=0.10, size=0.22, decay=0.055):
    """Tiny early-reflection sheen so cues sit in the same 'room'."""
    n = int(size * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / decay)
    ir = np.convolve(ir, np.ones(5) / 5, mode="same")  # a room, not a hiss
    ir[: int(0.004 * SR)] = 0
    ir /= np.abs(ir).sum() + 1e-9
    wet_sig = np.convolve(sig, ir)[: len(sig) + n]
    out = np.zeros_like(wet_sig)
    out[: len(sig)] += sig
    out += wet * wet_sig * 8.0
    return out


class Cue:
    def __init__(self, dur):
        self.buf = np.zeros(int(dur * SR))

    def add(self, t0, sig, gain=1.0):
        i0 = int(round(t0 * SR))
        if i0 >= len(self.buf) or i0 < 0:
            return
        n = min(len(sig), len(self.buf) - i0)
        self.buf[i0:i0 + n] += gain * sig[:n]


# --------------------------------------------------------------------------
# palette A — Toy Box (warm mallets: marimba, glockenspiel, woodblock)
# --------------------------------------------------------------------------
def a_success():
    c = Cue(1.30)
    for t, n in ((0.00, "C5"), (0.075, "E5"), (0.150, "G5"), (0.225, "C6")):
        c.add(t, mallet(hz(n), 0.9, 0.9, decay=0.55))
    c.add(0.30, bell(hz("C6"), 0.95, 0.30))
    c.add(0.34, bell(hz("E6"), 0.90, 0.20))
    return room(c.buf)


def a_pickup():
    c = Cue(0.20)
    c.add(0.00, mallet(hz("A5"), 0.24, 0.75, decay=0.11))
    c.add(0.04, mallet(hz("C6"), 0.24, 0.85, decay=0.12))
    return c.buf


def a_snap():
    c = Cue(0.32)
    c.add(0.00, woodblock(0.07, 0.65))
    c.add(0.00, thump(150, 90, 0.07, 0.30))
    c.add(0.005, mallet(hz("C6"), 0.28, 0.45, decay=0.14))
    return c.buf


def a_hit():
    c = Cue(0.30)
    c.add(0.00, thump(210, 110, 0.13, 0.85))
    c.add(0.00, mallet(hz("F3"), 0.22, 0.35, decay=0.10, tone=0.5))
    c.add(0.00, bandnoise(int(0.06 * SR), 180, 900) * np.exp(-np.arange(int(0.06 * SR)) / SR / 0.02) * 0.12)
    return c.buf


def a_error():
    # 0.26 s: pressing A while the dash recharges can repeat ~5/s, so this has
    # to read as a quick "not yet" rather than a phrase.
    c = Cue(0.26)
    c.add(0.00, mallet(hz("G5"), 0.26, 0.70, decay=0.10))
    c.add(0.10, mallet(hz("D5"), 0.26, 0.70, decay=0.12))
    return c.buf


def a_wrong():
    c = Cue(0.38)
    c.add(0.00, mallet_glide(hz("E5"), hz("B4"), 0.26, 0.75, decay=0.15))
    c.add(0.02, thump(140, 85, 0.10, 0.22))
    return c.buf


def a_tick():
    # 1/s for the last 15 s, 15 times in a row: tiny and soft or it grates.
    c = Cue(0.11)
    c.add(0.00, bell(hz("A6"), 0.09, 0.20))
    c.add(0.00, woodblock(0.03, 0.16, f=1500))
    return c.buf


def a_time_up():
    # Must NOT read as a win: the phrase walks down and stops on the 5th,
    # with a soft sigh over it instead of a resolving major chord.
    c = Cue(1.45)
    for t, n in ((0.00, "G5"), (0.16, "E5"), (0.32, "C5")):
        c.add(t, mallet(hz(n), 0.8, 0.85, decay=0.45))
    c.add(0.55, mallet_glide(hz("E5"), hz("C5"), 0.55, 0.30, decay=0.40))
    c.add(0.55, bell(hz("G4"), 0.70, 0.18))
    return room(c.buf)


def a_help():
    c = Cue(0.55)
    for t, n, g in ((0.00, "G5", 0.75), (0.10, "B5", 0.85), (0.22, "G5", 0.60), (0.32, "D6", 0.70)):
        c.add(t, mallet(hz(n), 0.35, g, decay=0.16))
    return c.buf


def a_rumble():
    # The dash lasts 300 ms, so the cue is a 300 ms whoosh with a low body.
    c = Cue(0.36)
    for i in range(6):
        t = i * 0.042
        c.add(t, mallet(hz("C3" if i % 2 == 0 else "G3"), 0.30, 0.40 + 0.05 * i, decay=0.13, tone=0.4))
    c.add(0.0, whoosh(0.30, 0.22, 220, 1100))
    return c.buf


# --------------------------------------------------------------------------
# palette B — Bubble Pop (bright rounded synth plucks, bubbles, slide whistle)
# --------------------------------------------------------------------------
def b_success():
    c = Cue(1.00)
    for i, n in enumerate(("C5", "E5", "G5", "C6")):
        c.add(i * 0.055, popnote(hz(n), 0.45, 0.85))
    c.add(0.26, bell(hz("C6"), 0.60, 0.30))
    c.add(0.29, bell(hz("E6"), 0.55, 0.22))
    return room(c.buf, wet=0.08)


def b_pickup():
    c = Cue(0.16)
    c.add(0.00, bubble(480, 1100, 0.075, 0.9))
    c.add(0.00, bandnoise(int(0.004 * SR), 2000, 7000) * 0.25)
    return c.buf


def b_snap():
    c = Cue(0.24)
    c.add(0.00, bubble(900, 280, 0.070, 0.95))
    c.add(0.00, thump(240, 140, 0.06, 0.35))
    c.add(0.00, bandnoise(int(0.006 * SR), 1500, 6000) * 0.30)
    return c.buf


def b_hit():
    c = Cue(0.30)
    c.add(0.00, thump(220, 95, 0.14, 0.85))
    c.add(0.01, bubble(330, 190, 0.09, 0.25))
    return c.buf


def b_error():
    # Two short "wah" blips, 0.25 s total: fast enough to mash.
    c = Cue(0.25)
    for i, n_name in enumerate(("G4", "E4")):
        f = hz(n_name)
        n_s = int(0.13 * SR)
        t = np.arange(n_s) / SR
        vib = 1 + (2 ** (18 / 1200) - 1) * np.sin(2 * np.pi * 6.5 * t)
        ph = 2 * np.pi * np.cumsum(np.full(n_s, f) * vib) / SR
        env = np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.12)
        c.add(i * 0.12, np.sin(ph) * env * 0.55)
    return c.buf


def b_wrong():
    c = Cue(0.35)
    c.add(0.00, popnote(hz("D5"), 0.24, 0.70, decay=0.14))
    c.add(0.11, bubble(700, 240, 0.11, 0.55))
    c.add(0.00, thump(150, 90, 0.09, 0.18))
    return c.buf


def b_tick():
    c = Cue(0.10)
    c.add(0.00, bubble(1450, 980, 0.045, 0.55))
    return c.buf


def b_time_up():
    # Descending pops, no major resolution: "that's the whistle, not a win".
    c = Cue(1.40)
    n = int(0.40 * SR)
    t = np.arange(n) / SR
    f = 950 * (300 / 950) ** (t / 0.40)
    ph = 2 * np.pi * np.cumsum(f) / SR
    c.add(0.00, np.sin(ph) * np.clip(t / 0.02, 0, 1) * np.exp(-t / 0.45) * 0.45)
    for i, n_name in enumerate(("G5", "E5", "C5")):
        c.add(0.46 + i * 0.12, popnote(hz(n_name), 0.45, 0.62))
    return room(c.buf, wet=0.08)


def b_help():
    # Repeats every 3 s until a teammate joins: a friendly "oi!" not an alarm.
    c = Cue(0.34)
    for i, n_name in enumerate(("G5", "C6")):
        c.add(i * 0.09, popnote(hz(n_name), 0.22, 0.75, decay=0.16))
    c.add(0.19, bubble(700, 1300, 0.06, 0.35))
    return c.buf


def b_rumble():
    c = Cue(0.36)
    c.add(0.00, whoosh(0.30, 0.55, 300, 3000))
    c.add(0.04, thump(160, 80, 0.24, 0.35))
    return c.buf


# --------------------------------------------------------------------------
# palette C — Picnic Band (ukulele, whistle, clap, shaker)
# --------------------------------------------------------------------------
def c_success():
    c = Cue(1.55)
    chord = ("C4", "E4", "G4", "C5")
    for i, n in enumerate(chord):
        c.add(i * 0.014, pluck(hz(n), 1.0, 0.55))
    c.add(0.10, whistle([("C5", 0.12), ("E5", 0.12), ("G5", 0.24)], 0.55))
    c.add(0.52, pluck(hz("C5"), 1.0, 0.65))
    c.add(0.52, pluck(hz("G4"), 1.0, 0.35))
    return room(c.buf, wet=0.10)


def c_pickup():
    c = Cue(0.18)
    c.add(0.00, pluck(hz("A4"), 0.30, 0.75))
    c.add(0.04, woodblock(0.04, 0.35, f=1300))
    return c.buf


def c_snap():
    c = Cue(0.20)
    c.add(0.00, woodblock(0.06, 0.75, f=950))
    c.add(0.005, pluck(hz("C5"), 0.30, 0.55))
    return c.buf


def c_hit():
    c = Cue(0.30)
    c.add(0.00, clap(0.18, 0.85))
    c.add(0.00, thump(170, 100, 0.12, 0.35))
    return c.buf


def c_error():
    c = Cue(0.26)
    c.add(0.00, whistle([("E5", 0.10), ("C5", 0.14)], 0.65))
    c.add(0.02, pluck(hz("C4"), 0.35, 0.30))
    return c.buf


def c_wrong():
    c = Cue(0.36)
    n = int(0.24 * SR)
    t = np.arange(n) / SR
    f = hz("D5") * (hz("A4") / hz("D5")) ** (t / 0.24)
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    # round the buzz off so it reads as a kazoo, not a buzzsaw
    saw = np.convolve(saw, np.ones(7) / 7, mode="same")
    c.add(0.00, saw * np.exp(-t / 0.22) * 0.38)
    c.add(0.00, pluck(hz("A3"), 0.35, 0.40))
    c.add(0.14, woodblock(0.04, 0.30, f=800))
    return c.buf


def c_tick():
    c = Cue(0.09)
    c.add(0.00, shaker(0.05, 0.55))
    return c.buf


def c_time_up():
    c = Cue(1.50)
    for i, n in enumerate(("C4", "E4", "G4")):
        c.add(i * 0.016, pluck(hz(n), 1.1, 0.45))
    c.add(0.08, whistle([("G5", 0.16), ("E5", 0.16), ("C5", 0.30)], 0.55))
    return room(c.buf, wet=0.10)


def c_help():
    c = Cue(0.45)
    c.add(0.00, whistle([("G5", 0.08), ("C6", 0.12), ("G5", 0.10)], 0.60, vib_cent=10))
    return c.buf


def c_rumble():
    c = Cue(0.36)
    for i in range(5):
        c.add(i * 0.038, shaker(0.06, 0.35 + 0.05 * i))
    c.add(0.04, pluck(hz("C3"), 0.30, 0.55, bright=0.25))
    return c.buf


# --------------------------------------------------------------------------
# extras for B — lobby loop, 3-2-1 countdown, player joined
# --------------------------------------------------------------------------
def bassnote(f, dur=1.2, amp=1.0, decay=0.55):
    """Soft synth bass: sine plus a little second harmonic."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.005, 0, 1) * np.exp(-t / decay)
    return amp * (np.sin(2 * np.pi * f * t) + 0.20 * np.sin(4 * np.pi * f * t)) * env * 0.5


def b_countdown():
    """0:00 C5, 0:01 E5, 0:02 G5, 0:03 go (C major bell chord)."""
    c = Cue(4.2)
    for i, n_name in enumerate(("C5", "E5", "G5")):
        t = i * 1.0
        c.add(t, popnote(hz(n_name), 0.35, 0.80, decay=0.11))
        c.add(t, bell(hz(n_name), 0.40, 0.22))
    for n_name in ("C6", "E6", "G6"):
        c.add(3.0, bell(hz(n_name), 1.0, 0.26))
    c.add(3.0, popnote(hz("C6"), 0.9, 0.55, decay=0.35))
    c.add(3.0, bubble(600, 1650, 0.18, 0.30))
    return room(c.buf, wet=0.10)


def b_player_joined():
    """Bright three-bell rise — deliberately higher and longer than `help`."""
    c = Cue(0.80)
    for i, n_name in enumerate(("C6", "E6", "G6")):
        c.add(i * 0.085, bell(hz(n_name), 0.55, 0.28))
    c.add(0.00, popnote(hz("C6"), 0.40, 0.50, decay=0.16))
    c.add(0.26, bubble(950, 1900, 0.10, 0.22))
    return room(c.buf, wet=0.10)


def b_lobby_loop():
    """19.2 s, 100 BPM, eight bars of C - Am - F - G, twice.

    Rendered with 2 s of spare tail, then the tail is folded back over the
    start, so the reverb and released notes carry across the loop point
    instead of being cut. Exactly L samples, no fade in or out.
    """
    bpm = 100.0
    beat = 60.0 / bpm
    bar = 4 * beat
    L = int(round(8 * bar * SR))
    tail = int(2.0 * SR)
    buf = np.zeros(L + tail)

    def put(t, sig, g=1.0):
        i0 = int(round(t * SR))
        if i0 < 0 or i0 >= len(buf):
            return
        n = min(len(sig), len(buf) - i0)
        buf[i0:i0 + n] += g * sig[:n]

    prog = [("C3", ("C4", "E4", "G4")),
            ("A2", ("A3", "C4", "E4")),
            ("F2", ("F3", "A3", "C4")),
            ("G2", ("G3", "B3", "D4"))] * 2

    melody = [
        [(0.0, "E5"), (1.5, "G5"), (3.0, "D5")],
        [(0.0, "C5"), (1.5, "A5"), (3.0, "G5")],
        [(0.0, "F5"), (1.5, "C6"), (3.0, "A5")],
        [(0.0, "G5"), (1.5, "D5"), (3.0, "G5")],
        [(0.0, "E5"), (1.5, "G5"), (3.0, "D5")],
        [(0.0, "C5"), (1.5, "A5"), (3.0, "G5")],
        [(0.0, "F5"), (1.5, "C6"), (3.0, "D6")],
        [(0.0, "C6"), (1.5, "G5"), (3.0, "E5")],
    ]

    for i, (root, chord) in enumerate(prog):
        t0 = i * bar
        put(t0, bassnote(hz(root), 1.6, 0.50, decay=0.75))
        put(t0 + 2 * beat, bassnote(hz(root), 1.2, 0.30, decay=0.60))
        for k in range(8):
            put(t0 + k * beat / 2, popnote(hz(chord[k % 3]), 0.40, 0.075, decay=0.11))
            put(t0 + k * beat / 2, shaker(0.05, 0.10 if k % 2 == 0 else 0.055))
        for off, n_name in melody[i]:
            put(t0 + off * beat, popnote(hz(n_name), 0.55, 0.42, decay=0.20))
        put(t0 + 1.5 * beat, bell(hz(chord[2]) * 2, 0.70, 0.07))

    wet = room(buf, wet=0.10, size=0.35, decay=0.08)
    out = wet[:L].copy()
    rest = wet[L:]
    out[:min(len(rest), L)] += rest[:min(len(rest), L)]
    return out


# --------------------------------------------------------------------------
# palette table
# --------------------------------------------------------------------------
PALETTES = {
    "palette-a-toy-box": {
        "title": "A. Toy Box",
        "dest": "archive/palette-a-toy-box",
        "master": False,
        "cues": {
            "success": (a_success, -17.0),
            "time_up": (a_time_up, -17.0),
            "help": (a_help, -18.0),
            "error": (a_error, -19.0),
            "wrong": (a_wrong, -19.0),
            "snap": (a_snap, -20.0),
            "rumble": (a_rumble, -20.0),
            "pickup": (a_pickup, -21.0),
            "hit": (a_hit, -22.0),
            "tick": (a_tick, -26.0),
        },
    },
    "palette-b-bubble-pop": {
        "title": "B. Bubble Pop",
        "dest": "final/palette-b-bubble-pop-wav",
        "master": True,
        "cues": {
            "success": (b_success, -17.0),
            "time_up": (b_time_up, -17.0),
            "help": (b_help, -18.0),
            "error": (b_error, -19.0),
            "wrong": (b_wrong, -19.0),
            "snap": (b_snap, -20.0),
            "rumble": (b_rumble, -20.0),
            "pickup": (b_pickup, -21.0),
            "hit": (b_hit, -22.0),
            "tick": (b_tick, -26.0),
            "player_joined": (b_player_joined, -18.0),
            "countdown": (b_countdown, -18.0),
            "lobby": (b_lobby_loop, -20.0),
        },
    },
    "palette-c-picnic-band": {
        "title": "C. Picnic Band",
        "dest": "archive/palette-c-picnic-band",
        "master": False,
        "cues": {
            "success": (c_success, -17.0),
            "time_up": (c_time_up, -17.0),
            "help": (c_help, -18.0),
            "error": (c_error, -19.0),
            "wrong": (c_wrong, -19.0),
            "snap": (c_snap, -20.0),
            "rumble": (c_rumble, -20.0),
            "pickup": (c_pickup, -21.0),
            "hit": (c_hit, -22.0),
            "tick": (c_tick, -26.0),
        },
    },
}

TOUR_ORDER = ["pickup", "snap", "tick", "hit", "rumble", "error", "wrong", "help", "success", "time_up"]

# Cues that must loop: no fades, exact length, tail already folded by the builder.
LOOP_CUES = {"lobby"}


def normalise(sig, rms_db, peak_db=-2.0):
    sig = sig - float(np.mean(sig))
    peak = float(np.max(np.abs(sig))) if len(sig) else 0.0
    if peak < 1e-9:
        return sig
    gate = peak * 10 ** (-45 / 20)
    active = np.abs(sig) > gate
    if not np.any(active):
        return sig
    rms = float(np.sqrt(np.mean(sig[active] ** 2)))
    sig = sig * (10 ** (rms_db / 20) / max(rms, 1e-9))
    peak = float(np.max(np.abs(sig)))
    limit = 10 ** (peak_db / 20)
    if peak > limit:
        sig = sig * (limit / peak)
    fade = min(len(sig) // 2, int(0.004 * SR))
    if fade > 0:
        sig[:fade] *= np.linspace(0, 1, fade)
        sig[-fade:] *= np.linspace(1, 0, fade)
    return sig


def highpass(sig, fc=30.0):
    """Remove sub-sonic content (DC, thumps below the TV's range)."""
    n = len(sig)
    spec = np.fft.rfft(sig)
    fr = np.fft.rfftfreq(n, 1 / SR)
    spec *= 1.0 / (1.0 + (fc / np.maximum(fr, 1e-6)) ** 4)
    return np.fft.irfft(spec, n)


def master(sig, rms_db, peak_db=-3.0):
    """Final-delivery pass: HPF, loudness to target, soft-knee peak limit."""
    sig = highpass(sig - float(np.mean(sig)))
    peak = float(np.max(np.abs(sig))) if len(sig) else 0.0
    if peak < 1e-9:
        return sig
    gate = peak * 10 ** (-45 / 20)
    active = np.abs(sig) > gate
    rms = float(np.sqrt(np.mean(sig[active] ** 2)))
    sig = sig * (10 ** (rms_db / 20) / max(rms, 1e-9))

    limit = 10 ** (peak_db / 20)
    knee = limit * 0.7
    over = np.abs(sig) > knee
    if np.any(over):
        mag = np.abs(sig[over])
        sig[over] = np.sign(sig[over]) * (knee + (limit - knee) * np.tanh((mag - knee) / (limit - knee)))

    fade = min(len(sig) // 2, int(0.004 * SR))
    if fade > 0:
        sig[:fade] *= np.linspace(0, 1, fade)
        sig[-fade:] *= np.linspace(1, 0, fade)
    return sig


def finish_loop(sig, rms_db, peak_db=-3.0):
    """master() without the fades: a loop has to join to itself cleanly."""
    sig = highpass(sig - float(np.mean(sig)))
    peak = float(np.max(np.abs(sig))) if len(sig) else 0.0
    if peak < 1e-9:
        return sig
    gate = peak * 10 ** (-45 / 20)
    active = np.abs(sig) > gate
    rms = float(np.sqrt(np.mean(sig[active] ** 2)))
    sig = sig * (10 ** (rms_db / 20) / max(rms, 1e-9))
    limit = 10 ** (peak_db / 20)
    knee = limit * 0.7
    over = np.abs(sig) > knee
    if np.any(over):
        mag = np.abs(sig[over])
        sig[over] = np.sign(sig[over]) * (knee + (limit - knee) * np.tanh((mag - knee) / (limit - knee)))
    return sig


def write_wav(path, sig):
    pcm = (np.clip(sig, -1.0, 1.0) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main():
    rows = []
    tour_dir = os.path.join(OUT, "tours")
    os.makedirs(tour_dir, exist_ok=True)

    for key, spec in PALETTES.items():
        out_dir = os.path.join(OUT, *spec["dest"].split("/"))
        os.makedirs(out_dir, exist_ok=True)
        rendered = {}
        for name, (fn, rms_db) in spec["cues"].items():
            raw = fn()
            if name in LOOP_CUES:
                sig = finish_loop(raw, rms_db)
            elif spec.get("master"):
                sig = master(raw, rms_db)
            else:
                sig = normalise(raw, rms_db)
            rendered[name] = sig
            write_wav(os.path.join(out_dir, f"{name}.wav"), sig)
            rows.append((spec["dest"], name, len(sig) / SR,
                         20 * np.log10(max(float(np.max(np.abs(sig))), 1e-9))))

        # one file that plays the set in the order a player meets it
        head, gap, tail = 0.55, 0.42, 0.5
        total = head + sum(len(rendered[n]) / SR + gap for n in TOUR_ORDER) + tail
        tour = np.zeros(int(total * SR))
        cursor = head
        for name in TOUR_ORDER:
            seg = rendered[name]
            i0 = int(cursor * SR)
            tour[i0:i0 + len(seg)] += seg
            cursor += len(seg) / SR + gap
        tour = normalise(tour, -20.0, peak_db=-1.5)
        write_wav(os.path.join(tour_dir, f"{key}.wav"), tour)
        print(f"{spec['dest']}: {len(spec['cues'])} cues + tour ({total:.2f}s)")

    print("\nfolder / cue / duration s / peak dBFS")
    for folder, name, dur, peak in rows:
        print(f"{folder:30s} {name:9s} {dur:5.2f}  {peak:6.2f}")

    final_dir = os.path.join(OUT, "final", "palette-b-bubble-pop-wav")
    size = sum(os.path.getsize(os.path.join(final_dir, f)) for f in os.listdir(final_dir))
    print(f"\nmasters: {size / 1024:.0f} KB of WAV across {len(os.listdir(final_dir))} files")
    print("encode to Ogg afterwards (see INSTALL.md) — the deliverable folder holds .ogg, not these")


if __name__ == "__main__":
    main()
