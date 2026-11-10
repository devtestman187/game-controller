# M14 s1: the party night's five sounds

Job: `docs/briefs/m14/s1-sounds.md`. Gate: after it. **Status: done, except that none of it could be rendered here.**
`dart run` and `ffmpeg` are refused in this session, exactly as they were for a1 ("write the generator, say so under
'Blocked', and Claude renders"). The generator, its encode script, the five `SoundKey`s, the CREDITS rows, the README
section and the tests are written and analyze cleanly; the five `.ogg` files are missing, so `host` fails on one test
until someone with `dart run` and `ffmpeg` runs `tools/audio/render-party-sounds.sh`. Every length and loudness below is
by construction.

## Files changed

| File | What changed |
| --- | --- |
| `docs/briefs/m14/s1-sounds-report.md` (new) | This report. |
| `tools/audio/party_sounds.dart` (new) | Renders the five cues (`meow`, `points`, `fanfare`, `celebration`, `new_record`): each cue's score, its length and loudness in one table, `masterEvent`, the printed table, and the run's two checks (a part cut off by its cue's end, a cue more than 1 dB under its target). Writes `tools/audio/final/party-wav/*.wav`. 227 lines. |
| `tools/audio/render-party-sounds.sh` (new) | Runs the renderer, encodes the five masters with the README's ffmpeg line, and prints each `.ogg`'s length beside its master's, as `render-arena-sounds.sh` does. |
| `tools/audio/README.md` | A new section, "The party night's five sounds (M14)": what each is for, how it is made and how to render it again. |
| `assets/lib/asset_manifest.dart` | Five `SoundKey`s after the Arena's and before the host's cues: `meow`, `points`, `fanfare`, `celebration`, `newRecord` (`new_record`), with a doc paragraph. |
| `assets/CREDITS.md` | Five rows (one per file), and the Audio paragraph names them after the Arena's. |
| `packages/party_host/test/sound_keys_test.dart` | Two tests: the five spellings both ways, and each of the five files exists at its manifest path (the second fails until the files are rendered). |

`packages/party_host/lib/src/sound.dart` is unchanged: the brief names it for `SoundKey`, but `SoundKey` lives in
`assets/lib/asset_manifest.dart` (which `allow: assets` covers), and the player already loads every key in
`SoundKey.values` without naming any of them. Nothing in `sound.dart` needed a line.

## The five sounds

All mono 44.1 kHz, 16-bit WAV, built from the kit's instruments in `pop_kit.dart`, then mastered exactly as `render.py`
masters a Bubble Pop event: 30 Hz high-pass, RMS to the cue's own target over the −45 dB gate, soft-knee limit at
−3 dB, 4 ms fade in and out. One fixed seed per cue, so every run writes the same samples.

| Cue | Length | Samples | Mastered RMS | How it is made | What it is for |
| --- | --- | --- | --- | --- | --- |
| `meow` | 0.46 s | 20,286 | −20 dB | A rise "me" (two `bubble` chirps 430→880 Hz, one 7 Hz sharp so they beat, plus their 2nd and 3rd harmonics at 0.20 and 0.06) from 0 s, a fall "ow" (880→470 Hz and harmonics) at 0.14 s for 0.28 s, and a 0.02 breath of band noise (900–3.6 kHz) under it | the cat's warning before it swipes a piece (G3): friendly, a voice-like waver, not a whistle |
| `points` | 0.18 s | 7,938 | −23 dB | One `popNote` on A5 (0.16 s, decay 0.075) with a 620→940 Hz `bubble` (0.05 s) on its front: a soft rounded "pwup" | under the "+2" pop-up (G1): 3 dB under `coin`, a step under `coin_appear`, because it plays with every award |
| `fanfare` | 2.00 s | 88,200 | −18 dB | Four `mallet` notes up C major (C5 E5 G5 C6, 110 ms apart), a held C-major chord of long mallets and a C3 `bassNote` from 0.34 s, and four `bell`s shimmering over it (C6 E6 G6 C7) | an award revealed on the night's scoreboard (G4): an announcement, not another reward |
| `celebration` | 2.50 s | 110,250 | −17 dB | Two "ta-da"s: a `clap`, a `thump` and a low root (`bassNote` G2) under a G-major mallet rise at 0 s, then the same under a C-major rise at 1.20 s (bass C3) that ends in four bells (C6 E6 G6 C7) ringing to 2.47 s | a round won, and the night's winner (G4): the set's loudest cue, with the percussion that tells it from `fanfare` |
| `new_record` | 1.50 s | 66,150 | −18 dB | A soft `popNote` on G5, four `bells` up a C-major climb (G6 C7 E7 G7, 70 ms apart), then C7, E7 and G7 ringing 0.85–1.15 s | a new best time on the results card (T15, N14): everything G5 and up and no bass or clap, so it is brighter than `celebration` a step quieter |

How each is told from its neighbours, by pitch shape and timbre rather than loudness alone:

- `meow` vs `help`, `coin` and `countdown`: `help` is three popnotes (G5 C6 G5), `coin` two mallets (G5, D6), the
  countdown beeps; `meow` is the only cue that slides up then down with a voice's harmonics and a waver, and the only
  one whose fundamental is below A4 and above the round music's bass.
- `points` vs `pickup` and `tick`: `pickup` is a 480→1100 Hz bubble with a noise click; `tick` a 1450→980 Hz blip;
  `points` is a pitched popnote body with a small rise under it, and 2 dB under `pickup`. It plays often, so it is
  short and quiet.
- `fanfare` vs `success`: `success` is four popnotes plus two bells over 1.02 s; `fanfare` is struck mallets, a held
  chord, a bass root and bells over 2.0 s, so an award sounds like a ceremony and the round's win like a jingle.
- `celebration` vs `fanfare` and `time_up`: both are C-major; `celebration` has claps, thumps and two bass hits and is
  a fifth longer, and `time_up` falls (low sine, then descending popnotes) where `celebration` rises.
- `new_record` vs `player_joined` and `coin_appear`: both are bells; `player_joined` is C6–E6–G6 for 1.02 s and
  `coin_appear` G6–D7–G7 for 0.30 s; `new_record` climbs G6–C7–E7–G7 and holds C7/E7/G7 for over a second.

**None of this has been heard.** When Claude runs it, the pairs worth a listen are `points` under the pop-up against a
busy round, `meow` against `help`, `fanfare` against `success`, and `celebration` against `fanfare` back to back.
Whether the stacked bubbles really read as a cat is the one thing the numbers cannot say.

## The keys

`SoundKey` gains, after the Arena's ten and before the host's own cues:

| Key | Event name | File |
| --- | --- | --- |
| `SoundKey.meow` | `meow` | `audio/meow.ogg` |
| `SoundKey.points` | `points` | `audio/points.ogg` |
| `SoundKey.fanfare` | `fanfare` | `audio/fanfare.ogg` |
| `SoundKey.celebration` | `celebration` | `audio/celebration.ogg` |
| `SoundKey.newRecord` | `new_record` | `audio/new_record.ogg` |

`soundFiles` builds each path from `eventName`, so the five are looked up with no other change. Nothing plays them yet:
the night's jobs (c2, a3, b1) call them by name.

## The CREDITS rows

| File | Used for | Source | Creator | License |
| --- | --- | --- | --- | --- |
| `audio/meow.ogg` | Party night (M14): the cat's warning before it swipes a piece | `tools/audio/party_sounds.dart` | Project | CC0 1.0 |
| `audio/points.ogg` | Party night (M14): a point won, a soft pop under the pop-up | `tools/audio/party_sounds.dart` | Project | CC0 1.0 |
| `audio/fanfare.ogg` | Party night (M14): an award revealed on the scoreboard | `tools/audio/party_sounds.dart` | Project | CC0 1.0 |
| `audio/celebration.ogg` | Party night (M14): a round won, and the night's winner | `tools/audio/party_sounds.dart` | Project | CC0 1.0 |
| `audio/new_record.ogg` | Puzzle (M14): a new best time on the results card | `tools/audio/party_sounds.dart` | Project | CC0 1.0 |

The Source column reads "Generated for this project with `tools/audio/party_sounds.dart` (synthesis ported from
`render.py`, encoded with ffmpeg; no sampled material)", as the Arena's rows do. The Audio paragraph names the five
after the Arena's files.

## The renderer's own checks

`party_sounds.dart` prints one row per cue (name, length, samples, RMS, peak), as `arena_sounds.dart` does, and exits 1
with a line on stderr if:

- a part ran past its cue's end (the cue's buffer comes from the table's length, so a score can no longer be silently
  cut off), or
