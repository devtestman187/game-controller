# Wave 3 review (phone1b y0h, y0h2, y0d): report

## Summary

needs Claude: 3 must, 7 should, 5 could. The three that matter most:
1. The pause test waits with a fixed `Future.delayed` to dodge the drop race, which the guidelines forbid (choice_round_pause_test.dart:169).
2. Two of the three new pause tests (the default kept, the host pick kept) pass on the old code, so they pin nothing new (choice_round_pause_test.dart:177 and :190).
3. The resume predicate still overwrites an away player's host pick during a pause, against the brief (choice_round.dart:121), and the choices overlay covers the top bar (controller_screen.dart:271).

## Findings

- **must** packages/connection/test/choice_round_pause_test.dart:169 The test waits with a fixed `Future.delayed(_insideGrace)` so the drop is seen before `pause()`, a timing fix the guidelines reject (§2 Timing fixes); brief y0h item 4 asked for a poll → poll until the round has seen phone-1 leave (e.g. until the server snapshot no longer lists it, then one event turn), or report the race to Claude.
- **must** packages/connection/test/choice_round_pause_test.dart:177 "keeps it after resume" passes on the old code: the old `resume()` re-arms the grace, the timer writes the same `save` with `byDefault: true`, and the outcome is identical → assert no change event fires during the grace after resume (the expiry adds one, `_changes.add(null)` at choice_round.dart:247), which the predicate prevents.
- **must** packages/connection/test/choice_round_pause_test.dart:190 "a host pick made during the pause survives resume" passes on the old code: `phone-2` is connected (line 68), and the old `resume()` starts timers only for unconnected players → make the picked player away before the pause, which is the case the predicate governs (see the decision below).
- **should** packages/connection/lib/src/choice_round.dart:121 The predicate skips only a default pick, so an away player's host pick made during a pause is overwritten with the default after the grace, although brief y0h says a host pick during the pause "is not overwritten" → Claude to decide (worker question 1); if kept, skip every player whose pick was set during the pause, and test an away player.
- **should** controller_app/lib/src/ui/controller_screen.dart:271 `Positioned.fill` puts the choices overlay over the whole body, including `_TopBar` (line 232), though brief y0d's repair decision says the top bar stays visible; no test covers it → place the overlay below the bar's height and test that the bar takes a tap during a round; check the leave path too (review-rules A3, leaving).
- **should** controller_app/lib/src/ui/choices_screen.dart:45 No 480 dp cap on the card column at 540 dp and wider, which brief y0d item 2 asked for (the worker's report says it is open) → wrap the column in a `ConstrainedBox` with a named max-width constant and test it at a wide size.
- **should** controller_app/lib/src/providers/choices.dart:85 `HostAway` and `HostBack` are ignored, so the round stays on top of the host-away card (`_WaitingOverlay`, controller_screen.dart:252, sits under the overlay at :271) and a tap still sends a pick to an away host (review-rules A3, "host away") → clear or hide the round on `HostAway`, or record why not, and test the pair.
- **should** controller_app/lib/src/providers/choices.dart:72 `ChoicesNotifier` is public with no dartdoc (guidelines §10); `copyWith` at line 56 too → add a dartdoc to each.
- **should** docs/protocol.md:263 The `cards` field says the title is "cut to 24 characters", but the code cuts to 24 code points (choice_round.dart:285) → say "24 code points" (worker question 4).
- **should** docs/briefs/m17/phone1b/y0d-report.md:15 The report has no review-rules part A self-check (six lines, each with its test); y0h's report has one → add it.
- **should** docs/briefs/m17/phone1b/y0h2-report.md:44 The report has no part A self-check either → add it.
- **could** controller_app/lib/src/ui/choices_screen.dart:109 A bare `1000` (ms per second) → a named `_msPerS` constant.
- **could** controller_app/lib/src/ui/choices_screen.dart:271 A result id that is not among the cards is shown raw to the child → show `PhoneText.choicesNoChoice` or a plain label instead.
- **could** packages/connection/test/choice_round_test.dart:324 The shop-round test's name says "gets Save +2 by default", but it asserts only that the player is locked, never the card or `byDefault` → assert `save` with `byDefault: true` before the pick.
- **could** packages/connection/lib/src/choice_round.dart:38 The generic connection package's dartdoc names "Save +2", a game's card → say "the build stop's default card".
- **could** controller_app/test/choices_screen_test.dart:1 No test for the clear on `ViewStarted`, a second round replacing the first, or a stale message after the end (all in the provider's contract) → add one test each.

## Decisions to confirm

- packages/party_host/lib/src/ui/games_screen_widgets.dart:99: the cards went from 340 to 294 px and the pictures from 186 to 140 px, not the brief's 308 and 154 (at 568x320, 308 + 16 + 81 = 405 is over the 392 body, so 294 is what fits); the owner must accept it.
- packages/party_host/lib/src/ui/games_screen_widgets.dart:70: outside a `HostFrame` the shop button's scale falls back to 1, a silent special case; confirm it is wanted.
- controller_app/lib/src/ui/choices_screen.dart:108: the countdown reads the phone's clock inside `build`; the brief asked for it, but review-rules B5 says a view never reads the clock; confirm for this non-game screen.
- packages/connection/lib/src/choice_round.dart:77: the `start()` assert runs only in debug builds, so a bad default is silent in release; the brief asked for an assert, so confirm that is enough.
- controller_app/test/support/fakes.dart: the feed is `choicesRound` and not `choices(msg)`, because `choices` is the stream getter (worker question 1); acceptable.
- controller_app/lib/src/host/hosting.dart:92: the host phone's own player drops `Capability.choices` (brief item 4); acceptable, and the dartdoc says why.

## Could not check

- No tests were run, and no checkout of the old commit was made (not allowed), so "passes on the old code" is read from the code paths, not run.
- The 48 dp touch-target result of y0h2 was not re-run; the 83 tests are the worker's figure.
- Whether `_TopBar` (controller_screen.dart:232) holds a leave or menu control was not read; only its mount line was.
- Whether `ChoiceRound` has a public change stream for the suggested test (finding 2) was not checked.

## Commit message — a draft

Review phone1b wave 3 (y0h, y0h2, y0d): findings report

Read-only review of the three jobs against the guidelines, the review rules
and their briefs. Verdict: needs Claude. Three must findings: a fixed delay
in the pause test, two new pause tests that pass on the old code, and the
away-player host pick that the resume predicate still overwrites. Fifteen
should and could findings with file and line are listed, plus the decisions
for Claude and the owner. Only this report changed.

## Status row

phone1b wave 3 review: done, verdict needs Claude (3 must, 7 should, 5 could); open: the must fixes, the away-player host pick decision, the top bar overlap, the 480 dp cap, and the owner's answer on the card heights.

## Delete

- none
