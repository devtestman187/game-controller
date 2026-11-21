# Wave 1 review — S3 (night start in the frame) and S9p (tablet-board picture)

## Summary

Verdict: **needs Claude**. Counts: must 0, should 4, could 3.
Two brief decisions are not met and need Claude's call: decision (d)'s "3 rounds autofocus" (the job
focused the footer's Shape Race instead) and item 1's "no scrollable in the body" (a `SingleChildScrollView`
stays, asserted only as `maxScrollExtent == 0`).
The s3 report's Question 4 calls `NightGameButtons` dead code; `night_scoreboard_widgets.dart:79` still uses it,
so acting on that question would break the scoreboard.
S3's screen is drawn in frame px in both shipped apps today (nothing wraps their navigators in `HostFrame`
until wph1/wtv): the phone host's night start scrolls and its type jumps from the phone look's 15/18 to 22/28.
S9p is sound: 167,512 bytes, 2486x1414, sha256 `4cd46f7e…`, reproduced; the plain guard run leaves the file alone
and the hash is unchanged after it.

## Findings

- **should** packages/party_host/lib/src/ui/night_start_screen.dart:102 the night start now lays out in frame px
  but no app has `HostFrame` above its navigator (only wph1/wtv do, and they are not in `waves.txt`), so the phone
  host opens it unscaled from `GamesScreen` and its body scrolls where DESIGN rule 6 says it does not →
  land wph1/wtv before any build, or let `HostFrameScreen` scale itself when it finds no `HostFrameInfo`.
- **should** docs/briefs/m16/phonehost2/s3-report.md:133 Question 4 lists `NightGameButtons` as dead code, but
  `packages/party_host/lib/src/ui/night_scoreboard_widgets.dart:79` still builds it (S4 has not moved the
  scoreboard) → name only `NightAwardCard`, `nightAwardCardWidthPx` and `nightGameButtonWidthPx` as unused.
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:104 decision (d)'s "3 rounds autofocus" is not
  implemented (`RoundSegment` at round_segment.dart:38 has no autofocus, and round_segment.dart was outside
  `allow:`), so the job put `autofocus: true` on the footer's Shape Race (line 124) and rewrote the rule in
  night_screens_test → add the flag to `RoundSegment` in a job that owns it, or approve the footer focus in the
  brief and say so in COMMON.md.
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:157 brief item 1 asks for "no scrollable in the
  body"; the body is a `SingleChildScrollView` and the test only asserts `maxScrollExtent == 0`
  (night_start_frame_test.dart:131) → drop the scroll view once wph1/wtv land, and until then record the net as an
  approved exception so S4–S6 do not copy it as the target layout.
- **could** packages/party_host/test/night_screens_test.dart:96 the right-press is conditional (`if (!hasFocus)`), so
  when the segment puts the focus on "5 rounds" the test never presses right and no longer proves the direction
  reaches the chip → press right from a known chip (assert which one has the focus first) and keep the check.
- **could** packages/party_host/lib/src/ui/host_frame_screen.dart:185 the band's `Padding` insets only the top by the
  ink line's width and the `Row` centres the 64 px button, so it has 12 px of paper above and 8 px below, not the
  16 px above the s3 report states (s3-report.md:36-37) → pad the band evenly or report the 12/8 split.
- **could** packages/puzzle_game/test/tablet_board_png_test.dart:96 the guarded test only writes the file when
  asked and otherwise checks `bytes.length > 5000` (line 99), so it never proves the committed picture matches
  the render and it can go stale again unnoticed → compare the rendered bytes with the file and fail on a
  mismatch (S9a's area; not asked in s9p's brief).

## Decisions to confirm

- Who owns `RoundSegment.autofocus`: the brief asked for it and forbade the file; S4/S5 reuse the segment, so it
  is cheapest now.
- The unreachable scroll as the staging answer for unframed screens (s3 Question 2): approve it for S4–S6 or
  require `HostFrameScreen` to scale itself.
- wph1 and wtv are not in `docs/briefs/m16/phonehost2/waves.txt`; with S3 the night start is the first
  user-visible screen in the apps that assumes the frame, so its order against a build matters.
- "Soon" is gone from the night's footer pair (s3 Question 3): a disabled Bumper Round now says nothing about why.
- `test/coverage_all_test.dart` does not list `award_tile.dart` or `night_footer_buttons.dart` (s3 Question 5), and
  `phone_fit_option_c_test.dart` still measures the old start card (Question 6); both need a job allowed to touch
  them.

## Could not check

- `tools/review.sh` (the report claims 0 fail, 1 note) and the full 701-test host suite; I ran only the files below.
- A visual check of the frame against DESIGN.md section 4 (no app run, pictures outside my file list).
- The other host screens whose tests the `HostFrameScreen` change could touch beyond the four files I ran.
- `run-findings.md` does not exist; `run.log` shows only "tests-first ok" for `night_start_frame_test.dart`.

Checks run: `dart format --set-exit-if-changed` on the six changed Dart files (0 changed); `dart analyze` on the
four lib files and the new test (no issues); `flutter test` `night_start_frame_test.dart` +
`night_screens_test.dart` (43 pass), `host_title_bar_test` + `host_frame_screen_test` +
`host_frame_screen_safe_area_test` + `controller_menus_test` (44 pass), `arena_touch_ready_test` +
`arena_touch_solo_night_test` (8 pass), and `packages/puzzle_game/test/tablet_board_png_test.dart` without the
define (1 pass, hash unchanged).

## Commit message

Review the phonehost2 wave 1 jobs: S3 night start, S9p picture

- Wave 1 read against the briefs, the coding guidelines and review rules parts A and B.
- No must; four should: the unframed app (wph1/wtv not scheduled), the report's dead-code claim about
  NightGameButtons, the unmet "3 rounds autofocus", and the body scroll the brief did not allow.
- Three could: the conditional right-press, the footer band's 12/8 padding, and the PNG guard never
  comparing the file.
- Checks: format, analyze, the six affected test files (96 tests) and the picture's guard run.

## Status row

Wave 1 reviewed: S3 puts the night start on HostFrameScreen (AwardTile, NightFooterButtons, footer band, back arrow; 31 tests) and S9p refreshed the tablet-board picture (126,808 -> 167,512 bytes); open — S3's autofocus and no-scroll decisions, the report's Question 4 dead-code claim, wph1/wtv before a build, coverage_all_test and the fit run.

## Delete

- none
