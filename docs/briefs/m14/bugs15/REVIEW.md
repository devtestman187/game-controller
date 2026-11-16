# Review of the M14 bugs15 run (91054c35..5790ee7f), read as one change

## Summary

Verdict: **needs Claude's design**. 2 must, 6 should, 11 could. The must is a rules conflict: cov-1's brief
asks the generator for `// ignore_for_file: unused_import`, `tools/review.sh:392` fails any `// ignore:` line,
so the hand-fix (run.log:22) dropped it and excluded the generated test from `dart analyze` in 11
`analysis_options.yaml`, none in cov-1's `allow:`. `flutter analyze` is clean today only because of that
exclusion, so a broken import in a committed coverage test would pass Analyze. Claude must pick one rule
(generator ignore allowed for GENERATED files, a written exception, or `review.sh` skipping them) first.

Next four: cov-1's report claims a `// ignore_for_file` no generated file has (must) and that only its
`allow:` files were written (should); the 92.8% total equals the brief's before-number with no before/after
run; `_waiting`'s end on `roundScreenClosed` is untested although the report names a test for it.

Owner's questions: may workers run `dart run`/`tools/coverage.sh` (cov-1 Q1), does `assets` get
`flutter_test` (cov-1 Q3), does a night's card play the lobby loop (b029 Q2).

Fix jobs: A = the two musts + the allow: should (11 `analysis_options.yaml` + cov-1 report); B = the `_waiting`
test + two `game_screen`/`lobby_music` coulds (`host`); C = `docs/dev-tools.md` (4 findings, split 2+2); D =
`tools/*.dart` + cov-1 report; the before/after number needs a job that may run the script. None is pinned by
controller_app (phone) tests.

## Findings

