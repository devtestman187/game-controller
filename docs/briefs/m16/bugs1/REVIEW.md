# Run review — M16 bugs1, B-032, B-033, B-034

## Summary

**one fix batch.** Counts: 1 must, 3 should, 5 could.

1. B-033's fixed 207 px award popover was measured in the menu look (48 px button), but the TV app
   draws the frame with the TV sizes (64 px buttons): the same card needs 223 px and its OK button
   is 16 px out of view behind the new `scrollBody`, and no test opens it in the TV look.
2. `live_stats_share_test.dart:148` expects the saved players in an order the two phones' connects
   do not pin; it failed a full host run for b032 and for b034, and both called it a flake.
3. `night_start_screen.dart:58-60` still says a night left before round 1 keeps its length.
4. The three jobs ran at once and were committed in one pass, so 8623c2af carries b033's and b034's
   tests and pins while their own commits carry only lib and report.
5. The games pin now measures the band against its own height, so a wrong band height passes.

Hand-fixes: none — `run.log` has no `HAND-FIX` line; tests-first proofs exist for all three new
test files (`run.log:11-13`) and the only review report is `wave1-review-report.md`. Unverified:
B-032 (`b032-report.md:5`) must be marked "Fixed, unverified: needs device check"; B-033's TV
claim is arithmetic. Owner questions: the popover height per look, quit-dropping the night, the
footer's flush top, B-032's device check.

## Findings

- **must** packages/party_host/lib/src/ui/award_tile.dart:41 (used at :131) the one fixed 207 px
  height was measured in the menu look (48 px OK button), but the TV app gives every host screen
  the TV sizes (`tv_test_app/lib/main.dart:54` → `look_providers.dart:91`, 64 px buttons), so the
  same content needs 223 px (207 + 64 − 48; the header's 4 px line is painted inside its box and
  adds no height), so the `scrollBody: true` body is 16 px short and the OK button's bottom is
  out of view, and `award_explanation_size_test.dart:74` only mounts `pumpHost`'s menu look →
  make the height the fixed part plus `look.sizes.buttonHeight` (207 − 48 = 159, 223 on TV),
  correct the doc at :35-42, and add a `toyTvProvider.overrideWithValue(true)` test case
  (from: b033; confirmed by wave1)
- **should** packages/party_host/test/live_stats_share_test.dart:148 the saved players are expected
  in `['phone-yes', 'phone-no']` order, which the two phones' concurrent connects do not pin, so
  the full host run fails one test and passes alone or on the rerun (`b032-report.md:31-33`,
  `b034-report.md:34-38`) → compare the two lists sorted (or as a set with each share checked),
  so the wave's `check: host` stops failing on it (from: across jobs)
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:58-60 the `_running` doc says
  the night the host left before round 1 stands with its length and awards, which B-032 now drops
  → reword it to the night under way, one with a recorded round (from: b032)
- **should** docs/briefs/m16/bugs1/run.log:4-6 with the commits at :14-16 b032, b033 and b034
  started before any finished and were committed in one pass, so 8623c2af carries b033's and
  b034's new tests and b034's pin edits, f22448cb and ac1618ec carry only their lib file and
  report → run a wave's jobs one at a time, or commit each as it finishes (from: across jobs)
- **could** packages/party_host/test/games_screen_frame_test.dart:216-221 the expected button
  offset is computed from `bandHeightPx` read off the band itself, so a band 8 px too tall or
  short still passes → compute it from `hostFrameFooterHeightPx - hostFrameFooterInsetPx - 2 *
  outlineWidth - buttonHeight` (from: wave1)
- **could** docs/briefs/m16/bugs1/b032-report.md:35 says `night_start_screen.dart` is 218 lines;
  the committed file is 221 → correct the count (from: b032)
