job: M14 a1: the Arena's sounds and round music, in the "Bubble Pop" set (owner, Nov 9, 2026: "For arena ... We need sound effects for the various actions (bumping, dashing, loosing and gaining coins) and new music during the round. Have flash-worker create these based on the current sound design")
pub: no
stop: after it.
read: docs/PRD-v2.md G9 (the Bumper Round: solid marbles, dash to shove, coins, a coin dropped on a hazard or a shove into a wall, gold coins worth 2 in the last 15 s, 60 s, most coins wins) · docs/design/look-and-sound.md section 8 (sound; the round music's decisions at step 10b) · tools/audio/README.md, render.py (the set's sounds: `hit`, `success`, `error`, `rumble`, `snap`, `wrong`, `tick`, `pickup`, `time_up`, `help`, and how each is built), pop_kit.dart (the Dart port of its instruments), round_music.dart and render-round-music.sh (how the round music is made: 16 bars, three tempos, sample-exact loops, RMS −23 dB, peak ≤ −3 dB) · docs/briefs/m13/s15-round-music.md and its report · docs/briefs/m14/research-arena-party-report.md · docs/review-rules.md · docs/coding-guidelines.md

This job makes the sounds only. Playing them (the SoundKeys, CREDITS rows, the Bumper Round's events, the Arena choosing its own music) is part of M14's Bumper Round job, which Claude briefs next. The worker sandbox could not run `dart` or `ffmpeg` last time: write the renderer and its script, and if you can't run them, say so. Claude runs them, listens to the numbers, and commits the files.

Claude's design:

**Sounds** (one-shots, mono 44.1 kHz, the set's instruments and room, mastered as `render.py` masters its event sounds so they sit at the same loudness as `hit` and `pickup`). Each must be told apart from every existing sound and from each other at once, by pitch shape and timbre, not loudness alone (the accessibility rule in section 8):
- `dash` (~0.18 s): a quick rising "fwip": a short band-noise swish sweeping up, with a light pop on its end. It plays on every dash, so it is soft and short and never tiring; quieter than `pickup`.
- `bump` (~0.25 s): two marbles meeting: a rubbery, bouncy "boing-bonk", a `thump` with a short upward pitch wobble and a mallet tick. Friendly, not a crash; clearly different from `hit` (a marble against a wall). Also `bump_big` (~0.35 s): the same with more body and a little spring, for a dash that shoves.
- `coin` (~0.25 s): picking up a coin: a bright two-note rising "plink-plink" (a fifth or an octave apart) on `mallet` / `popNote`, the happiest short sound in the set, but not `success`.
- `coin_gold` (~0.4 s): a gold coin worth 2: the coin's two notes and a third above, with a little shimmer, so it sounds worth more.
- `coin_lost` (~0.4 s): dropping a coin: a falling "plonk-plink" with a small wobble, playful, a "whoops", never sad or harsh (children around 8). Different from `wrong` and `error`.
- `coin_appear` (~0.3 s): a soft twinkle as a new coin starts its 1 s sparkle; quiet, since three coins come and go all round.

**Music**: `arena`, `arena_hurry`, `arena_final`, one 16-bar piece at three tempos, made like the round music (same key in all three, whole samples per sixteenth, seamless, RMS −23 dB, peak ≤ −3 dB), but clearly its own tune so a player knows from the first bar which game is on:
- Mood: a bouncy bumper-car funfair, a little more energetic than Shape Race's round: a different key (G major or B♭ major, not the lobby's C or the round's F), a driving toy beat (kick on every beat with `thump`, `clap` on 2 and 4, `shaker` sixteenths), a walking or octave-jumping bass, a short cheeky lead with call and response (`whistle` or `popNote`), mallet stabs. An A part and a B part, so 60 s doesn't wear it out.
- Tempos: 128 BPM, then ×1.15 (≈147) and ×1.3 (≈166), so the Bumper Round can speed up at 15 s and 5 s left as Shape Race does.
- Leave room for the game's sounds: no busy high mallet where `coin` and `bump` sit, no loud hit on the beat where `tick` lands.

**Tools**: `tools/audio/arena_sounds.dart` (or two files, as the limits need) renders all nine WAV masters into `tools/audio/final/arena-wav/`, outside the repo like the others, deterministic (fixed seeds). When it runs it prints, for each file, its length, peak and RMS, and for each loop the size of the jump between its last and first sample, and it fails if a loop isn't exactly 16 bars or peaks above −3 dB. `tools/audio/render-arena-sounds.sh` renders and encodes to `assets/audio/*.ogg` exactly as tools/audio/README.md says, and prints each file's length against its master. Add what the kit needs to `pop_kit.dart`, but the round music must render **exactly** as now: change no existing function's output. README.md: how the Arena's sounds are made and made again. Design section 8: a short "The Arena's sounds and music (M14)" part with the list above and what each is for.

tests: none run in the checks for tools/audio; the renderer's own checks above stand in for them. `tools/check.sh format analyze` must pass over the new Dart files.
in the report: the files changed; for each sound how it is built (instruments, notes, length) and what tells it apart from its neighbours; the music's key, chords, form and tempos; if you ran it, the renderer's printed table.
self-check: docs/review-rules.md part A, items 4 and 5, one line each.
rules: no file over 400 lines · no function over 60 lines · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing (no numpy, no new packages) · don't touch packages/, assets/CREDITS.md or the existing .ogg files.
allow: docs/briefs/m14/a1-arena-sounds-report.md · docs/design/look-and-sound.md · tools/audio/arena_sounds.dart · tools/audio/arena_music.dart · tools/audio/render-arena-sounds.sh · tools/audio/pop_kit.dart · tools/audio/README.md · assets/audio/dash.ogg · assets/audio/bump.ogg · assets/audio/bump_big.ogg · assets/audio/coin.ogg · assets/audio/coin_gold.ogg · assets/audio/coin_lost.ogg · assets/audio/coin_appear.ogg · assets/audio/arena.ogg · assets/audio/arena_hurry.ogg · assets/audio/arena_final.ogg
check: format analyze
report: docs/briefs/m14/a1-arena-sounds-report.md
