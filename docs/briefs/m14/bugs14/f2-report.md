# M14 bugs14 f2 — the sound watchdog's gaps

## Summary

The B-027 review's findings 3-6 are done: a failed restart no longer leaves the engine unwatched for
the session, the player's lifecycle read has a seam, and the watchdog's timer and looks have tests.
- **Finding 3.** `_isLoopWanted` required `_status.ready`, so a restart whose `soloud.init()` failed
  left `ready` false, every look skipped and the engine dead until the app was hidden and shown. The
  rule is now `SoLoudSoundPlayer.isLoopWanted(loop, ready, loadTried, hasSource)`: no loop → false;
  ready → `hasSource` (a missing file still stays silent on purpose); not ready → `loadTried`, so a load
  that was tried and did not bring the engine up makes the wished loop's silence its death. A new
  `_loadTried` is set as `_load` starts its init attempt, so nothing is judged before the first load.
  `pulse` is null then (a restart cleared the voice), which the watchdog already counts as dead: it
  restarts on the first look, then at most once per cooldown, with the restart callback's log line.
  Period, cooldown and `_applyLoop` (when effects and loops play) are untouched.
- **Finding 4.** `SoLoudSoundPlayer` takes `bool Function()? active`, defaulting to the static read
  `_appIsActive` (the old `_isActive`, renamed), and hands it to the watchdog; no player test (SoLoud
  needs a device), so the seam has none.
- **Findings 5-6.** New `test/sound_watchdog_gaps_test.dart`, 5 cases on a `_Rig` of fake callbacks:
  two `start()`s then 3 s → 1 look, 6 s → 2, `dispose()` + 9 s → still 2 and no restart; `wanted` false
  → no pulse read, no restart; wanted with a never-played loop (pulse null) → restart on the first look;
  not-ready with `loadTried` false → 0 restarts, then true → 1 restart; and the rule's five-entry table.
- **Old code:** the timer, not-wanted and no-voice cases pass on it (pure coverage of the unchanged
  watchdog); the two not-ready cases fail: the old rule gives 0 restarts, and `isLoopWanted` was absent.
- **Ran here:** new file 5 passed, both watchdog files 11 passed, `tools/check.sh format analyze host`
  PASS (host 509 tests, 504 before). `tools/review.sh`: 0 fail, 2 notes (`sound.dart` 375, `_load` 45).
  `sound.dart` 347 → 375 (brief limit 380; guideline aim 300, review finding 13 open),
  `sound_watchdog.dart` 120 → 123 (doc only), the test file 112.
- **Fixed, unverified: needs device check (iPad).** Whether SoLoud's init can fail after a restart, what
  a restart costs, and whether the music returns within a cooldown plus a period are read from the code,
  not measured.

### Decisions

1. **Where the rule lives.** The wanted rule is a pure static on `SoLoudSoundPlayer` instead of a
   private method, so the finding-1 behaviour can be shown without a sound device; `_isLoopWanted`
   delegates to it. It is `src/` surface only, not exported from the package library.
2. **No `fakeAsync` from `package:fake_async`.** It is only a transitive dependency of `party_host`
   (through `flutter_test`), and importing it gives `depend_on_referenced_packages`, which `dart
   analyze --fatal-infos` fails; `flutter_test` does not export `fakeAsync`. The timer case uses
   `testWidgets` + `tester.pump`, which runs on Flutter's FakeAsync, so no real time passes. A later
   job can add `fake_async` to the dev dependencies if plain `fakeAsync` tests are wanted.
