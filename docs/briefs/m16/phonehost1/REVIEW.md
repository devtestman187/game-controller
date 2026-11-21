# M16 phonehost1 — the run's review

## Summary

Verdict: **one fix batch**. 0 must, 8 should, 10 could (18 findings).
Both per-job reviews are carried in; nothing they found was fixed later (checked against the final code at 9b4c4ca1).
The five that matter most:

1. `_frameMedia` keeps the device's `textScaler`, so a phone host with larger system text overflows the fixed 960x540 layout.
2. Nothing switches the look's type to `ToyType.frame` inside `HostFrame` (DESIGN section 5 says it must), and S2's tests
   build a TV look, so a phone host's footer `ToyButton`s draw 18 px = 12 dp at s 0.667 — under the 20 px floor.
3. The frame divides the device's safe-area insets but no new widget claims them: a notched phone host loses its header and footer.
4. `phone_fit_picker_join_test.dart` rewrites the committed `s7-results.json` even when only some of its 20 cases ran.
5. `ScoreRow`'s `delta == 0` and `maxPoints == 0` rules have no test.

Hand-fixes: `run.log` has no `HAND-FIX` line (checked; `grep HAND-FIX docs/briefs/m16/phonehost1/` matches only this brief).
Unverified: no fix was made by reasoning alone; S9a's guard was measured on the no-write path, its write branch is unexercised (finding 13).
Checks I ran: the two frame test files (39 pass), `dart format` on the 10 changed Dart files (0 changed),
`dart analyze` on the four new lib files (no issues).
Fix jobs (no shared files, one wave): A = 1, 2, 9 (host_frame.dart, toy_look, host_frame_test.dart; phone) ·
B = 3, 6, 16 (host_frame_screen.dart, host_frame_screen_test.dart, s2-report.md; phone) · C = 5 (score_row.dart, new
score_row_test.dart) · D = 10, 11 (round_segment.dart, new round_segment_test.dart; phone) · E = 7, 13
(tablet_board_png_test.dart) · F = 4, 17 (phone_fit_picker_join_test.dart, s7-report.md) · G = 8 (the picture tests).
Second wave: 12, 14 (host_frame_test.dart) and 18 (the three test tables).

## Findings

