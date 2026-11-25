# f3 report: test fixes from the coach-marks and Home-marks reviews

## Summary

Test-only job. No lib file changed. Repair tests, so `tests-first: exempt` as the brief says.

Files changed:
- `controller_app/test/coach_marks_test.dart`: the once-only test after Skip now taps Skip, Skip again, then the step-1 box, and expects skipped 1, done 0. The test at :238 is renamed to "unmounting the marks after their first frame calls neither onDone nor onSkip", since the post-frame read has already run when it unmounts (the review's "rename" option).
- `controller_app/test/phone_home_marks_test.dart`:
  - "a saved showTips false shows none" gets a positive control: `showTipsProvider.notifier.set(true)`, then the marks appear.
  - "a client that is connecting shows none" gets a positive control: emit `ClientStatus.idle`, then the marks appear.
  - The tap-under-marks test expects `HomeText.tipPlay` after the tap on the role button, and no marks after Skip.
  - The :182 reason is now 'the pad alone must not overflow'.
  - Added the `home_prefs.dart` import for `showTipsProvider`.

Test results (`tools/mine.sh`, after the second run):
- Format: 2 files formatted. Analyze: controller_app clean (one `prefer_const_constructors` info at phone_home_marks_test.dart:99 was fixed with `const`, then re-run clean).
- Tests: OK, 40 tests across the touched files (mine.sh reports the total for both files together; I did not split the count per file).
- The positive controls were checked by reasoning only, not on the base: the base Home never shows marks, so both controls should fail there. I did not run the base.

Computed values: coach "tap after Skip" expects skipped 1, done 0. Home: the first tap moves the marks to `tipPlay`; Skip then leaves `_marks` at zero widgets.

Brief-vs-file note: the brief said the coach test "taps Skip, then Skip again, then the box". The file on disk taps `tipOne` first, then Skip, then `tipTwo`. I used the brief's sequence. The test still passes, and the second Skip is what catches a missing `_finish` guard.

## Decisions

- Coach test: kept the three-step sequence the brief gives, since a skip leaves the marks mounted in the test host, so the second Skip and the box are still tappable.
- Rename, not an unmount-while-read-pending test, for the :238 case (the brief allowed either).
- The tap-under-marks test relies on the tap on `joinGame` advancing the marks; it passed as written, so no change to the tap target was needed.

## Hand-over

Self-check (review-rules part A):
1. Hosts: this job touches only controller_app tests, so host setups are covered by the existing tests, not by new ones here.
2. Kept state: the new controls check the flag and the client status are read live; the saved flag is still asserted as null before the set.
3. Combinations: the tap-under-marks test shows the overlay takes the touch over a role button.
4. Stayed inside `allow:` (the two test files and this report). I also ran `tools/mine.sh`, which reverted 3 generated files under `tv_test_app/windows/flutter/` (see question 1).
5. No stop needed.
6. Looks: the overflow test at :182 still runs at the two sizes (menu and TV look).

## Commit message — a draft

Fix Home and coach-mark tests the reviews flagged as weak

- Coach: the after-Skip test taps Skip twice, then the box, and expects skipped 1, done 0
- Coach: renamed the unmount test to what it checks
- Home: positive controls for a saved showTips false and a connecting client
- Home: the tap under the marks expects the step-2 text, then Skip ends them
- Home: fixed the :182 overflow reason text
- Test-only change; lib is unchanged

## Status row

f3 (wave 2-789): coach-mark and Home-mark test repairs are done, and the 40 touched tests pass under mine.sh. Open: the base-run check that the new positive controls fail on the old code (not run here).

## Delete

- none

## Questions

1. `tools/mine.sh` reported "churn: reverted 3 generated file(s)". The three files (`tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `generated_plugin_registrant.h`, `generated_plugins.cmake`) were already modified at the start of the session, so the revert may have dropped uncommitted changes. Please confirm this is intended.
2. Should the base-run check (positive controls fail on the old code) be done by the runner, since I did not run the base?