- a cue's mastered RMS lands more than 1 dB under its target (the soft-knee limit should only take a few tenths).

Expected on the first run, by construction:

| File | Length | Samples | RMS | Peak |
| --- | --- | --- | --- | --- |
| `meow.wav` | 0.460 s | 20,286 | −20.0 dB | ≤ −3.0 dB |
| `points.wav` | 0.180 s | 7,938 | −23.0 dB | ≤ −3.0 dB |
| `fanfare.wav` | 2.000 s | 88,200 | −18.0 dB | ≤ −3.0 dB |
| `celebration.wav` | 2.500 s | 110,250 | −17.0 dB | ≤ −3.0 dB |
| `new_record.wav` | 1.500 s | 66,150 | −18.0 dB | ≤ −3.0 dB |

## Tests

Written before the keys, and each failed for its own reason:

1. **With the keys absent** (the tests in place, the enum not yet extended): the file failed to compile —
   `test/sound_keys_test.dart:84:25: Error: Member not found: 'meow'.` (and the four others, twice each), host 305
   passed, 1 load failure.
2. **With the keys present and no files**: `the party night's five files are bundled beside their manifest paths`
   failed with `Expected: true / Actual: <false>`; the five-spellings test passed; host 312 passed, 1 failed, 313
   total.
3. **After the render** (Claude): the same run is expected to report 313 passed, 0 failed.

