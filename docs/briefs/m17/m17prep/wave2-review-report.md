# Wave 2 review: ci job (findings only)

## Summary

Verdict: small fixes.
Counts: must 0 · should 2 · could 4.
1. The CI step now gates four packages (metrics, game_kit, toy_look, puzzle_game) that no CI step ran before; the job report does not say so.
2. The Coverage step runs `flutter test --coverage` for the pure-Dart packages protocol and connection, where the removed steps ran `dart test`; this is not checked here.
3. The expected job time is not consistent: the evidence says about 36 min, the job's own arithmetic gives about 29 min; the 45-min limit holds either way.

## Findings

- **should** docs/briefs/m17/m17prep/ci-report.md:9 The report says only that six packages run twice; it omits that the Coverage step also runs metrics, game_kit, toy_look and puzzle_game, which no CI step ran before (ci-evidence.md:9), so CI now fails on their tests → add that sentence to the Summary and to the commit message draft.
- **should** .github/workflows/ci.yml:57 The Coverage step runs tools/coverage.sh, which runs `flutter test --coverage` for protocol and connection (tools/coverage.sh:108), where the removed steps ran `dart test`; nothing in the report checks this on the CI image → name it in the report's next-push checks, or run `bash tools/coverage.sh protocol connection` once on CI before the STATUS row says the job is fixed.
- **could** .github/workflows/ci.yml:35 `timeout-minutes: 45` has no comment saying why (test growth, Nov 26 cancels), which the rest of the file's comments do → add a one-line comment with the reason, without a date.
- **could** .github/workflows/ci.yml:53 The comment "(Nov 26, ~10 min)" carries a date and a minute figure that go stale → keep the why ("it replaces the six plain Test steps, which ran the same tests twice") and drop the date and minutes.
- **could** docs/briefs/m17/m17prep/ci-report.md:33 Question 1 is right to flag it: the evidence's "about 36 min if the tests keep growing 20%" (ci-evidence.md:16) does not follow from 26.5 min × 1.2 (about 32) or from the tests-only growth (about 29) → recompute it and use one figure in the STATUS row.
- **could** docs/briefs/m17/m17prep/ci-evidence.md:11 "controller_app 91 to 117 (+29%) against Test controller +42%" mixes baselines: the file counts start on Nov 21, the time comparison on Nov 24 → state both as Nov 21 to 26 or both as Nov 24 to 26.

## Decisions to confirm

- Timeout 30 → 45 instead of cutting the test time further: safe at the projected 26–29 min, but the margin depends on test growth staying near 20% (ci-evidence.md:11).
- Four packages start gating CI (see the should finding at ci-report.md:9): a failing test in them now fails the main job, which is a policy change, not a dedupe.
- Coverage runs without a threshold, while docs/HANDOFF.md:135 asks for a manual check against 92.8% after changes that add code; the two are compatible but the CI step name says "no threshold", so a reader may think the rule is gone.
- The ci.yml diff matches docs/briefs/m17/m17prep/ci-timeout.patch as far as the diff shows; the worker did not edit ci.yml (its report says so).

## Could not check

- The job times and cancel counts (ci-evidence.md:2–7): from `gh run view` output that I cannot rerun here.
- `flutter test --coverage` on protocol and connection on the CI image (see the should finding).
- The "PASS" for tools/mine.sh in ci-report.md:22: not rerun.
- Test-file counts (451, 502, 542 total; 91, 117 controller_app): the working tree at this worktree's HEAD shows 543 `_test.dart` files and 119 in controller_app/test, a later commit than 509eaea0; I could not count at 509eaea0 (git ls-tree was refused).
- docs/dev-tools.md:8 ("runs the tests again") and :103 (the CI Format step) still describe the code; I did not find other non-brief docs that name the six Test steps or the 30-minute limit.
- run-findings.md has one line and nothing about this job.

## Files changed

- docs/briefs/m17/m17prep/wave2-review-report.md: this report only (new).

## Checks

- Read-only review: no code, no document other than this report changed; no tests or analyzer run (not in the brief's scope).

## Commit message — a draft

docs: wave 2 ci review, findings only

Review of the ci job (ci.yml timeout 45 and one coverage run per package).
No must findings; two should and four could.
Findings: the CI now gates four packages it did not gate before; the pure-Dart
packages now run flutter test in the Coverage step (unchecked on CI); the job
time figures do not add up. Report only; no code changed.

## Status row

Wave 2 ci reviewed (wave2-review-report.md): 0 must, 2 should, 4 could, verdict small fixes; open: the ci-report note on the four newly gated packages, the flutter-vs-dart check for protocol and connection on CI, the timeout reason comment, and one recomputed job-time figure.

## Delete

- none
