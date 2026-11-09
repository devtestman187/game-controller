job: M13 10: round music that speeds up as the clock runs out (owner, Nov 9, 2026: "Yes I want music during rounds. ... design music that sounds playful and fun. As the timer gets closer to running out the music's tempo should speed up. Think about how games like Mario party and Lego party work. Leverage the research done earlier.")
pub: no
stop: after it.
read: docs/design/look-and-sound.md section 8 (sound) · tools/audio/README.md and tools/audio/render.py (the "Bubble Pop" set: `popnote`, `mallet`, `pluck`, `whistle`, `bassnote`, `woodblock`, `shaker`, `clap`, `room`, `b_lobby_loop`, `finish_loop`, `master`) · the earlier audio research, read-only, in C:\Users\mrman\Documents\deepseek-harness\default-workspace\thumb-party-audio (PROPOSAL.md, README.md) · docs/briefs/m14/research-party-games-report.md and research-party-design-report.md (Mario Party, Lego Party; sound accessibility) · packages/party_host/lib/src/sound.dart, sound_wish.dart, sound_settings.dart, ui/lobby_music.dart, ui/lobby_music_widgets.dart, ui/round_palette_hold.dart, providers.dart · the round screens (PuzzleScreen, GameScreen, the pause menu's 3-2-1) · assets/lib/asset_manifest.dart, assets/CREDITS.md · docs/review-rules.md · docs/coding-guidelines.md

Claude's design:

**The music (three files, one piece).** `assets/audio/round.ogg`, `round_hurry.ogg` and `round_final.ogg`: the same seamless loop at three tempos, in the same key, so speeding up never raises the pitch.
- Mood: playful, bouncy and a little cheeky, like a party-game minigame: a major key (F major, so it isn't the lobby's C), a bouncing "oom-pah" bass (`bassnote` / `pluck` on the beats, octave jumps), staccato `popnote` / `mallet` chords on the off-beats, a short, hummable `whistle` lead with call and response, and light `woodblock`, `shaker` and `clap` percussion. Sixteen bars: an A part (8 bars) and a B part (8 bars), so it doesn't wear out in a 90 s round.
- It must differ from the lobby loop (the accessibility research: each cue distinct), and sit under the game's sounds: master it about 3 dB quieter than the lobby (RMS −23 dB against the lobby's −20 dB), leave room for the tick (no busy woodblock on the second beat), and peak no higher than −3 dB.
- Tempos: 120 BPM, then about 1.15× (≈138) and about 1.3× (≈156). Use a whole number of samples per sixteenth (44.1 kHz) so each loop is sample-exact; each file is exactly 16 bars long at its tempo. The loop's end must run into its start without a click (as `finish_loop` does).
- **No new installs**: numpy isn't on this PC. Write the renderer in Dart, `tools/audio/round_music.dart`, run with `dart run`. Port the instruments it needs from `render.py`, as faithfully as you can, so it sounds like the same set. It writes WAV masters next to itself (not in the repo, like `render.py`'s), and the oggs are encoded with ffmpeg exactly as tools/audio/README.md says. Deterministic: the same files every run (fixed seeds for noise).
- tools/audio/README.md: say how the round music is made and re-made.

**Playing it (host only, like the lobby music).**
1. The round music plays on the device that plays the lobby music (the TV or PC, or a host phone with no TV); joined phones never play it.
2. It starts at the round's "go" (after the 3-2-1, or when the round starts playing where there's no countdown), on Shape Race and the Arena. It stops when the round ends (results, time up, finished) with a short fade (300 ms), so `time_up` and `success` are heard clearly. While the pause menu or the host-away card is up it pauses, and resumes where it was.
3. **The speed-up** follows the clock, for a round that has one (Shape Race; the Arena has no clock, so it stays at the first tempo):
   - more than `warningS` left (the puzzle setting, 15 s by default): `round`;
   - `warningS` or less: `round_hurry`;
   - `warningS / 3` or less (5 s by default): `round_final`.
   - With `warningS` 0 there is no speed-up.
   - A change switches at the same place in the music: the new loop starts at the same share of its length as the old one has reached, and the two cross-fade over 120 ms, so it sounds like the band speeding up, not a new song.
4. It obeys Mute and the Music volume exactly like the lobby music (Music at 0% doesn't play it; a volume change reaches it as it plays). The lobby music and the round music never play together: a round still stops the lobby music when its screen opens, as now.
5. Keep it in one place with the lobby music, sharing its settle-after-the-frame and app-hidden rules: e.g. one music controller that decides which loop is wanted (none, `lobby`, `round`, `round_hurry`, `round_final`). The round screens tell it what they are doing (playing, paused, the time left) in the way `RoundHold` already tells it a round is open. Your call on the names; follow the file and function limits.
6. `SoundKey` gains the three keys, with CREDITS rows like the other cues (generated for this project, CC0).
7. Design section 8: add the round music (owner, Nov 9), these rules and the tempos.

tests (each failing first):
- The wanted loop: none in the lobby before a round; `round` at "go"; `round_hurry` at `warningS`; `round_final` at `warningS / 3`; none after the round ends; paused while paused; none on a joined phone; none with Music at 0%; muted with Mute.
- Changing tempo keeps the place: from `round` at 40% of its length, `round_hurry` starts at 40% of its own, cross-faded (a fake player records the calls).
- The Arena's round plays `round` and never speeds up.
- The lobby music still behaves as its existing tests say.
- The three oggs exist and are in the manifest; their lengths are 16 bars at their tempos to the millisecond (a test in the assets or host package that reads the ogg headers, or a check the renderer prints and your report quotes).
- All existing tests pass (format analyze look puzzle arena host phone tv kit).

in the report:
- the piece: key, chords, the A and B parts, instruments, tempos, the exact lengths and RMS/peak of each file;
- a short note, from the research you read, on how party games use music under minigames and when time runs out, and what you took from it;
- test counts before and after; the files changed;
- what a player hears, from the lobby to the results.
self-check: docs/review-rules.md part A, items 1–5, one line each with the test that shows it.
rules: no lib file over 400 · no function over 60 lines · tests first, each failing for the missing behaviour · tools/review.sh: no FAIL on your lines · write only inside this job's folder · install nothing (no pip, no new packages) · the puzzle tests rewrite docs/design/m12-mirror-*.png: restore them with `git checkout -- docs/design/m12-mirror-*.png` before you finish.
allow: docs/briefs/m13/s15-round-music-report.md · docs/design/look-and-sound.md · tools/audio · assets · packages/party_host · packages/puzzle_game · packages/test_game · tv_test_app/lib · controller_app/lib · controller_app/test · tv_test_app/test
check: format analyze look puzzle arena host phone tv kit
report: docs/briefs/m13/s15-round-music-report.md
