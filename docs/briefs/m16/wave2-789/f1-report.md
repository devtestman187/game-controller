# f1 report: coach marks review fixes

## Summary
- Stopped at item 2(e): the anchor re-read that the brief asks for does not make it pass. The brief's item 1 (LayoutBuilder schedules the read) is done as written, but a host setState that moves the anchor does not rebuild or relayout the overlay, so nothing schedules a read. Test (e) is held back from the file (it was red before and after item 1); its text is below. Needs a design choice (see Questions).
- Done: item 1 (builder schedules the read; the read in `build` removed as redundant; dartdoc on both public constructors), items 2(a) to 2(d) (four tests), item 3 (n8c-report.md corrected).
- Tests: `tools/mine.sh` on controller_app: format ok, analyze no findings, 22 tests OK.
- Red run on the base code (before the lib change): (e) failed, box top 68.0 vs expected 108.0. After item 1: the same failure (68.0), so item 1 alone does not fix (e).
- Tests-first: (a) to (d) are exempt per the brief (they pin behaviour that was already correct); the (d) Skip test was first written with a wrong finder and corrected before the lib change.

## Decisions
- Anchor step 2(a) test uses the 640x360 menu look, step 3 (the bottom right anchor), not the 568x320 TV look (no room; the arrow is dropped there).
- The arrow check finds a CustomPaint of the arrow's size (`coachArrowWidthDp` x `coachArrowHeightDp`); the test file cannot see the private painter types.
- `pumpMarks` now takes a `Phone` value object (screen, look, text scale) and `settle`, so it has five parameters with the tester (was six).
- `_Host` stays stateless (the stateful version was only for the held-back test and was reverted).
- The once-only test after Skip taps the visible text (`tipTwo`), since the marks are still on step 2 after Skip.

## Blocked
- Item 2(e) (an anchor that moves without CoachMarks rebuilding: the hole follows it). The brief expected item 1 to make it pass; it does not. Measured: after the host moves the first anchor down to top 40 dp (anchor 40–88 dp, hole 32–96 dp), the box top is 68.0 (= 48 + 8 + 12, the old position); expected 108.0 (= 96 + 12). Same on base and after item 1.
  - Why: `LayoutBuilder` rebuilds only when its own constraints change. The host's setState rebuilds only the host, and the overlay's constraints do not change.
  - Test text, to add back when the mechanism is chosen (needs `_Host` as a StatefulWidget with a `moveFirstAnchor(double topDp)` method that calls setState and wraps keys[0] in `Padding(top: ...)`):
    ```dart
    testWidgets('when the host moves the first anchor down the box moves down with it', (tester) async {
      final keys = [GlobalKey(), GlobalKey(), GlobalKey()];
      await pumpMarks(tester, phone: const Phone(screen: Size(640, 360)), anchors: keys);
      tester.state<_HostState>(find.byType(_Host)).moveFirstAnchor(40);
      await settleMarks(tester);
      final box = tester.getRect(find.byType(party.ToyCard));
      final anchor = tester.getRect(find.byKey(keys[0]));
      expect(anchor.top, 40);
      expect(box.top, anchor.bottom + coachHolePaddingDp + coachArrowHeightDp, reason: 'box $box, anchor $anchor');
    });
    ```
  - Mechanisms, for Claude to choose: (1) read the anchor each frame while the marks show (a post-frame loop with scheduleFrame; costs a frame per tick); (2) the host rebuilds CoachMarks when it moves an anchor (the simplest; a contract on the caller, and CoachMarks is not wired yet); (3) a listener on the anchor's render object (Flutter's RenderBox has no move notification, so this needs a wrapper around the host's anchor, which is outside allow).

