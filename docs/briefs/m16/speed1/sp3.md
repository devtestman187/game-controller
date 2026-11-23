job: M16 speed1 sp3: check.sh result cache (skip a suite whose inputs equal a recorded passing run)
pub: no
turns: 60
expected-min: 45
tests-first: exempt (shell tools: run the new test before your edits and show its FAIL lines in the report)
stop: after it. Do not touch tools/release.sh, tools/run-*.sh or docs (the driver does). check.sh has a size cap of 250 lines: new code goes in the sourced tools/check-cache.sh.
read: docs/briefs/templates/COMMON.md · tools/check.sh (all; wave 1 added -j and tools/check-par.sh) · tools/check-par.sh · tools/affected.sh (`--deps <suite>` prints the folders a suite depends on) · tools/tests/check-par-test.sh:1-60 (stub style)
changes: CHECK_CACHE · no-cache · check-cache.sh · suite_key
decisions (owner, Nov 23): a suite is skipped when a content hash of its package and every package it depends on, plus tools/check.sh, tools/check-par.sh, tools/check-cache.sh and pubspec.lock, equals the hash of a recorded PASSING run of that suite. format and analyze are never cached. `--no-cache` (and CHECK_CACHE=0) disables it; the release path always runs uncached.
do:
1 Write tools/tests/check-cache-test.sh first (temp git repo with check.sh, check-par.sh, check-cache.sh, affected.sh and stubs for dart/flutter): a second run skips every suite (prints `CACHED  <name> (passed <time ago>)`, exit 0, stubs not called); editing a file in a package reruns that suite and its dependents only; editing an unrelated package reruns nothing else; a FAILED suite is never recorded; `--no-cache` and CHECK_CACHE=0 run everything; a changed pubspec.lock or tools/check.sh reruns all; a corrupt or missing cache file is ignored; works with -j 4.
2 tools/check-cache.sh: suite_key <suite> = sha1 of the output of `git ls-files -z -co --exclude-standard -- <folders> tools/check.sh pubspec.lock` fed to `git hash-object --stdin-paths` (so a dirty tree counts; equals the tree state when clean). Cache file `.dart_tool/check-cache.tsv`, one `<suite><TAB><key><TAB><epoch>` line per suite, rewritten atomically (write temp, mv); parallel suites record after they pass, from the parent shell, never from two writers at once.
3 tools/check.sh: source check-cache.sh only when caching is on and the file exists; a cached suite prints one CACHED line and counts as passed in the summary; the summary says how many were cached. Header documents `--no-cache` and CHECK_CACHE.
4 Run `bash tools/tests/check-cache-test.sh`, `bash tools/tests/check-par-test.sh`, `bash tools/tests/check-failfast-test.sh` and `bash tools/tests/check-scope-test.sh`; all must pass.
allow: tools/check.sh · tools/check-cache.sh · tools/check-par.sh · tools/tests/check-cache-test.sh · docs/briefs/m16/speed1/sp3-report.md
check: format
report: docs/briefs/m16/speed1/sp3-report.md