Host test count: 305 before this job, 313 after, because `sound_keys_test.dart` goes from 6 tests to 8. Nothing else in
the host suite changed.

## Checks

- `tools/check.sh format analyze` — PASS, PASS.
- `dart analyze tools/audio` — no issues found (so `party_sounds.dart` compiles against the kit).
- `bash -n tools/audio/render-party-sounds.sh` — OK; the file is LF, as `.gitattributes` wants for `*.sh`.
- `tools/check.sh host` — **FAIL**: 312 passed, 1 failed (the five-file existence test, above). It goes green once
  `tools/audio/render-party-sounds.sh` has been run.
- `tools/review.sh` — 0 fail, 0 note. `tools/review.sh --strings` — 0 removed, 1 added (`'new_record'`).
- Not run (all "requires approval" in this session): `dart run tools/audio/party_sounds.dart`,
  `tools/audio/render-party-sounds.sh`, `ffmpeg`, `ffprobe`.

## Decisions

Low-usage mode: the brief and the design leave these open, so I took the safest fitting choice and list it here.

- **`meow` from stacked `bubble` chirps, no new instrument.** `pop_kit.dart` is already 663 lines (over the hard
  limit); a cat voice is one cue, so it is built from the kit as a1 built the Arena's cues rather than growing the kit.
- **Lengths 0.46, 0.18, 2.00, 2.50, 1.50 s.** The design gives "short" for `meow` and "about 2 s / 2.5 s / 1.5 s" for
  the other three; `points` is one pop, so the length of its decay.
- **Loudness −20 / −23 / −18 / −17 / −18 dB.** The set's scale is `success`/`time_up` −17, `help`/`player_joined` −18,
  `error`/`wrong`/`coin_gold` −19, `snap`/`rumble`/`coin`/`bump_big` −20, `pickup` −21, `hit`/`bump` −22, `dash` −24,
  `coin_appear`/`tick` −26. `celebration` takes the loudest slot because it is the night's biggest moment; `fanfare`
  sits with `help`; `points` is 3 dB under `coin` as the design asks, and above `dash`/`coin_appear` so an award is
  still heard over the round; `new_record` is a step under `celebration` and sounds brighter through its register.
