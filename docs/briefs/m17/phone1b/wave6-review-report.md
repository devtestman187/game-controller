# Wave 6 review (y0h7, y0h8): report

## Summary

needs Claude
Counts: must 1 · should 3 · could 1
1. Old-phone button presses are stored through the public `pick()`, so they are kept over resume, against the owner's rule that a phone's own pick is not covered (`choice_fallback.dart:151,159`).
2. A round that arrives after HostAway is shown again over the host-away card's Leave button; `_onRound` has no away check (`choices.dart:113`).
3. y0h7 report cites the wrong test for "host pick during pause" (`y0h7-report.md:55`); the `resume()` dartdoc no longer matches the rule (`choice_round.dart:114-117`).

## Findings

- **must** packages/connection/lib/src/choice_fallback.dart:151 and :159 — the old-phone fallback turns a phone's own button presses into `round.pick()` calls, so a peer-one-build-older phone's pick made during a pause is kept over resume and its player is not defaulted after a drop, which the owner rule excludes → send these presses through a store that does not mark `_pickedWhilePaused` (as `_onMessage` now does) and add a test where the old phone (`phone-2`) presses during a pause, drops, and is defaulted after resume.
- **should** controller_app/lib/src/providers/choices.dart:113 — `_onRound` has no check for "host is away", so a round received after `HostAway` (cleared at line 88-89) is shown again over the host-away card, whose Leave button (controller_app/lib/src/ui/waiting_card.dart:89) is covered by the choices overlay (controller_screen.dart:272) → drop a round while the host is away, with a test that Leave game stays tappable (the worker's own Question 1; needs a change outside the y0h8 allow list).
- **should** packages/connection/lib/src/choice_round.dart:114-117 — the `resume()` dartdoc says a player "picked during the pause" keeps their pick, but now only a host `pick()` counts → add "by pick(), not a phone's own ChoicePickMessage", as the `pick()` dartdoc does at line 136-137.
- **should** docs/briefs/m17/phone1b/y0h7-report.md:55 — "host pick made during the pause (existing test at line 203)" is wrong: line 203 is `_untilAllLocked` in the "already set to the default" test; the host-pick-during-pause tests are choice_round_pause_test.dart:158 and :219 → correct the citation.
- **could** packages/connection/test/choice_round_pause_test.dart:190-191 — the comment says the round "must see the drop", but `_untilAway` (line 118-127) only shows that the server snapshot changed → say "the server shows the drop" and keep the report's caveat.

## Decisions to confirm

- Old-phone presses (finding 1): the job treats them as host picks by the `pick()` path in the existing pause tests (`choice_round_pause_test.dart:163,250`); the owner rule says otherwise. Claude to confirm the rule for old phones.
- y0h7 decision 2: the "already away" test polls the server snapshot (real time, 2 s, `Stopwatch` at line 120) instead of a round signal; the brief asked for this, and G9 prefers fake clocks, so the real-time poll is a known deviation.
- y0h8: the three new tests pass on the code as it was before the wave (the job only moved code and added guards), so they are guards, not fail-first; the brief's standard ("fail on a broken leave path or a kept result card") is met by reasoning.
- y0h8: new tests went in `choices_screen_test.dart`, not a new file (G9); the allow list named that file, so this follows the brief.
- y0h8: `choiceCardLabel` and `ChoicesResult` are public for cross-file use (`choices_result.dart`).
- y0h8 report Q4: the two wave-5 "must" tests (already passing on the old code) are still open; the brief did not list them.

## Could not check

- The fail-first runs: I did not run the new phone-pick test on the old code. Reasoned from the code: old `pick()` put `phone-1` in `_pickedWhilePaused` (old line 145), so `resume()` started no away timer, nothing locked `phone-1`, and `_untilLocked` times out after 5 s. Not run.
- No test runs or analyzer runs by me; the counts (64 connection tests, 45 controller tests) are the workers' claims. `run-findings.md` has no entry about y0h7 or y0h8.
- Stack order of `_WaitingOverlay` and `ChoicesOverlay` in controller_screen.dart (only line 272 read).
- That `host_screen.dart:100` shows the overlay under "Show on this device" with `controls: false` (only the mount line was checked).
- Cap arithmetic: `ToySizes.space16` = 16.0 (checked); 480 + 2 × 16 = 512 (arithmetic).

## Commit message — a draft

Review wave 6 (y0h7, y0h8): findings only

Read-only review of the y0h7 (pause picks) and y0h8 (choices result card)
jobs against the guidelines, the review rules and their briefs. No code or
document changed except this report. One must finding: the old-phone
fallback (choice_fallback.dart:151,159) stores a phone's own presses as host
picks, so they survive resume. Two should findings: a round received after
HostAway is shown again (choices.dart:113), and the resume() dartdoc is out
of date. The fail-first run of the phone-pick test was not done.

## Status row

phone1b wave 6 review (y0h7, y0h8): done: both jobs reviewed, findings in the report; open: old-phone presses kept over resume (must, choice_fallback.dart:151,159), round after HostAway not dropped (choices.dart:113), fail-first run of the phone-pick test not done.

## Delete

- none
