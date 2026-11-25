# Review of n7a (awards flow test), commit 90b0713f

## Summary

- Verdict: **needs Claude**
- Counts: 1 must, 3 should, 2 could
- Top 3:
  1. `night_awards_flow_test.dart:128` leaves a `BISECT-TEMP` early return in the reveal loop. Every reveal check and every final-score check after it never runs, so the report's "debug block removed" claim is false and the no-tie tests assert only the start card.
  2. The tie rule (PRD item 7: tied players each get the award) has no running test. Both tie cases are `skip: true`, and the lib defect behind the skip is unproven (the report says the exception text was never read).
  3. The `mine.sh` churn revert (`tools/churn.sh:43-60`) ran `git checkout --` on three uncommitted `tv_test_app/windows/flutter/` files. They still show as modified now, so the report's account cannot be confirmed here.

## Findings

- **must** packages/party_host/test/night_awards_flow_test.dart:128 `if (i == 0) return; // BISECT-TEMP` ends the reveal loop before any check, so lines 129-157 (reveal names, reasons, `+3 points`, the scoreboard, `awardsWonBy`, `nightTotal-` totals) never run for the no-tie and phone-host tests → delete line 128, run the file, and fix whatever then fails.
- **should** packages/party_host/test/night_awards_flow_test.dart:164-166 and :180-181 Both tie cases are skipped, and the skip comment gives no file:line for the lib fault (the report gives only "around lines 179-191") and no exception text → have the driver read the flutter log for the tie reveal and put its file:line and exception in the comment before the tests are left skipped.
- **should** packages/party_host/test/night_awards_flow_test.dart:100-158 `_playNight` is about 59 lines against the ~40-line guideline → move the reveal-check loop (127-142) and the totals check (144-157) into named helpers.
- **should** tools/churn.sh:43-60 (run by tools/mine.sh:89-90) The n7a run reported "reverted 3 generated file(s)", i.e. it discarded uncommitted edits to `tv_test_app/windows/flutter/generated_plugin_registrant.cc`, `.h` and `generated_plugins.cmake` → the owner should confirm whether those edits mattered; the report's "I cannot restore them" needs a decision, not a change from this review.
- **could** packages/party_host/test/night_awards_flow_test.dart:135 `_names[id]!` uses `!` on a map lookup with no line proving the key exists → use a `final name = _names[id]; expect(name, isNotNull)` or a non-null map type.
- **could** packages/party_host/test/night_awards_flow_test.dart:132 `'Not won tonight'` is a literal that duplicates `NightText.notWon` (`packages/party_host/lib/src/text/night_text.dart:53`) → use the constant if the testing barrel exports it; keep the literal only if it is meant to pin the wording.

## Decisions to confirm

- Line 140: the missed reveal waits `nightAwardMissedRevealMs` (2000 ms), not `nightAwardRevealMs` as brief item 1 says. The report does not list this choice; it matches the reveal's own timing (`night_reveal_screen.dart:88`), so it is probably right, but it should be stated.
- Lines 84-91: `_noTieNight` replaces the old missed night, so the only tie case left in the file is skipped. The report asks this as question 2; the owner should decide whether a running tie case is required before this job is accepted.
- Lines 164-166 and 180-181: the two `skip: true` tests rest on an unread exception. The owner should confirm the skip is acceptable under brief item "stop" before it is merged.
- Line 176-178: the phone-host case runs in the menu look only. Brief item 3 asks for 640x360 as a phone host and does not name a look; the report says so, so this is only for the record.

## Could not check

- The run itself: I did not run `tools/mine.sh` or `flutter test` (read-only job). The report's "file's tests pass" is unverified, and it cannot be true for the file as committed, because the early return runs only the start card.
- Whether removing line 128 makes the no-tie and phone-host tests pass: the reveal and totals checks have never run.
- The tie-reveal exception text (not read by the worker or here).
- Whether the three `tv_test_app/windows/flutter/` files were discarded: `git status --short` still shows them as modified in this tree, so either the run used another checkout or they were modified again; the report's account is unconfirmed.
- PRD item 7 wording: not read; the tie rule is taken from the brief.

## Commit message — a draft

test(party_host): the awards flow from start card to final scores (n7a)

Pins the awards from the start card through the reveal to the final
scores, for a night with no tie, in both looks and as a phone host at
640x360. Tie cases are skipped pending a reveal fix (driver).

## Status row

n7a review: needs Claude. Open: remove the BISECT early return (line 128) and run the no-tie tests; the tie cases stay skipped until the reveal fault is read; confirm the churn revert of three tv_test_app generated files.

## Delete

- none
