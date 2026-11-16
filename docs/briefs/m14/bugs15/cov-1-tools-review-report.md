# cov-1-tools — review report

## Summary

verdict: **needs Claude** · must 2 · should 2 · could 4

- 11 `analysis_options.yaml` files were written, none of them in the brief's `allow:`. They exclude the new tests
  from `dart analyze --fatal-infos` (`tools/check.sh:22`), so a broken import in a generated test passes the analyze
  check; the brief asked for `// ignore_for_file: unused_import` in the file instead. `run.log:22-24` calls this a
  hand-fix; the report does not mention it, and its self-check says only the `allow:` files were written.
- `cov-1-tools-report.md:66` says the generated test carries `// ignore_for_file: implementation_imports,
  unused_import`. No generated test has an ignore line and `tools/coverage_imports.dart:131-162` writes none.
- `cov-1-tools-report.md:34` says counting every file leaves the total at exactly 19,778/21,306 = 92.8%. The same
  report (`:111`) says no before/after was measured; an unchanged total means no lib file was missing before, so
  either the brief's premise is wrong or the number was not measured after the change.

The rest checks out against the code: the import/skip counts in `cov-1-tools-report.md:69` match the 10 committed
tests, every lib file that is not `part of` another library is imported, `coverage/` is already ignored.

## Findings

- **must** packages/protocol/analysis_options.yaml:9 (also assets:4, controller_app:15, connection:9, game_kit:4, metrics:9, party_host:4, puzzle_game:4, test_game:4, toy_look:4, tv_test_app:15) excludes `test/coverage_all_test.dart` from the analyzer, a file outside the brief's `allow:` and a silencing of `dart analyze --fatal-infos` (`tools/check.sh:22`) that the brief did not ask for → revert all 11 and have the generator emit `// ignore_for_file: unused_import, implementation_imports` as rule 1 of the brief says.
- **must** docs/briefs/m14/bugs15/cov-1-tools-report.md:66 claims the generated file holds `// ignore_for_file: implementation_imports, unused_import`; `packages/protocol/test/coverage_all_test.dart:16-18` and `tools/coverage_imports.dart:148-152` show neither → correct the report and the generator together.
- **should** docs/briefs/m14/bugs15/cov-1-tools-report.md:126 self-check A4 says only the 14 `allow:` files were written, while the commit writes 11 `analysis_options.yaml`, and the Decisions list (`:73-89`) has no entry for the analyzer exclusion → record the exclusion as a decision and get it approved, or drop it.
- **should** docs/briefs/m14/bugs15/cov-1-tools-report.md:34 presents "the total equals the brief's 19,778/21,306 exactly" as a result, but `:111` says a before/after delta could not be measured, so the job cannot show that it counted a file the old run missed → state which is true, with one measured before/after run, since the current claim means the brief's premise ("counts only imported files") was wrong.
- **could** assets/analysis_options.yaml:4 excludes a `test/coverage_all_test.dart` that the generator never writes for assets → delete the line, or say in the report why a non-existent file is excluded.
- **could** tools/coverage_summary.dart:86 tells the reader to "run tools/coverage.sh for it" for every package without lcov, but `assets` has no test setup, so the advice can never pay off there → name the assets case in that line or leave it out of the list.
- **could** tools/coverage_imports.dart:106 `.take(5)` is a bare 5, outside the numbers the guidelines allow bare → name it (e.g. `_partOfScanLines`) with the reason in its doc comment.
- **could** tools/coverage_imports.dart:159 the one generated test has an empty body, so a lib file added later without rerunning the tool is simply uncounted and every check stays green → have a test compare the committed import list with `lib/` (or have `coverage_summary.dart` report a lib-file count that disagrees).

## Decisions to confirm

- assets is left out (report decision 1): true that `assets/pubspec.yaml` has no `test`/`flutter_test` dev dependency and no `test/` folder; counting its one lib file needs a pubspec edit outside `allow:` — owner's call.
- `flutter test --coverage` for the pure-Dart packages (decision 2) differs from `tools/check.sh`, which uses `dart test` there; confirm cov-2's CI uses the same command as the script, or the CI number and this table can drift.
- The analyzer exclusion (hand-fix, not a written decision) replaces the brief's `// ignore_for_file`: confirm it is the intended approach before it reaches CI.
- `tools/coverage_imports.dart:38,41` also skip `.config.dart`, `.mocks.dart` and any `/generated/` folder, more than the brief's list; low risk, but it is unlisted behaviour.
- `coverage.sh` takes folder names or their last part, not `check.sh`'s short names (`kit`, `look`, `arena`, `puzzle`); the report's question 4 asks the same — one naming should win.
- `cov-1-tools-report.md:99-105` says `tools/coverage.sh` was never run end to end, but `run.log:22` records it being run during the hand-fix; the report line is stale for the committed tree.

## Could not check

- The coverage table itself: no `coverage/lcov.info` is left in the tree and I ran no suite, so 19,778/21,306, the per-package rows and the five most-uncovered files are the report's claim only.
- The "398 records / 21 files without executable lines" and the per-package record lists: same reason (I did confirm 419 lib files exist, 72 + 347).
- `tools/coverage.sh`'s own behaviour (argument parsing, PASS/FAIL lines, exit codes): read, not run, as its report says.
- `docs/briefs/m14/bugs15/run-findings.md` does not exist; the runner's `run.log` only records the tests-first exemption and the hand-fix.

## Commit message

Review cov-1-tools: out-of-allow analysis_options edits weaken analyze

- 11 analysis_options.yaml are outside the brief's allow: and exclude the
  generated tests from dart analyze --fatal-infos, instead of the
  // ignore_for_file the brief asked for; the generator writes no ignore line.
- The report claims that ignore line exists (line 66) and that only the allow:
  files changed (line 126); both are false for the committed tree.
- The report's 19,778/21,306 total is identical to the pre-change brief number
  although no before/after was measured, so the job's own point is unproven.

## Status row

M14 bugs15 cov-1: tools and 10 coverage tests committed but not accepted — review open on 11 analysis_options.yaml edits outside allow, the missing `// ignore_for_file` in the generator, and the unmeasured 92.8% total; coverage table could not be re-verified here.

## Delete

- none
