# Wave 1 review (p4a, p4b, p4e): findings

## Summary

small fixes.

1 must · 6 should · 3 could.

- **must** p4a's fixture `.dart` files (`changes-hit-later-wave/.../holds.dart:2`, `changes-hit-test-file/.../widgets_test.dart:2`)
  did not analyze, so the next run's base analyze stopped before any job started (run.log:18); the driver made them
  comments in 8ebcdff6.
- **should** the p4e commit carries an edit to its own brief (`p4e.md:12`, the `allow:` line) plus the wire-test 25 → 45
  edit, while `p4e-report.md:22`/`:128-143` still say the wire test is untouched and the check red.
- **should** `tools/brief-check.sh`'s done.txt/dropped.txt skip (brief item 1) has no case, and the p4a self-check
  (`p4a-report.md:101`) points at case 7, which tests "no argument", not the missing-`waves.txt` path.

## Findings

- **must** tools/tests/fixtures/brief-check/changes-hit-later-wave/controller_app/lib/holds.dart:2 (as committed in f9f22f7d; `NewThing? thing;`, and changes-hit-test-file/controller_app/test/widgets_test.dart:2 `NewWidget();`) did not analyze, so the run's base analyze stopped with no job started (docs/briefs/m16/process4/run.log:18) → the fixtures' `.dart` files must be analyzer-clean at commit (declare the fixture type in the fixture tree instead of naming an undefined one), and a job that adds `.dart` files must run `dart analyze` on them.
- **should** docs/briefs/m16/process4/p4e.md:12 (in 895a5146) — the job's commit widened its own `allow:` to admit `tools/tests/run-limits-wire-test.sh`, a change no job may make, and the wire test's 25 → 45 edit rode in the same commit (run.log:13) → a brief widening is the driver's act, logged as HAND-FIX and named in the report, never folded into the job's commit.
- **should** docs/briefs/m16/process4/p4e-report.md:22 — the Blocked section and "Checks run" (lines 128-143) say the wire test is untouched and `tools/check.sh tools` fails, but commit 895a5146 fixes run-limits-wire-test.sh:148-156 → update the report (and its Question 1) to the hand-fix and the resulting suite state.
- **should** tools/tests/brief-check-test.sh:88 — no case covers the briefed skip of jobs in done.txt/dropped.txt (tools/brief-check.sh:101-105), and none covers the missing-`waves.txt` bad use, though the report's self-check (docs/briefs/m16/process4/p4a-report.md:101) claims case 7 shows it → add a fixture with a done.txt and one with no waves.txt, and cite them in the self-check.
- **should** docs/briefs/m16/process4/p4b-report.md:1 — the file has no `## Summary`, no `## Hand-over`, no self-check, no case list and no computed values (docs/briefs/templates/COMMON.md:6-8), so "14 cases pass, 23 s" (line 3) cannot be checked against it → write the standard report from the run log before the commit.
- **should** docs/briefs/m16/process4/p4b-report.md:3 — the test takes 23 s against the brief's "Under 20 s" (docs/briefs/m16/process4/p4b.md:11) → cut the per-case work (share one repo between cases, or shorten the timeout case's worktree) or get the limit raised by the owner.
- **should** tools/tests/run-limits-test.sh:68 — case 3's comment and its name (line 77) still state the old rule "its brief line, else the usage median, else the default", which `run_expected_min` no longer implements (it is now the higher of the two) → rename the case and the comment to the floor rule.
- **could** tools/brief-check.sh:181 — the search counts fixture `.dart` files as hits because their paths hold `/lib/` or `/test/`, so a real brief's `changes:` item that collides with a fixture class (e.g. `Thing`, tools/tests/fixtures/brief-check/good/packages/p/lib/thing.dart:1) FAILs on a file no job may allow → skip `tools/tests/fixtures/` in `search_item`.
- **could** tools/brief-check.sh:6 — the header (and the usage line, :55) call the argument `<briefs-dir>` while the brief, the report and the p4c wiring call it `<batch dir>` → use one name.
- **could** tools/tests/fixtures/brief-check/changes-hit-test-file/controller_app/test/widgets_test.dart:2 — after 8ebcdff6 the only hit is a comment, so the case no longer shows a real usage in a test file → have the fixture tree declare `NewWidget` and put an analyzer-clean real usage here.

## Decisions to confirm

- p4a decision 2 (no "committed report" fallback for done jobs): a batch without done.txt re-checks jobs run-jobs.sh treats as done.
- p4a decision 3 (a missing brief is skipped silently): a typo in waves.txt is then unchecked by this tool.
- p4a decision 5 / the brief's decision (d): the `changes:` search is a literal `grep -wF`, so `_NewThing` or an item with a space is missed.
- p4e decision 2: a 40 s median now counts as none, where the old code made it 1 min — a behaviour change beyond "still counts as none".
- p4e decision 1: a run with every job done or dropped keeps a backstop of 0.
- The hand-fixes bypass `tools/apply-job.sh` (docs/flash-lessons.md rule 12): p4b-report.md:3 "copied from the kept tree", and 8ebcdff6's freehand fixture edit.
- Wave 1's briefs carry no `changes:`/`probe:` lines, so the tools built by this wave were never run on the batch that built them; p4e's pinned wire-test case is exactly what the `changes:` rule exists for.

## Could not check

- Any suite run: script execution needs approval in this job's sandbox, so the 8 / 14 / 15 case counts, the times (8 s, 23 s, 11 s) and the green `tools/check.sh tools` after the wire-test hand-fix rest on the reports and run.log.
- The analyze log the 12:37 stop names (`.dart_tool/run-jobs/.../run-base-check.log`) is not in the folder, so the exact fixture errors come from 8ebcdff6 and run.log:18.
- No run-findings.md exists in the process4 folder.

## Commit message

m16 process4 wave 1 review: 10 findings on p4a, p4b, p4e

Reviews the three wave-1 commits against their briefs, the coding
guidelines and the review rules, and records what the runner's logs
show against the reports.
One must: p4a's fixture .dart files broke the base analyze at 12:37
and stopped the next run; the driver made them comments in 8ebcdff6.
Six should: the p4e commit edits its own brief's allow: and its report
still says the wire test is untouched; brief-check's done.txt skip and
the missing-waves.txt bad use have no case; the p4b report lacks the
standard sections and runs 23 s against a 20 s limit; a run-limits case
name still describes the replaced rule.
Three could: brief-check searches the fixture trees; its argument name;
one fixture hit is only a comment.

## Status row

M16 process4 wave 1 review: done (1 must, 6 should, 3 could; report in docs/briefs/m16/process4/wave1-review-report.md) | open: the wave-1 fixes, then wave 2 (p4c, p4d, p4f) and p4g's wiring of the two tools with BRIEF_CHECK_SKIP

## Delete

- none
