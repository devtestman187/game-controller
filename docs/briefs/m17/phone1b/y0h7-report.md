# y0h7 report: a host pick is kept over resume; a phone pick is not

## Summary

Works through the wave-4 review items the brief lists (must: phone picks kept over resume; should: the "already
away" test without a wait; the 124-column dartdoc; the shop test name). Not covered: the review's first item, that
the `changes == 0` test passes on the old code; the brief does not name it. Three files changed.

- `ChoiceRound.pick()` keeps a pick made during a pause over `resume()`. The phone's own `ChoicePickMessage` no
  longer goes through `pick()`: `_onMessage` calls a private `_storePick()`, which stores the pick and does not
  record it as picked-while-paused. A phone that picks during a pause and drops is now defaulted after the resume.
- The 124-column dartdoc line (near `choice_round.dart:39`) is rewrapped onto three `///` lines, all under 120 columns.
- `pick()`'s dartdoc gains the sentence on the pause rule.
- The "already away when the pause starts" test waits, for at most 2 s, on the server snapshot until phone-1 shows
  disconnected, before `pause()`. It no longer has a fixed delay.
- The shop test name no longer says "by default", and keeps the `defaultId == 'save'` assertion.
- A new test: a phone pick during a pause, then a drop, then resume, then the grace: the player is defaulted.

Test counts: `tools/mine.sh` ran 64 tests in packages/connection, all passing; 3 files formatted; 1 package analyzed.

## Changes by file

- `packages/connection/lib/src/choice_round.dart`: `pick()` now calls `_storePick()` and adds to `_pickedWhilePaused`
  only for a stored pick made while paused. `_onMessage` calls `_storePick()`. Dartdoc rewrapped and extended.
- `packages/connection/test/choice_round_pause_test.dart`: new constants `_pollLimit` (2 s) and `_pollStep` (10 ms);
  new helper `_untilAway()`; "already away" test uses the poll; new test
  "a phone pick during a pause does not stop its player being defaulted after a drop and resume".
- `packages/connection/test/choice_round_test.dart`: test name at line 324 changed; assertion at line 331 kept.

## Checks

- Phone-pick test values: after the pause the phone sends `ChoicePickMessage(round: 7, pick: 'build', count: 2)`;
  resume starts a grace of 300 ms (`_graceMs`); expected outcome `ChoiceOutcome(cardId: 'save', count: 1, byDefault: true)`.
- Fails on the old code: I reasoned it from the code, not run. Old `pick()` added the phone's pick to
  `_pickedWhilePaused` (old line 145), so `resume()` started no away timer for phone-1. `_untilLocked` then times out
  after 5 s (`_waitLimit`), so the test fails. I did not revert the library to watch it fail (that is the churn check
  in `mine.sh`, which passed, but I did not read its output for this test).

## Decisions

1. The phone-pick rule: only `pick()` (the public call) is a host pick; `_onMessage` uses `_storePick()`. That is
   the owner's rule as the brief states it.
2. The "already away" wait polls the server snapshot. `ChoiceRound` has no public signal that it has handled a drop,
   and its `_connected` set is private. So the poll shows the snapshot changed, not that the round handled it. The
   round subscribes to the server's changes in `start()`, before the test drops phones, but I have not measured the
   order of delivery.
3. The shop test name: "has the Save +2 default set" replaces "gets Save +2 by default". The test does not check
   `byDefault` through a public path before the pick; the brief asked to drop the claim, not add a check.

## Self-check (review-rules part A)

1. Host setups: the change is in `ChoiceRound`, which runs on the host only; the phone-pick test uses a capable phone
   (`phone-1`) and the old phone (`phone-2`) is left unchanged. Not covered: TV host vs phone host (no change to setup).
2. Kept state: `_pickedWhilePaused` is cleared in `resume()` (unchanged); it is only added to while paused.
3. Combinations: pause + phone pick + drop + resume is the new test; host pick during pause (existing test at line 203)
   still passes under the new code by reading (not separately run).
4. Files: only the three allowed.
5. Nothing stopped.
6. No look or layout changed.

## Hand-over

Not checked: the fail-first run of the new phone-pick test on the old code (reasoned, not run). The order of change
delivery under the snapshot poll (not measured).

## Commit message — a draft

Keep a host pick over resume; defaults a phone's pick

Only the public pick() marks a pick as kept over a pause. A phone's own
ChoicePickMessage no longer does, so a phone that picks during a pause
and then drops is defaulted after the resume, as the rule says.
The "already away" pause test now polls the server snapshot (max 2 s)
before pausing instead of using a fixed delay. Rewraps a 124-column
dartdoc line; the shop test name no longer claims a byDefault check.

## Status row

phone1b y0h7: done: host pick kept over resume, phone pick not; "already away" test polls the snapshot; new phone-pick test (fail-first reasoned, not run). Open: fail-first run of the new test; the round's own handling of a drop is not observed by the test.

## Delete

- none
