# M13 step 10: round music that speeds up as the clock runs out

Job: `docs/briefs/m13/s15-round-music.md`. Gate: the whole step ("stop: after it"). **Status: stopped.**

## Why I stopped

The brief asks for a Dart renderer run with `dart run`, and for the three cues to be encoded with ffmpeg.
This session's tool permissions refuse both, so I could not produce the files the rest of the step hangs on:

- `dart run tools/audio/round_music.dart` → *This command requires approval* (also with the sandbox off).
- `bash tools/audio/render-round-music.sh`, `sh tools/audio/render-round-music.sh` → the same.
- `dart --enable-asserts tools/audio/round_music.dart`, `ffmpeg -version`, `oggenc --version`,
  `flutter --version` → the same.

Allowed here: `ls`, `grep`, `find`, `wc`, `git status` (read only), `dart format`, `dart analyze`,
`dart test`, `tools/check.sh`, `tools/review.sh`. `dart test` is the only way this session can execute Dart
code; using it to run a renderer would just be a way round the `dart run` refusal, so I did not.

Without ffmpeg there is no way to make `assets/audio/round.ogg`, `round_hurry.ogg` or `round_final.ogg`:
Dart has no Vorbis encoder and the repo installs nothing. Without those three files every later piece of the
step is untestable and the `host` check would fail: the three `SoundKey`s must exist (the brief, item 6), and
`sound_keys_test.dart` asserts that each key's file is there. So I stopped before the playback code, the
tests and the docs, rather than leave a red build and a hundred unverifiable lines. The renderer itself is
written: it is the part the brief assigns to this job, it analyzes clean, and it is what the next attempt or
a human needs first.

## What is in the tree

- `tools/audio/pop_kit.dart` (new) — the instruments of the "Bubble Pop" set that the round music needs,
  ported from `render.py` with the same shapes and the same relative levels: `bandnoise` (FFT band mask),
  `mallet`, `popnote`, `bassnote`, `pluck` (Karplus-Strong), `whistle` (glide, vibrato, breath), `clap`,
  `woodblock`, `shaker`, `room` (FFT convolution with the short noise tail), `highpass` at 30 Hz, `finish_loop`
  (RMS over a -45 dB gate, soft-knee peak limit) and `write_wav`. A radix-2 FFT with per-level trig tables
  carries `bandnoise`, `highpass` and the room; `dart:math` has no `tanh`, so `finish_loop` brings its own.
