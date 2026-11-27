# night2b run review (read-only)

## Summary

Verdict: needs Claude's design (two owner decisions: the Done button's size and the labels' size); the rest is one fix batch of six jobs.
Counts: must 1, should 6, could 5 (12 open; 3 items the verdicts already settled are not repeated).
Top five:
1. `_StartColumn` takes six parameters, over the limit of five (night_start_screen.dart:190).
2. Done is 31.5 dp at 360x640 against the brief's 48 dp, and no test measures it (night_setup_screen_test.dart:96, night_setup_screen.dart:70).
3. Two f1 tests pass on the base, so they are not fail-first (night_pick_test.dart:109, :117).
4. The row labels, help lines and cat note are 8.25 dp at 360x640 with no 14 dp floor (night_setup_widgets.dart:42).
5. `variant_text.dart:9-10` says a test compares `mapNames` with test_game's list; no such test exists any more (hand-fix at run.log:22).
Fix jobs (no shared files, 3 findings or fewer): A night_start_screen.dart (#1, #12, `late _length`); B night_setup_screen_test.dart (name, scale formula, refused toggle); C night_setup_widgets.dart (labels, chip text size); E night_pick_test.dart (pass-on-base); F variant_text.dart (comment); G night_scoreboard_screen.dart + night_flow_controller.dart (unused `lastRound`). Done (#2) waits for the owner.
Unverified fixes: one — the d2g hand-fix (run.log:119) has no recorded re-run of the review before commit. The f1 fixes were measured on the base.
Owner-only questions: Done below 48 dp; labels below the 14 dp floor; the Bumper Round overwriting the host's Arena map.

## Findings

- **must** packages/party_host/lib/src/ui/night_start_screen.dart:190 `_StartColumn` has six parameters (awards, catVisits, players, oldAppIds, isPicked, onSetup), over the limit of five → group `isPicked` and `onSetup` into a value object, or have the column read `isPicked` from `nightSettingsProvider` itself. (from: wave3)
- **should** packages/party_host/test/night_setup_screen_test.dart:96 The Done button is never measured against the brief's 48 dp; it is 31.5 dp at 360x640 (the footer is 84 frame px, d2g-report.md decision 1) → measure it and list it as an exception the way `knownBelow48Host` does, once the owner has decided (see Open questions 1). (from: wave3)
- **should** packages/party_host/test/night_pick_test.dart:117 The seeds 0 to 19 director test and :109 the opening-at-medium test both pass on the base (f1-report.md: the base run failed only the tie case and the first-read case), so they are pins, not fail-first tests → say so in the report, or make a case fail on the base. (from: wave3, f1)
- **should** packages/party_host/lib/src/text/night_setup_text.dart and packages/party_host/lib/src/ui/night_setup_widgets.dart:42 The row labels use `ToyType.frame.body` (22 frame px), which is 8.25 dp at 360x640 and 7.3 dp at 320x640; the help line (:52) has the same style, and nothing measures them → apply `nightSetupAtLeastDp(context, …, nightSetupTextDp)` to these styles, or record the owner's decision. (from: wave3)
- **should** packages/party_host/lib/src/ui/night_start_screen.dart:66 `late NightLength _length = ref.read(...)` defers a read to dodge initialisation order, which the guidelines forbid → make it a plain field set in `initState` from `ref.read(nightSettingsProvider).length`. (from: wave3)
- **should** packages/party_host/test/night_setup_screen_test.dart:150 The test is named "Hardest Medium keeps Block Castle out and Easiest above Hardest moves Hardest up", but it sets both to medium (not above) and checks no Block Castle → rename it, or assert a pool without Block Castle and a case where Easiest goes above Hardest. (from: wave3)
- **should** packages/party_host/lib/src/text/variant_text.dart:9 The comment says a test (variant_text_test) compares `mapNames` with test_game's list, but the drift test was removed by hand (run.log:22) and no test in packages/party_host/test mentions `arenaMapNames` → correct the comment, or restore the comparison test (the export is the verdicted fix). (from: across jobs, d2f hand-fix)
- **could** packages/party_host/lib/src/ui/night_scoreboard_screen.dart:85 `startRound`'s `lastRound` parameter is never read (also the controller's call at night_flow_controller.dart:274) → drop it from `NightRoundHooks.startRound` (night_flow_controller.dart:17) and from both sides. (from: wave2, d2x Q3)
- **could** packages/party_host/test/night_setup_screen_test.dart:89 The 14 dp text check multiplies the style size by a hard-coded `phone.value.width / 960` and never measures the drawn text, so it repeats the frame's formula → read the scale from `HostFrameInfo`, or measure the rendered `Text`. (from: wave3)
- **could** packages/party_host/test/night_setup_screen_test.dart:146 The refused-toggle check passes when the tap misses, because `tester.tap` only warns on a miss → count the `update` calls (a listener or override) so the test fails when the chip is not hit. (from: wave3)
- **could** packages/party_host/lib/src/ui/night_setup_widgets.dart:79 The chip text copies `ToyType.frame.button` but takes its size from the body style (22 px, not the button's 28 px), so on a TV the chip text is smaller than the look's button text → use the button size as the normal size, unless the body size is intended. (from: wave3)
- **could** packages/party_host/lib/src/ui/night_start_screen.dart:1 The file grew from 239 to 313 lines over d2g (base copy checked); it is past the 300 target, under 380 → move the start card's columns into their own file when the start screen is next touched. (from: across jobs)

## Open questions

1. Done in the footer is 31.5 dp on phones, not 48 dp (night_setup_screen.dart:70) → accept it as an exception like `knownBelow48Host`, with a test that says so.
2. Row labels, help lines and the cat note stay at body size (8.25 dp at 360x640) while only chips get the 14 dp floor (night_setup_widgets.dart:42) → owner to say; suggest the floor for labels too.
3. The Kids chip sits in the list, not the footer (night_setup_screen.dart `_rows`, line 83; d2g Q1) → keep; the footer is fixed and HostFrameScreen may not change.
4. The Bumper Round pick overwrites the host's Arena map and mode (night_pick_open.dart:21-23, cited in wave2) → owner to confirm; suggest restoring the host's own choice after the round.
5. The Kids preset pins the picker to host (night_settings.dart:49-53, cited in wave1) → suggest confirm it is intended.
6. Vote is not wired: `voteDuration`, `offerFor`, `voteSetup` and `settleVote` have no caller in lib (vote_round.dart:10-76) → keep until the owner decides when the vote runs.
7. `NightPickNotifier.build` writes the prefs (clears the played list) when no night runs, which is every start without a night (night_pick_provider.dart:34-36) → accept; `partyNightProvider` loads synchronously.
8. A night restored mid-round re-picks that round after a restart, because the current pick is not saved (d2w Q2) → accept for now; say so in the status row.
9. The host-pick pin test sits in the existing file night_how_to_reason_test.dart:152, against G9's new-tests-in-a-new-file rule (f2 Q1) → move it to a new file, or record the exemption.
10. `withDifficulty` refuses a range that leaves only unplayable variants (night_setup_options.dart, d2i Q1) → yes, as built.
11. A pool that names only non-offered games, from an old save, is not cleaned on load (d2i Q2) → clean it on load in a later job.
12. The labels and cat note: 7.3 dp at 320x640 (see finding 4) → same as question 2.
13. The f1 tie band is 40 to 60 percent (80 to 120 of 200 seeds), narrower than the brief's 30 to 70 (f1-report.md) → accept; the base gives 67 percent, which the brief's band would pass.
14. `NightSetupText` carries Rotating and Vote strings only for exhaustive switches (night_setup_text.dart, wave3 decision) → keep.

## Numbers against targets

- Done button: 31.5 dp at 360x640 against 48 dp (miss, d2g-report.md decision 1; finding 2).
- Row labels and help line: 8.25 dp at 360x640 and 7.3 dp at 320x640, no target set for labels (the 14 dp floor is set for chips only).
- Chips: 128 frame px x 0.375 = 48 dp at 360x640; 144 frame px x 0.3333 = 48 dp at 320x640 (meets 48 dp). Chip text 37.3 frame px x 0.375 = 14.0 dp and 42 frame px x 0.3333 = 14.0 dp (meets 14 dp).
- Two joined phones at 960x540: the player card overflows by 9 px (verdicted in wave2; toy_card.dart:129, d2x Q1).
- Tie test band: f1 set 40 to 60 percent, base 67 percent (134 of 200); the post-fix count was not printed (f1-report.md).
- d2x took 62 turns against a cap of 60 (run.log:65, accepted by the runner).
- Test counts in the reports (1202 for d2g, 109 for f2, 46 for f1) are not checked here.

## Could not check

- No analyze or test was run: this review is read-only. The "analyze clean" and "tests pass" claims come from the reports and run.log only.
- Hand-fixes: d2f (run.log:22) has its tests-first proof (run.log:16-17, re-run at :33-37) and its review (wave1-review-report.md). d2g (run.log:119) has its tests-first proof (run.log:114, re-run at :138-139) and its review (wave3-review-report.md), but no re-run of tools/review.sh after the split is recorded.
- Not read: `packages/party_host/test/touch_targets_host_test.dart`, `host_button.dart`, the cat note (night_setup_screen.dart:62), the f2 test helpers, and the `Done` footer's own layout.
- `docs/briefs/m17/night2b/DRIVER-NOTES.md` is an uncommitted change and was not reviewed; `STATUS.md` and `run-findings.md` do not exist.
- Rendered sizes, the 9 px overflow and the "rendered text" checks were judged from code and constants, not by running.
- The wave reviews' signature checks (ShufflePicker.next, NightDirector.pick, partyNightProvider.end) were not re-opened here.

## Commit message — a draft

m17 night2b run review: findings for one fix batch

Read-only review of the whole night2b run (d2f to d2x, f1, f2) against the guidelines and
review rules, with the three wave reviews and the verdicts. Records one must, six should and
five could, and the open questions for the owner. Changes no code.

## Status row

night2b run review: done (1 must, 6 should, 5 could in REVIEW.md); open: the Done button below 48 dp and the labels below 14 dp (owner), the six fix jobs, and the d2g hand-fix's unrecorded review re-run.

## Delete

- none