- **must** packages/protocol/analysis_options.yaml:9 (and assets:4, controller_app:15, connection:9, game_kit:4, metrics:9, party_host:4, puzzle_game:4, test_game:4, toy_look:4, tv_test_app:15) excludes the generated coverage test from the analyzer, so `dart analyze --fatal-infos` (`tools/check.sh:22`) never sees a broken or unused import in it, and 11 files were written outside cov-1's `allow:` → drop the excludes and let the generated file carry the brief's `// ignore_for_file`, with `tools/review.sh:392` taught to allow it on GENERATED files (Claude's decision: three rules disagree here). (from: cov-1 review + run.log hand-fix)
- **must** docs/briefs/m14/bugs15/cov-1-tools-report.md:66 says the generator writes `// ignore_for_file: implementation_imports, unused_import`; `packages/protocol/test/coverage_all_test.dart:16` and `tools/coverage_imports.dart:149` show an "analysis_options.yaml excludes this file" line instead → describe the tree as committed (or, after the decision above, correct both together). (from: cov-1 review)
- **should** docs/briefs/m14/bugs15/cov-1-tools-report.md:126 self-check A4 says only the 14 `allow:` files were written while the commit carries 11 `analysis_options.yaml`, and the Decisions list (:73-89) has no entry for the analyzer exclusion → state the exclusion (and who approved it) as a decision or drop it. (from: cov-1 review)
- **should** docs/briefs/m14/bugs15/b029-b030-arena-music-report.md:76 self-check 3 names `arena_back_test` as the "card × leaving" test, but that file never reads the music and `packages/party_host/lib/src/ui/lobby_music.dart:190` clears `_waiting` untested → add a "Back from the card leaves the lobby's loop playing" test to `packages/party_host/test/arena_music_test.dart`, or say the pair is untested. (from: b029-b030 review)
- **should** docs/dev-tools.md:114 the exclusions bullet is wrong three ways: `part of` files are counted in the table through their library (`tools/coverage_summary.dart:132` drops only generated files), `*.config.dart` and `*.mocks.dart` are missing (`tools/coverage_imports.dart:38`), and the localisations/plugin registrants it names are matched only by the `generated_` prefix rules → rewrite the bullet from the two tools' `_isGenerated`. (from: cov-2 review + across jobs)
- **should** docs/briefs/m14/bugs15/cov-1-tools-report.md:34 presents "the total equals the brief's 19,778/21,306 exactly" as a result while :111 says no before/after could be measured; the brief's premise was that a file was missing from the old count, so one of the two statements is false → run the coverage once with the generated test moved aside and state the real delta. (from: cov-1 review)
- **should** docs/briefs/m14/bugs15/cov-2-ci-docs-report.md:3 says the two `ci.yml` changes are "not applied" and keeps them open at :21, :95 and :122, but commit c968b552 contains them (`.github/workflows/ci.yml:49-50`, :71-93) → rewrite the Summary, the "Not applied" section, Hand-over 1 and the Status row. (from: cov-2 review)
- **should** packages/party_host/lib/src/ui/game_screen.dart:121 (378 lines) and packages/party_host/lib/src/ui/lobby_music.dart:22 (364 lines) both sit past the guidelines' "about 300 lines" and the b029 report's own decision 2 raised the file size as a constraint on the fix → plan a split (the stage reporting out of `game_screen`, the round/lobby choice out of `HostMusic`) before the next change to either. (from: across jobs)
- **could** packages/party_host/lib/src/ui/game_screen.dart:124 `waiting: _stage == _Stage.waiting` is always true (`_stage` is initialised to `waiting` at :95) → write `waiting: true`, as the brief's "with its initial stage" says. (from: b029-b030 review)
- **could** packages/party_host/lib/src/ui/lobby_music.dart:23 the class doc says "Every stage the round's screen enters says so afresh", but the results stage reports through `roundEnded` (:177) and never calls `roundScreenOpened` → say "every stage but the results". (from: b029-b030 review)
- **could** docs/dev-tools.md:106 the sample table has no column pipes or rule line, uses `protocol`/`controller_app` rows, and its invented numbers (TOTAL 80.9%) contradict the same run's real 92.8% → paste the table `tools/coverage_summary.dart:68-70` prints from cov-1's report, or label it illustrative with the real row names. (from: cov-2 review + across jobs)
- **could** docs/dev-tools.md:115 the exit-code bullet lists 0 and 1 while `tools/coverage.sh:57` and `:82` also exit 2 for a bad argument, an unknown package or a missing tool → add 2, as the `tools/check.sh` section does. (from: cov-2 review)
- **could** docs/dev-tools.md:100 "runs in each package, as the test steps do" suggests `flutter test --coverage` mirrors CI's test steps, which run `dart test` for protocol and connection (`.github/workflows/ci.yml:53-58`) → say `flutter test --coverage` runs in every package, the pure Dart ones too. (from: cov-2 review)
- **could** assets/analysis_options.yaml:4 excludes `test/coverage_all_test.dart`, a file the generator never writes for assets (`tools/coverage_imports.dart:35`) → delete the line. (from: cov-1 review)
- **could** tools/coverage_summary.dart:86 tells the reader to "run tools/coverage.sh for it" for every package without lcov, which can never help `assets` → name the assets case in that line. (from: cov-1 review)
- **could** tools/coverage_imports.dart:106 `.take(5)` is a bare 5, outside the numbers the guidelines allow bare → name it (`_partOfScanLines`) with its reason in the doc comment. (from: cov-1 review)
- **could** tools/coverage_imports.dart:159 the one generated test has an empty body, so a lib file added without rerunning the tool stays uncounted and every check stays green → compare the committed import list with `lib/` in a test, or have `coverage_summary.dart` report a lib-file count. (from: cov-1 review)
- **could** docs/briefs/m14/bugs15/cov-1-tools-report.md:99-105 says `tools/coverage.sh` was "not run" end to end, but run.log:22 records it being run during the hand-fix → update the line to say who ran it and what it printed. (from: cov-1 review decisions)
- **could** tools/coverage_imports.dart:38 and tools/coverage_summary.dart:32 hold the same generated-suffix list twice (and docs/dev-tools.md:114 a third time), with no test tying them → keep one list in one tool and have the other read it, or add a test that the two agree. (from: across jobs)

## Open questions

1. May workers run `dart run`, `bash tools/coverage.sh` and `chmod +x`? (cov-1 Q1) → yes for coverage jobs: the script writes only ignored `coverage/` folders.
2. Do you want the before/after coverage delta for the PRD? (cov-1 Q2) → yes, as a job that may move the generated test aside for one run.
3. May `assets/pubspec.yaml` get `flutter_test` so its one lib file counts? (cov-1 Q3) → yes, one small job; until then say 419 of 420 files.
4. Package names in `coverage.sh`: folders, last parts, or `check.sh`'s short names? (cov-1 Q4) → keep both forms it has and document them; don't add a third.
5. Should `.github/` be writable by workers? (cov-2 Q1) → yes, limited to `ci.yml`, since the hand-fix had to apply the patch.
6. Keep the docs' CI Format sentence now that the step is in the tree? (cov-2 Q2) → yes, it is now true; only the cov-2 report needs the edit.
7. Is the one-frame `arena_final` blip after Play again acceptable? (b029 Q1) → accept for now; a follow-up guards a round's clock reports until its phase is `playing`.
8. Should a night's waiting card play the lobby loop? (b029 Q2) → yes: it is the owner's stated want for the card and a night uses the same screen.
9. CI test steps use `dart test` for protocol/connection, the coverage run `flutter test --coverage` (cov-1 review) → make the CI test steps and the coverage run use one command each per package.

## Numbers against targets

- Total coverage 19,778/21,306 = 92.8% both before and after (brief, cov-1 report:21,34): the target was
  "counts every lib file"; assets' 1 lib file is still uncounted (419 of 420), and the unchanged total is
  presented as a result although no before/after was run (:111).
- Verified here by counting: 419 lib files outside assets = imports + skips in the 10 generated tests
  (controller_app 66+6, tv_test_app 19+0, connection 40+0, game_kit 11+0, metrics 16+0, party_host 99+13,
  protocol 5+8, puzzle_game 32+30, test_game 33+13, toy_look 28+0); each file's `package:` import count is
  the report's number plus the one framework import.
- Five most-uncovered files asked for in the cov-1 brief: given (`cov-1-tools-report.md:25-27`).
- `docs/dev-tools.md:106-110` sample table TOTAL 80.9% against the same run's real 92.8%: misses by 11.9 points
  if a reader takes it as current.
- Added CI time: 3 to 5 minutes estimated (cov-2 report:74), never measured on a runner.
- b029: 4/4 new tests, host suite 514 (513 before the coverage test); file limits 378 and 364 against the
  brief's 380, past the guidelines' about 300.
- `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets`: formatted, 848
  files, 0 changed, so the generated tests pass the new CI Format step. `flutter analyze controller_app
  tv_test_app packages assets`: no issues, 18.3 s.

## Could not check

- The coverage table, the 398/21 records and the five weakest files: no `coverage/lcov.info` is in the tree and a run here would write files this job may not touch.
- `tools/coverage.sh` end to end, and whether the generated tests would fail analyze without the exclusion (that needs editing an `analysis_options.yaml`).
- The CI Coverage step, the `coverage` artifact and its 3 to 5 minutes on a GitHub runner.
- The b029 music on a real iOS phone host and a TV (the report's device check).
- `tools/review.sh` was not run; the 0-FAIL claims in run.log:22-24 come from the hand-fix.

## Commit message

Review of the M14 bugs15 run: analysis excludes weaken the check

- One must: 11 analysis_options.yaml outside cov-1's allow: exclude the
  generated coverage tests, so analyze cannot fail on their imports; the
  brief's ignore line is refused by tools/review.sh, so Claude must pick a
  rule.
- One must: cov-1's report claims an ignore line no generated file has; six
  shoulds cover its other stale claims, the untested _waiting clear, the
  wrong dev-tools exclusion bullet, and two files past 300 lines.
- 11 coulds: doc, naming and tool details, all with a file and line.

## Status row

M14 bugs15 run review: 3 jobs read as one change (Arena music, coverage tools, CI and docs) — 2 must, 6 should, 11 could, verdict needs Claude's design; open: the analyzer-exclusion rule decision, the report corrections, a Back-from-the-card music test, and a measured before/after coverage number.

## Delete

- none

## Claude's verdicts (wave 1)

- must analyzer exclusion: not real. A broken import fails the coverage test at compile time; the exclusion only hides the intended unused-import lint, and the reason is in docs/code-health.md.
- must cov-1 report text on the ignore comment, should allow: list: stale report wording only; the commit and code-health note are the record.
- should arena_back/_waiting test: deferred to docs/code-health.md. should file sizes: code-health.
- should dev-tools exclusions, sample table, exit code, dart test wording: fixed by hand.
- should before/after number: measured on the tip: 19,797/21,311 (92.9%) with the generated tests, against 19,778/21,306 before (+5 lines found, only a few files were uncounted).
- should cov-2 report "not applied": stale, ci.yml was applied by hand (c968b552).
- could waiting flag and class doc: fixed by hand. assets exclusion line: removed. Others (summary text, named constant, duplicate suffix list, empty-body test): code-health.
- Open questions: workers may run dart run and tools/coverage.sh (yes); .github edits stay with the driver; assets flutter_test: code-health (leave).
