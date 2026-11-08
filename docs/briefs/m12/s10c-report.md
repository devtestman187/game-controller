# M12 s10c — G3 report: the "Get ready" beat at a round's start on a phone host

**STATUS: done**, at G3, the gate the brief names. What the job landed:

1. `readyCountdownProvider` asks how long a round is held before its first step. It is `Duration.zero`, so
   the TV and a joined phone start as they always did (rule 6); the phone app overrides it with
   `Pausable.ready`, 3 s (rule 3).
2. `Pausable` holds the round for that long: no step runs, the game's clock stands still, the builder gets
   `paused == true` and `ReadyCard` counts 3, 2, 1 over the game. The round's phase is `ready` while the beat
   holds it and `playing` once it ends.
3. The round's first frame goes out before the hold (step 0, `n = -1`), so a joined phone draws the board
   during the beat instead of a blank screen (`GameSession`, so both games get it).
4. Start is ignored until the beat ends: the tick returns before it reads Start, and a Start still held from
   the beat is not a new press after it.
5. A round that stands still holds the beat too — a phone that dropped, the host app away, an open menu — and
   the beat starts again from 3 once nothing waits. The away card takes the beat card's place while a phone
   is away. (The brief asked for the away cases; the menu and the results fall out of the same `_stopped`
   test: any stop holds or ends the beat, so the beat never runs behind a menu.)

## The card's exact text

Two lines, centred on a rounded black box (75 % black, radius 24):

```
Get ready
3
```

The second line is the seconds left and reads `3`, then `2`, then `1`; the box's key is `getReady` and the
number's is `getReadyCount`. It takes no touch (`IgnorePointer`): the pad is the only thing under a finger
(rule 2).

## Files changed

- `packages/party_host/lib/src/providers.dart` — 321 → 328 lines. New `readyCountdownProvider`: a plain
  `Provider<Duration>` returning `Duration.zero`, documented as the beat rule 3 asks for and that the phone
  app overrides with `Pausable.ready` while the TV asks for none.
- `packages/party_host/lib/src/ui/ready_card.dart` — new, 45 lines. `ReadyCard(seconds:)`: `IgnorePointer` →
  `Center` → `DecoratedBox(key: getReady)` → `Text('Get ready')` + `Text('$seconds', key: getReadyCount)`.
  It owns no timer: the round's screen counts the seconds, so there is one clock.
- `packages/party_host/lib/src/ui/pause_menu.dart` — 313 → 381 lines. New `static const ready =
  Duration(seconds: 3)`; `_readyTotalMs`/`_readyMs` taken in `initState` from `readyCountdownProvider`;
  `_onBeat`, `_readySeconds`; `_beat()` called each tick before `_publish()`, which counts down, holds at the
  total while `_stopped`, and ends the beat when the round is off (`enabled == false`, the results); the tick
  returns while `_onBeat`, so Start opens nothing; `_roundPhase` gives `ready`/`playing`/`none` and
  `_publish()` posts it; `build` passes `_onBeat || ...` as paused and puts `ReadyCard` under the away card's
  slot (hidden while a phone is away or the app is hidden). The Start handling moved out of `_tick` into
  `_newPresses` + `_startPressed` unchanged, to keep `_tick` under the ~40-line rule (review.sh flagged it).
- `packages/party_host/lib/src/ui/round_phase.dart` — 82 → 83 lines. Docs only: `ready` and the signal's doc
  name the beat.
- `packages/game_kit/lib/src/game_session.dart` — 301 → 319 lines. `_firstFrameSent` and `_publishFirstFrame()`
  called from the `paused` setter when it goes true: at step 0, with a viewer and once, it sends the snapshot
  at step 0 as frame `n = -1`, so the first step's frame (`0`) follows it without a gap.
- `packages/game_kit/test/session_test.dart` — 240 → 271 lines: one expectation changed and two tests added
  (below).
- `packages/party_host/test/ready_beat_test.dart` — new, 174 lines: five tests (below).
- `controller_app/lib/src/host/host_overrides.dart` — 41 → 45 lines: `phoneHostOverrides` also overrides
  `readyCountdownProvider` with `party.Pausable.ready`.
- `controller_app/test/support/host_app.dart` — 237 → 247 lines: new `untilPlaying(tester)` (waits for
  `RoundPhase.playing`, fails with the phase it saw); `soloRound` waits the beat out and says so.
- `controller_app/test/host_mode_test.dart` — 399 → 456 lines: the first test asserts the beat, the results
  test waits it out, one test added, and the first test now ends with a system back (below).