- **should** packages/party_host/lib/src/ui/host_frame.dart:63 `_frameMedia` copies the device's `textScaler` into the frame, so an accessibility font scale on a phone host enlarges every frame label inside a fixed 960x540 layout and the 20 px-floor screens overflow → set `textScaler: TextScaler.noScaling` in `_frameMedia`, or write the choice into DESIGN section 2. (from: wave1 review)
- **should** packages/party_host/lib/src/ui/host_frame.dart:53 `HostFrame` provides `HostFrameInfo` but never a look whose type is `ToyType.frame`, which DESIGN section 5 requires ("the host picks `frame` when it is inside `HostFrame`"), and `host_frame_screen_test.dart:83` draws with `tv: true`, so a phone host's footer `ToyButton`s (host_frame_screen.dart:125) draw 18 px, 12 dp at s 0.667 → give `ToyLook.build` an explicit `type:` and have `HostFrame` provide a `ToyLookScope` with `ToyType.frame` around its child, then test a footer with a phone-shaped look. (from: across jobs — s2-report.md:104, wave2 decisions)
- **should** packages/party_host/lib/src/ui/host_frame_screen.dart:51 the scaffold's column is the frame's whole screen with no `SafeArea` (no SafeArea anywhere in the run's new files), so a notched phone host draws the 64 px header and the footer under the cutout and the `padding / scale` at host_frame.dart:66 is computed and never read → wrap the column in `SafeArea` in the scaffold, so every screen claims the insets once, or drop the division. (from: across jobs — s1-report.md:35, s2-report.md:94)
- **should** packages/party_host/test/phone_fit_picker_join_test.dart:71 `tearDownAll` rewrites the committed `s7-results.json` whenever `_results` is non-empty, so a run in which one of the 20 cases fails silently replaces the evidence file with a partial one → write only when all 20 cases are in (`_results.length == 20`). (from: wave2 review)
- **should** packages/party_host/lib/src/ui/score_row.dart:117 the `delta == 0` rule for hiding `+n` and the `maxPoints <= 0` guard at :128 have no test, so a row drawing "+0" or dividing by zero would still pass → add a `test/score_row_test.dart` with a `delta: 0` row (no "+0", no exception) and a card with `maxPoints: 0` (empty bar). (from: wave2 review)
- **should** docs/briefs/m16/phonehost1/s2-report.md:65 the report claims the tests assert "chip 48 px inside the 64 px header", but `host_frame_screen_test.dart` never reads `roundChipHeightPx` and tests `RoundSegment` only in a bare `Center` (:355, :376, :393), so the chip's fit could regress unnoticed → add the header test (a 48 px chip inside a 64 px header at the five sizes) or drop the claim. (from: wave2 review)
- **should** packages/puzzle_game/test/tablet_board_png_test.dart:14 the doc comment still says "the same guard the other picture tests use", which is false — no other picture test in `packages/` has an `UPDATE_PNG` guard → say "the guard `party_host`'s `PHONE_FIT` tests use". (from: wave1 review)
- **should** packages/puzzle_game/test/tablet_board_png_test.dart:15 the `UPDATE_PNG` guard lives in this one file only, so every `tools/check.sh puzzle` run still rewrites committed PNGs (run.log:8 lists the 13 the runner had to delete after S9a) → give the remaining picture tests the same guard from one shared helper. (from: across jobs — s9a-report.md:27, run.log:8)
- **could** packages/party_host/lib/src/ui/host_frame.dart:43 a device size of zero (a minimised desktop window, before the first layout) makes `scale` 0 and `frame` NaN, and the `SizedBox` at :48 then asserts on a non-finite size → return `const SizedBox.shrink()` when `size.isEmpty` before computing the scale. (from: wave1 review)
- **could** packages/party_host/lib/src/ui/round_segment.dart:90 the `Semantics(button: true)` has no `onTap` and the tap handler sits under `ExcludeSemantics` (:94), so a screen reader (TalkBack on a phone host) finds a button it cannot press → pass `onTap: onPressed` (null when disabled) to the `Semantics`. (from: wave2 review)
- **could** packages/party_host/lib/src/ui/round_segment.dart:97 a segment built with `onChanged: null` ("a night already under way") is never tested → add a test that taps and presses Enter on a disabled segment and asserts no callback and no focus. (from: wave2 review)
- **could** packages/party_host/test/host_frame_test.dart:242 the focus test only asserts the focus node moves, which a pass-through builder also passes, so it says nothing about the transform at s = 2 → also assert the moved button's rect is its frame rect times 2 (`tester.getRect`). (from: wave1 review)
- **could** packages/puzzle_game/test/tablet_board_png_test.dart:96 the `_updatePng` write branch is executed by no run, so a broken path or flag spelling would only show on the day someone refreshes the picture → exercise it once against a temp path, or note in the doc comment that the branch is manual-only. (from: wave1 review)
- **could** packages/party_host/test/host_frame_test.dart:151 `void _ignore(_Seen seen) {}` declares a parameter it never uses, which the guidelines' leftovers rule rules out → `void _ignore(_Seen _) {}`. (from: wave1 review)
- **could** packages/party_host/test/host_frame_screen_test.dart:34 the test restates the scaffold's heights as bare numbers (`64`/`84` here and at :173, :192, :198; `48` at :242) → use `hostFrameHeaderHeightPx`, `hostFrameFooterHeightPx` and `2 * hostFrameGutterPx`. (from: wave2 review)
- **could** packages/party_host/test/host_frame_screen_test.dart:178 the brief asks for a title at the header's left, but the test only reads the title's size and `maxLines`, so a centred title would pass → assert the title's rect `left` is `hostFrameGutterPx` and its right clears the chip. (from: wave2 review)
- **could** docs/briefs/m16/phonehost1/s7-report.md:13 "the smallest text is 10.0 dp" covers only `RenderParagraph`s (`phone_fit_support.dart:333`), while the join screen's badge numbers are painted, so a smaller painted number would go unreported → say the figure is paragraph text, or add the painted badge size to the method. (from: wave2 review)
- **could** packages/party_host/lib/src/ui/host_frame.dart:8 the frame's 960x540 and `s = min(W/960, H/540)` now appear four times (here, private; host_frame_test.dart:45-56; host_frame_screen_test.dart:45-56; phone_fit_picker_join_test.dart:27), so a change to the design frame would leave every test green against the old one → export the design frame size, or move the five-device `_cases` into `test/support/`. (from: across jobs — s2-report.md:52, :113)

## Open questions

1. The phone app's one `MaterialApp` draws both the pad screens and host mode, so the root builder would scale the pad too (s1-report.md:47-55) — suggest a provider gate in `controller_app` that wraps only host mode, not a nested app.
2. Where the frame's safe area is claimed (s2 open question 1) — suggest the scaffold takes it (finding 3), so S3-S6 add none.
3. The footer's paper band the design shows (s2 open question 2) — suggest S3 adds it to `HostFrameScreen`, not each screen.
4. The final scores' taller winner row (s2 open question 3) — suggest an optional named-const `heightPx` parameter in S4, not a flag.
5. Whether a score row draws ink on a card or `onBackground` on the sky (s2 open question 4) — suggest ink, as S2 assumed; S4 puts the rows in a `ToyCard`.
6. The bar fills by `points / maxPoints` while DESIGN rule 4 writes "bar (width = points)" (wave2 decisions) — suggest keeping `points / maxPoints`, so the leader's bar fills the slack.
7. S2's contract for S3-S6: the 24 px gutter and the `Scaffold` live in the scaffold (s2 Decisions 2, 3; wave2 decisions) — suggest confirming it in the S3 brief.
8. S7 measured only the picker's first card as its way on; `pickArena` and `pickPartyNight` share the list (wave2 decisions) — suggest that is enough, and S8 checks the settings button above the fold at 640x360.
9. The join screen with nobody joined was not measured, and its two empty seats can only be tighter (s7-report.md:122-124) — suggest S8 measures that case.
10. `ToyType.frameSmall` is a static beside the set rather than a `small` field (toy_type.dart:156; wave1 decisions) — suggest keeping it; DESIGN's "small 20" reads as the same object.
11. `ThumbySlot`'s `ValueKey` over the spot decides M17's reset behaviour now (host_frame.dart:151) — suggest keeping it and telling M17 in its brief.
12. The ring is 4 frame px, so 8 device px at s = 2, while DESIGN line 71 says the focus ring size is unaffected (wave1 decisions) — suggest accepting the scale and rewording DESIGN to "ring size in frame px".
13. `live_stats_share_test` failed once in a full host run with two IDs in the other order (s1-report.md:86-88) — suggest a small fix job that isolates the state the two tests share.

## Numbers against targets

- S7 at 640x360 in the frame: smallest text 10.0 dp against the target of 20 frame px = 13.3 dp (DESIGN section 1, rule 3), and 10.917 dp at 852x393; both screens fail.
- S7 at 640x360 plain: the picker scrolls 253 dp (557 content in a 304 viewport) and the join screen's side cards 49 dp (120 in 71) against "no scroll"; at 852x393 the same are 4 and 16 dp.
- `ToyType.frame` at s 0.6667 gives 26.67 / 18.67 / 14.67 / 13.33 dp for 40 / 28 / 22 / 20 frame px: meets the 13.3 dp floor, which is why S8 must move the screens to it.
- `ScoreRow`: 6 x 52 = 312 px of the 392 px body (fits), the bar 210.687 frame px wider at 852x393's frame (matches the extra width), row width 960 - 48 = 912.
- The 38 px badge's number is 38 x 0.55 = 20.9 px, above the 20 px floor (DESIGN says diameter x 0.5 = 19; the code's 0.55 share is what keeps it legal).
- The focus ring at 4 frame px is 2.67 device px at 640x360, 4 at 1024x768 and 8 at 1920x1080, against 4 today (DESIGN line 71: "unaffected").
- `docs/design/m13-tablet-board.png` is committed at 126,808 bytes while today's render is 167,512 (s9a-report.md:18, :30-33); the new test's floor is 5,000 bytes, so the committed picture stays stale and green.
- Sizes: largest new lib file 173 lines (`score_row.dart`), largest test 416 (`host_frame_screen_test.dart`, limit 500); all within the guidelines.

