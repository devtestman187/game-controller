# wave2 review — f1 (a framed board's pad clearance)

## Summary

Verdict: **clean** (no must, no should; five coulds, all tidying).
- must 0, should 0, could 5.
- The fix is the brief's mapping and nothing else: `leftPadRects` gets the room plus the bar and each rect is moved back up by it, `leftPadRects` and the division by `s` are untouched, and `puzzle_screen.dart` is 372 lines.
- The brief's three items are done, and the tests now compare with the D-pad the screen DRAWS, not with the pad's own answer, so the old mapping (Up arm top 60 device px against the drawn 8) fails them.
- Checks: `phone` PASS (63 s), `host` PASS (109 s), `flutter analyze` no issues, `dart format -o none --set-exit-if-changed` on the six Dart files 0 changed, and the three pad test files 12/12 pass.
- The three that matter most: `host_overrides.dart:89` uses the bar constant where `hostBarHeightProvider` is 0 inside the frame (a later "cleanup" would reinstate the bug); `mirror_pad_test.dart:338` re-derives the fix's arithmetic instead of the drawn pad; the two drawn-arm helpers exist twice (frame test and screen test).

## Findings

- **could** controller_app/lib/src/host/host_overrides.dart:89 `_hostPadRects` adds the `topBarHeightPx` constant while `hostBarHeightProvider` is 0 inside the gate's frame (host_frame_gate.dart:60 overrides it), and the doc at :82-88 does not say why the constant is right → add one clause to that doc ("the bar is the phone's, in device px, not the frame's 0") so the next reader does not read the provider and bring the 52 px bug back.
- **could** controller_app/test/mirror_pad_test.dart:338-345 the expected value restates the fix's own arithmetic (`leftPadRects(room + bar)` less the bar) rather than the pad that is drawn, so it pins the formula and not the placement → take the arms from `find.byKey(const Key('dpad'))` as pad_clearance_screen_test.dart:22 does, or say in the comment at :333-337 that the drawn placement is pinned by the other two files.
- **could** controller_app/test/pad_clearance_frame_test.dart:16 (also :30) `frameScaleAt` and `drawnArmsInBoardBox` are copied verbatim into pad_clearance_screen_test.dart:16 and :22 → move both into `test/support/host_app.dart` so the bar and the gate's scale are stated once.
- **could** controller_app/test/pad_clearance_frame_test.dart:77-85 this loop repeats pad_clearance_screen_test.dart:57-63 exactly (the same drawn arms at 852x393) → keep only what this test adds (pad.rects == drawn at :69-75, pxPerMm at :86) or drop the new file's 852x393 case; the brief asked for both, so one of the two copies is redundant.
- **could** docs/briefs/m16/phonehost3/f1-report.md:59 "only the eight files in `allow:` were written": the commit writes 7 files (all eight allowed ones but `packages/party_host/test/puzzle_pad_clearance_test.dart`) → say seven.

## Decisions to confirm

- Where the pad's box contract is written: it now lives in `padClearanceFor`'s doc (puzzle_pad_scale.dart:13-21) as "the box it is asked about", describing what the phone app's override answers; a TV or Windows host will read the same doc, so confirm that wording is the contract all hosts tune to.
- The bar in the mapping is the phone's device-px constant, never `hostBarHeightProvider` (0 inside the frame); this is right today but stays implicit, so confirm it should not become a provider read.
- pad_clearance_frame_test.dart:24/:57 now pin the drawn D-pad side (317) and the Up arm's top (8) as recorded figures, so a later `padLayout` change fails the test even when the mapping is right — confirm recorded figures are the wanted behaviour (the wave1 review asked for them).

## Could not check

- No device run: the mapping is verified in widget tests at 852x393 and 640x360 only, not on a phone whose safe-area insets move the bar.
- "The new test fails on the old code" is reasoned, not run: this review may change no file, so the old mapping was checked by its figures (Up arm top 60 device px = 95.02 frame px against the expected 12.67) rather than by a run.
- No `run-findings.md` exists at this commit, so there were no runner entries about f1 to weigh.
- Stick and gyro pad modes are not measured at either size; the shift is applied after `leftPadRects` for every mode, so only the arithmetic is shared, not a measurement.
- Running `tools/check.sh phone` and `host` rewrote the six tracked `site/shots/*.png`; they were put back from HEAD, so the tree holds only this report.

## Commit message

Review wave2 f1: the framed board's pad mapping

Checked f1 against its brief: the pad override answers in the board's own
box (the room plus the bar, shifted back up), leftPadRects and the
division by the frame scale untouched, puzzle_screen.dart back to 372.
The new screen test and the re-pinned frame and mirror tests compare
with the D-pad the screen draws, so the old 52 px mapping fails them.
phone and host suites pass, analyze and format are clean. Five coulds,
no must or should: the bar constant against hostBarHeightProvider, the
mirror test's formula, and the drawn-arm helper written twice.

## Status row

| M16 phonehost3 f1 review | done: f1 checked against its brief and the coding guidelines, f1's pad mapping verified against the drawn arms, phone and host PASS at 4ed8c34e; open: the five coulds in wave2-review-report.md, finding 3 (arena footer budget), findings 5 and 9-15, and the device check of the 52 px mapping |

## Delete

- none
