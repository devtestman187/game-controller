# Wave 1 review: c1 and t1

## Summary

Verdict: needs Claude (the must fix sits in tools/churn.sh, outside t1's allow).
Counts: must 1 · should 4 · could 2.
1. t1 does not keep a non-churn file that was dirty before the wave and is in a parked job's allow: (the brief's src/dirty.txt case). The snapshot holds churn paths only, so the file is still reverted. The commit subject claims pre-dirty paths are kept.
2. t1: a path listed by two parked jobs is kept by both, so nobody saves or removes it, and it stays dirty in the tree.
3. t1 case 4b waits on a 2 s sleep for ordering, which the guidelines forbid, and its named failure reasons were never inspected.
c1: clean apart from a missing constructor dartdoc; the refactor matches the brief (5 parameters each, counts 351 and 192 lines confirmed, no other callers broken).

## Findings

- **must** tools/run-wave.sh:32 (reads the snapshot; tools/churn.sh:58 writes it) the snapshot records only churn_path matches, so a pre-wave dirty non-churn file in a parked job's allow: is still checked out and removed → have the snapshot (tools/churn.sh, outside t1's allow) record every dirty path, or have the decision taken by Claude and the commit subject and status row narrowed.
- **should** tools/run-wave.sh:33 park_keeps counts every started sibling, parked ones too, so a file in the allow: of two parked jobs is kept by both and never saved or removed (stays dirty, the next combined check sees it) → skip siblings that are themselves parked in this wave.
- **should** tools/tests/run-stops-test.sh:145 pk's `stub-sleep: 2` orders sib's write before pk's park by a fixed sleep (guidelines §2, timing fixes) → have pk's stub poll, bounded, for src/shared.txt before it exits.
- **should** docs/briefs/m16/close/t1-report.md:15 says case 4b "failed" with named assertions, then says they were "not separately inspected" → rerun 4b against the old park_tree and quote the failing assertion, or drop the named assertions.
- **should** packages/test_game/lib/src/arena_board_options.dart:6 the public const constructor has no dartdoc (guidelines §10: every public member) → add a `///` line on what the constructor takes and that all fields default to unset, showHud true.
- **could** docs/driver-kit.md:54 says a parked job's files are "saved and removed from the tree"; shared and churn-dirty allow: paths now stay (outside t1's allow) → say so in the sentence.
- **could** tools/run-wave.sh:32 the comparison is exact: a folder entry in a sibling's allow: (`site/shots/`) never protects a file inside it, and an untracked folder recorded in the snapshot with its trailing `/` never matches the stripped path → match folder entries by prefix, or state the limit in the park_keeps comment.

## Decisions to confirm

- t1 tools/run-wave.sh:53: a parked job's own edit to a path a sibling also lists stays in the tree and is committed with the sibling; the parked patch does not contain it, and neither report says so (not listed in t1's Decisions). Why: the sibling then commits the parked job's change under its own name.
- t1 (listed as its question 1): the brief's snapshot wording ("names the paths already dirty at the wave's start") was narrowed to churn paths; t1 used site/shots/dirty.png instead of src/dirty.txt. Why: this makes the must finding above. Claude to choose the snapshot's scope.
- t1 (questions 2 and 3): src/shared.txt was added to pk's allow: in the fixture; folder entries match exactly. Why: both change which files the rule protects.
- c1 packages/test_game/lib/src/arena_hud_widgets.dart:41: `ArenaHud` takes `options` but ignores `showHud` (listed by c1). Why: the constructor shape the brief asked for; a reader may expect the field to apply.
- c1 `showHud` keeps its name in `ArenaBoardOptions`, though the rule says booleans read as questions. Why: the name comes from the brief and the PRD usage, so renaming is Claude's call.

## Could not check

- No suite was run: the review is read-only, so tools/tests/run-stops-test.sh, run-wave-test.sh and flutter test were not executed; the c1 claim "259 tests pass" and the t1 claims of 9/9 and 4/4 rest on the workers' reports.
- run.log (lines 6-16) records only "finished: result 0" and the two commits; it carries no check results, so the runner evidence does not confirm either job's checks.
- The t1 4b failure before the change: not reproduced (see finding on t1-report.md:15).
- The HUD looks and sizes (menu and TV look) for c1: the tests passing in both looks was not checked by reading.
- dart analyze and dart format on the c1 files: not run; the formatter claim (9 files) was not verified.
- docs/briefs/m16/close/t1-report.md has no "## Summary" block; run.log:15 already records this, so it is not repeated as a finding.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
m16 close: review of wave 1 (c1, t1)

Read-only review of the c1 ArenaBoardOptions refactor and the t1
park_tree change against their briefs and the guidelines. Writes this
report only; no code changed. Open: the must (pre-wave dirty non-churn
allow: paths are still reverted), two should items in the runner and
the test, and the decisions listed above for Claude.
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 close wave 1 review: done — c1 and t1 reviewed (report: wave1-review-report.md). Open: must (run-wave park_keeps keeps churn-dirty paths only; pre-wave dirty non-churn allow: files are still reverted); should (two parked jobs sharing a path leave it dirty; case 4b uses a 2 s sleep; t1's failure reason unverified; ArenaBoardOptions constructor has no dartdoc).

## Delete

- none
