## Summary

needs Claude: 3 must, 4 should, 2 could. The committed cache test asserts stub counts that a correct cache cannot meet, and 5 of its cases pass on the old code.
1. tools/tests/check-cache-test.sh:153 and :245 expect 0 stub calls on a cached run; format and analyze run through the stubs and are never cached, so they make 2 calls.
2. tools/tests/check-cache-test.sh:173 expects 5 stub calls; with format and analyze the protocol run makes 7. The hand-fix moved it from 7 to 5.
3. Five cases (lines 185, 199, 208, 215, 224) pass on code with no cache, so they do not test the cache.

## Findings

- **must** tools/tests/check-cache-test.sh:153 Case 2 asserts `calls` = 0 on a fully cached run, but format and analyze go through the CHECK_DART/CHECK_FLUTTER stubs (tools/check.sh:34-35) and are never cached (tools/check-cache.sh:36-39), so a correct cache makes 2 stub calls and this case fails → count only the `test` calls (`ran`) or expect 2; same fix for line 245 (case 10b).
- **must** tools/tests/check-cache-test.sh:173 Case 4 expects `calls` = 5, but the protocol edit reruns 5 test suites plus format and analyze = 7 stub calls (the worker's own pre-hand-fix run said seven) → expect 7, or drop the count and assert `ran` and `cached` only.
- **must** tools/tests/check-cache-test.sh:185 (also 199, 208, 215, 224) Cases 5a, 6b (CHECK_CACHE=0), 7a, 7b and 8a pass on code with no cache, by the worker's own pre-change run → before each edit or flag change, assert the cache is full (`cached` = ALL) so the case fails without the cache; keep the exit-code check at 185 as a separate case.
- **must** docs/briefs/m16/speed1/sp3-report.md:3 The report says STATUS: stopped, 6 of 15 cases failing on the new code, and the other three shell tests and tools/mine.sh not run; the hand-fix commit changed the test and I have no run of the final state → run the cache test on the committed tree and record the result before this is called done.
- **should** docs/release.md:33 and .claude/agents/thumb-release.md:20 Both are outside the sp3 allow list, and the brief says not to touch docs; tools/tests/check-failfast-test.sh:257 is also outside the list → confirm these hand edits are wanted, or move them to a docs job.
- **should** docs/release.md:33 The line points to docs/dev-tools.md for the "result cache", but dev-tools.md has no cache section, and `--no-cache` and CHECK_CACHE are documented nowhere → add a short section to docs/dev-tools.md in the docs job.
- **should** tools/check-cache.sh:76 The temp file is always `check-cache.tsv.tmp`, so two check.sh runs in one checkout can write the same file and move a half-written one → create it with `mktemp "$cache_file.XXXXXX"` in the same folder, then mv.
- **should** tools/check-cache.sh:26-29 The key has no input for the Dart/Flutter SDK or CHECK_DART/CHECK_FLUTTER, so a pass from an older SDK is reused after an upgrade → add the tool version to the hashed input, or state the limit in the header comment.
- **could** tools/check.sh:225 `-h` was folded into one line with `;`, and the unchanged `sed -n '2,20p'` now ends at line 20, in the middle of the CHECK_SKIP paragraph (lines 20-22) → restore the multi-line arm and extend the range to line 22.
- **could** tools/check-par.sh:3 The header was reflowed unevenly: the `and the cache's ...` line is short and the next line starts a new sentence mid-paragraph → rewrap lines 2-4 to 120 columns.

## Decisions to confirm

- The brief asks that a second run "calls no stub" and also that format and analyze are never cached; both cannot hold. The code caches neither and runs both, and the test (wrongly) asserts 0 calls. Owner to pick; the test must follow the pick.
- The hand-fix in the commit changed case 4's expected count from 7 to 5 under "test counts". That moves the expectation the wrong way (see the first must above).
- The key is the blob hash of the list of blob hashes, not the plain sha1 of the ls-files output the brief names. The report flags it; it is a reasonable reading, but confirm.
- The commit touches docs/release.md, .claude/agents/thumb-release.md and tools/tests/check-failfast-test.sh, which the brief does not allow.
- `--no-cache` is a new flag in the release instructions. tools/release.sh does not call check.sh (grep finds no call), so the release path is uncached by construction, not by the flag.

## Could not check

- I did not run any test: the brief is read-only, and the test and `tools/affected.sh --deps` need a run I was not allowed to make. The claims about the test's result rest on the worker's report and on reading the code.
- The `tools` suite's folder set from `affected.sh --deps tools` is unverified; if it is narrower than tools/tests, a change to a self-test script would not change its key.
- The worker's "the cache test hangs" and "the second run does not skip" causes are not confirmed by any run; I found no code path that proves either.
- docs/briefs/m16/speed1/run-findings.md does not exist, so there were no runner findings to check.