- `tools/audio/round_music.dart` (new) — the score and the loop builder.
  `dart run tools/audio/round_music.dart` writes `round.wav`, `round_hurry.wav` and `round_final.wav` to
  `tools/audio/final/round-wav/` (gitignored by `tools/audio/.gitignore`'s `final/`, so the masters stay out
  of the repository, as `render.py`'s do) and prints each file's tempo, samples, seconds, RMS, peak and seam
  step against the mean sample-to-sample step.
- `tools/audio/render-round-music.sh` (new) — runs the renderer from the repository root, encodes the three
  oggs with the exact ffmpeg line `README.md` documents, and ffprobes them.

**None of it has been run** (see above), so the numbers below are by construction, not measured. A run is
what would confirm them.

## The piece, as the renderer writes it

- Key F major, 16 bars in two parts, so a 90 s round hears it three times without wearing out.
  A (bars 1–8): F | C | Dm | Bb | F | Bb | C | F. B (bars 9–16): Bb | C | F | Dm | Gm | C | Bb | F.
- Bouncing oom-pah bass: `bassnote` on beats 1 and 3 (root, then fifth), `pluck` an octave up on beats 2 and 4.
- Staccato chord stabs on every off-beat (`popnote`, 0.18 s, in A; `mallet`, 0.30 s, in B — the lift at the
  turnaround), voicings F4-A4-C5, E4-G4-C5, D4-F4-A4, D4-F4-Bb4, D4-G4-Bb4.
- A whistle lead, two beats to the bar over the first half of it: a call in A (C5 A4 C5 | E5 C5 | D5 F5 A5 …),
  its higher answer in B (Bb5 A5 G5 | E5 G5 C6 | F5 A5 C6 …), a held F5 closing each part, and bars 4 and 12
  left to the band, which is where it breathes.
- Percussion: `shaker` on every eighth (0.10 on the beat, 0.055 off), a `woodblock` on beats 1 and 3 only —
  never the second beat, which belongs to the round's tick — and a `clap` at the head of bar 8 and bar 16.
- Room: wet 0.10, tail 0.35 s, decay 0.08; two spare seconds of ring-out folded back over the start (as
  `b_lobby_loop` does), then `finish_loop` to RMS −23 dB against the lobby's −20 dB with the peak at −3 dB
  and no fades, so the end runs into the start. Seeds 20261115/16/17, one per tempo, so every run is the same
  audio.
- The levels are `render.py`'s own (bass 0.50, a chord stab 0.075 a note, shaker 0.10/0.055) with the lead at
  0.32, so it should sit like the lobby — but nobody has heard it yet.

| file | sixteenth | tempo | samples | length | RMS | peak |
| --- | --- | --- | --- | --- | --- | --- |
| `round.wav` | 5512 | 120.01 BPM | 1,411,072 | 31.997 s | −23.0 dB | −3.0 dB |
| `round_hurry.wav` | 4793 | 138.01 BPM (1.15×) | 1,227,008 | 27.823 s | −23.0 dB | −3.0 dB |
| `round_final.wav` | 4240 | 156.01 BPM (1.30×) | 1,085,440 | 24.613 s | −23.0 dB | −3.0 dB |

Each is 256 sixteenths (16 bars): `sampleRate / (4 × sixteenth) × 60` BPM and `256 × sixteenth` samples, whole
numbers by construction, which is what makes the loop, and a tempo switch at the same share, exact.

## What the rest of the step still needs

1. Run `tools/audio/render-round-music.sh` where ffmpeg exists, and land the three oggs.
2. `SoundKey` gains `round`, `roundHurry('round_hurry')`, `roundFinal('round_final')`, with CREDITS rows.
3. `SoundPlayer`/`SoLoudSoundPlayer`: `playLoop(name, {at, fade})`, `pauseLoop`, `resumeLoop`,
   `stopLoop({fade})`, `double? get loopShare`; `FakeSoundPlayer` records them without changing `loop`,
   `loopStarts`, `stopped`.
4. One controller with the lobby music (a pure `MusicLoop` wanted-loop decision: none, `lobby`, `round`,
   `round_hurry`, `round_final`; the tempo from `timeLeftMs` and `warningS`, `warningS` 0 meaning no speed-up
   and no clock meaning `round`; a level change moves to the same share with a 120 ms cross-fade; a pause
   pauses, the round's end stops over 300 ms; the frame settle, app-hidden and Mute/Music rules stay the
   lobby's). The round screens report "playing, paused, time left" the way `RoundHold` reports "a round is
   open" — a writer-claimed hold, so a screen on its way out never speaks over its replacement.
   `PuzzlePlayView` needs an `onClock` for the time left; the Arena has no clock, so it stays on `round`.
5. The tests the brief lists, then section 8 of `docs/design/look-and-sound.md` and the README's "how it is
   made" section.

## Checks

- `tools/check.sh format analyze` — PASS, PASS (50 s). Nothing outside `tools/audio` changed, so the other
  suites were not re-run; `dart analyze tools/audio` on its own is clean too.
- `tools/review.sh` — 0 fail, 0 note.
- `dart format` does not cover `tools/` in this repo (the format check runs it on `controller_app
  tv_test_app packages assets`) and its default width is 80, so the two new Dart files are hand-wrapped at
  120 columns like the rest of the repo instead.
- `docs/design/m12-mirror-*.png`: untouched — the puzzle tests were never run.

## Questions

1. May this session run `dart run tools/audio/round_music.dart` and `ffmpeg`? That is all that stands between
   this tree and the rest of the step; the allowlist here has only `dart format`, `dart analyze`, `dart test`,
   `tools/check.sh` and `tools/review.sh`.
2. If they stay refused, should Claude run `tools/audio/render-round-music.sh` and land the three oggs, then
   hand the step back for the playback code and its tests?
3. `pop_kit.dart` and `round_music.dart` have never been executed: review them as unproven. When they run,
   the printed seam step should sit at or under the mean step (the lobby's does), and the RMS/peak columns
   above should come back exactly.

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** No playback code was written, so nothing plays on any host yet; nothing to show.
2. **When kept state starts and ends.** None added.
3. **How a new state combines with the others.** None added.
4. **Stay in the job's folder.** Every edit is inside `allow:`: three new files in `tools/audio` and this
   report. Nothing else in the tree is mine; the three `tv_test_app/windows/flutter/generated_*` files that
   `git status` shows were already modified before the job (Flutter tooling, line endings).
5. **Stop rather than overstep.** Stopped here: the step cannot be finished without two commands this session
   refuses, and carrying on would have meant a red `host` check and unverifiable code.

## Commit message

M13 step 10: a Dart renderer for the round music

tools/audio/pop_kit.dart ports the Bubble Pop instruments the round
music needs from render.py — mallet, popnote, bass, pluck, whistle,
clap, woodblock, shaker, the room and finish_loop, over a radix-2 FFT
— and tools/audio/round_music.dart scores a 16-bar piece in F major
and renders it at 120, 138 and 156 BPM as a whole number of samples
per sixteenth, writing the WAV masters beside itself. The encode
script runs it and makes the three oggs.

Not yet run or encoded: this session can't run dart run or ffmpeg
(approval required). See docs/briefs/m13/s15-round-music-report.md.

## Status row

M13 step 10 (round music): stopped — the Dart renderer and its encode script are written and analyze cleanly, but this session's permissions refuse `dart run` and `ffmpeg`, so there are no WAV masters, no oggs and no playback code; open: allow `dart run`/`ffmpeg`, or land the three oggs from another machine and resume at the playback controller.

## Delete

- none
