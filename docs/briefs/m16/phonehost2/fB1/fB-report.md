# fB — a tie's names and the footer band's padding: stopped on a six-way tie

## Summary

Done, per the brief's decisions:

- Winner names on the reveal shrink by count: 40 frame px for one or two winners (as designed),
  32 for three, 24 for four or more, each on one ellipsised line (`nightRevealWinnerPxFor` and
  three named constants in `night_reveal_widgets.dart`).
- The footer band pads its content evenly: the ink line's width (4 px with the TV look) is padding
  at the top and the same at the bottom, so a 64 px button now stands 10 frame px above and 10
  below inside the band (it was 12 above and 8 below).
- `s3-report.md:36` corrected from "16 px of air above" to 10 above / 10 below.
- New `night_reveal_tie_test.dart`: two-, three-, four- and six-way ties at the five sizes (no
  scrollable, no overflow, the card inside the body, nothing under 20 px, name sizes 40/32/24 and
  one ellipsised line each), and the band's even padding at the five sizes. The band test passes.

Stopped, because two cases cannot be met as briefed:

- A five- or six-way tie cannot keep one line per name at any size (numbers below): the six-way
  case fails at four of the five sizes, so the host suite is red.
- `games_screen_frame_test.dart:216-223` pins the old band (12 px above); the even band gives 10,
  and that file is not in this job's `allow:`.

## Computed values

The card's content box is 328 px at 640x360 and 852x393 (body 392, card padding 32), 388 at
1280x800 and 508 at 1024x768. The column without any names takes 188 px: award name 74 (52 px,
one line), 8, 16, reason 37 (26 px, one line), 16, the points row 37. A name's line is about
1.42 x its size: 34 px at 24, 45 at 32, 57 at 40 (measured through the card's 0.9 pop-in scale).

| winners | name px | names need | column | 328-room |
| --- | --- | --- | --- | --- |
| 2 | 40 | 2 x 57 = 113 | 301 | fits |
| 3 | 40 (old) | 170 | 358 | over by 30 (measured 31) |
| 3 | 32 | 136 | 324 | fits, 4 spare |
| 4 | 24 | 136 | 324 | fits, 4 spare |
| 5 | 24 | 170 | 358 | over by 30 |
| 6 | 24 | 204 | 392 | over by 64 (measured 64) |
| 6 | 20 (the floor) | 170 | 358 | over by 30 |
| 6 | 24, two per row (3 rows) | 102 | 290 | fits, 38 spare |

The six-way case fails at 640x360 and 852x393 (64 over), 1920x1080 (64 over) and 1280x800 (4 over);
at 1024x768 it passes. The band: 84 high, ink 4, padding 4 top and bottom, row 76, button 64,
slack 6, so 4 + 6 = 10 above and 6 + 4 = 10 below.

## Files changed

- `packages/party_host/lib/src/ui/night_reveal_widgets.dart`: the size tiers and their doc comments;
  `_AwardBody` draws each tied name at `nightRevealWinnerPxFor(winners.length)`.
- `packages/party_host/lib/src/ui/host_frame_screen.dart`: the band pads
  `EdgeInsets.symmetric(horizontal: hostFrameGutterPx, vertical: edge.width)`, and its doc comment
  says why.
- `packages/party_host/test/night_reveal_tie_test.dart` (new): the tie and band tests above.
- `docs/briefs/m16/phonehost2/s3-report.md:36`: the band's real numbers.
- `docs/briefs/m16/phonehost2/fB-report.md`: this report.

`night_reveal_test.dart`, `night_reveal_frame_test.dart`, `host_frame_screen_test.dart`,
`host_frame_screen_safe_area_test.dart` and `night_start_frame_test.dart` pin no old number (the
frame test draws a two-way tie only) and are unchanged; all pass.

## Checks

- `tools/check.sh format analyze`: PASS.
- `tools/check.sh format analyze host`: format PASS, analyze PASS, host FAIL — 5 failures: the
  tie test's six-way case at four of the five sizes, and `games_screen_frame_test.dart`'s band
  line.
- `flutter test` on the five reveal/frame tests above: 74 pass.

## Self-check (review-rules part A)

1. Every host setup: the change is inside the shared `HostFrameScreen` and the reveal, so TV, PC,
   phone hosts and the joined view all draw the same; the five device setups are the test's cases
   (`night_reveal_tie_test.dart`, five sizes). No services or protocol involved.
2. When kept state starts and ends: no state is added; the reveal's timer is the existing one, and
   the tie test pumps all three awards through to the final scores, so nothing is left running
   (`night_reveal_tie_test.dart`).
3. How a new state combines: none — layout only, no pause, hide or input block; Escape and Back
   are untouched (`night_reveal_test.dart`, passing).
4. Stay in the job's folder: only files in `allow:` were written (list above).
5. Stop rather than overstep: stopped on the five/six-way tie (a design decision) and on
   `games_screen_frame_test.dart` (outside `allow:`), rather than capping names or editing it.

## Questions

1. A five- or six-way tie: may the names sit two to a row for 4+ winners (six players -> three
   rows at 24 px, 290 px, which fits with 38 spare), or is there another rule? My numbers say a
   row per name cannot work at any size down to the 20 px floor.
2. May `games_screen_frame_test.dart` join `allow:` in the follow-up, with the expectation
   `(84 - 2 * outlineWidth - buttonHeight) / 2 + outlineWidth` (10 at the TV look)?

## Hand-over

The tier constants and `nightRevealWinnerPxFor` are in place, and a two-, three- or four-way tie
now fits. The six-way case and the five-way (not yet in the test) need the row layout decided;
then the tie test's six-way case will pass, and `games_screen_frame_test.dart`'s 12 px expectation
needs the 10 px formula. The band fix and the s3 numbers are complete.

## Commit message

The reveal's tie size tiers and the band's even padding

Winner names take 32 frame px at three winners and 24 at four or more, so a
four-way tie fits the card's 328 px; a five- or six-way tie cannot keep a row
per name, and this job stopped there.
The footer band now pads by the ink line's width above and below, so a 64 px
button stands 10 px above and 10 px below inside it.
night_reveal_tie_test.dart checks both at the five sizes; its six-way case is
the open one. s3-report.md's band numbers are corrected to 10/10.

## Status row

fB: done — tie size tiers (40/32/24) and an even footer band (10/10, s3-report corrected). Open: a five/six-way tie cannot fit one line per name (needs two per row or another rule); games_screen_frame_test.dart still expects the old 12 px.

## Delete

- none
