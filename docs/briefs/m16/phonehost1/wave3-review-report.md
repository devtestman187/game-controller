# M16 phonehost1 wave3 (f1 f2 f3) — the review

## Summary

Verdict: **small fixes** — 0 must, 0 should, 5 could. The three jobs do what their briefs asked and every changed
test file passes; the findings are test evidence and wording, not behaviour.

1. `score_row_test.dart` passes on the old code (run-findings:1), so it pins `ScoreRow`'s rules instead of proving a fix;
   the f3 brief exempts it, and the milestone should record finding 5 as pinned, not proven.
2. Seven of f2's nine new tests also pass on the old code (zero padding, chip fit); only the two notched tests prove the
   safe area, while f2-report.md:12-14 reads as if the whole file failed on the old code.
3. `round_segment.dart:98`'s `onTap` and `host_frame.dart`'s `textScaler`/`ToyType.frame`/empty-size changes match their
   briefs and are covered by tests that fail without them (the notched safe-area tests, the semantics tap, the look/type
   probe, the button size, the zero-size build).

Checks I ran: `flutter test` on the seven frame/look/round/score test files (39 + 19 + 10 green), `dart format
--set-exit-if-changed` on the 10 changed Dart files (0 changed), `dart analyze` on both packages (no issues).

## Findings

- **could** packages/party_host/test/score_row_test.dart:41 passes on the old code (run-findings:1), so its three tests pin `score_row.dart`'s zero rules rather than prove a fix; the f3 brief exempts it → keep it as regression coverage and record finding 5 as pinned, not proven.
- **could** packages/party_host/test/host_frame_screen_safe_area_test.dart:162 like the chip test at :185, this zero-padding test passes on the old code, so seven of the file's nine tests are pins and only the notched tests at :116 prove the fix → say that in the milestone's status row rather than leaving f2-report.md:12-14 to imply the whole file failed on the old code.
- **could** docs/briefs/m16/phonehost1/f1-report.md:13 says `ToyLookScope.of` is "unchanged" and, in the same sentence, that it now calls `maybeOf` → write "behaviour unchanged; `of` now calls `maybeOf` and keeps its assert".
- **could** packages/party_host/test/host_frame_screen_safe_area_test.dart:105 keeps `SizedBox.expand(key: Key('bodyFill'))` while no finder reads that key (a copy from host_frame_screen_test.dart) → drop the key or use it in an assertion.
- **could** packages/party_host/test/host_frame_look_test.dart:139 says the 40 px title is "drawn at 80 device px" but the test asserts no device-px value → assert `40 * HostFrameInfo.of(...).scale` (80 at s = 2) or reword the comment.

## Decisions to confirm

- f1 decision 4 keeps the device's `ToySizes` (menu on a phone, tv on the TV) and changes only the type, so button heights
  still differ per host inside one 960x540 frame — check that against DESIGN rule 1's "one layout for every host".
- f2's `SafeArea` claims the left/right insets too, so a notched phone's design stage narrows by both cutouts
  (960 → 840 frame px at 640x360); no test uses a fixed-width body, so confirm S3+'s 912 px cards still fit.
- f1 decision 5 returns before the child on an empty size, so a desktop window minimised to 0x0 unmounts the navigator and
  loses its state — confirm that is wanted over an empty frame.
- f3's disabled-segment test and `score_row_test.dart` are pins (f3 says so) — confirm that is enough evidence for
  findings 11 and 5.

## Could not check

- That the new tests fail on the old code: this is a read-only job and I ran no revert; the reports (and run-findings for
  `score_row_test`) are the evidence for the four f1 tests, the two notched f2 tests and f3's semantics test.
- Real-device insets: the safe-area tests set `tester.view.padding` only, not `viewPadding`, so a device whose two differ is
  not exercised.
- How any of it looks in an app: no app wires `HostFrame` (grep finds no caller) and I started none.
- `live_stats_share_test`'s flake that f1 and f3 report: I ran only the frame, look, round and score files.
- Whether S3+ screens keep their own `SafeArea`: no screen uses `HostFrameScreen` yet, so a double claim is untested.

## Commit message

```
Review wave3 (f1-f3): 0 must, 5 could, tests and wording only

Read f1-f3's diff, reports and the five new or changed test files against
the coding guidelines and review rules A-B. HostFrame's text scaler, frame
type and empty-size guard, HostFrameScreen's SafeArea and RoundSegment's
Semantics onTap match their briefs; the frame/look/round/score files pass
(39, 19, 10 tests) and format and analyze are clean.

Findings are could-level: score_row_test and seven of nine safe-area tests
pass on the old code, f1-report:13 contradicts itself, a dead test key, and
an unasserted device-px claim in a comment.
```

## Status row

M16 phonehost1 f1-f3 reviewed: HostFrame's no-scaling text, ToyType.frame and empty size, HostFrameScreen's safe area and RoundSegment's screen-reader tap match their briefs (0 must, 5 could); open: f1's type-vs-sizes decision and f2's side insets for S3, findings 4, 7, 8, 12-18, S3-S6, S8.

## Delete

- none
