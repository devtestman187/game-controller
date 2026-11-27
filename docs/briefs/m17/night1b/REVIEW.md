# Run review (night1b)

## Summary

Verdict: needs Claude's design (three decisions: round-0 resume, silent corrupt drop, championsAmong wiring), then one fix batch for the rest.
Counts: must 1 · should 11 · could 12 (24 findings; REVIEW-VERDICTS.md does not exist, so nothing was skipped as verdicted).
Five that matter most:
1. must: the "ending the night clears the save" test passes without any save; no save is asserted before `end()` (night_save_test.dart:92-103).
2. should: a night started but never played (round 0) is resumed after a restart, against B-032 (night_save.dart:31, party_night.dart:116-118).
3. should: a roster change (a leaver's row, from `remember`) is never saved (party_night.dart:65).
4. should: a corrupt save is dropped silently, against guidelines §2, and a failed write is discarded (night_save.dart:26, :37, :40).
5. should: `nightContainer()` has no callers and no prefs override; `savingNightContainer` duplicates it (test/support/night_harness.dart:27-32).
Questions only the owner can answer: see Open questions (round-0 resume, LogSink vs silence, "Game full" wording, TV look at 960x540, wiring championsAmong).
Sizing: phone-pinned candidates are join_screen*.dart and host_text.dart (controller_app/test/support/host_app.dart imports party_host; not traced further). Suggested jobs of 3 or fewer, disjoint files: (a) night_save_test.dart + night_save.dart + party_night.dart (the must, round-0 resume, roster save); (b) join_screen_widgets.dart + join_screen.dart + host_text.dart (_JoinBody parameters, the isFull rename, the job-id comments); (c) join_screen_full_test.dart + night_round_cap_test.dart + night_scoring_test.dart (all-looks helper, label ids, duplicate pins).

## Findings

- **must** packages/party_host/test/night_save_test.dart:96-102 the "ending the night clears the save" test sets `start` and `end()` in one cascade and never asserts a save exists before `end()`, so its `containsKey` false check (line 102) also passes on a build that never saves → split the cascade and add `expect(prefs.containsKey('party_night_v1'), isTrue)` after `start` (from: wave3).
- **should** packages/party_host/lib/src/night/night_save.dart:31 `load()` resumes any night that is not over, including round 0; party_night.dart:116-118 (`dropIfUnplayed`, B-032) drops round-0 nights, so a host killed after starting gets a 0-round night back instead of the fresh start card → in `load()` clear a save with `round == 0`, as `dropIfUnplayed` does (from: across jobs, e0c vs n1 B-032; wave3).
- **should** packages/party_host/lib/src/night/party_night.dart:65 the roster listener sets `state` directly, so the entries `remember` adds (a leaver's number and nickname) are not saved until the next change, while the doc at party_night.dart:54-55 says "saved after each change" → use `_set(night.remember(players))` (from: wave3).
- **should** packages/party_host/lib/src/night/night_save.dart:24-26 a corrupt save is cleared with no `LogSink` line (guidelines §2 says log at a documented boundary), and `save` (:37) and `clear` (:40) discard the write's `Future` through `unawaited`, so a failed write is silent → log at the load boundary through `LogSink` and log a false write result; the brief asked for silence, so Claude decides (from: wave3).
- **should** packages/party_host/lib/src/night/night_save.dart:64-83 the saved JSON has no `version` field (no match for "version" in the file), and `_readNight` (:96-112) returns null for any missing field, so one field added later drops every saved night → write `'version': 1` in `_nightJson` and check it in `_readNight` (from: wave3).
- **should** packages/party_host/lib/src/night/night_save.dart:1-187 the file is 187 lines, the e0c brief asked for under 120; the reader (about :85-187) is the bulk → move the reader to its own file in a job whose allow: names it (from: wave3; e0c Q1).
- **should** packages/party_host/test/night_save_test.dart:39-50 the round trip asserts only round, totals, one counter, awards, outcomes and rows, so a swapped `played`/`maps` key or a dropped `lastRoundPoints` or `isEndedEarly` would pass → add expects for `lastRoundPoints` `{'p1': 1, 'p2': 4}`, `isEndedEarly` false, `maps` empty and `seen['p2']?.number` 2 (from: wave3; not re-read here).
- **should** packages/party_host/test/support/night_harness.dart:27-32 `nightContainer()` has no callers (grep finds only its definition) and no prefs override, so any new use throws `UnimplementedError`; `savingNightContainer` (test/support/fake_prefs.dart:93) does the same job → delete `nightContainer` in a job whose allow: names this file (from: wave3; across jobs, e0c left it because it was outside allow).
- **should** packages/party_host/lib/src/ui/join_screen_widgets.dart:163-173 `_JoinBody` now has 9 constructor parameters (it had 8 before e0e; the rule is 5, beyond which a value object) → group the roster fields (`players`, `teams`, `watching`, `ownHere`, `full`) into one value object and add no parameter until then (from: wave1).
- **should** packages/party_host/test/join_screen_full_test.dart:26 the test builds the TV look by hand with `overrides: [if (tv) toyTvProvider.overrideWithValue(true)]` instead of the all-looks pump helper that review-rules.md item 6 names (test/support/all_looks.dart) → use the helper for the two looks (from: wave1).
- **should** packages/party_host/lib/src/text/host_text.dart:79, packages/party_host/lib/src/ui/join_screen_widgets.dart:42, :185 and packages/party_host/lib/src/ui/join_screen.dart:336 `full` is a boolean that does not ask a question → rename to `isFull` in the e0e change. Also host_text.dart:79's default `= false` is never used (its only caller passes `full`), so drop it (from: wave1; the brief chose the name, so confirm).
- **should** docs/briefs/m17/night1b/n1d-report.md:9 says the test file has "6 tests" (and the Status draft at :59 repeats it); night_scoring_test.dart has 8 `test(` calls (lines 12, 17, 23, 29, 46, 57, 68, 79) → change both counts to 8 (from: wave2).
- **could** packages/party_host/lib/src/night/night_state.dart:308 `rows` adds `awardPoints * awardsWonBy(id)` to each total, which `championsAmong` reads; no test in night_scoring_test.dart gives a player an award, so this path is unpinned → add one case with an awarded player and check the champion and `place == 1` agree (from: wave2; line was 290 at n1d, now 308).
- **could** packages/party_host/test/night_scoring_test.dart:57-66 repeats the tie-for-first case of champion_test.dart:97-111 → keep it if the brief's list needs it, else drop it or note in the file doc that the provider test is the other half (from: wave2).
- **could** packages/party_host/test/night_round_cap_test.dart:13 and :17 both pin the shipped lengths, and :17 repeats the list check of :13 except for the 8 case → merge them; keep :28 (`start(8)` throws), the one that fails without the change (from: wave1).
- **could** packages/party_host/test/join_screen_full_test.dart:30-31 passes the id number minus one to `phoneInfo`, so p6 is labelled "P5 Phone 5" (line 57) and p4 "P3 Phone 3" (line 66); the label and the id disagree → pass the number and make the expectations match the ids (from: wave1).
- **could** packages/party_host/lib/src/text/host_text.dart:78, packages/party_host/lib/src/ui/join_screen_widgets.dart:41 and :184, packages/party_host/lib/src/night/night_state.dart:11 comments name job ids ("(e0e)", "(M17 plan n1c)") that go stale → state the reason and drop the ids (from: wave1; the line is 11, not 8).
- **could** packages/party_host/lib/src/night/night_state.dart:9 and packages/party_host/lib/src/night/night_save.dart:11 import each other, because the `SavedNight` typedef sits in night_save.dart → move the typedef to night_state.dart if that file stays under 380 lines (374 now), or note the cycle in the file doc (from: wave3; e0c Q4).
- **could** packages/party_host/test/support/fake_prefs.dart:8 the doc "the preferences the host id code writes to" is garbled, in a file this run changed → "the preferences the host writes to" (from: wave3).
- **could** docs/briefs/m17/night1b/e0e-report.md:28 the self-check says the TV host and phone host setups are covered, but the test only switches the look; "Play on this phone" and "Show on this device" are not tested → reword to say which setups the test covers (from: wave1).
- **could** docs/briefs/m17/night1b/n1d-report.md:8 calls `championsAmong` a "getter"; night_state.dart:333 declares it as a method with a `players` parameter → write "method" (from: wave2).
- **could** packages/party_host/lib/src/night/night_state.dart:333 `championsAmong` has no lib caller (grep finds only its definition and the tests), while the scoreboard still reads place 1 from `rows`, so there are two champion rules that can drift → wire the champion to it in the next job, or say in the doc that it is not yet used (from: across jobs; n1d hand-over).
- **could** packages/party_host/test/night_save_test.dart:53-75 the garbage test covers a bad round and bad awards only; no case reaches the outcome award check (night_save.dart:162), the character check (:173-177) or the round range check (:99) → add one broken map per branch (from: wave3).
- **could** across jobs: the tests-first proofs for n1c, n1d and e0c are compile failures on the base (run.log:25, :36, :68; n1c, n1d and e0c reports), so they show "fails on the old code" only by compile error; e0e is the one with a behavioural proof (e0e-report.md:16) → accept, or ask for a behavioural check in later jobs (from: across jobs).

## Open questions

1. Should a round-0 night survive a restart (the code does) or be dropped as B-032 says? Suggested: drop it, as B-032 says (night_save.dart:31).
2. Should a corrupt save and a failed write be logged through `LogSink` (guidelines §2) or stay silent (the e0c brief)? Suggested: log through `LogSink`, since the guidelines are the rule.
3. Should a night that is over at restart be cleared (the host loses the final result until M15)? Suggested: keep as the brief says until M15 exists, and say so in the doc.
4. Should a roster change (a leaver's row) be saved at once? Suggested: yes (party_night.dart:65).
5. Is the text "Game full, watching: …" enough, with no next step (rule B8)? Suggested: keep the brief's wording and confirm.
6. Must the TV look fit 960x540 (toy_look/toy_card.dart:129 overflows by 40 px, outside allow; not read here)? Suggested: keep the test at 1920x1080 and check toy_look in a later job.
7. Should `championsAmong` be wired to the scoreboard now, so there is one champion rule? Suggested: yes, in the next job.
8. Do award points count toward the Quick night champion (night_state.dart:308)? Suggested: yes, as the brief and the scoreboard say.
9. Should `HostText.notJoined`'s default `full = false` go, and `full` become `isFull` (wave1)? Suggested: yes to both.
10. Should `nightContainer()` be deleted (outside e0c's allow)? Suggested: yes, in a job whose allow names night_harness.dart.
11. Should `_JoinBody`'s 9 parameters be grouped now, or in a later job? Suggested: a later job, with no new parameter until then.

## Numbers against targets

- packages/party_host/lib/src/night/night_save.dart: 187 lines against the e0c brief's "under 120" → missed.
- Worker turns, e0c: 77 against a cap of 70 (run.log:66, accepted by the runner) → missed.
- packages/party_host/lib/src/text/host_text.dart: 380 lines, at the 380 limit with no headroom (not over) → met, no headroom.
- packages/party_host/lib/src/night/night_state.dart: 348 (n1c), 356 (n1d), 374 (e0c) → met (under 380), grew across three jobs.
- packages/party_host/lib/src/ui/join_screen.dart: 368 lines against the e0e brief's 366 → under 380, the brief figure was off by 2.
- Test counts reported by workers: OK 42 (n1c), OK 5 (e0e), OK 26 (n1d), 70 (e0c); none re-run here.
- No measurement (timing, frame counts) appears in any report.

## Could not check

- Hand-fixes: none. `grep` for "HAND" in run.log finds no HAND-FIX line, so no tests-first proof or review report is needed for one.
- Unverified fixes: none. No fix job ran in this run (every job is a feature or a review).
- `tools/check.sh host` (the e0c brief's step 4) is not in run.log: the worker ran `tools/mine.sh`; the combined check skips other packages but no party_host result line is logged. 45 test files reference `partyNightProvider` and five were changed, so other tests may fail.
- The per-test "fails on the base" claim for `night_save_test.dart` (the file cannot compile on the base, so the reason is not shown).
- Whether controller_app tests pin join_screen*.dart or host_text.dart through controller_app/test/support/host_app.dart: not traced.
- The toy_look overflow (toy_card.dart:129) was not read; it is outside this review's files.
- Whether a joined phone that drops keeps its slot in `_teams` (join_screen.dart:74 `sideForNewPlayer` may then say "Game full" with a seat free): not verified.
- docs/briefs/m17/night1b/STATUS.md, run-findings.md and REVIEW-VERDICTS.md do not exist, so nothing was carried over from them.
- Tests, `dart analyze` and `dart format` were not run (read-only review); the counts above are the workers' claims.
- Files read in part only: night_save.dart (lines 14-45 and the grep hits), party_night.dart (lines 20-130), night_save_test.dart (lines 90-103), join_screen_full_test.dart (lines 20-69), join_screen_widgets.dart (lines 162-173). The rest of the change is taken from the wave reviews and the grep hits, not re-read.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
docs: run review of night1b (findings only)

Review of the night1b run (n1c, e0e, n1d, e0c) read as one change against the
coding guidelines and review rules. Writes docs/briefs/m17/night1b/REVIEW.md
only; no code changed. Findings: one must (a save test that passes without a
save), a round-0 resume that breaks B-032, a roster change that is not saved,
and the silent corrupt-save drop. Three decisions are left to the owner.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

night1b run review: done, verdict needs Claude's design (must: night_save_test.dart:92-103 passes without a save; should: round-0 resume vs B-032, roster change unsaved, silent corrupt drop, no save version). Open: Claude's decisions on round-0 resume, LogSink vs silence and championsAmong wiring; the fix batch; tests not re-run by this review.

## Delete

- none
