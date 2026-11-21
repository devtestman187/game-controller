# M16 bugs1 f2 — flaky stats test, stale doc, fail-proof pin

## Summary

The five review findings for this job (`REVIEW.md` findings 2, 3, 5, 6, 7) are done; no lib
behaviour changed (one comment reworded).

1. `live_stats_share_test.dart`: the saved players are now checked as an install → share map,
   so the two phones' concurrent connects cannot fail the test on list order. What it proves
   is kept: both players saved, each with its own answer, and the round's winner recorded.
2. `night_start_screen.dart:58-60`: `_running`'s doc now says the night under way, one with a
   recorded round, and names B-032 for the night left before round 1 (dropped). Comment only.
3. `games_screen_frame_test.dart`: the button's offset in the footer band is computed from
   `hostFrameFooterHeightPx - hostFrameFooterInsetPx` instead of the band's measured height,
   so a band 8 px too tall or short now fails the pin.
4. `night_start_back_out_test.dart`: a second back-out taps the frame's arrow
   (`hostTitleBarBack`); the file's original Escape back-out is kept, so both ways a phone host
   vs a remote leaves round 1 are exercised.
5. `b032-report.md`: `night_start_screen.dart` line count 218 → 221 (still 221 after the reword).

Tests seen: `flutter test test/games_screen_frame_test.dart test/night_start_back_out_test.dart`
= 15 passed (2 + 3 tests, the frame file pumps five sizes per test); `flutter test
test/live_stats_share_test.dart` = 1 passed. `tools/check.sh format analyze host` = format
PASS, analyze PASS, host PASS (151 s; the full host count is in the run's log at
`%TEMP%/thumbparty-check-20261121-123410/host.log`, which this session cannot read).

## Decisions

- **Item 1 (order):** compared a `{install: share}` map rather than two sorted lists: it pins
  each install *with its own* share, which sorting the two lists separately would not.
- **Item 4 ("one of the two back-outs"):** the file had only **one** back-out (Escape); the
  second test never back out. Rather than lose the Escape case, the original stays and a new,
  third test taps `hostTitleBarBack` — one of the now-two back-outs uses the arrow, as asked.
  Test count for the file goes 2 → 3.
- **Item 3 (constants):** `hostFrameFooterHeightPx` and `hostFrameFooterInsetPx` are already
  public (`lib/party_host.dart:81` exports `src/ui/host_frame_screen.dart`), so no literal 84/8
  and no library change.

## Files changed

- `packages/party_host/test/live_stats_share_test.dart` — the saved-players check is a map
  (`install: share`) compared with `{'phone-yes': true, 'phone-no': false}`.
- `packages/party_host/lib/src/ui/night_start_screen.dart` — `_running`'s doc reworded
  (comment only; still 221 lines).
- `packages/party_host/test/games_screen_frame_test.dart` — `bandHeightPx` now comes from the
  footer constants; the band's measured height is no longer used in the expectation.
- `packages/party_host/test/night_start_back_out_test.dart` — new test: the frame's arrow
  leaves round 1 and drops the unplayed night.
- `docs/briefs/m16/bugs1/b032-report.md` — the stale 218-line count is 221.

Churn I did not write, left as it is (outside `allow:`, and I make no git changes):
`docs/briefs/m16/bugs1/run.log` and `tv_test_app/windows/flutter/generated_plugin*` /
`generated_plugins.cmake` show as modified after `flutter test` / the checks; the new
`docs/briefs/m16/m16.1-build-summary.md` is not mine either.

## Computed values

- Footer pin, at 640x360 with the TV look (`outlineWidth` 4, `buttonHeight` 64):
  band height = 84 − 8 = 76 frame px; button top inside the band =
  (76 − 2×4 − 64)/2 + 4 = 2 + 4 = **6 frame px**, which is the old formula's value too — the
  change is the source of the 76, not the number.
- `night_start_screen.dart`: 221 lines before and after (the doc stayed three lines).
- `night_start_back_out_test.dart`: 70 lines; `games_screen_frame_test.dart`: 231.

## Self-check (review-rules.md part A)

1. **Every host setup:** test-only change plus a comment; no branch by host type. The arrow
   path is the phone host's tap and Escape the remote's, both in `night_start_back_out_test`.
2. **When kept state starts and ends:** untouched — the night still starts on the footer
   button and ends by `dropIfUnplayed`/`end`/`endNow`; the new arrow test shows the same drop
   (`night_start_back_out_test.dart`).
3. **How a new state combines with others:** no state added.
4. **Stay in the job's folder:** writes only in `allow:` (5 of 5 files listed).
5. **Stop rather than overstep:** nothing needed outside `allow:`.

## Questions

1. The review's "tap `hostTitleBarBack` for one of the two back-outs" assumed two back-outs in
   `night_start_back_out_test.dart`, but it had one; I added the arrow back-out beside it
   rather than replace it. Say if the Escape case should go instead.
2. The host suite's total count was not readable from this session's temp log; only the
   per-file counts above are mine.

## Suggestions

- `live_stats_share_test.dart:105` still pins `host.players.length == 2` in a `waitFor`, which
  is order-free; nothing else in the file depends on the players' order now.

## Hand-over

Done: the five REVIEW findings this job owns (2, 3, 5, 6, 7). Open in the run: finding 1 (the
award popover's 207 vs 223 px on the TV, `award_tile.dart`), findings 4 and 8 (the wave's commits
and the phone suite's site shots), finding 9 (`b033-report.md`'s "open: nothing"), and the
owner questions in `REVIEW.md` (popover height per look, quit-drops-night, the footer's flush
top, B-032's device check).

## Commit message

M16 bugs1 f2: order-free stats check, stale doc, tighter footer pin

The saved-players check in live_stats_share_test compared two lists in
connect order, which two racing connects do not pin; it now checks an
install-to-share map, so each install keeps its own share. The night start
screen's `_running` doc now says the night under way (one with a recorded
round; an unplayed night is dropped, B-032), and b032's line count is 221.
The games frame test derives the footer button's offset from the footer
constants rather than the band measured against itself, and a new back-out
test taps the frame's back arrow, the tap a phone host makes.

## Status row

M16 bugs1 f2 fixed: an order-free stats pin, a correct night-start doc, a footer pin that fails on a wrong band, and an arrow back-out (plus b032's 221-line count); open: the award popover's TV height (finding 1), the process rule, and the owner questions in `REVIEW.md`.

## Delete

- none