- **The five keys go after the Arena's, before the host's cues.** They are M14's night cues, beside the Arena's M14
  ones, and the host's own cues stay last as their doc paragraph says.
- **The renderer owns each length.** The table's `seconds` makes the cue's buffer, so a score cannot drift from the
  length the design gives; `_Cue` records a part cut off by the end and the run fails on it (arena_sounds.dart's `_Cue`
  cannot see that).
- **The existence test lives in `party_host`.** `assets` has no test folder; the Arena's file test is in the same file,
  added by g3, so the five follow it.

## Questions and suggestions

1. **The five `.ogg` files must be rendered** (as a1's were): `tools/audio/render-party-sounds.sh` writes
   `tools/audio/final/party-wav/*.wav` and the five `assets/audio/*.ogg`. Until then `host` fails on one test and the
   app has no files for the five keys ("no file (silent)" in the sound status). The masters and the folder are
   gitignored; only the `.ogg` files are committed.
2. **`_Cue` is now in two renderers** (`arena_sounds.dart`, `party_sounds.dart`). Suggest a later job moves it to
   `pop_kit.dart` and has both use it, in the same pure move that splits that file.
3. **The Arena's table in the design still says `bump` −21 and `coin` −19**, while the rendered `arena_sounds.dart`
   has −22 and −20 (Claude's trim after listening, a1's review). Not touched here; the design table is not in this
   job's allow list.
4. **`meow` is the one the numbers cannot judge**: if the stacked bubbles sound like a synth rather than a cat, the fix
   is a small pitch-and-formant voice, which would need the `pop_kit.dart` split first.

## Self-check: docs/review-rules.md part A, items 1–5

1. **Every host setup.** No host or screen code changed, and nothing plays the five yet; an older build lacks the keys
   and behaves exactly as today, and a build with a missing file plays nothing (`findSound` returns null →
   "no file (silent)"). Shown by `sound_keys_test.dart`'s two new tests and the existing `game_screen_test.dart`
   ("N of M loaded" counts `SoundKey.values`, so it follows the five).
2. **When kept state starts and ends.** Not affected: no timer, loop, wait, cache or flag is added; the cues are files
   and keys.
3. **How a new state combines with the others.** Not affected: nothing pauses, hides, waits or blocks input.
4. **Stay in the job's folder.** Every changed file is in `allow:` (`docs/briefs/m14/s1-sounds-report.md`,
   `tools/audio/*`, `assets/lib/asset_manifest.dart`, `assets/CREDITS.md`, `packages/party_host/test/…`); no `.ogg`
   written and nothing outside allow touched. Checked with `git status --short`.
5. **Stop rather than overstep.** `dart run` and `ffmpeg` are refused here exactly as the brief warns; I wrote the
   generator and its script and did not route around them through a test or a script of my own.

## Blocked

The render: `dart run`, `ffmpeg` and `ffprobe` all answer "This command requires approval" in this session, so there
are no WAV masters, no `.ogg` files and no measured table. Claude renders with `tools/audio/render-party-sounds.sh`,
listens (see the CREDITS rows and the listening pairs above), and commits the five files; the one failing `host` test
goes green with them.

## Commit message

M14 s1: the party night's five sounds, as a Dart renderer

Adds tools/audio/party_sounds.dart: meow (a stacked-bubble cat's
warning), points (a soft pop under a pop-up), fanfare (an award),
celebration (a won round or the night's winner) and new_record (a
best time), each built from the Bubble Pop kit, mastered to its own
loudness and seeded. render-party-sounds.sh encodes them the README's
way. Five SoundKeys, five CREDITS rows and a README section say what
each is for. Two tests: the spellings, and each file at its path.
The five oggs are not written here: dart run and ffmpeg are refused
in this session, so the file test fails until they are rendered.

## Status row

M14 s1 (the party night's five sounds): done except the rendered files — the generator, the encode script, the five `SoundKey`s, the CREDITS rows, the README section and the two tests are written and format/analyze clean, but this session refuses `dart run` and `ffmpeg`, so no `.ogg` files exist and `host` fails on one test; open: run `tools/audio/render-party-sounds.sh`, listen to the five, and commit the files.

## Delete

- none
