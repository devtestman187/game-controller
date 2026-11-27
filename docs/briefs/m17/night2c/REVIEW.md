# Review of the night2c run (f67e7419..86aa8cb3), read-only

## Summary
Verdict: one fix batch (the owner decisions under Open questions stay open).
Counts: must 1, should 10, could 10. Phone-pinned findings: none.
Hand-fixes: run.log has one `HAND-FIX` line (c1, 11:18:36). Its tests-first proof and worker review exist (run.log:97-98, wave1-c1-review-report.md). Commit 96fcea82 (isKids, with a test) was a hand-fix that run.log does not log, and no worker report exists for it.
Carried over and now fixed: isKids ignores the picker (night_settings.dart:135 area, test at night_settings_test.dart:64-68); the default voteStarterProvider and the timer close are tested (night_vote_test.dart:300, :319); dispose completes done (night_vote.dart:67); the c1 wording, `text!` and the self-check 1 claim.
Top five:
1. night_pick_test.dart:256: the vote-pick test is not shown to fail without `takeResult`.
2. night_scoreboard_screen.dart:83-84: a settled vote's strip stays on the last round's scoreboard.
3. shop_demo_screen.dart:83: `cardsFor` reads the live controller list on each call.
4. night_settings_test.dart:139-142: the no-picker case cannot tell a dropped save from a kept one.
5. test/support/all_looks.dart:32: `pumpHostLook` does not forward `hostPicks`, so the director-default test runs on one look.
Owner questions: the Kids tap now sets the director picker; a Next tap closes an open vote; every start-card press starts a vote; the untracked-file rule in mine.sh; O5 timing.

