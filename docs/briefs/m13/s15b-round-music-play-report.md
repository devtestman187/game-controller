# M13 10b: the round music plays, and speeds up as the clock runs out

Status: **done**, one deviation from the brief's "existing lobby tests unchanged" (question 1).

## What a player hears

- **The lobby.** The picker's loop (`lobby`) starts as the picker opens and carries on unbroken through the Shape
  Race list and the join screen, as before. Nothing of the round's music plays yet.
- **The round's "go".** The moment the round is playing — after the 3-2-1 on a host that asks for a beat, at once on
  the TV — the lobby's loop stops and `round` starts from its top. On a phone host that has the beat, the 3-2-1 is
  the only sound, then the music.
- **The clock runs out.** At `warningS` left on Shape Race's clock (15 s by default) the music switches to
  `round_hurry`, keeping its place: the new loop starts at the share of its own length the old one had reached, and
  the two cross-fade over 120 ms, so it sounds like the band speeding up on the same tune. At `warningS / 3` (5 s) it
  switches again to `round_final`, the same way. A round whose `warningS` is 0, or that has no clock (the Arena),
  stays on `round`.
- **A pause, the host away, a phone the round waits for.** The music pauses where it is and resumes there; nothing
  restarts. (The pause menu, the away card and the beat all show up as `RoundPhase.none`/`ready`, which is where the
  controller pauses.)
- **The results.** The music fades out over 300 ms as the results come up, so `time_up` or `success` is heard over
  it rather than under a cut. Silence then, on the results.
- **Play again.** The new round's screen opens in one frame: the old round's music has already gone, the new one
  starts at its own "go" (after its own 3-2-1), and the lobby music is never stopped or started in between.
- **Change teams / Back to the picker.** The round's loop stops with the round and the lobby's starts again, once.
- **Music at 0%** stops whichever music plays and nothing starts until it is turned up; **Mute** leaves the music
  playing and silences it through the volume, as it does the lobby's.
- **A joined phone** plays no music at all, before a round, during one, or after.

## How it works

- **One controller for both.** `HostMusic` (in `ui/lobby_music.dart`, the file the lobby music already lived in;
  the provider keeps its step-7 name `lobbyMusicProvider`) decides which loop is wanted: none, `lobby`, `round`,
  `round_hurry`, `round_final`. It keeps the lobby music's settle-after-the-frame rule, its hidden-app stop, its
  Music-volume and Mute handling, and its disposal.
- **The round's open/close** is still `RoundHold` (`openRound`/`closeRound`), exactly as before.
- **The round's "go", pause and results** come from `roundPhaseProvider` (`RoundPhase.playing` is playing; `ready`
  and `none` are standing still), which `Pausable` already publishes — no new signal. The results cannot be told from
  the phase alone (the phase is `none` there too), so the round's screen says so: `PuzzleScreen` calls
  `roundEnded(this)` as the results come, and the controller fades the round's loop over 300 ms instead of pausing it.
- **The clock** comes from the round's screen: `PuzzlePlayView` gained `onClock(int timeLeftMs, int warningS)`, called
  once a frame from the game's own state (no snapshot built for it), with `warningS` from the round's settings. The
  time left is the **smallest** of the sides' clocks — in a race that is the clock that will end the round (question
  2). `PuzzleScreen` passes it to `roundScreenClock`, which switches the loop only when the tempo changes, so a
  per-frame call costs a comparison, not a call to the player.
- **Who speaks for a round.** The controller holds one `_roundWriter`: a screen claims it in `initState` and speaks
  through it, and a screen on its way out (Play again) can't speak over its replacement, the same rule
  `RoundPhaseSignal` uses. `roundScreenClosed` releases it.
- **The tempos** are `MusicLoop.forRound` (new file `music_loop.dart`, one public enum):
  - no clock (the Arena) or `warningS` 0 → `round`;
  - more than `warningS * 1000` ms left → `round`;
  - `warningS * 1000` or less → `round_hurry`;
  - `warningS * 1000 / 3` or less → `round_final`.
