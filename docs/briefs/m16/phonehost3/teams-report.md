# M16 phonehost3 teams report — the "Change teams" label fits the puzzle results

## Summary

Tests first, then one lib change. The puzzle results' compact controls (a series' Shuffle, its replay, Change teams)
were a [Row] of equal [Flexible] shares, so at the 960-wide frames Change teams' button got 207.45 frame px where it
wanted 222.10, and its 144.10 px label was cut to 129.40. The button was the only one of the three that hit its share.

- **The fix:** each control's [Flexible] takes a flex in frame px measured from its own label with [TextPainter] in
  the dense button type, plus the button's own room ([ToyButton] pads 24 px a side, draws the icon at the label's
  size and puts 8 px before it), so the shares are proportional to the widths the buttons want. Loose flexes mean a
  button still draws at its own width when the row has room, so the look does not change where it already fitted.
- **Result:** "Change teams" draws whole at all five sizes (144.10 wanted, 144.10 given), with 81.47 frame px to
  spare in the row at the 960-wide frames. Text stays at frame type (22 px dense), the keys are unchanged
  (`shuffle`, `rematch`/`playAgain`, `changeTeams`), the footer is untouched.
- **A `Wrap` was tried first and rejected:** it fixes the host frames but took the card's controls to a second line on
  a phone-sized host outside the frame (852x393), where the column is narrower than the row, and broke
  `puzzle_continue_test.dart`'s "no overflow" case by 31 px. Equal-share shrinking cannot overflow, so the
  weighted shares are what shipped (question 3).
- **Tests:** new `test/puzzle_controls_fit_test.dart`, 20 cases = 2 rounds x 2 rosters (4 and 6 players) x 5 sizes.
  Before the fix the 8 series cases at the 960-wide frames failed on the cut label; after it all 20 pass.
- **No other test broke:** `puzzle_results_frame_test`, `puzzle_results_layout_test`, `puzzle_results_test`,
  `host_focus_ring_test`, `puzzle_series_fix_test`, `puzzle_continue_test` and `phone_fit_matrix_test` (81 cases) all
  pass unmodified. No test was loosened.
- **Checks:** `tools/check.sh format analyze host` — all three PASS.

## The case the matrix measured

`docs/briefs/m16/phonehost2/s9m-report.md` found "Change teams" (144 wanted in 129.4 px) at the 960-wide frames. The
round it drew was a 2v2 series: the card carries Shuffle, **Rematch** (a race's word for the series' replay; Play
again is the one-board series' word) and Change teams, so the row is three buttons whose chrome is identical (78
frame px = 2 x 24 padding + 22 icon + 8 gap).

Per-button wants in frame px: Shuffle 74.39 + 78 = 152.39, Rematch 88.39 + 78 = 166.39, Change teams 144.10 + 78 =
222.10; with two 12 px gaps that is 564.88 of the card column's 646.35.

## Label widths before and after, per size

Dense label type is the frame's type: Fredoka 22 px (`ToyType.frame.button` at the body size), so 20 px type floor is
cleared. Values are frame px; a button's label room is its share minus the 78 px chrome. The drawn button width is
what the test measures; the label width is the [TextPainter] want. 4 and 6 players give the same numbers (both rounds
seat 2v2; the fifth and sixth phones watch).

| Size | Frame | Controls column | Share before | Label room before | Wanted | Button after | Label after |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 640x360 | 960x540 | 646.35 | 207.45 | 129.40 (cut) | 144.10 | 222.10 | 144.10 |
| 852x393 | 1170.69x540 | 857.00 | 277.63 | 199.63 | 144.10 | 222.10 | 144.10 |
| 1024x768 | 960x720 | 646.35 | 207.45 | 129.40 (cut) | 144.10 | 222.10 | 144.10 |
| 1280x800 | 960x600 | 646.35 | 207.45 | 129.40 (cut) | 144.10 | 222.10 | 144.10 |
| 1920x1080 | 960x540 | 646.35 | 207.45 | 129.40 (cut) | 144.10 | 222.10 | 144.10 |

- Share before = (column - 2 x 12) / 3; at 852x393 the frame is 1170.69 wide, so the column has 857 px and the share
  already held the label.
- The other two labels were never cut: Shuffle 74.39 in its 152.39 button, Rematch 88.39 in 166.39, before and after.
- The `any <level>` round (Change teams alone) fitted before and after: 144.10 wanted in a 568.19 px label room.
- Flexes after: ceil(152.39), ceil(166.39), ceil(222.10) = 153, 167, 223, so each of the 622.35 px of shares
  (646.35 - 24) is 175.3 / 191.3 / 255.5 — all above what its button wants, and each button draws at its own width.

## The 20 test cases

`test/puzzle_controls_fit_test.dart`, over the five sizes of `host_frame_screen_test.dart` (640x360, 852x393,
1024x768, 1280x800, 1920x1080, each laid out inside `hostFrameBuilder` as both apps draw a host screen):

