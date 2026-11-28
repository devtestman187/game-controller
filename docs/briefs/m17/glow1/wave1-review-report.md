# glow1 wave 1 review (g1, c1)

## Summary

Verdict: small fixes
Counts: must 1 · should 3 · could 3
1. must: `Match.snapshot()` passes `golden` (match.dart:338) and no test would fail if that line were removed.
2. should: the c1 "not replayed" assertion (present_pop_widgets_test.dart:158) passes even if a pop were replayed on resume.
3. should: puzzle_screen.dart grew by 1 line (379 → 380), not 0 as c1 reports, because of an unasked comment rewrap and a split `Positioned.fill`.

## Findings

- **must** packages/puzzle_game/lib/src/match.dart:338 `golden: golden,` in `Match.snapshot()` is untested: the five tests in golden_snapshot_test.dart build `MatchSnapshot` by hand, so deleting this line leaves them all passing and the target never reaches a frame → add a test that a split match's `snapshot()` carries its `golden` value.
- **should** packages/party_host/test/present_pop_widgets_test.dart:158 the "not replayed" check pumps `popTime` (1500 ms) after the resume, and a burst replayed at resume would also have ended by then, so the assertion passes with a replay → after the resume, pump 1 ms and expect `findsNothing` there, so a replay (which would show at once) fails the test.
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:354 the brief said `PresentConfetti(...)` on one line with net growth 0; the worker split `Positioned.fill(` over three lines (353–355) and rewrapped the unrelated comment at 357–358, so the hunk is +1 line (file 379 → 380) and c1-report.md:13 says "net growth 0" → put `Positioned.fill(child: PresentConfetti(tracker: _present, paused: paused)),` back on one line and restore the original comment wrap.
- **should** docs/protocol.md:334 the new frame key `gd` is not documented, while the `cat` key on the same line is (the a2-cat job added its keys to protocol.md, docs/briefs/m14/a2-cat-report.md:175) → add one sentence on `gd` (the golden target's index, absent while none) beside the `cat` text. This file is outside g1's `allow:`, so Claude decides.
- **could** docs/briefs/m17/glow1/c1-report.md:23 "The remaining 1300 ms" is wrong: after 200 ms frozen and 500 ms resumed, 700 of 1500 ms have run, so 800 ms remain → write 800 ms.
- **could** packages/party_host/test/present_pop_widgets_test.dart:131 and :147 `paused.dispose()` sits at the end of each test body, so a failed `expect` leaks the notifier → register it with `addTearDown(paused.dispose)` after creating it.
- **could** packages/party_host/test/present_pop_widgets_test.dart:25-43 `pausableStage` repeats `stage` except for the `ValueListenableBuilder` → let `stage` take an optional paused notifier instead of a second helper.

## Decisions to confirm

- c1: a pop during a pause is dropped, not queued (present_pop_widgets.dart:85). The brief did not say; the held line still updates from the tracker, so only the burst is lost. Owner to confirm.
- g1: `gd` is added to the shared frame with no `MatchSnapshot.version` bump and no capability (snapshot.dart:325-328). An older phone's behaviour with the key was not checked (see Could not check). Claude to confirm the no-bump choice.
- c1: the parameter is named `paused`, an adjective, as the brief named it. The worker extract's rule "booleans ask a question" was not found in docs/coding-guidelines.md, so it was not applied here.

## Could not check

- Test counts in the runner's output: mine.sh reported "OK 14 tests" for c1, but present_pop_widgets_test.dart has 13 test declarations (12 in the two-look loop plus one); "OK 6 tests" for g1, but golden_snapshot_test.dart has 5. docs/briefs/m17/glow1/run.log holds no counts. Not re-run (review is read-only).
- Whether a phone one build older ignores the `gd` key (rule B7): the phone's frame decoder is not in the diff and was not read.
- Whether `Pausable`'s `paused` also covers host away and "Get ready" (c1-report.md question 2): `Pausable` was not read.
- The frozen burst's look on the TV at distance: needs a device.
- Tests-first for c1 is exempt in the brief; no base run was made for it.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

docs(glow1): record the wave 1 review of g1 and c1

Review of the g1 (golden target in the snapshot) and c1 (confetti freezes
during a pause) jobs against the guidelines, review rules and briefs.
Findings only: the fixes (a match snapshot test, a replay check that
shows a replay, the puzzle_screen line count, protocol.md's gd key) go
to the owner's next jobs. No code changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- glow1 wave 1 review (g1, c1): done: reviewed; verdict small fixes (1 must, 3 should, 3 could). Open: the must (match.dart snapshot test), the should items (replay check, puzzle_screen line count, protocol.md gd key), and the owner's decisions (pop dropped during pause; no snapshot version bump for gd).

## Delete

- none
