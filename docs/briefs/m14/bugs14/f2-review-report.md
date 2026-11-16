# Review of bugs14 f2 — the sound watchdog's gaps

## Summary

**small fixes.** 0 must, 2 should, 2 could. The rule change is right and the brief's three items are done,
but no test reaches the player's half of it: the new tests call `SoLoudSoundPlayer.isLoopWanted`
directly, so `_loadTried = true` (`sound.dart:181`) and its feed (`:243`) can go and all 509 tests stay
green. Second, `_load` is 45 lines because the diff put a four-line comment in it (`:177-180`).
Third, self-check 3's "Paused is irrelevant" is not what `tick()` does: `sound_watchdog.dart:85` skips
every look while `paused()` is true and `SoundLoop.reset` keeps `_paused`, so a not-ready loop whose
music the round paused waits for the resume.
Ran here: both watchdog files 11 passed, `flutter test` in `party_host` 509 passed, `dart analyze` clean,
`dart format --set-exit-if-changed` 0 changed on the three touched files.

## Findings

- **should** packages/party_host/lib/src/sound.dart:181 no test covers the player's feed — deleting `_loadTried = true` here (or the `loadTried:` argument at `:243`) leaves all 509 host tests green, and the two not-ready cases fail on the old code only because `isLoopWanted` is a new symbol → add a player-level test through a fake engine (as REVIEW finding 4 asked) or say "untested by this job" at `:181`.
- **should** packages/party_host/lib/src/sound.dart:177 the four comment lines added at `:177-180` plus the flag take `_load` from 40 to 45 lines (guideline §3, about 40) → cut the comment to one line (the flag's doc at `:134-136` already gives the reason) or move the attempt marker into a named helper.
- **could** docs/briefs/m14/bugs14/f2-report.md:65 self-check 3 says "Paused is irrelevant: a wanted not-ready loop has no voice to pause", but `tick()` (`sound_watchdog.dart:85`) judges nothing while `paused()` is true and `SoundLoop.reset` (`sound_loop.dart:180-188`) keeps `_paused`, so a not-ready loop whose music the round paused is not restarted until the round resumes → state that limit in the report (a paused loop waits for the resume), or clear `_paused` when a load fails.
- **could** packages/party_host/lib/src/sound.dart:230 `isLoopWanted` is public in `src/` only so a test can reach it while every other rule in the file is private (guideline §3 public surface) → keep it private and reach it through the same fake-engine seam, or move the rule beside the wish it reads.

## Decisions to confirm

- Decision 1, the public static rule: a pure function, not a mutable hook, but it widens `src/` surface for the test alone; the finding above is the same point from the guideline side.
- Decision 3, the flag set when the load is tried, not when it ends: I checked the windows (first load not watched, restart's looks blocked by `busy`) and they do read the same; safe as written.
- Decision 5, no `start()` after a failed first load: the fix helps only after a restart, so a host whose engine never came up at startup stays unwatched until a `play()` throws — the report already asks this as question 1, and it is the remaining half of REVIEW finding 3.
- Decision 2, no `fake_async` dependency: correct as fact (`pubspec.lock:180` marks it transitive) and `testWidgets`'s fake clock keeps the test free of real time, so the brief's "or else" is met.

## Could not check

- Device behaviour: whether `soloud.init()` can fail after a restart, what a restart costs, and whether the music returns within a cooldown plus a period — code-read only, as the report says.
- The old-code run: I read the old `_isLoopWanted` (ready required) instead of checking out `f4020ea`; the new file does not compile against it at all, because `isLoopWanted` is new.
- "host 504 before": I saw 509 after; the before count is the report's.
- `docs/briefs/m14/bugs14/run-findings.md` does not exist, so there were no runner entries about f2 to weigh.

## Commit message

```
Review of bugs14 f2: the sound watchdog's gaps

Reads the f2 diff against the guidelines, the review rules and the brief:
verdict small fixes, no must, two shoulds (the player's wanted feed has no
test, and `_load` is 45 lines after a four-line comment) and two coulds
(the "paused is irrelevant" self-check line is not what `tick()` does, and
`isLoopWanted` is public only for the test). The rule, the `active` seam and
the five new tests hold; 11 and 509 tests pass here, analyze and format
clean. Adds no code.
```

## Status row

**bugs14 (Nov 15, fix batch after the run review):** f2 reviewed — the not-ready rule, the `active`
seam and the five watchdog tests hold (0 must, 2 should, 2 could: the untested player feed at
`sound.dart:181`, `_load` at 45 lines, and the paused case the report understates); still open: the
other REVIEW findings (a first load that fails is still unwatched, the fixed cooldown, the frozen check's
loop length), the f2 device check on the iPad, and the four decisions above.

## Delete

- none
