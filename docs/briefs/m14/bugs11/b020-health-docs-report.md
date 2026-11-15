# b020 health docs: close the run review's code-health findings

## Summary

- docs/code-health.md is the only repo file changed (plus this report). No code, no tests.
- Deleted the two "M14 bugs6 leftovers" bullets about code `f11c4b1` deleted: `party_host (solo skip)` (the empty-box solo Bumper start) and `game_screen.dart (late-joining phone)` (`_alone`).
- Corrected the `party_host (screens)` bullet from `game_screen.dart 379/380` to `373/380 (before bugs11's next change)`; `wc -l` on `packages/party_host/lib/src/ui/game_screen.dart` is 373.
- Added "### M14 bugs11 leftovers (run review of Nov 15, 2026)" before "## Before a milestone", with the review's four coulds shortened to one bullet each: the `solo_arena_card_test.dart:52` map assertion, `:17`'s single-use helper (with its b020-solo-both note), `night_start_screen.dart:74`'s "for two or more", and the next-map proposal's carry list (373 / 381 / 370, `menu_press_test.dart:61-64`, `party-night.md:107`, `_ResultsBody`'s callbacks and `:68`'s `Wrap`, base 379).
- The file is Windows-1252 with CRLF line endings, and the Edit tool refuses a non-UTF-8 file, so the edit was made byte-preserving with `head`/`tail`/`printf` and checked with `diff` and `file` (still "CRLF line terminators", still non-ISO extended-ASCII).

## Checks

- `tools/check.sh format`: PASS (7s).

## Decisions

- **Kept the file's Windows-1252 encoding and CRLF endings**: converting it to UTF-8 would rewrite bytes on several lines unrelated to this job; `diff` against the old file now shows only the three intended hunks.
- **Rebuilt the file in place rather than with `sed -i`**: `sed -i` and `grep`/`sed` output rewrite CRLF as LF on this host (verified: a piped grep dropped every CR), so the lines were assembled from `head`/`tail` slices and `printf '%s\r\n'`, and the result was `file`-checked.
- **Placed the new section after the B-019 leftovers bullet rather than straight after the bugs6 heading**: the bugs6 section still holds bugs10's and housekeeping bullets (toy_look, contrast helper, tracked pictures, B-019), and the file's habit is newest-last.
- **Phrased `night_start_screen.dart:74` without an apostrophe**: the comment reads "as Shape Race's join screen does for two"; the bullet quotes only "for two" so no non-ASCII or quoting trouble enters the doc. The instruction ("say for two or more") is unchanged.
- **No file deletions in the code-health doc beyond the two named bullets**: the `party_host (screens)` split recommendation stays, and so does every other bugs6 bullet.

## Hand-over

- `night_start_screen.dart:74`'s comment fix (could c) is a one-line code change nobody has taken yet; it belongs with the next night-start change, and the doc now records it.
- `solo_arena_card_test.dart` is rewritten by b020-solo-both, so both coulds (a) and (b) there should be done in that job, not before it.
- The next-map follow-up brief must use 373 / 381 / 370 and carry the five extra items; `b020-next-map-report.md` itself is unchanged (not this job's file), so the stale 379 / 387 / 376 is still in it and still in the review report.
- Tools note for the next docs job on this file: `Edit` will refuse it again; use the same head/tail/printf route, or convert the whole file to UTF-8 in a job that says so.

## Commit message

docs/code-health: drop two stale bullets, add bugs11 leftovers

The run review of Nov 15 found code-health notes about code
f11c4b1 deleted (the solo Bumper start's empty box, `_alone`)
and a size that moved: game_screen.dart is 373, not 379.
Delete both bullets, mark the screens note as pre-bugs11, and
add "M14 bugs11 leftovers": the solo card test's missing map
assertion, its single-use helper, the night start comment
reading as "two", and the next-map report's carry list.

## Status row

- M14 bugs11 code-health notes: the two deleted-code bullets are gone and the screens size is 373; open: the four new leftovers (two in solo_arena_card_test with b020-solo-both, the night_start_screen comment, the next-map carry list).

## Delete

- none