- **The player** grew the calls the switch needs: `playLoop(name, {at, fade})`, `pauseLoop`, `resumeLoop`,
  `stopLoop({fade})` and `loopShare`. The engine side is a new `SoundLoop` (`sound_loop.dart`) that owns the one
  voice: it starts a loop at a share (seeking), fades in and out, cross-fades (a second voice fading while the old
  one fades out, the old one stopped by a timer it owns), pauses and resumes, and reads the share for the next
  switch. Unpausing before a results fade so the fade is heard is part of it.
- **No restart is ever asked for**: the controller compares what it wants with what it gave the player, so a route
  replaced in one frame, a volume change or a new frame with the same tempo never touches the player.

## Files changed

- `packages/party_host/lib/src/ui/lobby_music.dart` — the controller is `HostMusic`, with the round's state, the
  tempo, the pause, the results fade, the writer rule and `onClock`'s entry point; its docs describe both jobs.
- `packages/party_host/lib/src/ui/lobby_music_widgets.dart` — `LobbyHold`/`RoundHold` hold `HostMusic`; the
  `RoundHold` doc says what the round now plays.
- `packages/party_host/lib/src/music_loop.dart` (new) — `MusicLoop`: the four loops, their keys and names, and
  `forRound`.
- `packages/party_host/lib/src/sound_loop.dart` (new) — the engine's one loop: play at a share, pause, resume, stop
  with a fade, cross-fade, share, reset, dispose.
- `packages/party_host/lib/src/sound.dart` — `SoundPlayer` gained `playLoop(..., {at, fade})`, `pauseLoop`,
  `resumeLoop`, `stopLoop({fade})`, `loopShare`; `SoLoudSoundPlayer` delegates the looping to `SoundLoop` and
  disposes it.
- `packages/party_host/lib/src/sound_settings.dart`, `sound_wish.dart` — docs say "the music", not "the lobby
  music".
- `packages/party_host/lib/src/testing/adapter_fakes.dart` — `FakeSoundPlayer` records the new calls:
  `loopSwitches` (name, share, fade), `loopStops` (fades), `loopPaused`, and a settable `share`.
- `packages/party_host/lib/party_host.dart` — exports `music_loop.dart`.
- `packages/party_host/lib/src/ui/puzzle_screen.dart` — the round reports its clock, its results and its going, and
  reads the music in `initState` (not in `dispose`).
- `packages/puzzle_game/lib/src/play_view.dart` — `onClock`, called from `_tick` with the ms left and the warning.
- `assets/lib/asset_manifest.dart` — `SoundKey.round`, `roundHurry` (`round_hurry`), `roundFinal` (`round_final`).
- `assets/CREDITS.md` — a row for each of the three files (generated with `tools/audio/round_music.dart`, CC0) and
  the Audio paragraph.
- `docs/design/look-and-sound.md` — a "Decided at step 10b" block: the piece and its tempos, rules 1–7 in short, the
  controller and the switch.
- `packages/party_host/test/music_loop_test.dart` (new) — the tempo's boundaries and the keys/names.
- `packages/party_host/test/round_music_test.dart` (new) — the round's music end to end.
- `packages/party_host/test/lobby_music_test.dart` — the round's assertions only (question 1); every lobby assertion
  is untouched.
- `packages/party_host/test/sound_keys_test.dart` — the three keys and their files.
- `controller_app/test/sound_test.dart` — a joined phone in a round still plays nothing.

## Computed test values

`MusicLoop.forRound`, with `warningS` 15 (the default) and 15000 ms = `warningS * 1000`,
5000 ms = `15000 / 3`:

