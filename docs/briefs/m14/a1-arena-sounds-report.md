# M14 a1: the Arena's sounds and round music (assets only)

Job: `docs/briefs/m14/a1-arena-sounds.md`. Gate: after it. **Status: done, except that none of it could be rendered or encoded here.**

`dart run` and `ffmpeg` are refused in this session (as the brief expected: "write the renderer and its script, and if you can't run them, say so"). `dart analyze tools/audio` is allowed and clean, so the two renderers compile; `dart run tools/audio/arena_sounds.dart` reports *This command requires approval*, and `ffmpeg -version` the same. So there are no WAV masters, no `.ogg` files and no measured table: every number below is by construction, and the ten `assets/audio/*.ogg` files are the ones Claude has to make by running the script.

## Files changed

| File | What it does |
| --- | --- |
| `tools/audio/arena_sounds.dart` (new) | Renders the seven one-shots: the score of each cue, its loudness, its seed, `masterEvent`, and the printed table. Writes `tools/audio/final/arena-wav/*.wav`. |
| `tools/audio/arena_music.dart` (new) | Renders `arena`, `arena_hurry` and `arena_final`: the 16-bar G-major score, the three tempos, the loop builder, the checks (16 bars, peak ≤ −3 dB) and the seam measurement. Writes into the same `final/arena-wav/`. |
| `tools/audio/render-arena-sounds.sh` (new) | Runs both renderers, then encodes the ten masters with the README's ffmpeg line and prints each `.ogg`'s length beside its master's. |
| `tools/audio/pop_kit.dart` | Adds the rest of `render.py`'s primitives that the Arena needs — `malletGlide`, `bell`, `bubble`, `swish` — the event mastering `masterEvent`, the measuring helpers `rmsDb`/`peakDb`, and `scriptDir()`. No existing function changed, so the round music renders exactly as before. |
| `tools/audio/README.md` | A new section: how the Arena's seven cues and three loops are made and made again. |
| `docs/design/look-and-sound.md` | Section 8 gains "The Arena's sounds and music (M14)": the cue table and the music's key, form and tempos. |
| `assets/audio/*.ogg` (ten, in `allow:`) | **Not written**: `ffmpeg` cannot run here. `dash`, `bump`, `bump_big`, `coin`, `coin_gold`, `coin_lost`, `coin_appear`, `arena`, `arena_hurry`, `arena_final` are what the script writes. |

The brief says the renderer makes "all nine WAV masters", but the seven one-shots plus the three loops are ten, and the `allow:` list names ten `.ogg` files. I rendered all ten and note the miscount here rather than pick a side.

The renderer is two files because of the 400-line limit: `arena_sounds.dart` (173 lines) holds the one-shots, `arena_music.dart` (255 lines) the score and the loops, and both write into `final/arena-wav/` so the one encode script finds every master in one folder.

## The seven one-shots

All mono 44.1 kHz, 16-bit WAV, built from the kit's instruments, then mastered exactly as `render.py` masters a Bubble Pop event: 30 Hz high-pass, RMS to the cue's own target over the −45 dB gate, soft-knee limit at −3 dB, 4 ms fade in and out. Fixed seed per cue, so every run writes the same samples. The target loudness is the same scale `render.py` uses (`hit` −22, `pickup` −21, `snap`/`rumble` −20, `success` −17).

