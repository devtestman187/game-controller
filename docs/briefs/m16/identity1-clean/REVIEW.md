# M16 identity1-clean: run review

## Summary

- Verdict: **needs Claude's design** (the StickPainter parameter limit needs a shape decision; the rest is one fix batch).
- Counts: must 1, should 4, could 5. Across-jobs items: 1 (listed with the could items).
- Hand-fixes: none. `run.log` has no `HAND-FIX` line. No per-job `*-review-report.md` exists; `cp-report.md` and `ct-report.md` exist.
- Top five:
  1. `stick_widgets.dart:201` `StickPainter` still has 7 named parameters against the limit of 5 (8 before the run).
  2. `pad_widgets.dart:191`, `:233`, `:334` and `stick_widgets.dart:199`: four doc comments still say the fill is "the player's colour"; the code now fills with the character's colour over the player's.
  3. `tilt_view.dart:42` still passes `player` and `character` separately: the pair `PadFill` now carries is passed loose on this one call site.
  4. `pad_drawing.dart:26`: `PadFill` `==` and `hashCode` have no direct test; the new `shouldRepaint` depends on them.
  5. `ct-report.md:1`: no Summary block (carried over from `run-findings.md`).
- Fix-job sizing (no shared files, one wave): job A = `pad_widgets.dart` doc fixes (3 findings, `phone`); job B = `stick_widgets.dart` doc fix plus the parameter design (2, `phone`); job C = `PadFill` test in a new file (1, `phone`). The `tilt_view.dart` call is a could and stays out unless Claude picks it.
- Owner questions: the StickPainter parameter shape; whether the tilt dot should take `PadFill`; whether the combined tools suite must pass before merge.
- Unverified: the `claude-worker-test.sh` turns cases were argued from `flash.sh:244`, not run with the line removed. The `selftest.sh` `FLASH_WORKER` unset was not reproduced in a combined run. Fixed, unverified: needs device check applies to neither (no device fix in this run).

## Findings

- **must** `controller_app/lib/src/ui/stick_widgets.dart:201` `StickPainter` has 7 named parameters (look, center, radius, value, active, faint, fill) against the 5 limit; it was 8 before the run → fold `center`, `radius` and `value` into one stick-geometry value object (Claude's design call) (from: cp; phone)
- **should** `controller_app/lib/src/ui/pad_widgets.dart:191` the `DpadPainter` doc says lit arms are "filled in this phone's player colour"; the code now uses the character's colour over the player's → reword to "the character's colour over the player's" (from: cp; phone)
- **should** `controller_app/lib/src/ui/pad_widgets.dart:233` the `_paintLitArms` doc says "the player's colour"; it now paints `fill.colour(...)` → reword to match `PadFill` (from: cp; phone)
- **should** `controller_app/lib/src/ui/pad_widgets.dart:334` the `SmallButtonPainter` doc says the pill is "filled with this phone's player colour"; it now uses `fill` → reword to match `PadFill` (from: cp; phone)
- **should** `controller_app/lib/src/ui/stick_widgets.dart:199` the `StickPainter` doc says the knob is "the player's colour"; it now uses `fill` → reword to match `PadFill` (from: cp; phone)
- **could** `controller_app/lib/src/ui/pad_drawing.dart:26` `PadFill` `operator ==` and `hashCode` have no test; `shouldRepaint` in three painters now relies on them → add a unit test in a new file (equal fills, differing player, differing character, null) (from: cp; phone)
- **could** `controller_app/lib/src/ui/tilt_view.dart:42` still calls `padPlayerColour(look.colors, player, character: character)` with the loose pair `PadFill` replaces; the cp brief kept the tilt dot out of scope, so this is consistent but leaves two ways to fill one concept → decide in Claude's design whether the tilt dot takes `PadFill` (from: across jobs; phone)
- **could** `docs/briefs/m16/identity1-clean/ct-report.md:1` has no `## Summary` block; the run's log flagged it at 09:53:14 and it still holds → add a Summary block to the report template or accept it as report-only (from: run-findings; not code)
- **could** `controller_app/lib/src/ui/pad_widgets.dart:236` names the local `litPaint` while `pad_widgets.dart:351` and `stick_widgets.dart:248` name the same kind of local `colour` → pick one name for the fill-colour local; no behaviour change (from: cp; phone)

## Open questions

1. How should `StickPainter` reach 5 parameters? Suggested: one stick-geometry value holding `center`, `radius` and `value`; `active`, `faint` and `fill` stay as named fields.
2. Should the `claude-worker-test.sh` turns cases be shown to fail with `flash.sh:244` removed? Suggested: yes, one scratch-copy run before merge; no repo change.
3. Keep the `selftest.sh` comment edit that goes beyond the one-line brief? Suggested: keep; the comment would be wrong otherwise.
4. Should `tilt_view.dart:42` move to `PadFill` in this batch? Suggested: no; leave the tilt dot as the brief scoped it.
5. Is the combined tools suite result needed before merge? `run.log` (09:43:04) starts it but logs no result. Suggested: yes, read its result before merge.
6. `docs/briefs/m16/identity1-clean/DRIVER-NOTES.md` is untracked. Suggested: keep it out of the run's commits.

## Numbers against targets

- `StickPainter` named parameters: 7 against the limit of 5 (miss; 8 before the run).
- `pad_widgets.dart`: 357 lines (358 at base). Above the ~300 guideline, under the 380 hard limit for touched files; not grown by this run.
- `stick_widgets.dart`: 274 lines. `pad_drawing.dart`: 88 lines. Under the limits.
- `pad_look_test.dart`: 293 lines; `pad_character_fill_test.dart`: 186 lines (tests limit 500). Under.
- `tools/tests/claude-worker-test.sh`: 181 lines; `tools/selftest.sh`: 275 lines. No stated target.
- Reported by the jobs (not re-run here): `pad_character_fill_test.dart` +26 passed; `pad_look_test.dart` +16 passed; `tools/mine.sh` OK 64 tests; `claude-worker-test.sh` 17/17 PASS (new turns cases: `turns: 50` gives `max-turns: 50`, `turns: 20` gives `max-turns: 35`); `tools/check.sh format analyze phone` PASS.

## Could not check

- No command was run for this review; the test counts above are the jobs' own reports.
- The combined tools suite result after `ct` and `cp` is not in `run.log`.
- Whether the turns test fails without `flash.sh:244`: not run (ct report says argued from code).
- Whether `FLASH_WORKER` unset in `selftest.sh` changes a combined run: not reproduced.
- Host setups other than the phone controller (TV and PC hosts): the change is in phone-only painters, read from the diff; not run.
- The `tv_test_app/windows/flutter/*` and `site/shots/*` working-tree changes at run start are outside this run's commits; not examined.

## Commit message — a draft

Record the identity1-clean run review (no code change)

Review of the run's commits 8e92b196 and 4e56e823 as one change. Writes
only this REVIEW.md. Findings: one must (StickPainter has 7 named
parameters), four stale painter doc comments, and a could list for
tilt_view and PadFill tests. Nothing else is changed.

## Status row

M16 identity1-clean run review: done (REVIEW.md written, verdict needs Claude's design). Open: StickPainter parameter shape, four stale painter docs, PadFill equality test, turns-test fail check, combined tools suite result.

## Delete

- none
