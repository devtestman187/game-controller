# M16 phonehost3, the run's review (pad, night, teams + wave1 review)

## Summary

Verdict: **one fix batch**. The pad's bar mapping is a real bug with a one-file fix; everything else is small.

- must 2, should 5, could 8 (15 findings), 11 open questions; no file outside a job's `allow:` was written.
- Still broken after the wave: (1) `phone` is red at HEAD — the `mirror_pad_test.dart` hand-fix was applied but
  never committed; (2) a framed board keeps clear of a pad 52 device px (82.4 frame px at 852x393) too low and, at
  that size, 0.836 of its real size, because `leftPadRects` is handed the room below the bar and subtracts the bar
  again; (3) the arena footer checks were loosened 160 px by the night's 480 -> 640 budget; (4) the pad's frame test
  and the night/results harness assert the code's own call or the wrong frame, so they passed (2).
- Hand-fixes: one (`HAND-FIX pad`, run.log:16). Pad's tests-first proof (run.log:19) and `pad-report.md` exist; the
  edit itself is uncommitted and re-pins the buggy mapping (`leftPadRects(box * s) / s`).
- Unverified, needs a device check: the 52 px mapping and the results' new spacing (reasoned from the code).
- Pinned by controller_app tests, `phone` in `check:`: findings 1, 2 and 4 (marked [phone]).
- Owner only: the bar mapping; five players 3 + 2 vs one row; whether the 640 footer budget stays; the results'
  left-aligned 81 px spare.

## Findings

- **must** controller_app/test/mirror_pad_test.dart:329 the hand-fix for this test is still uncommitted (`git status`
  shows it modified), so the run's HEAD fails `phone` — the committed test expects `view.pxPerMm == phonePxPerMm` →
  commit the working-tree edit with the pad job's files, adjusted to find (2)'s new answer (from: pad, hand-fix).
- **must** packages/party_host/lib/src/ui/puzzle_pad_scale.dart:23 the pad is asked about `boardBox * scale`, which under
  the gate is the room below the bar (852x341), but `leftPadRects` (controller_app/lib/src/ui/joined_view.dart:33-35)
  lays the pad out in that box minus another 52 px bar and shifts it down 52, so a framed board's arms are 52 device px
  (82.4 frame px at 852x393) low and its D-pad is 265 px against the drawn 317 → in
  controller_app/lib/src/host/host_overrides.dart:77 answer in the game's own box: call
  `leftPadRects(Size(box.width, box.height + topBarHeightPx))` and translate each rect by `-topBarHeightPx`, leaving
  `leftPadRects`' contract for joined phones and party_host's division by the scale as they are [phone] (from: pad).
- **should** packages/party_host/test/arena_results_frame_test.dart:266 (also :369) the arena's two footer pairs are
  checked against `nightFooterButtonsWidthPx`, which the night job raised 480 -> 640, so both checks now pass pairs up
  to 160 px too wide (arena_results.dart:127 keeps 480) → assert them against the arena's own 480 px budget (from: night).
- **should** controller_app/test/pad_clearance_frame_test.dart:45-49 the expected rects are `pad.rects(deviceBox)`
  divided by `s`, the same call the code makes, so the test passes whatever `leftPadRects` does and passed (2) → expect
  the pad's drawn arms for the screen (the room plus the bar), shifted up by the bar, then divided by `s` [phone]
  (from: pad).
- **should** packages/party_host/lib/src/ui/night_footer_buttons.dart:32-48 and
  packages/party_host/lib/src/ui/puzzle_results_widgets.dart:246-255 two jobs each restate ToyButton's content width
  (2 x space24 padding, the icon at the label's size, space8) with different rules (the footer merges
  `DefaultTextStyle`, adds 1 px slack and the text scaler; the controls do none and assert `style.fontSize!`) → one
  content-width helper in toy_look (or host_button.dart) used by both, so the two cannot drift (from: across jobs).
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:375 the pad brief said the file "ends no longer than
  now" (372) and it ends at 375; its part `puzzle_results_widgets.dart` ends at 377 against the 380 cap → move the two
  conversion comment lines into `puzzle_pad_scale.dart`'s doc, and let the next controls change keep the part's prose
  short (from: pad, across jobs).
- **should** docs/briefs/m16/phonehost3/run.log:8 the night job ran 127 turns against its brief's "never over 120" and
  neither report says so → the next night-sized job splits the work, or the owner grants the exception (from: night).
- **could** packages/party_host/lib/src/ui/puzzle_results_widgets.dart:248-251 the control's label is measured from
  `look.type.button` alone, without the surrounding `DefaultTextStyle` or `MediaQuery.textScalerOf`, while ToyButton
  draws the merged style, so a host screen outside the frame under font scaling measures short and can cut the label →
  measure the drawn style, as night_footer_buttons.dart:35-39 does (from: teams).
- **could** packages/party_host/lib/src/ui/night_footer_buttons.dart:46 the `fontSize == null` branch returns the width
  without the icon's room, so a look whose button type has no size would cut the label → the look always sets it; give
  both branches the icon's room or guard it as the controls' helper should (from: night).
- **could** packages/party_host/lib/src/ui/night_start_names.dart:77 the last line of a five-player night is a row of
  two `Expanded` names, each half the stage, while the lines above give a third, so the columns do not line up → give
  the split lines fixed third slots (a `SizedBox` width) so five names stand under six (from: night).
- **could** packages/party_host/lib/src/ui/night_footer_buttons.dart:12 `nightFooterButtonsWidthPx` is read only by
  tests now, so nothing in the footer keeps the pair off Thumby's corner and the bound can drift from the layout → let
  the footer read it as its max width, or document it as the test's bound and drop it from the public export
  (from: night).
