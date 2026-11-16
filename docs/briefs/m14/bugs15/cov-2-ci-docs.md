job: M14 bugs15 cov-2 — CI coverage step, CI format check, docs/dev-tools.md
pub: no
tests-first: exempt CI config and docs
stop: after it. No threshold gate; no external coverage service; do not change the Analyze step (a later job adds --fatal-infos).
read: .github/workflows/ci.yml · docs/dev-tools.md (how tools are documented) · tools/check.sh (its format line). Job cov-1 (same wave) creates tools/coverage.sh (prints a per-package line-% table, writes coverage/summary.txt at the repo root and coverage/lcov.info in each package), tools/coverage_imports.dart and tools/coverage_summary.dart: reference them by those names; do not create them.
decide: low-usage mode: never stop for a question; list choices under "Decisions".

do:
1 ci.yml, job analyze-test-android: add a "Format" step before Analyze: `dart format --output=none --set-exit-if-changed controller_app tv_test_app packages assets` (the repo's 120 columns come from each analysis_options.yaml; the repo is clean today).
2 ci.yml: after the existing test steps, a "Coverage" step running `bash tools/coverage.sh` (it regenerates the import tests and runs `flutter test --coverage` per package); the table prints in the job log and is appended to the job summary file (the GITHUB_STEP_SUMMARY variable) inside a fenced block. Then upload coverage/summary.txt and every package's coverage/lcov.info as artifact `coverage` (retention-days 14, the same upload-artifact action version the file already uses, `if: always()`). No failing on a threshold.
3 Keep the existing Test steps; the report says what the extra CI minutes are likely to be.
4 docs/dev-tools.md: a "Coverage" section: what `bash tools/coverage.sh` does (regenerates `test/coverage_all_test.dart` per package so untested files count; runs tests with coverage; prints the table; writes coverage/summary.txt), its options, how CI uses it and where the artifact is, that no threshold fails CI yet, the exclusions (generated files). Mention the Format step where CI is described.
in the report: start with `## Summary` (at most 20 lines). End with `## Hand-over`.
rules: aim for 40-60 turns · write only inside allow: · stage nothing yourself · never use git add -A.
allow: .github/workflows/ci.yml · docs/dev-tools.md · docs/briefs/m14/bugs15/cov-2-ci-docs-report.md
check: format
report: docs/briefs/m14/bugs15/cov-2-ci-docs-report.md
