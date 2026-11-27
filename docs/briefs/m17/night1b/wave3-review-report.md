# Review of wave3 (e0c): save the party night

## Summary

Verdict: small fixes
Counts: must 1 · should 6 · could 3
1. must: night_save_test.dart:92-103 "ending clears the save" passes on a PartyNight that never saves (no save is asserted before `end()`).
2. should: night_save.dart:31 a round-0 night (started, never played) is resumed after a restart, which breaks the B-032 fresh-pick rule.
3. should: night_save.dart:64 the saved JSON has no version field, and any missing field drops the whole night.

## Findings

- **must** packages/party_host/test/night_save_test.dart:97-102 the test "ending the night clears the save" never checks that a save exists before `end()`; its only `containsKey` check (line 102) is true on a build that never saves, so it passes without persistence → split the cascade at line 97 and add `expect(prefs.containsKey('party_night_v1'), isTrue)` after `start`.
- **should** packages/party_host/lib/src/night/night_save.dart:31 a night started but never played (round 0) is loaded after a restart, so a host killed in round 1 gets back a 0-round night, not the fresh start card of B-032 (party_night.dart:113-119) → clear a round-0 save in `load()` (as `dropIfUnplayed` does), or record the choice as a decision.
- **should** packages/party_host/lib/src/night/night_save.dart:64-83 the saved JSON has no version field, and `_readNight` (lines 95-99, 110-112) returns null for any missing field, so one field added later silently drops every saved night → write `'version': 1` in `_nightJson` and check it in `_readNight`.
- **should** packages/party_host/lib/src/night/party_night.dart:65 the roster listener sets `state` directly, so the entries `remember` adds (a leaver's number and nickname) are not saved until the next change → use `_set(night.remember(players))` here.
- **should** packages/party_host/lib/src/night/night_save.dart:24-26 a corrupt save is dropped with no `LogSink` line (guidelines §2), and `save` (line 37) and `clear` (line 40) discard the `Future<bool>` of the write, so a failed write is silent → log at the load boundary through `LogSink` and log a false write result; the brief asked for silence, so Claude decides which rule wins.
- **should** packages/party_host/lib/src/night/night_save.dart:1 the file is 187 lines; the brief (e0c.md, step 2) asked for under 120 → split the reader (lines 85-187) into its own file in a job whose allow: names it, or accept the size in writing.
- **should** packages/party_host/test/night_save_test.dart:39-50 the round trip asserts only round, totals, one counter, awards, outcomes and rows; a swapped `played`/`maps` key or a dropped `lastRoundPoints` or `isEndedEarly` would pass → add expects: `lastRoundPoints` `{'p1': 1, 'p2': 4}` (night_state.dart:285 sets it from the last round), `isEndedEarly` false, `maps` empty, and `seen['p2']?.number` 2.
- **should** packages/party_host/test/support/night_harness.dart:27-32 `nightContainer()` has no callers left and no prefs override, so any test that uses it throws `UnimplementedError` → delete it in a later job whose allow: names this file (outside this job's allow:).
- **could** packages/party_host/test/night_save_test.dart:53-75 the garbage test covers a bad round and bad awards only; no case reaches the outcome award check (night_save.dart:162), the character check (:173-177) or the round range check (:99) → add one broken map per branch.
- **could** packages/party_host/lib/src/night/night_state.dart:9 and packages/party_host/lib/src/night/night_save.dart:11 the two files import each other, because the `SavedNight` typedef lives in night_save.dart → move the typedef to night_state.dart if that file stays under 380 lines (it is 374 now), or note the cycle in the file's doc.
- **could** packages/party_host/test/support/fake_prefs.dart:8 the doc "the preferences the host id code writes to" is garbled (a line that predates this job, in a file it changed) → "the preferences the host writes to".

## Decisions to confirm

- night_save.dart:24-26: a corrupt save is dropped silently, as the brief asks; guidelines §2 says to log it through `LogSink`. Why it matters: the two rules conflict and the worker picked the brief.
- night_save.dart:31 and party_night.dart:113-119: a round-0 night survives a restart, while B-032 wanted it dropped. Why it matters: it changes what a host sees after a crash.
- night_save.dart:31: a night that is over at restart is cleared, so a host who restarts on the final scores loses the result until the M15 hall of fame exists. Why it matters: the brief asked for this, but it is a visible loss.
- night_state.dart:9 / night_save.dart:11: the cycle and the typedef's home (see could above).
- e0c-report.md (the worker's Q5): the roster change is not saved, which the brief's "after each change" wording may not cover (see should above).
- The worker used 77 turns against a cap of 70; the runner accepted it (run.log 18:23:09). Why it matters: the cap was not met.

## Could not check

- `tools/check.sh host` (brief step 4) was not run: the worker ran only `tools/mine.sh`, and run.log shows a combined check with no party_host result line. 45 test files reference `partyNightProvider`, and only five were changed, so other tests may still fail.
- "The restart test fails on the base": run.log says night_save_test.dart fails on the old code, but that file cannot compile on the old code (no `NightSave`), so the per-test reason is not shown.
- The "70 tests OK, analyze clean" in the worker's report: not reproduced here (read-only job).
- docs/briefs/m17/night1b/run-findings.md does not exist, so nothing from it was read.
- Formatting (`dart format`) of the changed files: not run.

## Commit message — a draft

Review wave3 e0c: save the party night after each change

Read-only review of e0c against the coding guidelines, the review rules and its
brief. Finds one must (test 4 passes without a save) and should items: the
round-0 resume, no save version, the roster change not saved, the 187-line
night_save.dart, and the unused nightContainer helper. Changes no code.
Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>

## Status row

e0c reviewed (wave3): small fixes. Done: the save, load and clear paths read correctly. Open: must, the test 4 assertion; should, round-0 resume, save version, roster save, file size, nightContainer, round-trip asserts, and the silent-drop decision.

## Delete

- none