- **could** packages/party_host/test/night_start_back_out_test.dart:24 the back-out is Escape,
  which the pick screen handles (`games_screen.dart:56`; wave1 named the start card's shortcut),
  so the frame's back arrow a phone host taps is never exercised → tap `hostTitleBarBack` for one
  of the two back-outs (from: b032)
- **could** docs/briefs/m16/bugs1/run.log:10 `tools/check.sh phone` regenerates `site/shots/*.png`
  (`controller_app/test/site_shots_test.dart`), outside every job's `allow:` list → name the shot
  test the jobs skip, or the path as allowed churn (from: b034, wave1)
- **could** docs/briefs/m16/bugs1/b033-report.md:80 says "open: nothing" although the TV look is
  unhandled → say the TV popover is open until the must above is fixed (from: b033)

Fix jobs, no shared files: A — the award must and the b033 status row (`award_tile.dart`,
`award_explanation_size_test.dart`, `b033-report.md`); B — the footer pin
(`games_screen_frame_test.dart`); C — B-032's docs and test (`night_start_screen.dart`,
`b032-report.md`, `night_start_back_out_test.dart`); D — the host flake
(`live_stats_share_test.dart`). The process findings need no code job; no finding is pinned by
controller_app (phone) tests, so no job needs `phone` in `check:` (nor its site-shots churn).

## Open questions

- One popover height per look, or one tuned to the TV? → per look: 159 plus `buttonHeight`.
- Is `scrollBody: true` wanted in a remote-driven dialog, or does it hide content? → keep it as a
  guard only; with the per-look height nothing scrolls, so it can be dropped too.
- B-032: quitting round 1 from the pause menu now also drops the night — wanted? → yes: it is
  "left before any round was recorded", and the card returns as a fresh pick.
- B-034: the band's top is flush with the footer's top, not inset — wanted? → keep it flush (the
  footer's top is not a frame edge); a top gap means growing the footer to 92 px.
- Which look is the footer's reference: the new footer test builds the TV look, the other footer
  pins run in `pumpHost`'s menu look → keep the TV case and add a menu case.
- The brief named `shape_race_screen.dart`, which does not exist (`ShapeRaceScreen` is in
  `games_screen.dart`) → future briefs name the real file.
- B-032's device check: back out of Shape Race's pick and the 3/5 chips should pick.

## Numbers against targets

- The award popover: 207 given, 223 needed on the TV (16 short); the target is text and button
  inside the box at every host look, and the test checks the menu look only.
- `b033-report.md:19`'s 1920x1080 row measures the menu look, not the TV app's look, so the table
  does not cover the TV host.
- `b032-report.md:35`: 218 lines claimed, 221 actual. `b033-report.md:80`: "open: nothing".
- B-034's figures check out: band 944 wide, row 912, buttons end at 936, band top 456, 76 tall; at
  640x360 the inset 5.333 and band 50.667; 6 px above and below a 64 px button. B-033's "333 px
  short of 540" (540 − 207) checks out.

## Could not check

- No suite was rerun: the reports' test counts (81 + 27, 74, 208) and the flake story are unverified.
- The TV clipping is arithmetic on `ToySizes` and the popover's parts, not a rendered layout, and
  whether a remote can scroll the body at all was not tested.

## Commit message

M16 bugs1: review of the run (B-032, B-033, B-034)

Reviewed the wave as one change against the briefs and the guidelines: one
must, three shoulds, five coulds. The award popover's fixed 207 px was
measured in the menu look, so the TV host's 64 px OK button is 16 px out of
view behind the new scroll; the live-stats test's player order is not pinned
and failed a full host run twice; a stale comment in the night start screen
still says an unplayed night is kept; and the three parallel jobs left
commits that do not line up with their jobs. Four smaller pins and doc
lines follow.

## Status row

Run reviewed: one fix batch (the award popover is 207 px but needs 223 on the TV; the host flake, a stale night comment, mixed commits); open: the batch, the owner's calls on the popover height, quit-drops-night and the footer's flush top, and B-032's device check.

## Delete

- none

## Verdicts (driver, Nov 21)
- must award_tile TV height: verified at award_tile.dart:41/:131; fixed in f1 (962c4aa0), TV test added.
- should live_stats_share flake: fixed in f2 (1e4d6cb9). should night_start doc: fixed in f2.
- should one-pass commit of wave 1: process note, no code; next time run jobs with disjoint test files or accept (the tests sat in 8623c2af).
- could games pin, back-out arrow, b032 line count, b033 "open": fixed in f1/f2. could site/shots churn: restored, not staged.
- Wave 2 review (clean, 3 could): back-out test name says "frame's back arrow" but taps the pick's arrow, awardExplanationFixedPx exported unused, f1 self-check 3 cites a test that covers only closing: all minor, in docs/code-health.md.