## Computed values (expectations)
- 2(a), 640x360 menu look, step 3, anchor bottom right 80x48 (x 280–360, y 312–360): hole 304–368 (padding 8), roomBelow = 360 − 16 − 368 − 12 = −36, roomAbove = 304 − 16 − 12 = 276, so the box is above; box bottom = 304 − 12 = 292 (computed, not printed). Expectation: box bottom ≤ anchor top 312. Passed.
- 2(b), 640x360 menu look, step 1, anchor top left (x 0–80, y 0–48): hole −8–88 × −8–56; box below; box top = 56 + 12 = 68 = 48 + 8 + 12. Expectation: box top = anchor bottom + 8 + 12 = 68; arrow of 24x12 present. Passed.
- 2(c): after the unmount no exception, onDone 0, onSkip 0. Passed.
- 2(d): tap after onDone (scrim taps at 284,5): onDone stays 1, onSkip 0. Tap after Skip (box text): onSkip stays 1, onDone 0. Passed.
- 2(e) (held back): box top 68.0 measured; 108.0 expected; box then Rect.fromLTRB(16.0, 68.0, 185.3, 177.0).

## Files changed
- `controller_app/lib/src/home/coach_marks.dart` (357 lines): the `LayoutBuilder` builder calls `_scheduleRead()` (with the mounted guard in the post-frame callback unchanged); the read in `build` removed as redundant; one-line dartdoc on `CoachStep` and `CoachMarks`.
- `controller_app/test/coach_marks_test.dart` (331 lines): `Phone` value object; `pumpMarks` takes `phone`, `settle`; new groups for the box side, the stop cleanly/no second callback tests; `paintSizes` helper; the three existing `pumpMarks` call sites moved to `Phone`.
- `docs/briefs/m16/wave2-789/n8c-report.md`: 124/76 corrected to 100/100 (hole 128–192 dp); tests-first stated as not done; part A self-check; check results (the n8c log is not in this worktree, so its results are not cited).
- `docs/briefs/m16/wave2-789/f1-report.md`: this report.

## Checks
- Red run on the base (before the lib change): 1 failure, test (e), box 68.0 vs 108.0. A Skip-test finder error (test bug) fixed.
- After item 1: test file 22 pass, 1 fail (e), same numbers.
- `tools/mine.sh` (final): format ok (2 files formatted by the script), `dart analyze` controller_app: no findings, 22 tests OK.
- `mine.sh` also reported "churn: reverted 3 generated file(s)": files I did not edit (generated by the Flutter tool run); the revert is the script's.

## Hand-over
- The worktree's `controller_app/pubspec.lock` may have been re-resolved by `flutter test` (the first run printed a dependency resolve); check it before committing.
- No commit made; nothing staged.

## Questions
1. Which mechanism for the anchor that moves without a rebuild: (1) a per-frame read while the marks show, (2) the host rebuilds CoachMarks when it moves an anchor, or (3) a wrapper on the host's anchor (outside allow)? Recommend (2): the caller already owns the anchors, and nothing is wired yet.
2. Should the held-back test (e) be added back once the mechanism is chosen? Its text is above.
3. The n8c format and analyze results: `flash-n8c.log` is not in this worktree; can someone supply it or should the n8c check be re-run?

## Suggestions
- The n8c job could have written the test for the anchor move first; that would have shown the gap in item 1 before the fix.
- `coach_marks.dart` is 357 lines: the hint box and the arrow are separate responsibilities; split them when the next change touches the file (the review noted this).

## Commit message
coach_marks: re-read the anchor on layout changes; add 6 tests

The LayoutBuilder builder now schedules the anchor read, so a layout change
of the overlay reads the anchor again. New tests: the bottom right step's
box sits above its anchor, the top left box sits below with an arrow,
unmounting before the read calls nothing, and no second onDone or onSkip
after the end. An anchor that moves without the marks rebuilding is not
re-read yet; that test is held back (see f1-report.md).

## Status row
n8c coach marks review fixes: report corrected (100/100 dp, tests-first not done, part A self-check, 22 tests), anchor re-read on layout change, tests (a) to (d) added and green. Open: an anchor that moves without a rebuild is not re-read (needs a mechanism choice; test (e) held back, red), and the n8c format/analyze log is not in this worktree.

## Delete
- none
