job: M16 process2 mine — tools/mine.sh ("check what I touched") and tools/churn.sh
pub: no
stop: after it. No flash.sh edits (done already).
read: docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/script-rules.md · docs/briefs/m16/scriptable-work.md (items F1, F5) · tools/run-jobs.sh (:68-73 CHURN_OUTSIDE, CHURN) · tools/check.sh (how format/analyze are called)
decisions (owner, Nov 21): "tools/mine.sh: format changed files, analyze touched packages, run touched tests plus tests naming touched lib files once, print failures only, revert known generated churn." Tell workers in COMMON.md to use it.
tests-first: exempt shell tooling; its test is tools/tests/mine-test.sh (run it with bash tools/tests/mine-test.sh).

do:
1 tools/churn.sh (sourced): CHURN_PATHS array (the CHURN list of run-jobs.sh), CHURN_REGEX (its CHURN_OUTSIDE), function churn_revert (git checkout -- on those paths only, quiet).
2 tools/mine.sh, run from anywhere, cds to the repo root: change list from `git status --porcelain -z` (handle renames, spaces, deletions); `dart format` on the changed .dart files that exist; `dart analyze` once per touched package (nearest pubspec.yaml); `flutter test`/`dart test` per package on touched *_test.dart plus tests under that package's test/ that name a touched lib file's basename (git grep -l), each once; print only failures (name plus first 8 lines) and `OK n tests`; then churn_revert. DART/FLUTTER env vars name the commands (tests stub them). MINE_TIMEOUT total seconds, default 900.
3 COMMON.md Bash line: "Run tools/mine.sh when a change is ready (format, analyze, touched tests, churn revert in one call); it prints failures only."
4 tools/tests/mine-test.sh per script-rules.md, a temp git repo with stub dart/flutter: no changes, only .md changed, deleted lib with a surviving test, deleted test, renamed file, path with spaces, package without tests (NO TESTS line), failing test output, hang (TIMEOUT), second copy refused, churn reverted but a user file untouched, interrupt cleanup.
allow: tools/mine.sh · tools/churn.sh · tools/tests/mine-test.sh · docs/briefs/templates/COMMON.md · docs/briefs/m16/process2/p2-mine-report.md
check: format
report: docs/briefs/m16/process2/p2-mine-report.md
