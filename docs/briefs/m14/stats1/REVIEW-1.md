# M14 stats1: the run's review

## Summary

Verdict: **one fix batch** — 1 must, 7 should, 6 could.

- Re-ran what is cheap: `dart test` in `packages/metrics` → 145 passed (b5-2's number), `dart analyze` → no issues. The Flutter suites and `tools/review.sh` were not run (below).
- The five that matter: `round_frames_test.dart:62` lost its `endsWith` to `start_s`; both CSV docs still say the rounds CSV has 16 columns where it has 17; `SessionRecorder` has no clock of its own, so two new host tests run on the real clock (§9); `_sinceStartS` adds a bare `1000`; `run-base` is not an ancestor of the tip, so the run's diff drags in the whole bugs10 run.
- Then: `roundEnded` is 9 parameters and 41 body lines; the milestone `STATUS.md` has no stats1 line; code-health records only `ModeRow._row` of the kept findings.
- Fixed, unverified — needs device check: b4's `level_` tag (never seen in an export, the claim rests on commit dates), b6's Windows `hz`/tags (probed on a real host, but the export's build is still a guess), and B-019's phone lifecycle (in this range; STATUS already marks it).
- No finding is pinned by `controller_app` tests; the only phone files in the diff are bugs10's, and I checked them for conflicts with the stats work only.
- Shared files to watch when splitting the batch: `session.dart` (findings 4 and 5), `session_clean.dart` (9 and 10) and `report.dart` (11 and 12); the rest are one file each.
- Owner-only questions: the one device round bundle for b4/b6, a robot win in the printed tables, and whether the analysis reads the CSVs by column position.

## Findings

- **must** packages/metrics/test/round_frames_test.dart:62 the header check was loosened from `endsWith(',players,frames_drawn,frames_late,fps')` to `contains(…)` and renamed while b5-2 appended `start_s`, which §2 "weakened checks" rejects and the b5-2 report's Files changed never mentions → assert `endsWith(',players,frames_drawn,frames_late,fps,start_s')` and keep this the one literal-header test for the rounds CSV (`round_winner_csv_test.dart:30` and `round_offset_test.dart:85` pin pieces of it). (from: b5-2-offset review)
- **should** docs/dev-tools.md:343 and docs/design/m12-report.md:22 both give the rounds CSV as 16 columns ending `fps`, while `roundsCsvHeader` (report_rounds.dart:159-161) writes 17 ending `start_s`: fix1 wrote the 16 the day before b5-2 added the column → add `start_s` to both, and make each CSV-column job that cannot edit `docs/` list the two lines in its report. (from: across jobs)
- **should** packages/party_host/lib/src/session_recorder.dart:76 `atMs: host.nowMs` makes the real host clock the only clock, so round_offset_recorder_test.dart:56 asserts `61.5` within 50 ms of real movement, `:89` cannot tell old from new code, and round_stats_test.dart:22 must delete `startS` from every round, all against §9 "no real time in tests" → inject `int Function() nowMs` into `SessionRecorder` (as `random` is at :22) and assert the exact offsets. (from: b5-2-offset review, across jobs)
- **should** packages/metrics/lib/src/session.dart:207 the new `1000` in `_sinceStartS` is a bare ms-to-s divisor that §2 rejects, and the b5-2 report filed the review.sh note as "unchanged" though it is on this job's added line → divide by `Duration.millisecondsPerSecond`. (from: b5-2-offset review)
- **should** packages/metrics/lib/src/session.dart:227 `roundEnded` takes 9 parameters (a2 added `robotWin` to the 8 it had before the run; b5-2's report says ten) against §3's "at most 5, beyond that a value object", and its body (238-278, 41 lines) sits over ~40 — the b5-2 report calls that note pre-existing, but the body only passed the limit after this run's three added lines → a `RoundEnd` value object and the round-map block (246-263) as a private helper. (from: across jobs, b5-2-offset review)
- **should** docs/briefs/m14/stats1/run-base:1 `3566fe85` is not an ancestor of the tip (merge-base `5467267`), so the run's diff and this review carry the whole bugs10 run (five code files, its briefs and its run review) and the stats1 briefs commit twice → point the base at `edaeb3e` (bugs10's close) and fix `tools/run-jobs.sh` to write `run-base` from the run's real start. (from: across jobs)
- **should** docs/briefs/m14/STATUS.md:7 the milestone status has no M14 stats1 line, so everything this run did lives only in the job reports' status rows → add one line after bugs10: app columns, winner/draw/players, per-round frames and fps, the session split, the round offset, the CSV docs; open: the fix batch, and no table reads the new columns. (from: across jobs)
- **should** docs/code-health.md:117-121 the new M14 stats1 section records only `ModeRow._row`, while review-rules says every kept finding goes here: the 330-line aim on `session.dart` (340 now), `roundEnded`'s 9 parameters and 41-line body and the `session_clean.dart` name are missing → add a row each with rec. "when touched", and the two unread round columns as "before a milestone". (from: across jobs)
- **could** packages/metrics/lib/src/session_clean.dart:4 `HostType` now lives in a file named for string cleaning, so neither half of the name fits what the file holds → rename it to something both halves fit (`session_format.dart`) or give `HostType` its own file exported by `session.dart:12`. (from: b5-1-split review)
- **could** packages/metrics/lib/src/session_clean.dart:40-44 the moved device bounds are still bare numbers (`16`, `40`, `2000`) against §2 magic numbers; the move re-added unchanged text, so it is not this diff's break → name them (`maxModelChars`, `maxDeviceMm`) with the reason in the doc when the file is next touched. (from: b5-1-split review)
- **could** packages/metrics/lib/src/report.dart:217 `ModeRow._row` is 57 lines (217-273) against §3's ~40, and code-health already carries it as "when touched" → read the player's `app` once in `_PlayerRows` beside `about.hostApp` and split the mode-stat block out with the next column. (from: a1-app-version review, fix1)
- **could** packages/metrics/lib/src/report.dart:158 `appCell` only turns a comma into a semicolon: a `"` would break the row, a real semicolon reads as a replaced comma, and `model` one line above at :122 still uses `_csv` quoting, so one CSV now has two comma rules (the doc's example "iPhone15,2" is a model, not an app version) → quote both app cells with `_csv`, or write in the docs that app cells never quote. (from: across jobs: a1, fix1)
- **could** packages/metrics/test/csv_app_comma_test.dart:5 the doc comment points at `session.dart`'s `_technical`, which b5-1 renamed to `technicalPattern` and moved to `session_clean.dart:50` → name the new symbol and file. (from: across jobs)
- **could** docs/briefs/m14/stats1/b5-1-split-report.md:23,41 the Summary says the helpers serve "three call sites" where `session.dart` has six references (75-77, 162, 169, 247), and Decision 4 names two new dartdocs while the move wrote three (`cleanDevice` at session_clean.dart:36-38) → say six references and name all three docs, dropping the "verbatim" claim. (from: b5-1-split review)

## Open questions

- b4: was a puzzle round on m14.4 (build 571) ever played? — Safest: one device round bundle for b4 and b6 (one puzzle round, one Windows round, read `host.app` and `rounds[].tags`), the owner's, and no code either way.
- a2: should a robot win show in the printed tables? — Safest: not now; the CSV says `robot` and no table has asked.
- a2: is a space the right team separator, or `+`? — Safest: keep the space (no reader depends on it; changing it later is one line).
- a2: is the host-suite temp-folder flake (`live_stats_lifecycle_test`, `PathNotFoundException`) worth a bug? — Safest: yes, a bugs11 entry; it is a Windows test-only fault, no app path.
- a2: should the recorder read `robotWin` from the winner id instead of a key? — Safest: keep the key; `'robo'` as a literal in `party_host` is hard-coded identity (§2).
- b4: is a cross-package tag test wanted in `party_host/test`? — Safest: no; `round_stats_test.dart:83-106` already carries a record's tags to the summary.
- b5-1: is `HostType` in `session_clean.dart` acceptable, and is `roundTagsOf` the name? — Safest: keep the name, rename the file (finding 9) rather than move the type again.
- b5-2: strip `startS` in `round_stats_test`, or assert `0.0`? — Safest: strip until the recorder's clock is injectable (finding 3), then assert the exact values.
- b5-2: `start_s` after `fps`, or next to `time_s`? — Safest: keep it after `fps`; appending is what keeps positions stable, and nothing reads by position.
- b5-2: a backwards clock and a round at the session's start both read `0.0` — tell them apart? — Safest: not now; if it matters, leave the key out instead of clamping, since a missing key is distinguishable.
- a1: do the owner's analysis files read the CSVs by column count? — Safest: no (the repo reads none), but the appended columns assume so.

## Numbers against targets

- `packages/metrics/lib/src/session.dart` is 340 lines: over the b5-1 brief's 330 aim (and the guideline's ~300), under the 400 limit; it was 371 at the run's base and 324 after the split.
- `roundEnded` body 41 lines against ~40 (§3); `ModeRow._row` 57 against ~40; `live_stats.dart` 380, exactly bugs10's cap and over the ~300 aim (in code-health).
- CSV column counts the docs state against the code: stats 35/35 match; rounds docs say 16, the header has 17 (finding 2).
- metrics tests: 145 in my run, matching b5-2's report (117 at a1, 123 at a2, 132 at b5-1).
- party_host suite counts in the reports (460, 463, 466) were not re-run here.

## Could not check

- The Flutter suites (`party_host`, `controller_app`, `test_game`), `tools/review.sh` and `tools/check.sh format`: not run; the per-job reviews ran them.
- How often `round_offset_recorder_test.dart:56` flakes on a loaded machine: it needs the real clock to move under 50 ms, which no run here measures.
- Whether `_roundWaitsForFrames` (session.dart:241) can hand a frames record to the previous round when one arrives after a new round started but before its end: no game writes frames mid-round today, so I could not exercise it.
- The bugs10 commits in the range: reviewed by bugs10's own run review; I read only their interaction with the stats work.
- Nothing ran on a device, a phone host or an older peer.

## Commit message

docs: the M14 stats1 run's review

Read the run's diff (24 commits, including the bugs10 run its base
drags in) against the guidelines and the review rules, and re-ran
metrics: 145 tests pass, analyze clean. One fix batch: 1 must, 7
should, 6 could. The must is round_frames_test's header check, which
lost endsWith when start_s was appended; both CSV docs still say 16
round columns, the recorder runs on the real clock, roundEnded is 9
parameters, and run-base is not an ancestor of the tip.

## Status row

M14 stats1 (Nov 15, committed, unpushed, nothing built): app columns in both CSVs, winner/draw/players and robot wins, per-round frames with fps, the session.dart split, each round's start offset (`start_s`), and the CSV docs; run review verdict one fix batch (1 must, 7 should, 6 could), no table reads the new round columns yet; open: the fix batch, one device round for b4's `level_` and b6's Windows `hz`/tags, and a stats1 line in docs/briefs/m14/STATUS.md.

## Delete

- none
