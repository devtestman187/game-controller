job: m12 step3 s3c-b G4 — the measuring tools
stop: after G4. The plan (docs/briefs/m12/s3c-b-g1-plan.md) with the decisions below is the job.
read: docs/briefs/m12/s3c-b-g1-plan.md (the plan) · docs/design/m12-sessions.md §1, §2, §4, §6 (the contract; it wins) · docs/coding-guidelines.md · the files in plan §7 as they are now

since the plan was written (re-read these files, line numbers moved):
- s3b G4 landed: `PuzzleSession` is built in `puzzle_game/lib/src/play_view.dart` `initState`, with no settings; `ArenaSession` in `arena_view.dart` the same. So the rate reaches both through `GameSession`'s default, as plan §4 says.
- s3c-a landed: `FrameView` takes a `ViewerStats` and `nowMs` (`game_kit/lib/src/frame_view.dart`). Don't change it.
- s5a landed: `session.dart` already lost `DelayStats` and `RatingScheduler` (to `session_stats.dart`), and `HostType` gained `tablet`. **Drop plan files 10–12**: don't move them again. `session.dart` only gets the `view` counts.

decisions (answers to plan §9):
- Q1 Yes: `HostingSettings? settings` with `settings ?? HostingSettings.fromEnvironment()`.
- Q2 Yes: `FRAME_RATE_HZ` and `START_GAME`.
- Q3 (a): print the last drain with its sample count.
- Q4 No unit test for `SimView`; the smoke `frames` step proves it.
- Q5 As proposed: the values on each mode row in the CSV and the compact columns in both group tables; no new table.
- Q6 `FrameView` keeps taking `ViewerStats` (the contract). Step 6's screen reads `client.viewerStats` once and doesn't use `!`; nothing in this job.
- Q7 As written: the step restarts the TV app only when this run started it; otherwise `SKIP`.
- Q8 `smoke.sh` at ~400 is accepted (a script).

do: plan §1 to §6 in plan §7's order, minus files 10–12. Every check green after each slice.
tests: as plan §1–§5 list them. Existing tests: no expected value changes except the CSV column count (26 → 33, plan file 17); list any other old → new with the reason.
report: line counts of every file touched or created (flag > 300), test counts per check before and after, and the output of one real run of `tools/smoke.sh` if the sandbox lets the TV app start (otherwise say so; Claude runs it).
rules: no lib file over 400 (tests 500, scripts accepted at ~400); new lib files ≤ 300; no wire change; release builds ignore both defines · tools/review.sh: no FAIL on your lines.
allow: docs/briefs/m12/s3c-b-report.md · packages/connection · packages/metrics · packages/game_kit/lib/src/hosting_settings.dart · packages/game_kit/lib/src/game_session.dart · packages/game_kit/test · tv_test_app/lib · tv_test_app/test · tools/tv-dev.sh · tools/smoke.sh · docs/dev-tools.md
pub: yes
check: format analyze protocol connection metrics kit arena puzzle host phone tv
report: docs/briefs/m12/s3c-b-report.md
