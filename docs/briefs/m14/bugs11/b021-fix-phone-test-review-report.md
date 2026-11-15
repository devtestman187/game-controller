# b021-fix-phone-test review

## Summary

Verdict: `small fixes`. 0 must, 1 should, 3 could.
The diff is the three briefed items and nothing else: the waiting-card check
(test line 44), `setUpAll(loadLookFonts)` (line 16) and the comment fix
(night_start_screen.dart:74). All three items done; format clean; the file
passes and `tools/check.sh host` passes (472 tests now).
The findings are about what the change and the report claim, not what they do:
the report's Summary says the test measures the card and that fonts make it
"wrap as a phone draws it", but this file asserts only key finders and no text
or size, so the font load changes nothing in it; the same inaccuracy sits in
the new comment at test line 15; and the new `setUpAll` makes the file need
cwd = `packages/party_host` (it now fails from the repo root).

## Findings

- **should** docs/briefs/m14/bugs11/b021-fix-phone-test-report.md:8 the Summary says the font load makes "the card it measures" wrap as a phone draws it, but `arena_touch_solo_night_test.dart` measures no text or size (finders by key only), so that is not what the change does → say the fonts are loaded so the screen draws with the look's real faces, and drop "measures"/"wraps".
- **could** packages/party_host/test/arena_touch_solo_night_test.dart:15 the new comment says "The night's screens are measured with the look's real fonts", but the one test here measures nothing (coding-guidelines.md §10: a comment must be true) → word it as why the fonts are loaded ("the card draws with the look's real faces, as on a phone") or leave it out.
- **could** packages/party_host/test/arena_touch_solo_night_test.dart:16 adding `setUpAll(loadLookFonts)` makes the file read `../toy_look/fonts/...` (support/toy_fonts.dart:27), so `flutter test packages/party_host/test/arena_touch_solo_night_test.dart` from the repo root now dies in `setUpAll` with `PathNotFoundException` where it passed before → accept as the price of matching `arena_touch_ready_test.dart:19`, or make `toy_fonts.dart` find the package root.
- **could** docs/briefs/m14/bugs11/b021-fix-phone-test-report.md:8 and :20 the two references to the same borrowed check disagree (`solo_arena_card_test.dart:57-58` vs `:56-58`; the pump is 56, the two expects 57-58) → cite `:56-58` in both.

## Decisions to confirm

- Report Decision 3: `setUpAll(loadLookFonts)` is in a file whose only test asserts no text or size, so it currently guards nothing here; keep it only if the file is expected to grow measurement (findings 2-3 come from it).
- Report Decision 2 (its own reason string) is safe: the reason read out on failure is the only thing that differs from the line above.

## Could not check

- Whether the new expect at line 44 fails on the code before this job: reverting is not allowed here; by reading, line 38 already finds the card and line 45 already finds no round, so line 44 adds only the "card is still up one second later" case.
- The report's "466 tests" in the host suite at the job's commit: I ran the suite at HEAD instead (472 tests, PASS), after the other b021 jobs landed.

## Commit message

docs(bugs11): review of the lone-night phone test hardening

Findings only, no code change. The diff is the three briefed items
(waiting-card check after one second, `setUpAll(loadLookFonts)`, the
"two or more" comment) and stays inside `allow:`.
The report's Summary and the new comment say the test measures the card
and that fonts change its wrap; the file asserts only key finders, so
that wording is untrue and should say why the fonts are loaded.
The new `setUpAll` also makes the file need cwd = `packages/party_host`.

## Status row

M14 bugs11 b021-fix-phone-test reviewed (small fixes: report wording, test comment, cwd note); open: the 1 should and 3 could findings for Claude to accept or fix.

## Delete

- none
