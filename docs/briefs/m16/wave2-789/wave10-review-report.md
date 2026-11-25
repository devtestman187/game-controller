# wave10 review: f7 and f6 (wave2-789)

## Summary

- Verdict: small fixes
- Counts: must 0, should 1, could 1
- 1. f7 item 1 is not done: `client_messages.dart:90` still says "The TV made this phone player"; the brief's premise "nothing pins these strings" was wrong for that line (`tools/smoke.sh:329`).
- 2. f6 test name overclaims: "closes once" at `launch_home_test.dart:184` is not asserted.
- 3. Decision: `host_connection.dart:193` still says "The TV app uses protocol", outside both jobs' allow lists.

## Findings

- **should** packages/connection/lib/src/client_messages.dart:90 `'The TV made this phone player ${message.number}'` is still "TV", though f7 item 1 asked for "The screen made …" and the `rg -nw TV packages/connection/lib` check cannot pass → add `tools/smoke.sh` (line 329 pin) to an allow list in a job, repin it, then change line 90 to "The screen made this phone player".
- **could** controller_app/test/launch_home_test.dart:184 the test name says Home "closes once after the answer", but the body (lines 200-202) only checks `homes()` is empty, so a second close would not fail → drop "once" from the name, or assert the route is removed exactly once.

## Decisions to confirm

- `packages/connection/lib/src/host_connection.dart:193` close reason `'The TV app uses protocol v…'` was left as is (outside f7's allow). Owner decision 7 says generic display strings say "screen"; "Thumb Party TV" stays. Confirm whether this one is an app name (keep) or a generic string (change, in a job that allows it).
- f7 brief premise: it said "nothing pins these strings", but `tools/smoke.sh:329` pins line 90. The brief should have listed the smoke file in allow:. The f7 worker's stop was correct.
- f6 live-host test (`launch_home_test.dart:205-242`) asserts `demoProvider` is true, not the demo readout, because the readout is not on screen while the phone hosts (worker measured this). It also pushes Home with `fromLaunch: false`. Both are listed in the f6 report; the choice is safe because `_close()` (`phone_home_screen.dart:109`) keeps Home open for a live host.
- f6 `tools/mine.sh` reported "churn: reverted 3 generated file(s)". `git status` in this worktree still shows `run.log` and the three `tv_test_app/windows/flutter/generated_plugin*` files modified, the same as at the start, so the revert did not restore them. Confirm the runner's churn step leaves uncommitted files alone.

## Could not check

- Did not run any test (`mine.sh`, `flutter test`): the run-findings file has no entry for f6 or f7, so no "passes on the old code" evidence exists. By reading: test at line 184 would fail without the `_closeWaits` branch (`phone_home_screen.dart:141-142`), and test at line 205 would fail without the live-host check in `_close()` (`phone_home_screen.dart:109`). A mutation run would confirm this.
- f6 self-check item 6 says the existing look tests in `phone_home_screen_test.dart` cover the Home look; the looks group exists (line 269-274) but I did not check that it covers Home with the demo.
- The f7 commit (70ada00c) was checked against the diff only, not against the test run.
- Could not tell which 3 files the churn revert touched (see Decisions).

## Commit message — a draft

```
review: wave10 jobs f7 and f6 (wave2-789)

Review of the f7 wording change and the f6 launch-Home tests. f7 left
client_messages.dart:90 as "TV" because tools/smoke.sh pins it, which
was outside its allow list. f6's live-host test name and its "closes
once" wording need one fix.
```

## Status row

wave2-789 wave10 review (f7, f6): reviewed; verdict small fixes (1 should, 1 could). Open: client_messages.dart:90 "TV" needs tools/smoke.sh repinned in a job that allows it; launch_home_test.dart:184 "closes once" name; host_connection.dart:193 decision for the owner.

## Delete

- none
