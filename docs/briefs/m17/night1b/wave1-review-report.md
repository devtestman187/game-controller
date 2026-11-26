# wave1 review (n1c, e0e): report

## Summary

- Verdict: needs Claude.
- Counts: must 1 · should 2 · could 4.
- Top 1: `_JoinBody` now takes 9 parameters (limit 5), so the e0e diff adds to a rule already broken at 8 (join_screen_widgets.dart:162-172).
- Top 2: the e0e test skips the all-looks helper that rule A6 and the brief name (join_screen_full_test.dart:26).
- Top 3: the boolean `full` is not a question, so rename it `isFull` (host_text.dart:79, join_screen_widgets.dart:37, :42, :185, join_screen.dart:336); the brief chose the name, so confirm it.
- Runner evidence (run.log:24-25): both new test files fail on the base code. No test passes on the old code.
- Line counts: host_text.dart is 380 (limit 380, no headroom); join_screen.dart 368; night_state.dart 347; night_flow.dart 311. No line over 120 columns in the changed files.
- No prints, TODOs, commented-out code, or magic numbers found in the changed lines.
- Tests were not re-run here (read-only job); see Could not check.

## Findings

- **must** packages/party_host/lib/src/ui/join_screen_widgets.dart:172 `_JoinBody` now has 9 constructor parameters (it had 8; the rule is at most 5, beyond that a value object) → group the roster fields (`players`, `teams`, `watching`, `ownHere`, `full`) into one value object in a follow-up job, and add no more parameters until then.
- **should** packages/party_host/test/join_screen_full_test.dart:26 The test builds the TV look by hand (`overrides: [if (tv) toyTvProvider.overrideWithValue(true)]`) and does not import `test/support/all_looks.dart`, which rule A6 names and the brief said to import → use the all-looks pump helper for the two looks.
- **should** packages/party_host/lib/src/text/host_text.dart:79 `full` is a boolean that does not ask a question (also join_screen_widgets.dart:37, :42, :185 and join_screen.dart:336) → rename to `isFull` everywhere in the e0e change.
- **could** packages/party_host/test/join_screen_full_test.dart:30-31 The helper passes the id number minus one to `phoneInfo`, while packages/party_host/test/support/phone_fit_support.dart:100 passes the number, so p6 is labelled "P5 Phone 5" (line 57) and p4 "P3 Phone 3" (line 66) → pass the number and let the expectations match the ids.
- **could** packages/party_host/test/night_round_cap_test.dart:13 and :17 Both pin the shipped lengths and pass with the constant alone (no assert needed), and :17 repeats the list check of :13 except for the 8 case → merge them into one test; keep :28 (start(8) throws), which is the one that fails without the change.
- **could** packages/party_host/lib/src/text/host_text.dart:78, packages/party_host/lib/src/ui/join_screen_widgets.dart:41 and :184, packages/party_host/lib/src/night/night_state.dart:8 Comments name job ids ("(e0e)", "(M17 plan n1c)") that go stale → state the reason in the comment and drop the ids.
- **could** docs/briefs/m17/night1b/e0e-report.md:28 The self-check says the "TV host" and "phone host" setups are covered, but the test only switches the look; "Play on this phone" and "Show on this device" are not tested → reword the line to say which setups the test covers.

## Decisions to confirm

- The text "Game full, watching: …" tells a phone it is watching but not what to do next (rule B8 asks for a next step); the brief fixed the wording, so the owner should confirm it.
- `HostText.notJoined(names, {bool full = false})` (host_text.dart:79): its only caller (join_screen_widgets.dart:48) always passes `full`, so the default is never used; confirm whether to drop it.
- e0e's TV-look test runs at 1920x1080, not 960x540, because the TV look overflows at 960x540 (reported as toy_look/toy_card.dart:129, outside the job's allow list); the owner decides whether the TV look must fit 960x540.
- `join_screen.dart:336` reuses `sideForNewPlayer(_teams) == null`, the same rule that refuses a join (join_screen.dart:193 and :206), so the text and the join rule agree; kept as is.

## Could not check

- Test results: I did not run any test or analyzer (read-only job). The counts `OK 42` (n1c) and `OK 5` (e0e) are the workers' claims; run.log holds only the tests-first lines (run.log:24-25).
- Whether a joined phone that drops keeps its slot in `_teams`: if it does, `sideForNewPlayer` (join_screen.dart:74) may report "Game full" while a seat is free. Not verified; the e0e report says the dropped-link pair is not tested.
- docs/PRD-v2.md and docs/briefs/m17/STATUS.md matched a grep for "Not joined", "8 rounds", "nightRoundCap" or "Game full"; I did not read them. The wave did not change them.
- toy_look overflow claim (toy_card.dart:129): outside the job's allow list, not read.
- docs/briefs/m17/night1b/run-findings.md does not exist, so there were no run findings to check.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
docs: review of wave1 (n1c, e0e) findings
```

Review of the n1c (5-round cap) and e0e (Game full) jobs against the guidelines, review rules and briefs: one must (a 9-parameter `_JoinBody`), two should, four could. Findings in docs/briefs/m17/night1b/wave1-review-report.md; no code changed.

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

wave1 review (n1c, e0e): done, verdict needs Claude (must: `_JoinBody` at 9 params; should: e0e test skips all-looks helper, `full` name). Open: Claude's decision on the fixes and the owner's on the "Game full" text and the TV 960x540 overflow.

## Delete

- none