3. **Flag set when the load is tried, not when it ends.** Nothing looks before the first load ends (the
   watchdog's `start()` is at the end of a successful load) and a restart's looks are skipped by
   `busy`, so the two readings behave the same; setting it at the attempt matches "after a load has
   been tried" and is one line.
4. **No log line added for the not-ready case.** The watchdog's restart callback and the failed init
   already log; a third line would repeat them.
5. **No start after a failed first load.** `_watchdog.start()` stays at the end of a successful load,
   so the not-ready rule only helps after a restart (which the brief's "before the first load finishes
   nothing is judged" allows). Widening it is a question for Claude.

## Self-check (review-rules part A)

1. **Every host setup.** Host-only code (TV, PC and phone host all use this player); a joined phone and
   a one-build-older peer never run it, so only the host changes. No UI change; shown by the new tests
   at the watchdog level, and by `host` 509 passing (the player's other tests unchanged).
2. **When kept state starts and ends.** `_loadTried` starts when a load attempt begins and never ends
   (the player lives for the session; a later restart keeping it true is the point). Nothing is judged
   before it ("a loop is wanted once its sounds are in..." in the new file: not ready before a load →
   false); the watchdog's timer ends with `dispose()` ("two starts share one timer...": 9 s more → no
   look).
3. **How a new state combines with the others.** "Wanted but not ready" only restarts while `active`
   and not `busy`, like every other look; hidden beats it (the lifecycle restarts on show) and a
   restart in flight beats it (that load sets the state). Paused is irrelevant: a wanted not-ready loop
   has no voice to pause. The combinations are shown by the existing `sound_watchdog_test.dart` case
   "nothing is judged while the app is hidden, the music paused or a restart runs", plus "a loop wanted
   while the engine is not ready is judged dead once a load was tried" here for the not-ready look.
4. **Stay in the job's folder.** Only `packages/party_host/lib/src/sound.dart`,
   `packages/party_host/lib/src/sound_watchdog.dart`, the new test file and this report changed; the
   other entries in `git status` (`run.log`, the tablet PNG, the Windows plugin registrants) were
   already modified before this job (23:08, my first edit 23:10).
5. **Stop rather than overstep.** No file outside `allow:` was needed. The one mismatch, the brief's
   `fakeAsync`, is answered under Decisions 2 without changing `pubspec.yaml`.

## Hand-over

- **Fixed, unverified: needs device check (iPad).** On the iPad: start a round with music, force the
  engine to die (lock/unlock or several minutes of play), and see the music come back and the log line
  "The sound engine stopped on its own, starting it again" appear; if a restart's load fails, the line
  should repeat about every 6 s (5 s cooldown + up to a 3 s period) and "Sound engine could not start"
  should be beside it.
- `isLoopWanted` is public only for the test; with a fake-engine player test (finding 4's second half)
  it can go back to private.

## Suggestions / questions

1. Should the watchdog also `start()` after a load that failed at `soloud.init()`? Today the first load
   failing leaves nothing watching until some `play()` throws; after a restart the timer keeps it
   watched. One line, but it is a behaviour change the brief did not ask for.
2. Should a first-load failure that keeps failing be logged once rather than every cooldown? The fixed
   cooldown (review finding 12) is still open and would cover it.
3. Add `fake_async` to `party_host`'s dev dependencies in a later job so timer tests can use plain
   `fakeAsync`.

## Commit message

```
Watch a wished loop whose engine never came up, and test the watchdog

A restart whose load failed at soloud.init() left ready false, so the
wanted check was false, every look was skipped and the engine stayed
dead and unwatched for the session. A wished loop now counts as wanted
once a load was tried and the engine is not ready, so the watchdog
restarts it after the cooldown and logs it. The player takes the
lifecycle read as an injected `active` function, and a new test file
shows the watchdog's timer, its not-wanted and no-voice looks and the
not-ready case.
```

## Status row

**bugs14 f2:** B-027's review findings 3-6 are closed — a wished loop whose engine never came up is
watched and restarted, `active` is injected, and the watchdog's timer, not-wanted, no-voice and
not-ready looks have tests (5 new, host 509) — all Fixed, unverified: needs device check (iPad); still
open in this area: a first load that fails is not watched until a `play()` throws, the fixed cooldown,
the frozen check's loop length and `sound.dart`'s size (375 lines).

## Delete

- none
