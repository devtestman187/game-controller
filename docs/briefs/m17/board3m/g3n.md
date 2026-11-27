job: board3m g3n — board-line merge gate script (paths, size, layers)
stop: no change to any existing file; no coverage run in the script (the driver runs tools/coverage.sh itself); never tools/mine.sh
read: docs/briefs/templates/COMMON.md · tools/tests/proc-sweep-test.sh:1-30 (shell test style) · tools/tests/sim-test.sh:1-25 · merge gate (plan): "The diff touches only city/, tools/sim/, tests and docs."
changes: tools/board-gate.sh · tools/tests/board-gate-test.sh (both new)
model: haiku
turns: 60
expected-min: 45
tests-first: exempt new files only
do:
1 Tests first: new tools/tests/board-gate-test.sh. It builds a throw-away git repo in a mktemp dir (git init, commit identity set with `-c`), runs `bash tools/board-gate.sh --root <dir> --base <ref>` and checks the exit codes: a clean change under packages/party_host/lib/src/city, packages/party_host/test/city, tools/sim, tools/tests, docs gives 0; a changed path outside those (e.g. controller_app/lib/a.dart or packages/party_host/lib/src/night/x.dart) gives 1 and names the path; a .dart file under city/ over 380 lines gives 1; a file in city/ other than night_adapter.dart whose text has an import with `/night/` gives 1; night_adapter.dart importing night/ gives 0; a city/ file importing package:flutter gives 1; bad arguments give 2. Print PASS or FAIL per case, exit 1 if any failed.
2 New tools/board-gate.sh: options --root <dir> (default the repo root) and --base <ref> (default m17). It compares `git diff --name-only $(git merge-base <base> HEAD)..HEAD` and prints `FAIL paths <file>`, `FAIL size <file> <lines>`, `FAIL layers <file> <what>` per finding, then `RESULT: PASS` or `RESULT: FAIL <n>`; exit 0, 1, or 2 for bad use. Allowed path prefixes: packages/party_host/lib/src/city/ · packages/party_host/test/city/ · tools/sim/ · tools/tests/ · tools/board-gate.sh · docs/. Size: lib files under city/ and tools/sim/ at most 380 lines (a test file 500). Plain bash, under 120 lines, no stdin reads.
3 Run `bash tools/tests/board-gate-test.sh`.
4 Report: the test output lines.
allow: tools/board-gate.sh · tools/tests/board-gate-test.sh
check: format
report: docs/briefs/m17/board3m/g3n-report.md
