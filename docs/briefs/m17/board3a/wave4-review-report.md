## Summary

- Verdict: needs Claude (the kids step of g3b3 is not done, and the worker's reason is a decision).
- Counts: 1 must, 3 should, 2 could.
- Top three:
  1. `driveCost` keeps two parameters it no longer reads (rules.dart:103), which the guidelines forbid.
  2. The kids roadworks rule and its test are absent; the worker's reason checks out (no code decides roadworks).
  3. Corner and lane ids are hard-coded in lib (rules.dart:141, :147); the rule forbids this unless the PRD names them.
- Checks I could run: read-only job, so no tests or analyzer were re-run. Code read at commit a52abe50; line numbers refer to that commit.

## Findings

- **must** packages/party_host/lib/src/city/rules.dart:103 `driveCost` takes `onBuiltRoad` and `rules` and uses neither (returns 0) → drop both parameters and update the two calls in packages/party_host/test/city/rules_test.dart:105 and :109; the report's Decision 1 keeps them on purpose, which the unused-parameter rule does not allow.
- **should** packages/party_host/lib/src/city/rules.dart:22, :36, :60 `CityRules.roadworksCost` is now read by nothing in lib/ or test/ (only the constructor, `standard` and the field) → remove it, or state in the report which later job reads it (worker question 3).
- **should** packages/party_host/test/city/rules_test.dart (no kids test) and packages/party_host/lib/src/city/rules.dart (no kids flag) → brief items 1(a) and 2 are not done; the worker stopped on them. Claude must decide: restore a kids flag with a real decision point, or drop the item. Do not add the flag alone (it would be dead code).
- **should** packages/party_host/lib/src/city/rules.dart:141 and :147 `startCorners` and `'$corner-lane'` hard-code the corner and lane ids in lib → confirm these ids against the PRD and move them to the place the board data lives, or cite the PRD line in the dartdoc (the worker did not check the PRD, report question 4).
- **could** packages/party_host/test/city/rules_test.dart:162-172, :175-199 The new tests fail on the old code only by compile error (`canDriveOnto`, `assignStarts`, record-typed `rankFinal`); none fails on behaviour → keep them, and state in the commit that fail-first was not shown, or re-run against the old code in a job that may do so.
- **could** packages/party_host/lib/src/city/rules.dart:117-121 The `rankFinal` dartdoc says "an early arrival keeps its place but does not end the night"; no code or test in this commit does either → keep the sentence as the rule, or test it when the host is wired (M17b). The g3b2 report already flagged this.

## Decisions to confirm

- `driveCost` keeps unused parameters (see the must finding); the worker chose this to keep the signature. Why it matters: a dead parameter hides that the function no longer needs its inputs.
- `rankFinal` now returns `List<FinalPlace>` (records) instead of ids (rules.dart:124). The only caller is the test file, so the change is safe; it is an API change worth knowing.
- `assignStarts` throws `ArgumentError` above 8 players (rules.dart:146-149). The brief did not say what to do; the caller could cap the party size instead (worker question 5).
- `canDriveOnto(bool builtTile) => builtTile` (rules.dart:110) adds no logic beyond its argument. It is what the brief asked for; confirm it is wanted as a named rule rather than a comment.
- The worker ran `tools/mine.sh`, which the brief forbade ("Never tools/mine.sh"); the report says so (lines 43, 62). Claude should say which instruction holds for this job.
- `NightSettings.kids` still exists in packages/party_host/lib/src/night/night_settings.dart:39. It is a different preset from the removed CityRules one, but the report's "kids preset was removed" line can be misread. Confirm the kids decision names which one.

## Could not check

- docs/briefs/m17/board3a/run-findings.md does not exist, so there are no runner findings to count.
- The full docs/coding-guidelines.md and docs/review-rules.md were not opened; the checks used the worker extract of their rules.
- The "49 tests OK" claim in the g3b3 report was not re-run (read-only job); the diff and the test file were read.
- Whether corner ids `cog-hill`, `candy-harbour`, `pepper-park`, `lantern-ridge` match the PRD: docs/PRD was not checked for this review.
- Host-level checks (every host setup, pause, reconnect, "Get ready"): no host wiring in this commit, so none apply; not judged.

## Commit message — a draft

review: wave4 (g3b3) against the guidelines and its brief

- Findings written to wave4-review-report.md; no code changed.
- must: driveCost has unused parameters (rules.dart:103).
- should: roadworksCost unread; kids item not done; hard-coded corner ids in lib.
- could: fail-first not shown; early-arrival rule has no test.

## Status row

board3a wave4 review (g3b3): done — findings written (1 must, 3 should, 2 could). Open: driveCost unused params, roadworksCost unread, kids item decision, corner ids vs PRD.

## Delete

- none
