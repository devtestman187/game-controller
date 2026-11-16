# B-027: the sound engine dies silently and nothing restarts it — report

## Summary

**Fixed, unverified: needs device check (iPad).** The SoLoud engine can stop without an error after
several minutes, and until now only the app-lifecycle `onShow` (host route, joined view) ever restarted
it, so the music and the sounds stayed off until the app was hidden and shown again.

What changed:

- **New `packages/party_host/lib/src/sound_watchdog.dart` (120 lines):** `SoundWatchdog` looks at the
  music loop every `period` (3 s, `Timer.periodic` started by `start()`, stopped by `dispose()`). A look
  while the app is hidden, the music paused, no loop wanted or a restart running judges nothing and
  forgets the place seen before; otherwise a loop with no voice, a voice the engine no longer knows, or a
  place equal to the one the look before saw means a dead engine and calls `restart`. `failed()` (a
  `play()` that threw) restarts too when the app is on screen and no restart runs. Both paths keep
  `cooldown` (5 s) between restarts, on an injected `now`.
- **`sound_loop.dart`:** adds `bool get paused`, `bool hasSource(String name)` and
  `SoundPulse? get pulse` (`valid` false when the engine lost the handle or threw; null when no loop
  sounds). Nothing else about the loop changed.
- **`sound.dart`:** a `late final SoundWatchdog _watchdog` wired to the player — `active` from
  `WidgetsBinding.instance.lifecycleState` (resumed or unknown), `wanted` = `status.ready && wish loop
  set && loop.hasSource`, `paused` = `_loop.paused`, `busy` = `_restarting != null`, `restart` = the
  existing `restart()` plus one log line. It starts at the end of a successful `_load`, is disposed in
  `dispose()`, and `play()`'s catch now calls `_watchdog.failed()`.
- **New `packages/party_host/test/sound_watchdog_test.dart` (173 lines), 6 tests:** a fake
  `LoopAudioEngine` whose one voice can die (`hasVoice = false`) or stand still (`place`), a real
  `SoundLoop` over it, and a watchdog counting restarts with a hand-moved clock.

Test counts seen here: the new file runs **6 tests, all pass**; `tools/check.sh host` shows **504 tests
passed** (498 before this job). The new file fails on the old code because it imports
`party_host/src/sound_watchdog.dart`, which the old tree does not have.

Decisions (safest choice that fits the design):

1. **The watchdog watches the music loop only** — the one voice a round keeps sounding; the effect
   sounds are one-shot handles with nothing to compare. A round with the Music setting at 0 or no loop is
   not watched (a dead engine then shows only as a `play()` that throws).
2. **A missing or lost voice restarts on that same look; only a frozen place waits for a second one** —
   a gone voice needs no comparison, a place needs one.
3. **Restarts go through the existing `restart()`** (brief), so the wish (loop, volumes) survives; a dead
   voice has no share, so such a restart starts the loop at 0 — the same as a restart today.
4. **The cooldown is set when a restart is asked for, before it runs**; `busy()` covers the run, so no
   second ask lands during a load.
5. **The watchdog logs nothing itself**; the player's `restart` callback logs "The sound engine stopped on
   its own, starting it again", and `restart()` already logs the result — one place owns the engine log.
6. **`failed()` ignores `paused` and `wanted`** (brief: active and not busy only): a `play()` that throws
   is proof the engine is gone whatever the music was doing.
7. **`pulse` reports `position: Duration.zero` when the voice is invalid or the call threw** — the place
   is meaningless then, and `valid` is what the watchdog reads.
8. **`start()` is idempotent** and called at the end of every successful load, so a restart's load keeps
   the one timer; it never starts before the first load, so a player that never loaded has none.

Self-check (review-rules part A):

1. **Every host setup.** The watchdog lives in `SoLoudSoundPlayer`, shared by the TV/PC host, "Play on
   this phone" and a game shown on the device (the joined view's `restart` on show is unchanged); its one
   platform read is `lifecycleState`, so nothing differs by host type. An older build sees no protocol or
   file change. Shown by `nothing is judged while the app is hidden…` and `a failed play is ignored while
   the app is hidden…`.
2. **When kept state starts and ends.** The timer starts at the first successful load and ends in
   `dispose()`; the remembered place and restart time are cleared on every skipped look and before each
   restart, so with no round, no players or the app hidden nothing is judged. Shown by `nothing is judged
   while the app is hidden…` (the hidden rig forgets its 3 s place and needs two fresh looks after).
3. **How a new state combines with the others.** It adds no state of its own: `paused` is the loop's
   existing pause (beat, pause menu, host away), `busy` the existing restart. A paused-and-restarting
   loop is skipped by both conditions. Shown by the same test's paused and busy rigs.
4. **Stay in the job's folder.** Only `sound.dart`, `sound_loop.dart`, the new `sound_watchdog.dart`, the
   new test and this report changed; `git status` shows nothing else from this job.
5. **Stop rather than overstep.** Nothing was needed outside `allow:`; no rule contradicted the code.

## Hand-over

- Device check (iPad, the owner's several-minute play): with the round's music on, play until the sound
  used to die; the music should come back within about 3 to 8 s (one look plus a load), and the device log
  should show "The sound engine stopped on its own, starting it again" followed by "Sound engine
  restarted (N of M sounds)". With the music off, the recovery shows only through a `play()` that threw,
  so a silent-effects case would need the log or a later brief.
- What is not watched: the effect sounds on their own (no long-lived handle to compare) and a round with
  no loop wanted. Both are stated in Decision 1; a fix would need a silent pulse voice, which changes
  what plays.
- A dead voice has no share, so a watchdog restart starts the music at 0 rather than at its place; the
  brief asked for the existing `restart()`, whose `_restartAt` comes from `loop.share` (null when the
  voice is invalid).

## Commit message

```
Restart the sound engine when it dies (B-027)

The SoLoud engine can stop without an error after minutes on an iPad and
nothing detected it: only the app-lifecycle onShow restarted it, so music
and sounds stayed off until the app was hidden and shown again.
SoundWatchdog looks at the wanted music loop every 3 s and restarts the
engine when its voice is gone or its place stops moving, and a play()
that throws does the same, at most once per 5 s. SoundLoop gains paused,
hasSource and pulse for it. Nothing that plays, its volumes, the
lifecycle restarts or the sound settings changed.
```

## Status row

M14 B-027: a dead sound engine is now restarted from the host (music-loop watchdog every 3 s plus a
failed `play()`, 5 s cooldown) — done in code, open: the device check on the iPad and the unwatched case
of a round with no music.

## Delete

- none
