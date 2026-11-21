# Wave 2 review — f1, f2

## Summary

**clean** — no must and no should; every numbered brief item is done and the two lib changes are correct.
Counts: 0 must, 0 should, 3 could.

1. `night_start_back_out_test.dart:39,47-49` is named and commented as "the frame's back arrow", but it taps
   the Shape Race pick's own title-bar arrow (`HostScreen`, `host_screen.dart:114`); the frame's
   `_FrameBackButton` (`host_frame_screen.dart:125,156`) is still never tapped. The test's proof stands either
   way (both arrows pop the same route).
2. `award_tile.dart:41` `awardExplanationFixedPx` is public and exported but read nowhere outside its file.
3. f1's self-check 3 cites `night_start_frame_test.dart:240-257`, which tests three ways to close the popover,
   not any pairing with pause, away players or results.

## Findings

- **could** packages/party_host/test/night_start_back_out_test.dart:39 the test is named "the frame's back arrow" (comment at :47-48 "the tap the card puts on screen"), but `hostTitleBarBack` at :49 finds the pushed Shape Race pick's `HostScreen` arrow (`games_screen.dart:105` → `host_screen.dart:111-114`); the start card's `_FrameBackButton` (`host_frame_screen.dart:124-125,156`) shares that key but is offstage under the pushed route, so it is still never tapped → reword the name and comment to "the Shape Race pick's back arrow" (or pump the start card above a home route so its own frame arrow is the top one).
- **could** packages/party_host/lib/src/ui/award_tile.dart:41 `awardExplanationFixedPx` is exported from `party_host.dart` but only read inside `award_tile.dart` (both tests pin 207/223 as literals), so it grows the package's public surface for no caller → make it private or fold the sum into `awardExplanationHeightPx`.
- **could** docs/briefs/m16/bugs1/f1-report.md:43 self-check 3 cites `night_start_frame_test.dart:240-257` as proof the popover cannot coexist with pause, away players and results, but those lines only close it three ways and test no combination → cite it as structural (the dialog only opens on the start card) or say the pairings are untested.

## Decisions to confirm

- f1: `awardExplanationHeightPx` stays a function but keeps a constant's name, and its fixed part is a second exported const (see the could above); confirm the name and the export are wanted for a later screen.
- f1: the 164-line TV test copies the size test's `_Case`, tile, `_expectInside` and loop rather than sharing them; confirm the duplication is preferred to a `test/support/` helper the other job's file would also use.
- f2: a third back-out test was added beside the Escape one instead of changing it (2 → 3 tests in the file), so both ways out stay pinned; say if the Escape case should go.
- f2: the saved players are compared as one `{install: share}` map instead of two sorted lists; confirm that is the "keep what it proves" the brief meant (it pins each install with its own share).

## Could not check

- `tools/review.sh` was not run (it needs the working tree and writes outside my file), so both reports' "0 fail" lines are unverified.
- Reran only the five changed test files: 26 passed together (`live_stats_share`, `games_screen_frame`, `night_start_back_out`, `award_explanation_size`, `award_explanation_tv`); `dart format` changed nothing and `dart analyze packages/party_host` found no issues. f1's "43 passed" over `night_start_frame_test` + `night_screens_test` was not rerun.
- The TV test failing on the old code is runner evidence (`run.log:34,36` "fails on the old code") plus the 223/inside assertions; nothing was run against the old code, and no app or device was started.

## Commit message

M16 bugs1: review of wave 2 (f1, f2)

Reviewed f1 and f2 against their briefs, the guidelines and the review
rules: no must and no should. f1's popover is 159 px plus the look's
button (207 menu, 223 TV), pinned as a literal in a new TV test that
opens all twelve awards at the five sizes. f2's stats check is an
install-to-share map, the night start doc matches B-032, the footer pin
comes from the footer constants and an arrow back-out was added. Three
coulds: the back-out test's name, one exported const with no outside
reader, and a self-check citation that does not test the pairing.

## Status row

Wave 2 reviewed: f1 (award popover per look) and f2 (stats order, night doc, footer pin, arrow back-out) have no must or should; open: three coulds (the back-out test's name and target, the exported fixed height, the popover self-check citation) and the four decisions above.

## Delete

- none