## Findings
- **must** packages/party_host/test/night_pick_test.dart:256 The vote-pick test asserts `pick.variant == voted`, but the test was never run against code that ignores `takeResult`, and the random fallback can land on the same card (f1-report.md Questions) → temporarily make `_votePick` ignore `takeResult` and confirm the test fails; if not, pick a vote the fallback cannot produce. (from: f1, wave3)
- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:83-84 `_startVote` returns early on the last round without cancelling, so a settled vote from the previous round stays in `nightVoteProvider` and the scoreboard strip shows its "wins!" line → call `ref.read(nightVoteProvider.notifier).cancel()` before each early return, and add a test: vote for round 2 of 3, then the round-3 scoreboard shows no strip. (from: v1c, wave3)
- **should** packages/party_host/lib/src/night/night_vote.dart:20 The `VoteHandle.done` doc says it completes "when the round closes, by its timer or by [closeNow]", but `dispose` now completes it with an empty map (night_vote.dart:67) → add "or when the handle is disposed, with an empty map". (from: wave3)
- **should** packages/party_host/lib/src/ui/shop_demo_screen.dart:83 `cardsFor` calls `_listsChoices` (:100-101) on every press, so a last phone that drops out mid-round loses Roadworks and its pick is refused → evaluate `_listsChoices` once at round setup and capture the bool; add a test where the last capable phone's link drops and Roadworks stays offered. (from: wave1-c1)
- **should** packages/party_host/test/night_settings_test.dart:139-142 The no-picker-key case asserts only `picker == director`, which also holds when `tryFromJson` drops the whole save (night_settings.dart:135 returns null when `picker` is missing) → also save a non-default `length` in that JSON and assert it is kept, or assert the drop. (from: wave2, v2)
- **should** packages/party_host/test/support/all_looks.dart:32 `pumpHostLook` does not forward `hostPicks`, so the app-default test at night_setup_screen_test.dart:301 covers one look only (review rule A6 asks for every look) → forward `hostPicks` in `pumpHostLook` and run the test through `forEachLook`, or record the gap as open. (from: wave2, v2)
- **should** packages/party_host/lib/src/night/night_vote.dart:138 The End-night path has no test: the listener (:137-139) cancels the vote when night is null, but no test shows the timer stops or the strip clears; a dropped or away phone on the scoreboard with an open vote is also untested → add one scoreboard test for End-night and state the other pairs as "not tested" in the report. (from: wave3)
- **should** tools/tests/agent-cost-test.sh:172 `agents-off-unchanged` only checks that `driver:` and `rows sum` are absent; t1 item 1 asks for byte-identical output without the flag → compare the no-flag output with a stored expected text. (from: wave1)
- **should** tools/agent_cost.py:243 `main()` runs from line 243 to the end (about 113 lines; the guideline is about 40) and grew in this run (the file went from 309 to 356 lines) → move the per-owner and driver accumulation into a named helper. Already recorded in docs/code-health.md:380. (from: wave1)
- **should** tools/agent_cost.py:240 `gap / 60` is a bare 60 → name it, for example `_SECONDS_PER_MIN = 60`, with a one-line comment. Already recorded in docs/code-health.md:380. (from: wave1)
- **should** packages/party_host/test (v1a-report.md, v1b-report.md, f1-report.md, v2-report.md, d1-report.md) Five job reports have no review-rules part A self-check (grep finds no "Host setups", "Play on this phone" or "A1" lines); guidelines §11 and review-rules A ask for one → add the self-check to the report of each job, or decide that the reports stay out of the record. (from: across jobs)
- **could** packages/party_host/lib/src/night/night_vote.dart:19 One file holds five public types (`VoteHandle`, `VoteStarter`, `ServerVoteHandle`, `NightVoteState`, `NightVoteNotifier`) → move `ServerVoteHandle` (:34-74) to its own file. (from: wave1)
- **could** packages/party_host/lib/src/text/night_setup_text.dart:37 `pickerVoteHelp` hard-codes "5 seconds", but the duration is `voteDuration` (night_vote.dart:106 uses it) → name the constant in the doc comment, or add a test that checks the text against `voteDuration.inSeconds`. (from: wave3)
- **could** packages/party_host/lib/src/text/night_setup_text.dart:33 The host help text reads "You choose each game yourself, every time.", which the brief did not ask for ("update only what reads wrong") → revert to "You choose each game yourself." unless the owner wants it. (from: wave2)
- **could** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:79 The doc comment runs past 120 columns → rewrap it at 120. (from: wave3)
- **could** docs/driver-kit.md:127 "This replaces the old 'no protocolVersion bump' rule" points at a rule that no doc under docs/ holds (the matches are briefs only) → name where the rule lived, or drop the sentence. (from: wave2, d1)
- **could** docs/driver-kit.md:130 The text says "any wait over about 55 min", but the tool prints the longest wait in minutes, always (t1 decision 4) → say "the longest wait (min)", so the doc matches the output. (from: wave1)
- **could** tools/mine.sh:200 The header (lines 1-16) does not list the new `FAILED untracked folder <path>` line or its exit 1 → add one line to the header. (from: wave2)
- **could** docs/code-health.md (no line) The verdicts say these were deferred to code-health, but the file has no entry for them: the live `cardsFor` read (shop_demo_screen.dart:83), the no-picker test (night_settings_test.dart:139-142), the shared old-phone helper, and the mine.sh header → add the four entries, or drop the deferral from the verdicts. (from: across jobs)
- **could** packages/party_host/lib/src/ui/night_start_screen.dart:141-146 and packages/party_host/lib/src/ui/shop_demo_screen.dart:100-101 Two jobs wrote the same old-phone rule ("no `Capability.choices`"); choice_fallback.dart:199 has a third copy (c1-report.md Suggestions) → one shared helper, in a follow-up job. (from: across jobs)
- **could** packages/party_host/lib/src/ui/night_start_screen.dart:323 and tools/agent_cost.py:356 Files over 300 lines: night_start_screen.dart grew from 317 to 323 over the run, and agent_cost.py from 309 to 356. Both are under the hard limits (380 for lib, 400 for files) → no split needed now; track in code-health. (from: across jobs)

