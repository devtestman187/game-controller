# night1b wave4 (e0g) review

## Summary

Verdict: small fixes. Counts: must 0, should 3, could 4.

Brief items 1 to 5 are done (the three fixes, the report, dart analyze); no code is out of scope.
Fail-on-base for tests (b) and (c) holds by reading: base `load()` returns the round-0 night, and base's listener does not save p2.

The three findings that matter most:
1. e0g-report.md has no review-rules part-A self-check (A1 to A6); the job's report omits it.
2. e0g-report.md:14 says "8 tests ... 8 passed"; night_save_test.dart has 7 `test(` calls.
3. The two new tests sit in the existing night_save_test.dart, against the worker-extract rule "new tests in a NEW file"; the worker followed the brief and did not report the conflict.

## Findings

- **should** docs/briefs/m17/night1b/e0g-report.md:22 the report has no part-A self-check (every host setup, kept state start/end, combination with pause/host away/player away/Get ready/dropped link/results/leaving, folder, stop-rather-than-overstep, every look) → add one line per A1 to A6, each naming the test that shows it.
- **should** docs/briefs/m17/night1b/e0g-report.md:14 "the 8 tests in night_save_test.dart: 8 passed" but the file has 7 `test(` calls (lines 12, 53, 79, 94, 109, 119, 135) → correct the count, or paste the mine.sh line that shows 8 and name the other test.
- **should** packages/party_host/test/night_save_test.dart:109 new tests (b) and (c) are in the existing file; the worker-extract rule says new tests go in a new file, and coding-guidelines §11 says stop on a brief/rule conflict → Claude to decide; if the rule stands, the two tests need a new test file (outside this brief's allow list).
- **could** packages/party_host/lib/src/night/night_save.dart:13 the class doc says a host that restarts resumes the night, but `load()` (line 32) now drops a round-0 night → add "a night with a round played" to that sentence.
- **could** packages/party_host/lib/src/night/night_save.dart:25 the doc wraps unevenly (line 26 is short, line 27 starts a new run) → reflow lines 24 to 27 to the 120-column width.
- **could** packages/party_host/test/night_save_test.dart:61 the formatter-split `NightSave(` / `prefs,` / `).save(...)` is hard to read → bind `NightState.start(...).record(...)` to a local `final` and pass it to `save`.
- **could** packages/party_host/test/night_save_test.dart:47 the line is over 120 columns (pre-existing, not in this diff) → put the record `(row.id, row.total, row.isHere, row.nickname)` on its own line.

## Decisions to confirm

- Round-0 nights are dropped on load (night_save.dart:32), as well as in `dropIfUnplayed`. The brief decided this; REVIEW.md:45 had it as an owner question. Confirm it is the owner's answer to B-032.
- Every roster change while a night runs now writes prefs (party_night.dart:65). The brief asked for it; the cost is one small write per roster change.
- The garbled-save test's valid save now records a round (night_save_test.dart:61). This is a test-side change the worker listed; it is needed because round 0 now clears.
- The new tests live in the existing file (see finding 3).

## Could not check

- The base run: no checkout is allowed to me, so fail-on-base for (b) and (c) is by reading only. The runner's own check is the proof.
- The mine.sh output is not in the repo; the "8 passed" claim could not be reproduced here.
- docs/briefs/m17/night1b/run-findings.md does not exist, so there were no run-findings entries to check.
- `savingNightContainer` is used by the tests but its definition was not located; I read its use only.
- Other party_host suites that restore a night were not run; a grep found no other test that writes or reads the `party_night_v1` key.
- The device check of a restart after a roster change is out of scope here (it is the status row's open item).

## Commit message — a draft

```
night1b wave4 review: e0g findings written, no code changed

Review of the e0g job (night save: round-0 drop, roster save, test fixes).
Findings: 0 must, 3 should, 4 could (see wave4-review-report.md).
Should: the report lacks the part-A self-check; it says 8 tests, the file
has 7; the new tests sit in the existing file, against the new-file rule.
No code or other document changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row

night1b wave4 (e0g) review: done — 0 must, 3 should, 4 could written to the report; open: the part-A self-check, the 8-vs-7 test count and the new-file rule are Claude's to decide.

## Delete

- none
