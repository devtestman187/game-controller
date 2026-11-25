# wave11 review: n8g (tools/tv-word-check.sh and its self-test)

## Summary

small fixes
Counts: must 1 · should 3 · could 1
1. The allowed-spelling branch in the guard can never run: the scan is case-sensitive and none of its three entries contains uppercase TV (must).
2. The three allowed-spelling self-test cases pass because nothing is scanned on those lines, so they prove nothing about the list (should).
3. The "no controller_app/lib" self-test case uses a missing root, so the controller_app check in the script is never exercised (should).

## Findings

- **must** tools/tv-word-check.sh:58 The allowed-list branch (lines 58–62) is unreachable: the scan is `grep -w TV` (case-sensitive) and none of the three `allowed_lines` entries contains uppercase TV, so this is a dead branch the guidelines forbid → drop the list and its branch, or change the scan so the entries are reachable, and say which in the report.
- **should** tools/tests/tv-word-test.sh:65 Cases 65–67 (`'tv' => kindTv`, `static const tv = 'tv'`) pass with the list deleted, so they cannot fail on the list → remove them with the list, or add a case that fails when the list is removed.
- **should** tools/tests/tv-word-test.sh:68 The "root with no controller_app/lib" case passes a folder that does not exist (`$tmp/empty` is never created), so it exits at the "no such folder" check (script line 28), not the `controller_app/lib` check (script lines 32–35), which no test runs → create `$tmp/empty` as an empty directory before the call.
- **should** docs/briefs/m16/wave2-789/n8g-report.md:24 The report says the mine.sh churn step reverted the three `tv_test_app/windows/flutter` generated files and that `git status` no longer lists them, but `git status` in this worktree still lists all three as modified (` M`) → confirm which is true; if the revert happened, the churn step discarded uncommitted work and that needs its own job, not a fix in this one.
- **could** tools/tv-word-check.sh:6 "(owner scope, driver Nov 25)" is shorthand a reader can't decode → say "per owner decision 7 (APP-START.md), 2026-11-25".

I checked the other items and found no fault: the header, the `//` and `///` skip, the three allowed names, exit codes 0/1, the 25-case count (11 verdicts × 2 + 1 exit-2 + 2 real-repo = 25), and the claim that `tv_test_app` is not scanned.

## Decisions to confirm

- Exit code 2 for a root with no `controller_app/lib` is not in the brief; it is small and the brief's own test asks for a missing-folder case, so keep it only if Claude agrees.
- The allowed-spelling list is kept because the brief asked for it, but it cannot match anything (see the first finding); Claude should decide whether to drop it.
- `grep -w` treats `'` and `"` as word breaks (so `TV's` is a hit) but not `_` or digits (so `TV_` and `TV2` are not hits). This is the usual reading, but it is a choice.
- `tv_test_app` is not guarded, as the brief says. Its strings are unchecked, for example the `Thumb Party TV app` text it may show; the owner should confirm this scope stands.
- Real-repo result: the report says the guard passes with no hit lines. My own search of the same pattern found only allowed-name lines outside comments (for example `packages/party_host/lib/src/text/phone_text.dart:38`, `packages/connection/lib/src/host_connection.dart:193`), which agrees with that.

## Could not check

- `bash tools/tv-word-check.sh` on the real repo was refused by the permission check twice, so I did not see its exit code. The real-repo claim is supported only by the equivalent search above.
- I ran `bash tools/tests/tv-word-test.sh` myself: 25/25 PASS, `RESULT: 25/25 cases passed`. The report's "0/25 before the script existed (exit 127)" is not verifiable now.
- `docs/review-rules.md` parts A and B were not read in full. Its host-setup and kept-state items are about the app, not a shell guard, so I checked only the self-check claims against the code.
- The `tools/smoke.sh` change in HEAD after `cde937f5` is outside this job and was not reviewed.

## Commit message — a draft

Review wave11 n8g: findings for the tv-word guard

Findings only, no code change. The allowed-spelling list in
tools/tv-word-check.sh can never match, because the scan is case-sensitive
and the three entries have no uppercase TV, so its branch is dead. Three
self-test cases pass without the list, and the missing-folder case
never reaches the controller_app/lib check. The report's churn-revert
claim for the tv_test_app generated files is unconfirmed (git status
still lists them). Verified: the self-test 25/25.

## Status row

wave11 review of n8g: done, verdict small fixes (1 must, 3 should, 1 could). Open: drop or make reachable the dead allowed-list branch (tv-word-check.sh:58); fix the two weak self-test cases (tv-word-test.sh:65, :68); confirm the churn revert of the tv_test_app generated files (n8g-report.md:24).

## Delete

- none
