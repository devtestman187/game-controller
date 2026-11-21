# wave1 review — pad, night, teams

## Summary

Verdict: **needs Claude** (two musts: the pad mapping is 52 device px off, and the range's HEAD leaves the phone suite red).

- must 2, should 4, could 7.
- The pad fix asks `leftPadRects` about the room below the bar, but that function lays a pad out in a full screen, so every rect comes back 52 device px low (82 frame px at 852x393) and the dpad is sized in a 52 px shorter body; pad-report question 2 is real.
- `controller_app/test/mirror_pad_test.dart` still pins the old device px at 1b0ae28d; the fix for it is in the working tree but uncommitted, so `phone` is red at HEAD.
- Raising `nightFooterButtonsWidthPx` 480 -> 640 silently loosened the arena results' two footer checks by 160 px, and no lib code reads the constant any more.

## Findings

- **must** controller_app/test/mirror_pad_test.dart:329 the committed test still expects `view.pxPerMm == phonePxPerMm`, which `padClearanceFor` (puzzle_pad_scale.dart:24) now breaks, so the wave's HEAD fails the `phone` suite while the working tree carries an uncommitted fix → commit the working-tree edit (scale from `HostFrameInfo`, rects and px/mm divided by s).
- **must** packages/party_host/lib/src/ui/puzzle_pad_scale.dart:23 the pad is asked about the room below the bar (852x341), but `leftPadRects` (controller_app/lib/src/ui/joined_view.dart:33-36) lays the pad out in a full screen and shifts it down by the bar, so every rect comes back 52 device px too low (pad-report.md:52-53: top device 112 against the pad's 60) in a 52 px shorter thumb box → add the bar back to the box asked about and subtract it from each returned rect before dividing by s.
- **should** packages/party_host/test/arena_results_frame_test.dart:266 (also :369) the arena's two footer pairs are checked against `nightFooterButtonsWidthPx`, so raising it 480 -> 640 loosened both checks by 160 px without failing → assert them against the arena's own budget (the 912 px band less Thumby's corner) in a job that allows this file.
- **should** controller_app/test/pad_clearance_frame_test.dart:41-53 the test builds the expected rects from `pad.rects(playBox * s)`, the same call the code makes, so it passes whatever `leftPadRects` does with the box and cannot see the 52 px offset → compare with `leftPadRects(screen, mode, mm)` on the full screen, divided by s and shifted by the bar.
- **should** packages/party_host/lib/src/ui/puzzle_screen.dart:320-322 the pad brief said this file "ends no longer than now" and it grew 372 -> 375 lines → move the two comment lines into `puzzle_pad_scale.dart`'s doc so the screen returns to 372.
- **should** docs/briefs/m16/phonehost3/run.log:8 the night job ran 127 turns against its brief's "never over 120", and night-report.md does not say so → the next night-sized job splits the work or the brief's turn rule gets an owner's exception.
- **could** packages/party_host/lib/src/ui/puzzle_results_widgets.dart:248 the label is measured with no `textScaler: MediaQuery.textScalerOf(context)` although the drawn `Text` scales, so a results screen outside the frame (which sets `noScaling`) would measure short → pass the scaler, as night_footer_buttons.dart:39 does.
- **could** packages/party_host/lib/src/ui/night_footer_buttons.dart:46 the `fontSize == null` branch returns a width with no icon room, so on a look whose button type has no size the label would be cut → drop the branch (the look always sets it) or add the icon room to it too.
- **could** packages/party_host/lib/src/ui/night_start_names.dart:77 the last line of a five-player night gives its two names half the stage each (456 px), not the third-column slots the doc names, so the rows do not line up → give the split columns a fixed third each instead of `Expanded`.
- **could** packages/party_host/lib/src/ui/night_footer_buttons.dart:12 `nightFooterButtonsWidthPx` is no longer read by any lib code, so 640 is a test-only bound and nothing in the footer keeps the pair off Thumby's corner → enforce it in the footer or document it as the test's bound.
- **could** packages/party_host/test/night_labels_fit_test.dart:95 (and puzzle_controls_fit_test.dart:146) the harness lays the frame out in the whole device box, not the gate's room below the bar, so four of the five sizes build the same 960x540 frame and 852x393 builds 1170.69, not the app's 1349.21 → drive the phone sizes through the gate's room so the cases differ and the frame is the app's.
- **could** docs/briefs/m16/phonehost3/night-report.md:66 the 852x393 values ("stage 1122.7 px", 374.2 a slot) are the harness's 1170.69 px frame, not the phone app's 1349.21 (host_frame_gate.dart:20-21; pad-report.md:39), so the per-device column is not what the app draws (the stage is 1301.2, a name room 365.7) → recompute the 852x393 column from the gate's scale; teams-report.md:47 has the same 1170.69 row.
- **could** packages/party_host/lib/src/ui/puzzle_results_widgets.dart:145 the teams job also collapsed `_headline` and rewrote unrelated docs (also :353 `_NewRecordChip`), churn a reviewer has to read in a job about one label → keep such rewrites out of a single-label diff.

## Decisions to confirm

- The 52 px bar: subtract `topBarHeightPx` inside the frame mapping, or make `hostPadProvider` answer frame-relative — the second changes `leftPadRects`' contract for joined phones too (joined_view.dart:26).
- The night footer's budget: keep `nightFooterButtonsWidthPx` at all (now test-only) or let the band's 912 px and the `Flexible` in `_FrameFooter` be the only bound.
- Five players stand 3 + 2, the second row's names each half the stage; one row with a narrower slot is the alternative (night-report question 2).
- The teams' controls now draw at their own widths and leave ~81 frame px free at the row's right end (left-aligned); wanted, or spread with `spaceBetween`?
- `nightFooterButtonWidthPx` was removed from party_host's public library (exported at party_host.dart:88) with no caller in the repo; a deprecation would keep an outside user building.
- The teams' `puzzle_results_controls.dart` still needs one `part` line in `puzzle_screen.dart`; either allow it next time or drop the file from allow lists.

## Could not check

- Ran no test suite: the HEAD failure of `mirror_pad_test.dart` is read from the diff of its committed expectations and run.log:15-16, not from a run.
- No device or emulator run, so the 52 px offset and the controls' new spacing are reasoned from the code and the reports' numbers.
- s9m's original name widths (113-124 px) were not re-measured; the night report's 110.0-121.5 is taken as its own measurement.
- `analyze` and `host` at HEAD were not re-run; only `dart format --output=none --set-exit-if-changed` on the ten changed files (0 changed).

## Commit message

```
Scale the pad, size the night footer and fit the results controls

The host's pad figures are device px while a board in HostFrame draws in
frame px, so a framed round cleared the wrong place (M16 phonehost3).
A new padClearanceFor asks the pad about the device-sized box and divides
its rects and px/mm by the frame scale. The night footer's pair takes its
labels' own width, and the start card re-flows five or six names onto two
rows. The results' controls take shares measured from their labels, so
Change teams draws whole at the five sizes. New tests fail on the old code.
```

## Status row

| wave1 pad night teams | done: pad rects scaled into the frame (852x393, 640x360, unframed), night footer pair 521 px in a 640 budget, six start names whole, results controls whole at five sizes; open: pad rects still 52 device px low (needs the owner's mapping), `mirror_pad_test.dart` fix uncommitted so `phone` fails at HEAD |

## Delete

- none