- **could** packages/party_host/test/night_labels_fit_test.dart:58 (and puzzle_controls_fit_test.dart:100) the harness
  lays the frame out in the whole device box, not the gate's room below the bar, so four of the five sizes build the
  same 960x540 frame and 852x393 builds 1170.69, not the app's 1349.21 → drive the phone sizes through the gate's room
  (`Size(w, h - 52)`) so the cases differ and match the app (from: across jobs).
- **could** packages/party_host/lib/src/ui/night_start_screen.dart:140 the doc still says the card's content is 286 px
  at 4 and 6 players, but six names now take two rows (~326 px) → update the number (it still fits the 392 px body)
  (from: night).
- **could** docs/briefs/m16/phonehost3/night-report.md:66 and docs/briefs/m16/phonehost3/teams-report.md:47 their
  852x393 rows are the harness's frame (stage 1122.7, frame 1170.69), not the phone app's (stage 1301.2, frame
  1349.21), so the per-device figures are not what the app draws → recompute them when the harness is fixed
  (from: night, teams).
- **could** packages/party_host/lib/src/ui/puzzle_results_widgets.dart:225-229 `labels` restates `buttons`' three
  conditions by hand, so one edit to either list mispairs a flex with another label → build one list of (widget, label)
  records; the same job also collapsed `_headline` (:145) and `_NewRecordChip` (:353) and reflowed unrelated docs,
  churn in a one-label diff (from: teams).

## Open questions

1. Which side owns the bar mapping? Suggested: the phone's pad override (finding 2); `leftPadRects` keeps its
   screen-box contract for joined phones (pad-report.md question 2).
2. Add `mirror_pad_test.dart` to the next pad job's `allow:`? Suggested: yes, with finding 1's adjustment
   (pad-report.md question 1).
3. `Rect` division helper in a shared place (pad-report.md question 3)? Suggested: no new package now; the frame test
   and the helper may keep their four lines.
4. Add `phone` to `check:` for every job that changes a box's px (pad-report.md question 4)? Suggested: yes.
5. Are s9m's name widths (113-124) or this build's (110.0-121.5) right (night-report question 1)? Suggested: font-build
   difference; keep both and do not "correct" s9m's figures.
6. Five players as 3 + 2 (night-report question 2)? Suggested: keep 3 + 2; it is the brief's example and matches six.
7. A lib helper under `lib/src/ui` needs a `part` line in `puzzle_screen.dart` (teams-report question 1)? Suggested:
   allow that one line when a brief wants such a file, or keep helpers in the existing widget files.
8. A public "what width does this label want on a button" in toy_look (teams-report question 2)? Suggested: yes; it is
   finding 5's fix.
9. Does `nightFooterButtonsWidthPx` stay at 640 (wave1 decisions)? Suggested: keep 640 as the pair's max, read by the
   footer; 521 is the measured pair and 391 px of the 912 px band stays Thumby's.
10. Are the controls wanted left-aligned with ~81 px spare, or spread (wave1 decisions)? Suggested: left-aligned; they
    are one group under the rows, not a spread footer.
11. Removed public `nightFooterButtonWidthPx` (wave1 decisions)? Suggested: no in-repo caller; skip the deprecation
    unless a build outside this repo uses party_host.

## Numbers against targets

- pad: the board's up arm lands at frame 95.0 where the drawn arm is at 12.7 (852x393; 52 device px, 82.4 frame px),
  and the D-pad it is told about is 265 device px against the drawn 317. Target: the pad's device rects divided by `s`
  (pad.md decisions).
- pad-report.md:52-53's check ("top device 112 against the pad's 60") mixes frames: 95.015 frame px is device 60; the
  52 px is the board's origin sitting at screen 52, not the rect's position.
- puzzle_screen.dart 375 lines against the brief's 372; `puzzle_results_widgets.dart` 377 against the 380 cap.
- night: 127 turns against the brief's 120; six names 110.0-121.5 against s9m's 113-124 (report's own 2.5 px gap).
- night/teams 852x393: report stage 1122.7 / frame 1170.69 against the app's 1301.2 / 1349.21.
- Night footer pair 521 px in the 640 budget, 391 px of the 912 px band left: meets its target.

## Could not check

- Ran no suite (read-only, no code changed): the HEAD failure is read from the committed expectations
  (mirror_pad_test.dart:329) and pad-report.md, not from a `phone` run.
- No device or emulator: the 52 px offset, the 0.836 size and the results' spacing are derived from `padLayout`,
  `leftPadRects` and `controller_parts.dart`'s `body` doc, not seen.
- No `STATUS.md` and no `run-findings.md` exist at this commit, so only the job reports and run.log were available.
- DESIGN section 4's "player names on one line" (quoted by the removed code) was not found in `docs/design`, so I
  cannot say whether the design doc is now stale under the two-row layout.
- Font widths are the reports' measurements, not re-measured here.

## Commit message

```
Fix the framed pad's bar offset and share one button width

A board under HostFrame still keeps clear of a pad 52 device px too low:
leftPadRects is handed the room below the phone's bar and subtracts the
bar again, and at 852x393 it lays out a 0.84-size D-pad. The phone's pad
override now answers in the game's own box, and the pad tests compare
with the pad's drawn arms. The uncommitted mirror_pad_test fix is
committed with it. The night footer and the results share one measured
button width, the arena footer keeps its own 480 px budget, and two docs
say what the code does.
```

## Status row

| M16 phonehost3 run review | done: pad, night and teams read as one change; open: mirror_pad_test fix uncommitted so `phone` is red at HEAD, framed pad rects 52 device px low, arena footer checks 160 px loose, two measured-width helpers to merge, night job at 127 turns |

## Delete

- none