- **Two rounds:** a series round on the house puzzle (Shuffle, Rematch, Change teams) and a non-night `any easy`
  round (Change teams alone, the level having more than one puzzle), each played to its results through the harness.
- **Two rosters:** 4 phones (2v2) and 6 phones (2v2 seated, two watching), as the matrix does for Shape Race.
- **Each case asserts:** no exception (no overflow); nothing scrollable under `hostFrameBody`; for every control the
  round has: its label's `didExceedMaxLines` is false, its wanted width <= the room its box gives it, its type is at
  least 20 frame px, the button sits wholly inside the body and the device view, and it is hit-testable. Every key the
  round does not have is asserted absent.
- Before the fix: 8 failures (series round, the four 960-wide frames, both rosters); the `any` round and 852x393
  passed, exactly as the matrix found. After: 20/20.

## Self-check (review-rules.md part A, items 1-5)

1. **Every host setup:** the results are a `HostFrameScreen` on every host type, laid out in frame px and scaled by
   the frame, so a TV/PC, "Play on this phone" and "Show on this device" all get the same shares; a joined phone draws
   no host screen, and the change adds no protocol message, so an older peer is unaffected. Shown by the 20 cases in
   `puzzle_controls_fit_test.dart`, which run inside `hostFrameBuilder`.
2. **When kept state starts and ends:** nothing is held, timed or cached; the only work per build is three
   `TextPainter` measurements, each disposed on the spot. Shown by the 20 cases running in one file with
   `tester.takeException()` null in each.
3. **How a new state combines:** nothing pauses, hides, waits or blocks input, so the pairs with the pause menu, a
   player away or the results do not change; taps and the pad still reach the controls. Shown by `host_focus_ring_test`
   (dpadLeft from Change teams to Rematch to Shuffle) and `puzzle_results_test` (button order and taps).
4. **Stay in the job's folder:** only `puzzle_results_widgets.dart` and the new `puzzle_controls_fit_test.dart` were
   written, both in `allow:`; `git status` shows no other change from this job (the `site/shots` and
   `tv_test_app/windows/flutter` churn was there before it).
5. **Stop rather than overstep:** no file outside `allow:` was needed; the brief's own `puzzle_results_controls.dart`
   could not be used (question 1), which is raised rather than worked around by editing `puzzle_screen.dart`.

## Questions

1. The allow list names a new `packages/party_host/lib/src/ui/puzzle_results_controls.dart`, but a file under `lib/src/ui`
   only joins the `puzzle_screen.dart` library through a `part` directive in that file, and `puzzle_screen.dart` is
   outside `allow:`. So the one helper stayed in `puzzle_results_widgets.dart`, which ends at 377 lines (limit 380): I
   tightened some doc prose in the same file to make room. If a controls file is wanted, the next brief needs the one
   `part` line in `puzzle_screen.dart` allowed (or the file dropped from `allow:`).
2. `_controlFlexPx` restates how [ToyButton] composes a dense button (24 px padding a side, the icon at the label's
   size, 8 px before it). toy_look has no public way to ask "what width does this label want on a button"; a public
   helper there would keep the two in step if the padding ever changes.
3. The brief's second option (wrap to a second row) is not viable as written: it grows the card and overflows the body
   on a phone host drawn outside the frame (852x393, `puzzle_continue_test.dart` proves the card already uses the
   body's spare height there). The weighted shares fix every measured size without using more height.

## Suggestions

- "Bumper Round" on the night footer (187 wanted in 148 px, s9m) is the same kind of cut; it could take the same
  measured-share treatment in its own job, now that the pattern exists.
- A toy_look test asserting a dense `ToyButton`'s laid-out width equals the summed want (padding, icon, gap, label)
  would pin question 2 from the other side.

## Hand-over

- After any change to the results card's column, the footer or the button type, run `test/puzzle_controls_fit_test.dart`
  (labels whole, nothing scrolling) and `test/phone_fit_matrix_test.dart` (the whole matrix).
- The fit file is the gate for this label; the numbers in the table above are what it measures today.

## Commit message

Fit the puzzle results' controls by their labels

The series' results gave Shuffle, its replay and Change teams equal
shares of the row, so at the 960-wide frames Change teams' label (144
frame px) was cut in its 129.40 px share. Each control now takes a share
measured from its label with TextPainter plus the button's own padding
and icon, so all three labels draw whole at the five phone sizes. A
narrower card shrinks the labels alike instead of taking a second line,
so nothing scrolls. New test: 20 fit cases, 4 and 6 players.

## Status row

M16 phonehost3 teams: the puzzle results' "Change teams" label draws whole at all five phone sizes (weighted
measured shares, 20 fit cases green, host suite green); open: "Bumper Round" on the night footer is still cut.

## Delete

- none
