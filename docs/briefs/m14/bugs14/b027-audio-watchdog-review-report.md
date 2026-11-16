# Review of b027-audio-watchdog (B-027 sound engine watchdog)

## Summary

**small fixes.** must 0, should 4, could 3. The code does what the brief asked, the checks pass, and the
runner confirms the new file fails on the old code (`run.log:9`); the gaps are untested paths and one
unrecovered case, no overstep.
1. A restart whose load fails leaves the engine dead and unwatched for good (`sound.dart:214`): `ready` stays
   false, every look is skipped, and with no sources `play()` returns before its catch — the same silent
   engine until the app is hidden and shown.
2. The timer is untested: no test calls `start()` or `dispose()` (`sound_watchdog.dart:78`), so Decision 8
   and guidelines §5 ("a test proves dispose leaves nothing running") are unchecked.
3. The not-wanted and "no voice though a loop is wanted" branches of `tick()` are unexercised
   (`sound_watchdog.dart:82`, `:87`): the rig never sets `wanted = false` and always plays.
Checks: format on the four files 0 changed, `dart analyze` in `packages/party_host` clean, `flutter test`
there 504 passed, `test/sound_watchdog_test.dart` 6 passed.

## Findings

- **should** packages/party_host/lib/src/sound.dart:214 `_isLoopWanted` requires `_status.ready`, so a watchdog restart whose `_load` fails at `soloud.init()` (`sound.dart:169-173`) leaves `ready` false, every later look is skipped, and with `_sources` empty `play()` returns at `sound.dart:247` before its catch, so nothing starts the engine again until the app is hidden and shown — the silent engine this job was to fix → count a wanted loop with a not-ready status as a dead engine (restart again after the cooldown, logged), or state in the report that this case is left to the lifecycle.
- **should** packages/party_host/lib/src/sound_watchdog.dart:78 the new `Timer.periodic` and its `dispose()` (`:105`) have no test — nothing in `sound_watchdog_test.dart` calls `start()` — so Decision 8 ("`start()` is idempotent") and guidelines §5 ("a test proves dispose leaves nothing running") are unshown → add a `fakeAsync` test: two `start()` calls, one look after 3 s, none after `dispose()`.
- **should** packages/party_host/test/sound_watchdog_test.dart:86 the rig's `wanted` is never set false and `_Rig()` always plays a voice (`:60`), so `sound_watchdog.dart:82`'s not-wanted skip and `:87`'s "no voice though a loop is wanted" restart (brief item 1, report Decision 1) are untested → add a case with `wanted = false` (no restart) and one with a wanted loop that never got a voice (restart on the first look).
- **should** docs/briefs/m14/bugs14/b027-audio-watchdog-report.md:56 self-check 1 and 2 (`:56` and `:62`) name tests that call `tick()` by hand, so they show neither the player's `lifecycleState` read (`sound.dart:205`), nor the timer starting at `sound.dart:200` and ending at `:332`, nor `play()` → `failed()` (`sound.dart:257`) → mark that wiring as untested by this job, or add a player test with a fake engine.
- **could** packages/party_host/lib/src/sound_watchdog.dart:92 "frozen" is exact equality with the previous position and no wrap is handled, so a loop whose length divides the 3 s look reports the same position on two looks and is restarted every cooldown for ever → let `pulse` carry the loop's length (`SoundLoop` has `_source` and `getLength`) and treat a position one length later as moving.
- **could** packages/party_host/lib/src/sound_watchdog.dart:47 the fixed 5 s cooldown restarts an engine that cannot come back about every 6 s for the rest of the session, each time a deinit, an init and every sound reloaded (`sound.dart:223-241`) with two log lines → widen the cooldown after each restart that did not help, and say why in the doc comment.
- **could** packages/party_host/lib/src/sound_watchdog.dart:7 the file holds two public types (`SoundWatchdog`, `SoundPulse`) and makes `sound_loop.dart:8` import the watchdog, the reverse of who uses whom (guideline §3) → move `SoundPulse` beside `SoundLoop` (or to a small shared file) and import it in the watchdog.

## Decisions to confirm

1. Decision 1 (music loop only): with the Music setting at 0 the lobby stops the loop (`lobby_music.dart:239`), so `wanted` is false and nothing is watched — the owner reported music *and* effects dying, so with music off this fix changes nothing; confirm that half is acceptable for now.
2. The brief's own definition `wanted = status.ready && …` (`sound.dart:214`) is what leaves a failed restart unwatched (first finding); the fix changes what the brief asked for, so it is Claude's call, not the worker's.
3. Decision 3 (a dead voice restarts the music at 0): in the owner's case the track jumps back to its start mid-round instead of resuming; confirm that is preferred to better guesswork.
4. Decision 6 (`failed()` ignores `wanted` and `paused`): one effect `play()` that throws while the music is off restarts the whole engine mid-round, reloading every sound; confirm that cost is wanted.
5. Decision 7 (`pulse` reports `Duration.zero` when invalid) is safe only because the watchdog reads `valid` first (`sound_watchdog.dart:87`); a later caller reading `position` alone would take 0 for a place.

## Could not check

- That the new file fails on the old code: not re-run here (no checkout allowed); `run.log:9` is the runner's line, and the reason in the report (the file imports `sound_watchdog.dart`, absent at 50c47d1) is true.
- Any device behaviour: whether the iPad engine actually freezes this way, how long a restart takes, and whether `getPosition` on a looping SoLoud voice wraps as assumed.
- Whether `WidgetsBinding.instance.lifecycleState` is reached in any non-widget test: no existing test loads a player and provokes a `play()` throw (`sound_wish_test.dart:51` builds one without loading), so the binding read is only exercised in the app.
- `docs/briefs/m14/bugs14/run-findings.md` does not exist, so there are no third-party "passes on the old code" entries for this job.

## Commit message

```
Review b027 audio watchdog: 4 should, 3 could

The watchdog does what the brief asked and the checks pass, but a
restart whose load fails leaves the engine dead and unwatched, the
timer and two tick() branches have no test, and the report's
self-check names tests that do not show the player wiring.
```

## Status row

M14 B-027 (dead sound engine): code and 6 tests in, 504 host tests pass, analyze and format clean, runner
confirms the new file fails on the old code — open: dispose/timer test, not-wanted and no-voice tests,
player wiring untested, an engine left dead after a failed restart, the iPad device check.

## Delete

- none