## Could not check

- Any real device: the font scale (finding 1), the phone host's footer (2), a notched phone (3) and TalkBack (10) are reasoned from the code, not run.
- A real minimised window (finding 9): reasoned, not reproduced.
- `tablet_board_png_test.dart`'s `UPDATE_PNG` write branch: not run, it writes outside this job's `allow:`.
- The full `host`, `puzzle` and `look` suites and `tools/review.sh`: only the two frame test files were run here, so the one-off `live_stats_share_test` failure and S2's "0 fail" are unverified.
- The 13 PNG rewrites: taken from run.log:8, not re-run.
- `HostFocusRing` drawing inside the frame: still never run anywhere; the run's tests only exercise focus movement.

## Commit message

Review the phone-host run: 8 shoulds, 10 coulds, no musts

- Both per-job reviews carry over; nothing they found was fixed later. The one fix (S9a's PNG guard) holds on the no-write path.
- Three shoulds came from reading the run as one change: the frame keeps the device's text scale, no look switches to
  `ToyType.frame` inside it (so phone-host footers draw 12 dp), and nothing claims the safe-area insets it divides.
- Further shoulds: the fit test can overwrite the committed results with a partial run, `ScoreRow`'s zero and empty-card
  rules are untested, and the PNG guard's doc comment and reach are still thin.
- The coulds are the per-job reviews' small ones plus one across jobs: the frame's 960x540 and scale math live in four
  places, three of them tests.

## Status row

phonehost1 reviewed: S1 (HostFrame/HostFrameInfo/ThumbySlot/hostFrameBuilder, ToyType.frame + frameSmall), S2 (HostFrameScreen, ScoreRow + ScoreRowData, RoundSegment + RoundOption) and S9a (tablet-board PNG guarded by UPDATE_PNG) are done and green; S7 measured the picker and join screen at five sizes. Open: 8 shoulds and 10 coulds (18 findings, no musts), the phone-app wiring gate, the frame's look type, safe area and footer band, S3-S6, S8, S9's matrix and TV check.

## Delete

- none

## Verdicts (Claude's batch driver, Nov 20)

- Fixed in f1 (c67c9d37): findings 1, 2, 9 (also 12-adjacent focus rect check was not added; deferred). Fixed in f2 (d992a92f): 3, 6. Fixed in f3 (406bb9f0): 10; 5 and 11 added as tests (finding 5 pinned, not proven: coverage-only).
- Hand-fixed (HAND-FIX line in run.log): 4 (and the cause of f1-f3's result 4: the S7 test rewrote s7-results.json on every run; now only with PHONE_FIT=1 and a complete run), 7.
- Deferred to docs/code-health.md ("M16 phonehost1"): 8, 12, 13, 14, 15, 16, 17, 18 and wave3's five coulds; open questions 1-13 go to the main session (STATUS.md).
- wave3 review: 0 must, 0 should, 5 could, all deferred; the safe-area file has 7 of 9 tests that pin existing behaviour, only the notched ones prove the fix.