| time left | `warningS` | loop |
| --- | --- | --- |
| 15 001 ms | 15 | `round` |
| 15 000 ms | 15 | `round_hurry` (at the warning exactly) |
| 5 001 ms | 15 | `round_hurry` |
| 5 000 ms | 15 | `round_final` (at the third exactly) |
| 0 ms | 15 | `round_final` |
| 3 334 ms | 10 | `round_hurry` (the third is 3 333.33 ms) |
| 3 333 ms | 10 | `round_final` |
| any | 0 | `round` |
| none (the Arena) | 15 | `round` |

Each row is a test in `music_loop_test`; a 90 s round at 15 s warning starts near 90 000 ms, which is `round`.

The fade and switch values the tests pin: `HostMusic.switchFade` = 120 ms, `HostMusic.resultsFade` = 300 ms. The
share kept on a switch is the fake's `share` (0.4, 0.2 in the tests), read from the player as
`position / length` clamped to 0–1.

## Tests

| check | before | after |
| --- | --- | --- |
| look | 111 | 111 |
| puzzle | 218 | 218 |
| arena | 66 | 66 |
| host | 241 | 254 (+4 `music_loop_test`, +7 `round_music_test`, +2 `sound_keys_test`) |
| phone | 433 | 433 (one joined-phone test extended) |
| tv | 53 + 1 skipped | 53 + 1 skipped |
| kit | 48 | 48 |

