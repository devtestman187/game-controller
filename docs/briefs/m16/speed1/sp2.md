job: M16 speed1 sp2: tools/affected.sh maps changed paths to check.sh suites and prints a suite's dependency folders
pub: no
turns: 60
expected-min: 45
tests-first: exempt (shell tools: run the new test before the script exists and show its FAIL lines in the report)
stop: after it. Do not touch tools/check.sh, tools/run-*.sh or docs/dev-tools.md.
read: docs/briefs/templates/COMMON.md · tools/check.sh:28-52 (checks table; `check.sh --list` prints `name dir about`) · pubspec.yaml of packages/protocol, packages/game_kit, packages/party_host, controller_app (the `path:` dependencies, also under dev_dependencies and dependency_overrides) · tools/tests/check-failfast-test.sh:1-40 (test style, report helper)
changes: affected.sh · affected_suites
decisions (owner, Nov 23): the runner's combined check runs format and analyze on the whole workspace plus only the affected test suites; the full check stays at batch end and before every build.
do:
1 Write tools/tests/affected-test.sh first. It builds a temp repo with a fake `tools/check.sh --list` table and small pubspecs (a -> b -> c path deps, d alone) and also runs once against the real repo (a protocol change gives every dependent; controller_app gives phone only).
2 tools/affected.sh `[--not] [--deps <suite>] [paths...]`. The suite table and folders come from `bash tools/check.sh --list` (no copy); the graph from `path:` dependencies in each suite folder's pubspec.yaml (transitive). Paths = arguments, else every path in `git status --porcelain` (renames, untracked included) against HEAD. A path under a package folder: that suite plus every suite depending on it. `tools/...`: the tools suite. Any pubspec.yaml, pubspec.lock, analysis_options.yaml, tools/check.sh or tools/affected.sh: every suite. docs/ and top-level *.md: none. Any other unmapped path (assets/, root files): every suite (safe). Output: suite names one per line in check.sh order (test suites only, never format or analyze). `--not`: the complement as ONE line separated by spaces (for CHECK_SKIP). `--deps <suite>`: the repo-relative folders of that suite's package and every package it depends on, one per line (tools: `tools`); an unknown suite exits 2.
3 Exit codes: 0 ok, 2 bad input. Header documents it. Pure bash plus git; works in Git Bash.
4 Run `bash tools/tests/affected-test.sh`; it must pass. Report one real-repo example per kind.
allow: tools/affected.sh · tools/tests/affected-test.sh · docs/briefs/m16/speed1/sp2-report.md
check: format
report: docs/briefs/m16/speed1/sp2-report.md
