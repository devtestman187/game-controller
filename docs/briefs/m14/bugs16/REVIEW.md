# Run review: m14 bugs16 wave1 (one job, b031-stick-dispose)

## Summary

Verdict: **one fix batch**. The fix holds (4/4 new tests pass here, phone suite 532 PASS, format
0 changed), but one new test cannot fail on the old code and one rule that only the review caught
should be pinned by the runner.

Counts: 1 must, 4 should, 3 could.

The five that matter:
1. `stick_dispose_test.dart:113` — the normal-path test passes on the old code; the brief asks for
   the opposite in item 1 and for this test in item 1(c). Claude must rule.
2. `b031-stick-dispose-report.md:24` — "two failed on the old code" leaves out the whole-tree test.
3. `tools/run-jobs.sh:185` — the tests-first proof runs a new file whole, so one failing test covers for the rest.
4. `stick_widgets.dart:159` — the deferred release can still leave an uncaught async error.
5. `pad_widgets.dart:147` — D-pad and buttons keep the same stale-lift pattern sticks now survive.

Unverified fix (mark "Fixed, unverified: needs device check" in the batch): the whole B-031 fix —
no report measured a real thumb on a stick while a round ends on a device.

Questions only the owner can answer: none; the ruling in question 1 is Claude's (the brief
contradicts itself).

Fix-job sizing (≤3 findings, no shared files, one wave):
- Job A (docs, no `check:`): report:24, report:36, run.log:8.
- Job B (`phone`): `stick_widgets.dart`:103 and :159, plus a test in `stick_dispose_test.dart`;
  if Claude drops the must's test, it joins this job (same test file).
- Job C (`phone`): `pad_widgets.dart`:147 (and :283, `face_buttons.dart`:23) with its own test.
- Job D (no `check:`): `tools/run-jobs.sh`:185.

## Findings

- **must** controller_app/test/stick_dispose_test.dart:113 the normal down/move/up test passes on the old code, which review rule 4 and the brief's item 1 both call a must, while the same brief's item 1(c) asks for exactly this test → keep it as the named regression guard and have Claude record the exception in the brief (dropping it is the other option). (from: b031-stick-dispose; phone-pinned)
- **should** docs/briefs/m14/bugs16/b031-stick-dispose-report.md:24 "On the old code two failed" leaves out test 3 (stick_dispose_test.dart:100): it lifts a thumb after the whole tree is gone, so the old `_up` runs its `setState` after dispose exactly as in test 1 and should fail too → say three, or list which of the four were run against the old code. (from: b031-stick-dispose)
- **should** tools/run-jobs.sh:185 the tests-first gate runs a new test file whole, so one test failing marks the file proved and a test that passes on the old code never surfaces (the review had to catch it) → run the file once per test name, or report how many of its tests passed on the old code and fail on a mixed result. (from: across jobs)
- **should** controller_app/lib/src/ui/stick_widgets.dart:159 the deferred release body is guarded only by `_scope?.mounted`, so any throw from `pad.stick` (the client send, the pad's own providers) escapes as an uncaught async error and reports to Sentry, the class this job closes → catch at that boundary and log through `LogSink`, or skip the send when the client is gone. (from: b031-stick-dispose; phone-pinned)
- **should** controller_app/lib/src/ui/pad_widgets.dart:147 (also :283 and face_buttons.dart:23) the D-pad, the small button and the face buttons still take the pad notifier from a build and call it from a pointer lift, so a thumb down while the root scope goes throws `UnmountedRefException`, the case sticks now survive → give them the same mounted guard and release in a later wave. (from: b031-stick-dispose hand-over; phone-pinned)
- **could** controller_app/lib/src/ui/stick_widgets.dart:103 `_scope` is nullable yet declared `late final`, which buys nothing and would throw `LateInitializationError` from `dispose` if `initState` had failed → declare `State<ProviderScope>? _scope;`. (from: b031-stick-dispose; phone-pinned)
- **could** docs/briefs/m14/bugs16/b031-stick-dispose-report.md:36 "was 237" is 236 (`git show ca2af4a4:controller_app/lib/src/ui/stick_widgets.dart | wc -l`) → say 236. (from: b031-stick-dispose)
- **could** docs/briefs/m14/bugs16/run.log:8 the log says "8 finding(s)" for the wave but wave1-review-report.md lists 5 findings (9 with its decisions to confirm) → align the count or say what it includes. (from: across jobs)

## Open questions

- Brief item 1 (each test must fail on the old code) versus item 1(c) (a normal-path test) → keep test 4 and name it the exception in the brief.
- Is capturing the ancestor `ProviderScope`'s State wanted? → yes: it is the only liveness signal (`ProviderContainer.exists` stays true, `Notifier.ref` is protected).
- The deferred release lands after a `releaseAll`/`switchMode` a round end or mode change calls in the same frame; that order is untested → add one test that both leave the pad centered.
- `touched: false` is not visible in `PadInput`, so the metrics half of the release is untested → accept for now; a check needs an active metrics session.
- Which of the four tests were run against the old code? → three (1, 2, 3); test 4 passes by design.

## Numbers against targets

- New tests: 4/4 pass here; `dart format --set-exit-if-changed` 0 changed; `tools/check.sh phone` PASS, 532 tests, 47 s — all match the report's claims.
- Brief item 1 "each test must fail on the old code": not met (test 4 passes); `run.log:6` records only a file-level proof.
- `b031-stick-dispose-report.md:36` "was 237": actual 236.
- `run.log:8` "8 finding(s)" versus 5 findings in wave1-review-report.md.
- `run.log:5` 108 turns against the brief's "aim for 60-100 turns" (an aim, not a rule).
- Sizes: `stick_widgets.dart` 273 lines (limit 380), `stick_dispose_test.dart` 129 (limit 500).

## Could not check

- The per-test old-code runs: a read-only job may not revert `lib` or check out a worktree, so test 3's old-code failure is argued from the code, not run.
- The report's riverpod claims (`ProviderContainer.exists` after dispose, `Notifier.ref` protected) against the riverpod version in use.
- `tools/review.sh` (the report's "0 fail, 0 note") — not re-run.
- The device behaviour: a thumb on a stick while a round ends on an iPad.

## Commit message

Review the m14 bugs16 run: 1 must, 4 should, 3 could

One job ran (b031-stick-dispose): the fix and its four tests hold, but
the normal-path test passes on the old code, the report's "two failed"
leaves out the whole-tree test, and the runner's tests-first proof is
per file, so it cannot see a passing test among failing ones. Also the
deferred release can still throw uncaught, the D-pad and buttons keep
the stale-lift pattern, and two report/run.log counts are off.

## Status row

Bugs16 run reviewed read-only (b031-stick-dispose: fix and 4 tests hold, phone 532 PASS); open: 1 must (Claude's ruling on the normal-path test), 4 should, 3 could, and the device check.

## Delete

- none
