# Wave 1 review — B-032, B-033, B-034

## Summary

**needs Claude** — one `must` in B-033; B-032 and B-034 are clean.
Counts: 1 must, 0 should, 4 could.

1. B-033's fixed `awardExplanationHeightPx` (207) is the menu look's tallest card — the report
   names its "48 px OK button" — but the TV host draws the frame with `ToySizes.tv` (64 px
   buttons, `tv_test_app/lib/main.dart:54`), so the same popover needs 223 px and its OK button
   is clipped by the new `scrollBody`; no test opens the popover in the TV look.
2. B-034's games-screen pin now takes the band's own measured height as the expected value, so
   it can no longer catch a band of the wrong height.
3. B-032's report says `night_start_screen.dart` is 218 lines; the committed file is 221.

## Findings

- **must** packages/party_host/lib/src/ui/award_tile.dart:41 207 is the menu look's intrinsic height (the report names the "48 px OK button"), but the TV app draws every host screen in the TV look (64 px buttons, `tv_test_app/lib/main.dart:54` via `toyTvProvider`), so the identical content needs 223 px and the `scrollBody: true` at :137 puts the OK button's bottom 16 px outside the box → derive the height from `look.sizes.buttonHeight` plus the fixed parts (or fit it to the taller look) and add a `toyTvProvider` true case to `award_explanation_size_test.dart`.
- **could** packages/party_host/test/games_screen_frame_test.dart:221 the expected button offset is computed from `bandHeightPx` read off the band itself, so a band 8 px too tall or short still passes → compute it from `hostFrameFooterHeightPx - hostFrameFooterInsetPx - 2 * outlineWidth - buttonHeight` instead.
- **could** docs/briefs/m16/bugs1/b032-report.md:35 claims `night_start_screen.dart` is 218 lines; the file in commit 8623c2af is 221 → correct the line count.
- **could** packages/party_host/test/night_start_back_out_test.dart:24 the back-out is the start card's own Escape shortcut, not the header arrow or Shape Race pick's way out that the owner used, so neither is exercised → tap the pick screen's back arrow (key `hostTitleBarBack`) for at least one of the two back-outs.
- **could** docs/briefs/m16/bugs1/run.log:10 b034's worker regenerated `site/shots/join.png` and `site/shots/menus.png`, outside its `allow:` list, and the runner had to drop them → name the screenshot suite the brief's `check:` must not run (or its output path) so the next worker does not write outside its list.

## Decisions to confirm

- B-033: one fixed height means one height per look, or a height tuned to the TV look (and the must above); the owner should say which, since a phone host and the TV draw the frame in different sizes.
- B-033: `scrollBody: true` was added although no frame cap was needed; confirm a scrollable card is wanted in a remote-driven dialog (it hides content instead of overflowing).
- B-034: the band's top stays flush with the body although the brief says "inset from the frame edges by a few px"; the report lists it, the owner's word is missing.
- B-032: quitting round 1 from the pause menu (round never recorded) now drops the night too, a second way to lose a set-up night (the report's Question 2).
- B-034: the new footer test builds the TV look itself, while the other 12 footer tests run through `pumpHost`, which is the menu look; confirm which look is the frame's reference so the new test does not pin the wrong one.

## Could not check

- No suite was rerun here: the reports' test counts (81 + 27, 74, 208) and the host-suite flake story are unverified; `run.log` only proves the three new files fail on the old code.
- Per-commit attribution: b032's commit 8623c2af also carries B-033's and B-034's new tests and B-034's pin edits, so the commits do not line up with the jobs.
- The TV-path claim above comes from the code (the app overrides `toyTvProvider` with true; `hostFrameBuilder` wraps the navigator) and arithmetic on the measured 207; nothing was run in the TV look or on a device.

## Commit message

M16 bugs1: review of wave 1 (B-032, B-033, B-034)

Reviewed the three wave-1 jobs against their briefs and the coding
guidelines. B-032 (drop an unplayed night) and B-034 (footer outline)
are clean. B-033 has one must: the fixed 207 px award popover was
measured with the menu look's 48 px OK button, so on the TV host (64 px
buttons) the button's bottom 16 px is clipped by the new scrollBody and
no test covers that look. Four coulds note a self-referential footer
pin, a wrong line count in B-032's report, a test that backs out with
Escape rather than a pick's back arrow, and b034's screenshot churn.

## Status row

Wave 1 reviewed: B-032 and B-034 clean, B-033 has one must (the award popover is 16 px short in the TV look); open: that fix plus the owner's calls on the popover height, the footer's flush top and B-032's quit-drops-night rule.

## Delete

- none