- `docs/briefs/m12/s10c-report.md` — this file.

## Old → new, test by test

`packages/party_host/test/ready_beat_test.dart`, five new tests. `startBeat` hosts a house puzzle with P1 on
the left and P2 on the right, `readyCountdownProvider` overridden with `Pausable.ready`, and returns with the
beat running:

1. **"the round is held for the beat: the card counts 3, 2, 1 and no step runs"**: the card and
   `RoundPhase.ready` are there at once; over every 16 ms frame of the beat the puzzle's clock equals what it
   was at the start; the counts the card shows, in order, are `['3', '2', '1']`; after the beat the card is
   gone, the phase is `playing` and 100 ms on the clock is lower.
2. **"the round's first frame goes out before the beat holds it, so a phone draws the board"** (with
   `hasViewers`): one frame, `n == -1`, its `MatchSnapshot` board's `timeLeftMs` equals the held clock's; 60
   frames on, still one frame.
3. **"Start during the beat opens nothing, and the round goes on after it"**: Start down then up on P1 (the
   harness's press is two ticks apart, so the beat outlasts it) shows no `pauseMenu`; when the beat runs out
   there is still no menu and the `PuzzleScreen` is there.
4. **"a round that waits during the beat holds the beat, and it starts again from 3"**: 63 frames (1 s) into
   the beat, P2 drops → the away card is up, no count, and 2 s later the clock is unchanged; P2 back → the
   beat shows `3` again; the host app away (`hostAwayProvider` on a `ValueNotifier` this test moves) → no
   count for 2 s; back → `3` again.
5. **"with no beat asked for (the TV), there is no card and the round steps at once"**: no override; no
   `getReady` card, the first frame is `n == 0` (no frame before step 0), and after 100 ms the clock is lower.

`packages/game_kit/test/session_test.dart`:

1. **"nothing steps or is sent while paused"** — old: `clock.host.frames` is empty after 60 paused frames.
   New: `hasLength(1)` (the round's first frame only).
2. **new "a session that starts paused sends the round's first frame at once"**: one frame, `n == -1`,
   `snapshot == {'n': 0}` (the `CounterSession`'s step counter), `atMs == 0`; 60 paused frames later still one;
   resumed, the frames' steps are `[-1, 0]`.
3. **new "with no viewer the first frame is not sent"**: `Clock()` has no viewer, so the paused session leaves
   `frames` empty (and `paused` is true).

`controller_app/test/host_mode_test.dart` (the phone app now asks for the beat, so every round it opens gets
one):

1. **"a phone hosting plays its own game…"** — the start of the round now asserts `RoundPhase.ready`, the
   `getReady` card and `faceButtons` (the pad is up under the card, rule 2), waits with `untilPlaying`, and
   then checks the compact-bar expectations with the card gone (unchanged otherwise). The test now ends with
   `tester.binding.handlePopRoute()` + `settle`: on the worktree it failed with "A Timer is still pending"
   because the tree went away with the session's last `setStatus` half-sent — that call rate-limits on the
   server's real clock (46 ms) while the test's clock is fake. The back pops the round to the
   `ShapeRaceScreen` (the join screen replaced the puzzle list), where the phase is `none`.
2. **"a round ends on the results…"** — waits with `untilPlaying` after the puzzle screen, so a step (not the
   beat) ends the round.
3. **new "a round starts with a 3 s Get ready beat: the pad is up and the clock is held"**: on the puzzle
   screen the phase is `ready`, the count is `3`, `faceButtons` is up; 1 s later `2` with the clock unchanged;
   1 s later `1`; 1 s later (via `settle`) the phase is `playing`, the card gone and the clock lower.

## Computed values

- The beat is 3000 ms; the tick is `ControllerMenus.step` = 16 ms, so it ends on the 188th tick (16 × 188 =
  3008 ms). The plan's 180 frames (3 s at 60 fps) all fall inside the beat, so the puzzle's clock is unchanged
  over them — test 1 checks every frame of the beat, not a count of frames.
- The card's number is `ceil(_readyMs / 1000)`: `3` for 3000…2001 ms (≈ 63 ticks), `2` for 2000…1001,
  `1` for 1000…1, and no card at 0. That is what tests 1, 4 and 5 read.
- The first frame is `n = -1` with the snapshot at step 0 (`_stepCount` 0); the first step's frame is `n = 0`,
  so a phone's step numbers start at `-1, 0, 1, …` with no gap. Only one is sent, only with a viewer.
- A held round's frame count stays 1 for the whole beat (the session publishes nothing while `paused`).

## Checks (all on the tree I leave)

```
$ tools/check.sh format analyze kit host puzzle phone tv
PASS  format      (2s)
PASS  analyze     (7s)
PASS  kit         (36 tests, 4s)
PASS  puzzle      (118 tests, 13s)
PASS  host        (117 tests, 14s)
PASS  phone       (348 tests, 25s)
PASS  tv          (9s)
All checks passed (74s).
$ tools/review.sh
review: 0 fail, 6 note     # three size notes and three numeric-literal notes in ready_card.dart
```

- **Test counts:** kit **34 → 36** (+2); host **112 → 117** (+5 in the new file; s10b's report said 111 and
  s11's commit added one to that); puzzle **118 → 118**; phone **347 → 348** (+1); tv unchanged (28 passed,
  1 skipped).
- The size notes are `game_session.dart` 319, `providers.dart` 328 and `pause_menu.dart` 381 (limit 400, aim
  300). The numeric-literal notes are `ready_card.dart`'s 0.75, 24 and 40, matching `AwayCard`'s style.
- Tests failed first, as the brief asks: the new party_host file did not compile before the code (no
  `Pausable.ready`, no `readyCountdownProvider`), the kit tests failed against the old session (frames empty
  instead of one), and the app's tests failed on the beat with
  `Expected: RoundPhase:<RoundPhase.playing> Actual: RoundPhase:<RoundPhase.ready>` until they waited.

## Not sure / questions

1. **Where the countdown lives.** The plan sketched a `Timer` in `ReadyCard`; I put the seconds in `Pausable`
   instead, on the tick it already runs, and the card only draws. One clock means the hold and the count can
   never disagree, and it made the "holds and restarts" rule one `_beat()` rather than two timers. Say if you
   want the card self-timed.
2. **The beat restarts from 3 after any stop**, not only the away cases the brief names: an open menu, the
   results (where it ends). A menu opened after the beat has already run leaves the round playing on resume
   (the beat is only at the start), so only a stop during the beat replays it. If you would rather the beat
   never replay, `_beat()`'s `_stopped` branch is the line to change.
3. **A Start still held from the beat** does not open the menu when the beat ends; a fresh press does. That is
   what "ignored until the beat ends" reads as to me, and it is how the harness's press (down, tick, up, tick)
   behaves.
4. **`pause_menu.dart` is 381 lines** (limit 400). The beat added ~68. A later job should move the beat (and
   maybe the away card) into its own widget when the file next grows; I did not split it here because the
   brief's files are the beat's and the away logic is woven into `_tick`.
5. `git status` also lists `tv_test_app/windows/flutter/generated_plugin_registrant.{cc,h}` and
   `generated_plugins.cmake` as modified; their diff is empty (line endings only), the Flutter Windows build
   rewrites them, and I did not edit them (s10a's and s10b's reports note the same).
6. **plan §7 question 5 is still open**: after s10c, `m12.md` §2.6 should point at `m12-host-touch.md` and
   rule 1 name the screens. That is a docs job, not this one.

## Commit message

```
feat(m12): a phone host holds its round for a 3 s "Get ready" beat

readyCountdown is zero, so the TV starts as it always did; the phone app
asks for Pausable.ready, 3 s. Pausable holds the round for it: no step,
the clock still, the phase ready then playing, a ReadyCard counting 3, 2,
1 over the game, and Start ignored until it ends. The session sends the
round's first frame (step 0, n -1) when it is paused at step 0, so a
joined phone draws the board during the beat instead of a blank screen.
A stop during the beat (a phone away, the host away, a menu) holds it and
it starts again from the top.
```

## Status row

| Step 10 host touch s10c | Done ([s10c-report.md](s10c-report.md)): `readyCountdown` (zero; the phone app 3 s) holds a round's start for a "Get ready" beat, no step and the clock still, the phase `ready` then `playing`, a `ReadyCard` counting 3, 2, 1 over the game, the round's first frame (`n = -1`, step 0) sent before the hold so joined phones draw the board, Start ignored until it ends, and a stop during the beat holds it and restarts it from 3. Checks: format, analyze, kit 34→36, host 112→117, puzzle 118, phone 347→348, tv unchanged, review 0 fail | Open: `m12.md` §2.6's pointer (plan Q5), `pause_menu.dart` at 381 lines (split the beat out later) |

## Delete

- none