| Cue | Mastered RMS | Length | How it is built |
| --- | --- | --- | --- |
| `dash` | −24 dB (quieter than `pickup`, as the brief asks) | 0.18 s, 7,938 samples | `swish` from 700 Hz to 4.8 kHz over 0.15 s (six noise bands under a sine swell), then a `bubble` 1000→1700 Hz, 0.05 s, at 0.10 s: the rising "fwip" with a light pop on its end. |
| `bump` | −21 dB | 0.25 s, 11,025 samples | `thump` 200→105 Hz (0.14 s) for the body, a `malletGlide` 190→330 Hz (0.20 s, decay 0.085) for the rubbery upward wobble, and a `mallet` on C5 (0.10 s, tone 0.7) as the tick of the shells. |
| `bump_big` | −19 dB | 0.35 s, 15,435 samples | The same recipe with more body and a spring: `thump` 215→80 Hz (0.22 s), `malletGlide` 140→300 Hz (0.28 s), `mallet` F4 (0.12 s), and a `bubble` 240→520 Hz (0.14 s) at 0.10 s for the rebound. |
| `coin` | −19 dB | 0.25 s, 11,025 samples | Two `mallet` notes a fifth apart: G5 at 0 s and D6 at 0.07 s, both 0.22–0.24 s, tone 0.9 (bright partials). The "plink-plink". |
| `coin_gold` | −18 dB | 0.40 s, 17,640 samples | A four-note G-major rise on the `mallet` 55 ms apart — G5, B5, D6, G6 (the coin's G5 and D6 inside it) — plus two `bell`s shimmering over it: G6 at 0.165 s (0.30 s) and D7 at 0.22 s (0.25 s). |
| `coin_lost` | −20 dB | 0.40 s, 17,640 samples | A small `mallet` tap on A4 (0.07 s), a `malletGlide` falling E5→B4 (0.18 s) as the "plonk", a `thump` 170→110 Hz (0.07 s), then two `bubble`s at 0.12 s — 500→330 Hz and 506→334 Hz — whose 6 Hz beat is the wobble that makes it a "whoops". |
| `coin_appear` | −26 dB (the quietest, with `tick`) | 0.30 s, 13,230 samples | A 30 ms band of noise (3–8 kHz, 8 ms decay) as a breath of sparkle, then `bell`s on G6 (0.26 s), D7 at 0.055 s and G7 at 0.11 s (quiet, 0.06). |

How each is told apart, by pitch shape and timbre and not loudness:

- `dash` is the only cue that is mostly band noise; its nearest neighbour is `rumble`, which is today's dash sound: `rumble` is 0.36 s, 4 dB louder, starts much lower (300 Hz) and carries a 0.24 s low thump, while `dash` is half as long, 700 Hz–4.8 kHz, has no body and ends on a pitched pop. `pickup` also rises but is a sine chirp with a noise click and no sweep.
- `bump` versus `hit`: `hit` is a dark downward thump plus a falling bubble. `bump` keeps the thump but adds an upward glide and a bright mallet tick, so the meeting goes *up* and the wall goes *down*. `bump_big` is a tone lower, half again as long and has the spring bounce, so a shove is heard through `bump`s.
- `coin` versus `success`, `help` and `pickup`: `success` is four popNotes plus two bells over 1 s, `help` is two popNotes a fourth apart plus a bubble, `pickup` a single chirp. `coin` is two *mallets* a fifth apart in 0.25 s — a timbre (struck bar) and an interval (fifth) no other cue uses.
- `coin_gold` versus `coin`: the same mallet timbre four notes long with bell shimmer, so the difference is length, note count and air, not just level.
- `coin_lost` versus `wrong` and `error`: `wrong` is a popNote plus a large falling bubble (700→240 Hz) over a thump; `error` is two vibrato "wah" blips, both mid and both *statements*. `coin_lost` falls in the mallet (a struck bar bending down), stays low and wobbles; no minor third, no buzz.
- `coin_appear` versus `player_joined`: both are bells, but `coin_appear` is G6–D7–G7 (two fifths), 0.30 s and 8 dB quieter, while `player_joined` is C6–E6–G6, 1.02 s and mid.

## The music

One piece, 16 bars, two parts of 8, **G major** (the lobby is C major, the Shape Race round F major), rendered at three tempos with the same score:

| File | Samples per sixteenth | Tempo | Samples | Length |
| --- | --- | --- | --- | --- |
| `arena` | 5168 | 127.999 BPM | 1,323,008 | 29.999 s |
| `arena_hurry` | 4494 | 147.196 BPM (×1.1500) | 1,150,464 | 26.088 s |
| `arena_final` | 3975 | 166.415 BPM (×1.3001) | 1,017,600 | 23.075 s |

Each tempo is a whole number of samples per sixteenth, so every file is exactly 256 sixteenths and the loop is sample-exact. Mastered as the round music is: `finishLoop` to RMS −23 dB with the peak under −3 dB, no fades, 2 s of ring-out past the last bar folded back over the start (so the seam carries the reverb), one fixed seed per tempo.

- **Chords.** A (1–8): G | D | Em | C | G | C | D | G. B (9–16): C | D | Em | Am | C | D | G | D — the last bar turns round on the dominant so the loop falls back into G.
- **Beat.** A soft `thump` kick (120→70 Hz, 0.09 s) on every beat; `clap` on beats 2 and 4; `shaker` on every sixteenth, with the sixteenth on the beat loudest (0.060 / 0.032 / 0.048 / 0.032); a `clap` on the head of bars 8 and 16.
- **Bass.** Octave-jumping and slightly walking: `bassNote` on each beat (the root on 1–3, the fifth on 4, walking back to the root), a plucked octave `pluck` on every off-beat.
- **Chords' backbeat.** `mallet` stabs on every off-beat, three notes (D4–D5 voicings): short and quiet in A (0.20 s, 0.055 a note), longer and fuller in B (0.26 s, 0.085), which is where the piece lifts.
- **Lead.** A popnote *call* over the first two beats of a bar in A (B4 D5 B4 | A4 D5 F#5 | B4 E5 G5 | — rest | D5 B4 G4 | E5 G5 E5 | F#5 A5 | G5), and in B a whistle *answer* a little higher (G4 E5 G5 | A4 F#5 A5 | B4 G5 E5 | A4 E5 C5 | E5 G5 C6 G5 | A5 F#5 | G5 | F#5 A5). Bar 4 is left to the band.
- **Room for the game's sounds.** The stabs stay between D4 and D5, well under `coin`'s G5/D6 and over `bump`'s thump; nothing bright lands on a beat (where `tick` sits); the kick is under 120 Hz; and the whole piece is 3 dB under the lobby, as the round music is.

**None of this has been heard.** The things to listen for when Claude runs it: `bump` against `hit` in the same bar, `coin` against a busy lead bar, `dash` against `rumble`, and whether the shaker at 128 BPM tires in a 60 s round.

## What the renderer prints

`arena_sounds.dart` prints one row per cue (name, length, samples, RMS, peak); `arena_music.dart` prints, per loop, the path, tempo, samples, seconds, RMS, peak, the size of the jump between the last and the first sample, and that against the mean sample-to-sample step. It also fails (exit 1) if a loop is not exactly 16 bars (checked against `_bars`, independently of the score's length) or peaks above −3 dB, and says on stderr why.

Expected on the first run, by construction:

| File | Length | RMS | Peak |
| --- | --- | --- | --- |
| `dash.wav` | 0.180 s | −24.0 dB | ≤ −3.0 dB |
| `bump.wav` | 0.250 s | −21.0 dB | ≤ −3.0 dB |
| `bump_big.wav` | 0.350 s | −19.0 dB | ≤ −3.0 dB |
| `coin.wav` | 0.250 s | −19.0 dB | ≤ −3.0 dB |
| `coin_gold.wav` | 0.400 s | −18.0 dB | ≤ −3.0 dB |
| `coin_lost.wav` | 0.400 s | −20.0 dB | ≤ −3.0 dB |
| `coin_appear.wav` | 0.300 s | −26.0 dB | ≤ −3.0 dB |
| `arena.wav` | 29.999 s | −23.0 dB | ≤ −3.0 dB |
| `arena_hurry.wav` | 26.088 s | −23.0 dB | ≤ −3.0 dB |
| `arena_final.wav` | 23.075 s | −23.0 dB | ≤ −3.0 dB |

The RMS figures are the targets; the soft-knee limit can only take a little off them, so they may print a few tenths under. The seam is unknown until it runs; on the round music it came out under the mean step.

## Checks

- `tools/check.sh format analyze` — PASS, PASS (13 s). `format` does not cover `tools/`, so the new Dart is hand-wrapped at 120 columns (no line over 120).
- `dart analyze tools/audio` — no issues found (so both renderers compile against the extended kit).
- `tools/review.sh` — 0 fail, 0 note.
- `bash -n tools/audio/render-arena-sounds.sh` — OK; the file is LF, as `.gitattributes` wants for `*.sh`.
- Not run: `dart run tools/audio/arena_sounds.dart`, `dart run tools/audio/arena_music.dart`, `tools/audio/render-arena-sounds.sh`, `ffmpeg`, `ffprobe` (all "requires approval").

## Self-check: docs/review-rules.md part A, items 4 and 5

4. **Stay in the job's folder.** Every changed file is in `allow:` — this report, `docs/design/look-and-sound.md`, four files in `tools/audio/`; no `.ogg` written; nothing else in the tree touched.
5. **Stop rather than overstep.** The renderers and their script are written and analyze clean, and the two commands the brief names (`dart run`, `ffmpeg`) are refused here exactly as the brief warns; I did not route around them through `dart test` or a script.

## Questions and suggestions

1. **Ten, not nine.** The brief says "all nine WAV masters" and lists seven cues plus three music files; I rendered ten (the `allow:` list has ten `.ogg` files). Confirm that is what was meant.
2. **`pop_kit.dart` is 663 lines**, over the guidelines' 400-line hard limit. It was already 536 before this job (s15), and the brief asked for the additions to go here, so I followed it. Suggest a later job splits it, e.g. instruments in `pop_kit.dart` and mastering/IO in a second file.
3. **`dash` and `rumble`.** Today a dash plays `rumble` (`packages/test_game` raises `HapticEvent.rumble` for a dash and the host maps it to the `rumble` cue). The Bumper Round job will decide which of the two a dash plays; `dash` is built to be the better fit (shorter, softer, higher) while leaving `rumble` as it is.
4. **Listening order for Claude.** Run `tools/audio/render-arena-sounds.sh`, then listen to the set in this order: `dash`, `bump`, `bump_big`, `hit`, `coin`, `coin_gold`, `coin_lost`, `coin_appear`, `success`, `help`, `pickup` (the neighbours each must be told from), then `arena` twice in a row (the seam) and the three tempos back to back at the same point.
5. **The music's tempo values** are 128.00, 147.20 and 166.42 BPM rather than exactly ×1.15 and ×1.3, because a tempo is chosen as a whole number of samples per sixteenth; the round music made the same trade (120.01, 138.01, 156.01).

## Commit message

M14 a1: the Arena's seven sounds and three loops, as Dart

tools/audio/arena_sounds.dart renders dash, bump, bump_big and the
four coin cues; arena_music.dart scores one 16-bar G-major piece at
128, 147.2 and 166.4 BPM; render-arena-sounds.sh encodes ten
masters the README's way. pop_kit.dart gains the rest of render.py's
primitives, event mastering and two measuring helpers, with no
existing function changed, so the round music renders as before.
Design section 8 and the README say what each cue is for. No masters
or oggs yet: dart run and ffmpeg are refused here.

## Status row

M14 a1 (the Arena's sounds and music): done except the files — the two Dart renderers, the encode script, the README and design section 8 are written and analyze cleanly, but this session's permissions refuse `dart run` and `ffmpeg`, so no WAV masters and no oggs exist yet; open: run `tools/audio/render-arena-sounds.sh` where both are allowed, listen, and commit the ten files.

## Delete

- none

## Claude's review

Accepted. Claude rendered and encoded it (`tools/audio/render-arena-sounds.sh`): ten oggs, each its master's length to the microsecond, loop seams in line with the round music's (seam step ≈ 2× the mean step). The round music re-rendered byte-identical to before this job (sha256 of all three masters), so `pop_kit.dart`'s additions changed nothing existing.
- Levels trimmed one step to sit with their nearest neighbours in `render.py`'s scale: `bump` −22 (as `hit`), `bump_big` −20, `coin` −20 (as `snap`, the Shape Race "good drop"), `coin_gold` −19. Coins are the round's most frequent sound; ffmpeg measured the first `coin` 5 dB over `pickup`.
- Q1: ten is right; the brief's "nine" was a miscount.
- Q2: `pop_kit.dart` at 663 lines goes into the end-of-M13 review's list: split instruments from mastering and file IO.
- Q3: the Bumper Round job plays `dash` for a dash; `rumble` stays for whatever else uses it.
- Not yet heard by a person: the owner listens to the oggs before the Bumper Round job wires them.