## Open questions
1. The Kids preset now sets the director picker (night_settings.dart:46-54 area), so a Kids tap changes a host's picker. Suggested: keep, since the brief asked for it.
2. A Next tap on the scoreboard closes an open vote at once (night_scoreboard_screen.dart:170-172 → `startNow` → `pickFor` → `takeResult`), so phones lose the 5 s. Suggested: wait for the vote, the safer choice.
3. Every start-card press runs a new round-1 vote, and Back returns with nothing started (night_start_screen.dart:126-129). Suggested: keep as built, since the owner wanted the vote first.
4. O5 timing (the vote during the previous scoreboard; round 1 on the start card) is "NOT yet owner-confirmed" (d1-report.md Q3). Suggested: confirm before the vote is wired.
5. mine.sh:162: an untracked non-.dart file still prints a green `0 file(s) formatted`. Suggested: the literal brief reading (note or fail for any untracked file).
6. Which version text ships: the committed "This phone app and the Thumb Party TV app ..." (phone_text.dart:112) or the owner's "Thumb Party app on this phone" (c1-report.md Q1). Suggested: keep the committed text.
7. Does the old-phone rule belong in `cardsFor` or in `choice_fallback.dart`? Suggested: keep it in `cardsFor` now, and share one helper later.
8. When a saved settings file has no `picker`, the whole save is dropped (night_settings.dart:135). Suggested: default only the picker, so the other saved fields keep their value, as the brief asks.
9. Where did the old "no protocolVersion bump" rule live (d1-report.md Q1)? Suggested: name it in driver-kit.md, or drop the sentence.
10. The 1 h cache claim "since Nov 23" (d1-report.md Q2) was not verified. Suggested: check before relying on it.

## Numbers against targets
- Vote length: 5 s in the help text (night_setup_text.dart:37); the constant `voteDuration` was not read, so the match is unverified.
- Long wait threshold: driver-kit.md:130 says "about 55 min"; the tool prints the longest wait, not the wait over 55 min. The test fixture (agent-cost-test.sh:160) uses 70 min only as a fixture.
- Version text: 154 characters, under the 200 limit (c1-report.md:26; the test checks `< 200`).
- File sizes against the soft 300 target: agent_cost.py 356 (from 309), night_start_screen.dart 323 (from 317), mine.sh 299 (from 293). No lib file is over the 380 limit.
- Test counts from the workers, not re-run here: mine.sh 125 tests (wave2 verdicts), v1a 72, c1 20, t1 31 PASS, v2 124. No target is stated in the briefs for these.

## Could not check
- Nothing was run: no tests, no analyze, no mutation check. Every line number is from a read or a grep; the wave reports' test counts are unverified.
- The fixes for night_vote_test.dart:215 (the 60-line setup helper) and :92 (the name "pool of 7"), and v1a-report.md's "10 tests" count, were not re-read; they are left out.
- test/support/all_looks.dart:32 and night_pick_test.dart:215 were cited from the wave reviews, not reopened.
- choice_fallback.dart:199 was cited from the c1 report, not reopened.
- Whether a real old app lists `Capability.layout` (c1 review decision): no old build is available.
- Whether the vote strip fits on a TV at real sizes: wave3 found no measurement; the overflow test is the only check.
- That the Next-tap path cuts a vote short was read from the code, not run.
- The untracked-file behaviour of mine.sh was read from lines 161-162 and 200; the output was not run.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
review: night2c run (f67e7419..86aa8cb3), findings only

Read-only review of the whole night2c run as one change, against the
coding guidelines and review rules. Findings: 1 must, 10 should, 10
could (see REVIEW.md). Carried over: the vote-pick test is not shown
to fail on the old code; a settled vote's strip stays on the last
scoreboard; the VoteHandle.done doc misses the dispose completion.
Already fixed in the run: isKids, the default vote starter and the
timer close tests, dispose completing done. No code or other
document changed.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

- night2c run review: done (1 must, 10 should, 10 could; one fix batch). Open: the vote-pick test proof (night_pick_test.dart:256), the stale strip on the last scoreboard, shop_demo cardsFor live read, the no-picker test, the all_looks hostPicks gap, and the owner questions (Kids tap, Next tap, start-card vote, mine.sh untracked rule, O5 timing).

## Delete
- none

## Owner answers (Nov 27, recorded in night2d)
- Q1: keep 5 s / 2 s and the O5 order; the owner says yes or no at the BP2 device test.
- Q2: keep for now: the Kids tap replaces all settings, with no restore. Ask again at BP2.
- Q3: keep.
- Q4: mine.sh should fail per the brief, but only after BP2, with an allowlist. mine.sh NOT changed now.
- R7: the old-phone rule stays in `cardsFor`; a code-health note was added (docs/code-health.md "night2d notes").
- R8: no change; saved night settings reset once.
- R9 and R10: closed internally.
- Must finding 1 (night_pick_test.dart:256): proved, see docs/briefs/m17/night2d/REPORT.md.
