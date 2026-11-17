# Wave 1 review: b031-stick-dispose

## Summary

Verdict: **small fixes** — code and guards match the brief; the report's claim about which tests
fail on the old code does not, and one new test cannot fail on the old code at all.

Counts: 1 must, 1 should, 3 could.

- **must**: `stick_dispose_test.dart:113`, the normal down/move/up test, is the one new test that
  passes on the old code — the brief's rule and the review rule both forbid that.
- **should**: the report's "on the old code two failed" leaves out the whole-tree test (line 100),
  which by the same reasoning as the lift test should fail too.
- **could**: the release's microtask body has no guard beyond the scope check; `_scope` is `late`
  for nothing; the report's "was 237" is 236 lines.

Evidence I ran: `flutter test test/stick_dispose_test.dart` (4/4 pass), `dart format
--set-exit-if-changed` on both changed files (0 changed). Self-check item 3's "a double release
sends nothing" is true (`providers/pad.dart:127-130`: `!change.changed` returns after
`_recordHeld`), and item 3's "no other State class" is true (`StickModeView:18` is a
`ConsumerWidget`, `StickPainter:200` a `CustomPainter`).

## Findings

- **must** controller_app/test/stick_dispose_test.dart:113 the normal down/move/up test is the only new test that passes on the old code, against the brief's "each test must fail on the old code" (and the review rule that such a test is a must) → keep it as item 1(c)'s regression guard with Claude's recorded ruling that 1(c) is the named exception, or drop it.
- **should** docs/briefs/m14/bugs16/b031-stick-dispose-report.md:24 "On the old code two failed" leaves out test 3 (`stick_dispose_test.dart:100`): it lifts a thumb after the whole tree is gone, so the old `_up` runs its `setState` after dispose exactly as in test 1 and should fail too → say which of the four were actually run against the old code (three, unless one was not run).
- **could** controller_app/lib/src/ui/stick_widgets.dart:157 the microtask body calls `pad.stick` guarded only by `_scope.mounted`, so any other throw inside it (`phoneMetricsProvider`, the client send) leaves as an uncaught async error, the same class of Sentry issue this job fixes → name the remaining throw sources in the comment above, or check the pad before calling.
- **could** controller_app/lib/src/ui/stick_widgets.dart:103 `_scope` is nullable yet declared `late final`, so `late` buys nothing and would throw `LateInitializationError` from `dispose` if `initState` had failed → declare it as a plain `State<ProviderScope>? _scope;` (project-notes' `late final` rule is for fields that use `ref`).
- **could** docs/briefs/m14/bugs16/b031-stick-dispose-report.md:36 "was 237" is wrong: `git show ca2af4a4:controller_app/lib/src/ui/stick_widgets.dart | wc -l` is 236 (273 now) → say 236.

## Decisions to confirm

- The brief's item 1 (every test must fail on the old code) contradicts its item 1(c) (a normal
  path test): the worker took 1(c) and said so; only Claude can rule which one wins.
- Capturing the ancestor `ProviderScope`'s `State`: `controller_app/lib/main.dart:36` has the app's
  only `ProviderScope`, so the guard fires only when the app itself is torn down, where no TV is
  left to tell; it is there for the root-replacement test (test 3). Confirm the capture is wanted.
- The release is deferred to a microtask, so it lands after `releaseAll`/`switchMode` that a round
  end or a mode change may call in the same frame; that ordering is not tested.
- `touched: false` is not visible in `PadInput`, so the metrics half of the release is untested
  (the report says this at lines 112-114); confirm that is acceptable.

## Could not check

- The old-code runs: I did not revert `lib`; `run.log` says only "tests-first ok: … fails on the
  old code" for the file as a whole, not per test, so the report's per-test account rests on the
  worker's word.
- The full `phone` suite (532 tests) and the `tools/review.sh` result: not re-run here (the script
  needs approval); only the one test file was run.
- The report's riverpod claims (`ProviderContainer.exists` returning true after dispose, `Notifier.ref`
  being protected): not checked against the riverpod version in use.

## Commit message

Review wave1 b031-stick-dispose: one must, one should, three could

The fix matches the brief and its four tests pass here (4/4). The
report's "two failed on the old code" leaves out the whole-tree test,
which should fail the same way as the lift test, and the normal-path
test is the one that passes on the old code — both need a line from
Claude. The other three findings are the unguarded microtask body, a
`late` on a nullable scope field, and the report's old line count
(236, not 237).

## Status row

Wave1 b031-stick-dispose reviewed read-only (fix and 4 tests hold; 1 must, 1 should, 3 could in docs/briefs/m14/bugs16/wave1-review-report.md); open: Claude's ruling on the normal-path test that cannot fail on the old code, and the job's device check.

## Delete

- none
