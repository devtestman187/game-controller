# Wave 2 review: d2h, d2i, d2x

## Summary

- Verdict: needs Claude
- Counts: must 1, should 5, could 2
- 1. The resumed controller constructor has six named parameters (rule: at most five).
- 2. `reasonFor` in the provider calls `pickFor`, which picks and saves the played list when the how-to card is emitted. The reports do not say so.
- 3. `startRound` records a pick before the open checks, so a round refused by a dialog still counts as played.

## Findings

- **must** packages/party_host/lib/src/night/night_flow_controller.dart:92 The resumed constructor `NightFlowController.resumed` takes six named parameters (rounds, playedRounds, pacing, schedule, onEvent, reasonFor); the rule allows five → group the pacing, schedule, onEvent and reasonFor into a value object, or get Claude's ruling that the brief's both-constructors wording stands.
- **should** packages/party_host/lib/src/night/night_flow_provider.dart:30 `reasonFor` calls `pickFor(round)`, which sets the pick state and calls `_record` (night_pick_provider.dart:42-54, 106-109), so a pick is made and saved when the how-to card is emitted, not when the game opens; the comment at :29 says only "comes from the pick" and d2h-report.md:21 does not list this → list it under Decisions and correct the comment, or read the pick without recording it.
- **should** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:86 `startRound` calls `pickFor(round)` before the mounted and dialog checks, so a round refused because a dialog is on top is recorded as played but never opens → record the pick only when the game opens, or confirm the intent (d2x-report.md Questions 2 asks the same).
- **should** docs/briefs/m17/night2b/d2h-report.md:33 The self-check says a picker-host night's cards are unchanged, "covered by the no-reasonFor controller test"; no test covers it (night_how_to_reason_test.dart:131-155 uses the director only, and :95-102 builds a controller without a provider) → add a provider test with `NightPicker.host` asserting `reason` is null, or correct the claim.
- **should** packages/party_host/test/night_pick_open_test.dart:114-124 The two-joined-player test runs both looks at 1920x1080 only, so the menu look with two players at its own 960x540 size is never drawn, and the 9 px overflow the report names (d2x-report.md:52) is not pinned by any test → add a 960x540 case that states the overflow, or a known-failure note.
- **should** docs/briefs/m17/night2b/d2h-report.md:23 The report says "14 tests" in `night_how_to_reason_test.dart`; the file has 11 (`test(` at lines 42, 47, 58, 61, 65, 72, 79, 86, 95, 104, 131) → correct the count.
- **could** packages/party_host/test/night_how_to_reason_test.dart:153-154 The second assertion repeats the first (`howTo` equals `NightHowTo(2, reason: pick?.reason)`, then `reason` equals `pick?.reason`) → delete line 154.
- **could** packages/party_host/lib/src/night/night_variant.dart:8 `nightNextVariantProvider` is now a `NightPick?` provider, so its name no longer matches its type; the brief kept the name → rename in a later job.

## Decisions to confirm

- d2h: the how-to card now makes the round's pick (see the provider finding). Confirm that the pick and its played-list entry may be made when the card shows, before the game opens.
- d2i: `NightSetupOptions` is imported only by its test (grep over packages). The setup screens still offer what they offered before, so the "pool honesty" is not yet visible to a host. Confirm the wiring is the next job.
- d2i: `withDifficulty` with both `min` and `max` applies `max` first, then `min`, so min wins and max moves up (night_setup_options.dart:68-75). No test covers that case.
- d2i: toggling a game on adds its game name and keeps variant entries of other games (night_setup_options.dart:47-50). Confirm that a variant-level pool survives a toggle.
- d2x: the Bumper Round pick overwrites the host's Arena map and mode with `setMode`/`setMap` (night_pick_open.dart:21-23) and nothing restores the host's own choice afterwards. Confirm this is wanted.
- d2x: `startRound` calls `pickFor` first (see the should finding at night_scoreboard_screen.dart:86).

## Could not check

- Did not run `dart analyze` or any test: this job is read-only. Runner evidence: docs/briefs/m17/night2b/run.log:62, 63 and 65 show d2h, d2i and d2x finished with result 0; run.log:67 says d2x used 62 turns over its cap of 60 (accepted).
- docs/briefs/m17/night2b/run-findings.md does not exist, so there were no "passes on the old code" entries to check.
- Read the rules from the worker extract, not from docs/coding-guidelines.md and docs/review-rules.md in full.
- The 9 px overflow at 960x540 is taken from d2x-report.md:52; I did not run it.
- Whether `nightNextVariantProvider` re-reads synchronously after `pickFor` (scoreboard :86-87) is not verified without a run.
- The body of `NightEvent.operator ==` (night_flow.dart:58) was not read; the tests assume it compares facts.

## Commit message — a draft

review: wave2 d2h d2i d2x, findings only

Read-only review of the three wave 2 jobs against the coding guidelines,
the review rules and their briefs. No code or test changed. Findings:
one must (the resumed controller has six parameters), five should, two
could. Open decisions: the how-to card makes the round's pick, pickFor
runs before the open checks, NightSetupOptions is not wired yet, and
the Bumper Round pick overwrites the host's Arena map.

## Status row

wave2 review (d2h d2i d2x): 1 must, 5 should, 2 could in wave2-review-report.md. Open: the resumed controller's six parameters, the pick made at card time, pickFor before the open checks, the two-player test at one size, NightSetupOptions not wired.

## Delete

- none
