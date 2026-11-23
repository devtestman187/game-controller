# M16 w4f: a dropped player's colour and accessory stay reserved for the reserve minute

Status: stopped before any edit. No file was changed.

## Summary

- Stopped at the time seam. The brief says to time the new reservation "through the host's clock seam as the other host tests do" and to use the host `nowMs` seam. The code has no such seam that a test can drive.
- `HostServer` takes its clock from a private `final _clock = Stopwatch()..start();` (host_server.dart:96), read through `int get _now` (:248) and `nowMs` (:89-90). There is no constructor parameter, no `helpers.dart` hook, and no fake clock in any identity test.
- The other host tests do not fake time. `identity_rows_test.dart:11` uses a real `Duration(minutes: 1)` grace and says the tests "end an away slot themselves, never by the clock".
- A test of "after the minute it gets it" with the real clock would need a 60-second real wait. G9 forbids real time ("no real time (fake clocks, injected nowMs)"), so that test cannot be written as the brief asks.
- The number reservation in `host_pairings.dart:181` uses `DateTime.now()`, not `nowMs`. The brief says the colour minute should match "the same minute" as the numbers, so the two minutes would run on different clocks unless the numbers change too. The brief excludes changing numbers.
- Because the tests-first rule (G9) applies, I did not write the production change ahead of a failing test. The change (items 1-4) is small, but I could not write item 5 as specified, so I held all edits.

## What I read

- docs/briefs/m16/identity1-w4/w4f.md
- docs/briefs/templates/COMMON.md
- packages/connection/lib/src/host_character_reservation.dart (1-51)
- packages/connection/lib/src/host_server.dart (89-90, 96-100, 248-260, 336-376; 376 lines in all)
- packages/connection/lib/src/host_pairings.dart (178-193)
- packages/connection/test/identity_reservation_test.dart (1-60, 115-140)
- packages/connection/test/helpers.dart (33-50)
- packages/connection/test/identity_rows_test.dart (1-12)
- docs/protocol.md (118-126)

## Decisions

- No edits. The brief needs a design decision that is not mine to make (see Questions 1 and 2).
- Checks not run: `tools/check.sh format analyze connection` was not run, since there is no change to check. The lib and test files are unchanged, so the baseline is the committed tree.

## Questions

1. Add an injectable clock to `HostServer` for tests? For example, a constructor parameter `int Function() clockMs` that defaults to the Stopwatch, passed through `startHost` in helpers.dart. That touches host_server.dart (one parameter line, one field) and helpers.dart, which is not in `allow:`. Which do you want: (a) add the seam and allow helpers.dart, or (b) another approach?
2. Should the colour minute use the same clock as the numbers (`DateTime.now()` in host_pairings.dart:181), or `nowMs`? The brief says "the same minute", but it also says to use `nowMs`. Choosing `nowMs` for colours alone leaves the two minutes on different clocks.
3. Is a real 60-second wait in one test acceptable as a fallback? G9 says no. I recommend against it.

## Suggestions

- Option (a) in Question 1 is the smallest path. With it, the test can set the clock to 0, drop P2, and move it to 60,000 ms and 59,999 ms, so the boundary is checked without real waiting.
- If the seam is added, `RecentCharacters` can take `now` as a plain argument in `note` and `takenAt`, which keeps the class free of the server clock.

## Expected changes once the question is answered

- host_character_reservation.dart: `final class RecentCharacters` and `HostServer._sessionEnded(session)` (items 1 and 3).
- host_server.dart: one field line and `_SessionHost.sessionEnded` calls `_server._sessionEnded(session)` (item 2). The file stays under 380 lines (376 now, plus one line).
- docs/protocol.md:122: one sentence that colour and accessory stay reserved for the same minute (item 4).
- identity_reserve_minute_test.dart: new file, fails on the old code (item 5).

## Self-check (review-rules part A)

- Not applicable: no code was changed. No host setup, state, look or test was added.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

(none: no change made)

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 w4f: stopped before edits. Open: the host has no test clock seam (HostServer clock is a private Stopwatch) and the colour minute and number minute use different clocks; decide Q1 and Q2 in w4f-report.md.

## Delete

- none