(The host's 241 was measured on this tree before the job; `STATUS.md`'s 240 is one test older than df2eec9's.)

`round_music_test` cases: the lobby's gives way to the round's at go; the hurry and the final, keeping the place and
cross-fading, and back to `round` when the clock is put back to 20 s; the Arena stays `round` for 30 s with no
switch; the results stop it with `resultsFade`; a pause pauses and the resume never restarts; Music 0% / 60% /
Mute; Play again's new round starts at its own go after its own 3-2-1, with the countdown still playing twice and
the old round stopping nothing.

## Self-check (review rules part A)

1. **Every host setup.** The music is the host device's, and nothing new branches on the host's setup: the TV/PC host
   starts the round's loop at once (no beat), a phone host after its 3-2-1 — both are `RoundPhase.playing` — and
   "Show on this device"/"Play on this phone" change neither. A joined phone plays nothing: `controller_app`'s
   `sound_test` (a joined phone in an Arena round), and `round_music_test`'s default-beat test. No protocol change
   at all, so a host or phone one build older is the same host or phone as before.
2. **When kept state starts and ends.** The counters start at the picker's/round's screen opening and end at its
   close (`lobby_music_test` "two changes in one frame", "a scope disposed with the loop playing stops it"); the
   round's writer, clock and end flag start at `initState`, end at the screen's `dispose` or the next screen's
   claim (Play again test), and with nothing open `_wanted` is null and no call reaches the player
   (`round_music_test` "the Arena ..."/lobby's own test).
3. **How a new state combines.** Paused: `round_music_test` "a paused round pauses its music"; the 3-2-1: the Play
   again test; the results: the results test; the host away and a phone the round waits for are the same
   `RoundPhase.none`, so the same branch as the pause (not tested separately); Music 0%/Mute: the 0% test; leaving
   the round: the lobby test's Change teams step; Play again over the results: the Play again test. One owner stays
   `Pausable` for the phase; the controller only reads it.
4. **Stay in the job's folder.** Every edit is inside `allow:`. `git status` also shows
   `tv_test_app/windows/flutter/generated_*` as modified with an empty content diff (line endings, Flutter tooling
   rewriting them on Windows); s15's report notes them as already modified before, and nothing in this job changes
   them.
5. **Stop rather than overstep.** The brief's "keep the lobby music's existing tests passing unchanged" cannot hold
   as written: the test asserts the loop is *null* while a round runs, which is the one thing this job changes. I
   changed those assertions only (question 1) and left every lobby assertion as it was; I did not stop the job for
   it, since the rest of the brief is explicit that the round now plays.

## Checks

`tools/check.sh format analyze look puzzle arena host phone tv kit` — all PASS (format 2 s, analyze 12–14 s, kit 48,
look 111, arena 66, puzzle 218, host 254, phone 433, tv). `tools/review.sh` — 0 fail, 2 notes (both files at 302 and
308 lines against the 300 aim; the limit is 400). The puzzle tests left `docs/design/m12-mirror-*.png` unchanged
(`git status` shows none).

One full run failed `live_stats_test` ("a simulated session, with a Wi-Fi drop ... nothing is uploaded without
consent": 2 session files where the test expects 1) while the whole host suite ran in parallel; the test passes
alone, and a rerun of the host suite and `tools/check.sh host` both passed 254. It touches nothing this job changed
(the session recorder and its temp folder), so I've noted it rather than changed it.

## Questions for Claude

1. **The lobby test had to change.** `lobby_music_test`'s round test asserted `sounds.loop, isNull` and
   `loopStarts == ['lobby']` while a round runs; with round music the loop is `'round'`. I changed those three
   assertions (and the test's title comment) and nothing else — was that the expected reading of "unchanged"?
2. **A race's two clocks.** The tempo follows the side with the **least** time left, as that is the clock that ends
   the round. If the design wants the first side's clock, or only a one-board round to speed up, say which.
3. **`warningS` is read live** from the round's own `game.settings.warningS` (a playtest change reaches the music as
   it reaches the game's own tick warning), not read once at the start. OK?
4. **The Arena has no end.** Its `Pausable` stays enabled for the screen's life and it has no results, so its music
   plays until the screen closes and never fades — rule 2's "stops when the round ends" has no moment to happen on
   the Arena. Is that the intended behaviour until M14's waiting card gives it an end?
5. **`SoLoud.seek` returns void**, so a tempo switch may reach its place a frame after it starts. The share is read
   once, at the switch. Good enough, or should the share be re-applied on the next frame?

## Suggestions

- A round's music could duck slightly under the last-15-s tick (the design already masters it 3 dB under the lobby);
  today it is a fixed volume.
- `SoundLoop` owns its fade timers; if M14 adds a second music source (a waiting card), the "one loop" rule in
  `SoundPlayer` is the thing to revisit.
- The Arena's results would give its music the fade rule 2 asks for; worth pairing with M14's waiting card.

## Commit message

M13 10b: play the round music and hurry it with the clock

The host's music is now one controller, HostMusic: the lobby's
loop on the picker and join screen, the round's own from its "go"
to its results. Shape Race's clock moves it from round to
round_hurry at warningS and round_final at a third of it, keeping
the place in the loop and cross-fading over 120 ms; a pause
pauses it, the results fade it out (300 ms), the Arena stays on
round, and joined phones play nothing. SoundPlayer gained seek,
fade, pause and share for it, behind a new SoundLoop.

## Status row

M13 step 10b (round music plays): done — host 254 tests (was 241), phone 433, all checks green; the round's music starts at the round's "go" on Shape Race and the Arena, hurries at `warningS` and runs at `warningS / 3` (120 ms cross-fade at the same place), pauses with the round, fades out (300 ms) on the results, and joined phones never play it. Not yet heard on a TV or phone; tag when the owner says so.

## Delete

- none

## Claude's review

- Accepted. `MusicLoop.forRound` is the brief's rule; `HostMusic` starts the round loop at `RoundPhase.playing`, pauses on a hold, fades 300 ms at the results and cross-fades 120 ms at the same share on a tempo change. All checks pass on the tree with today's later fixes (rematch view, sail stand, portrait clock): host 254, puzzle 227.
- Answers: 1) the lobby test's change is right (a round now plays its own loop). 2) A race follows the side with the least time: yes. 3) Live `warningS`: yes. 4) The Arena fades only when its screen closes: fine for now. 5) A frame-late seek is inaudible: fine.
- Not checked on a device: how it sounds, and the switch on a real phone. The owner has the three files to listen to.
