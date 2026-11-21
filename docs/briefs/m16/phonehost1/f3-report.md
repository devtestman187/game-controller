# M16 phonehost1 f3 — ScoreRow's zero rules, RoundSegment's disabled state, a screen-reader tap

## Summary

- Tests first: `packages/party_host/test/score_row_test.dart` (3 tests) and
  `packages/party_host/test/round_segment_test.dart` (2 tests), both new files.
- The semantics test failed on the old code for the bug's reason: the chip's `Semantics` node reported
  `hasAction(SemanticsAction.tap) == false`, because the tap sat under `ExcludeSemantics` (finding 10).
- Fix (finding 10 only): `round_segment.dart` passes `onTap: onPressed` to the chip's `Semantics`, which is
  null for a disabled segment, so a screen reader finds a button it can press and a night under way offers none.
  Five lines added (one statement, one comment); the file is 139 lines.
- `score_row.dart` is unchanged: the `delta == 0` and `maxPoints <= 0` rules already behave as the brief says, and
  the new tests now lock them (they pass on the unmodified file — no real bug found).
- Checks: `tools/check.sh format analyze host` → PASS format, PASS analyze, PASS host (657 tests, second run).
  The first host run had one fail, `live_stats_share_test` (review open question 13's known flake, outside this
  job's `allow:`); it passes alone and in the rerun. `tools/review.sh` → 0 fail, 0 note.

## What each test proves

`score_row_test.dart` mounts one row at the width a card gives it, 960 - 2 x 24 = **912** frame px.

1. **a row with nothing to add shows no "+0"** — a `delta: 0` row (`points: 30`, `maxPoints: 30`) draws no `+0`
   anywhere, still draws the score `30`, and throws nothing, so the `if (delta != 0)` rule keeps a final-scores
   card free of zeroes (finding 5).
2. **a row with a round's points shows "+3"** — a `delta: 3` row draws exactly one `+3` and one `25`, so the delta
   text is `'+$delta'` and appears once, not once per point.
3. **a card with no points yet draws an empty bar and never divides by zero** — `points: 0`, `maxPoints: 0` gives a
   bar whose fill has `widthFactor: 0.0` and a rendered width of **0.0**, with no exception. Without the
   `maxPoints <= 0` guard the share is `0 / 0` = NaN, which would break the bar's layout; the test fails on that
   (found by reading `_share`, not by running the old code, which already guards).

`round_segment_test.dart` mounts a segment choosing the "5 rounds" chip in a bare `MaterialApp`.

4. **a screen reader presses a chip and picks its option** — with semantics on, the chip's node says the label
   `3 rounds` and has `SemanticsAction.tap`; `tester.semantics.tap` on it then calls `onChanged` with `3`, the
   tapped chip's own value (not the chosen 5). Fails on the old code at the `hasAction` line (finding 10).
5. **a segment with nothing to change calls nothing and takes no focus** — the same tree is first built with a
   recording callback, then rebuilt with `onChanged: null` ("the night already under way"): a tap calls nothing
   (the callback it had is not kept), an arrow key plus Enter leave the primary focus outside the `RoundSegment`,
   nothing throws, and the chip's semantics node has no tap action (finding 11). Passes on the old code too, as
   the brief expects.

## Decisions

1. **`onTap` on the `Semantics`, not a second gesture.** `onPressed` is the one callback the chip already holds
   (null when disabled), so the screen reader and the thumb reach the same handler; there is no second path to
   keep in step.
2. **The semantics test taps the unselected chip.** Tapping "3 rounds" while the value is 5 would fail if the
   segment ever reported its own value instead of the tapped one.
3. **The disabled test rebuilds in place.** Building enabled first and then with `onChanged: null` proves the
   dropped callback, which merely building with null cannot show.
4. **`score_row.dart` stays as it is.** The brief allows a change only for a real bug; the two rules hold, so the
   tests document them (guidelines §9: a bug fix starts with a failing test; there is no bug here).
5. **The row's width comes from the consts:** `960 - 2 * hostFrameGutterPx` = 912, with the 960 in a documented
   test const, because the frame's design size is not exported (review finding 17).
6. **Each test file carries its own small pump helper** (`ProviderScope` + `ToyLookScope` above `MaterialApp`,
   as `host_frame_screen_test.dart` mounts them) rather than moving the harness to `test/support/`, which is
   outside this job's `allow:`.

## The values the tests assert

- Row width 912 frame px; name column 190, badge 38, rank 32, bar height 16, star 24, delta text at
  `ToyType.frameSmall` (20 px).
- Bar fill with `maxPoints: 0`: fraction `0.0`, drawn width `0.0` (the FractionallySizedBox inside the bar).
- Delta text: `'+3'` for `delta: 3`, absent for `delta: 0`.
- Chip label `'3 rounds'`; a semantics tap reports `[3]` for options 3 and 5.

## Self-check (review-rules part A)

1. **Every host setup** — the change adds an accessibility action to a chip that reads only the look and the host
   focus look; a TV/PC host, a phone on "Play on this phone" or "Show on this device" and a joined phone all draw
   the same widget, and no app uses `RoundSegment` yet. A host one build older is unaffected: no message, file or
   protocol changed. Proven by both `round_segment_test.dart` tests (no provider overrides needed).
2. **When kept state starts and ends** — nothing is held, timed or counted: the chosen value is the caller's, and
   the only state is each chip's focus, which ends when the focus leaves. Proven by "a segment with nothing to
   change calls nothing and takes no focus" (the focus is outside the segment at the end).
3. **How a new state combines with the others** — the only state here is "the segment is disabled", owned by the
   caller; the widget adds no pause/hide/wait of its own, so it combines with the pause menu, a player away or the
   results exactly as before. Proven by the same test: disabled chips take no tap, no Enter, no focus and no
   semantics tap, so nothing can be changed while a round is under way.
4. **Stay in the job's folder** — `git status` shows my three Dart files and this report; `run.log` and
   `tv_test_app/windows/flutter/generated_plugin*` were touched by the tooling, not by me.
5. **Stop rather than overstep** — nothing outside `allow:` was needed. `score_row.dart` was left unchanged as the
   brief says; no design question came up.

## Suggestions (not acted on)

- The disabled test would read better if `ensureSemantics` could be torn down with `addTearDown`; Flutter 3.47
  verifies the handles before tear-downs run, so each test disposes its handle as its last statement.
- A future slice could give `RoundSegment` a `SemanticsHint` or an "unavailable" state for a night under way, so
  TalkBack says why the chips don't press.
- The four score bars' rule could be shown once with a made-up card (points 30/25/0) instead of one row at a time,
  if a screen test ever needs it.

## Hand-over

- f3 is complete: findings 5, 10 and 11 are covered, and finding 10's fix is the only `lib/` change.
- `score_row.dart` needs no fix; its zero rules are now guarded by three tests.
- Nothing else is open in this job; findings 1, 2, 3, 4, 6, 7, 8, 9, 12-18 are other fix jobs' (A, B, E, F, G and
  the second wave).

## Commit message

Test ScoreRow's zero rules and RoundSegment's disabled state

- Pass the chip's own callback to its Semantics as onTap, null while the
  segment is disabled, so a screen reader can press a chip (finding 10);
  before this the tap sat under ExcludeSemantics and TalkBack found a
  button that did nothing.
- New score_row_test.dart: delta 0 draws no "+0" and throws nothing,
  delta 3 draws "+3", and maxPoints 0 gives an empty bar (0.0 fraction,
  0.0 wide) rather than a divide by zero.
- New round_segment_test.dart: a semantics tap on the unselected chip
  reports its own value (fails before the fix); a segment rebuilt with
  onChanged null takes no tap, no Enter, no focus and no semantics tap.

## Status row

phonehost1 f3 done: ScoreRow's zero rules tested (3 tests, no code change) and RoundSegment's disabled state and screen-reader tap tested (2 tests), with the Semantics onTap fix (findings 5, 10, 11). Open: the other fix jobs' findings (1-4, 6-9, 12-18) and the second wave.

## Delete

- none
