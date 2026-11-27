# y0d report: the phone's generic choices screen

tests-first: exempt new widget with no earlier behaviour; its new test file is the first test.

## Files
- controller_app/lib/src/providers/choices.dart (new): `choicesProvider`, `ChoicesState`, `ChoicesNotifier` (pick, step, lock, undo; cleared on ViewStarted, dropped link, 3 s after the end).
- controller_app/lib/src/providers.dart: exports it.
- controller_app/lib/src/ui/choices_screen.dart (new): `ChoicesOverlay`, `ChoicesScreen` (cards, counted cards, countdown, Paused chip, lock/undo, result). Toy look tokens only; 48 dp step buttons.
- controller_app/lib/src/ui/controller_screen.dart: overlay in the Stack, pad hidden while a round shows (4 lines changed).
- controller_app/lib/src/storage.dart: `Capability.choices` in the phone's list.
- controller_app/lib/src/host/hosting.dart: `ownPlayerIdentity` drops `Capability.choices` too (dartdoc says why).
- packages/party_host/lib/src/text/phone_text.dart: choices* strings.
- controller_app/test/choices_screen_test.dart (new), test/support/fakes.dart (feeds), test/phone_metrics_test.dart (hello lists Capability.choices after view).

## Checks
tools/mine.sh: ok (format, analyze, controller_app tests, connection, party_host, protocol).

## Computed test values
Countdown: 12000 ms, phone clock 3000 -> "9 s"; paused at endsInMs 9000 stays "9 s" at clock 8000. Result hold 3000 ms (2900 ms still shown, 3100 ms gone). Counts 1,2,3 then 2,1 (capped 1..3).

## Questions
1. The brief names the feeds `choices(msg)`/`choicesEnd(msg)`, but `choices` is already the stream getter on ControllerClient, so FakeClient's feed is `choicesRound(msg)`; `choicesEnd(msg)` as named.
2. Q1 (pause freezes timers) and Q3 (tapped but unconfirmed counts) defaults are as in the brief; Q3 is a host matter, not on this screen.
3. The overlay covers the whole controller body (top bar included), not the pad area only; the brief's repair decision said the top bar stays visible and the card column is capped at 480 dp from 540 dp wide. Neither is done in this re-creation of the parked patch. Not verified by a test.

## Commit message
phone: generic choices screen with lock-in, undo and result

Add choicesProvider and ChoicesOverlay: cards, counted cards, countdown
on the phone clock, Paused chip, Lock in/Locked undo, and the result
line. The phone lists Capability.choices; the host phone's own player
does not and plays through the old-phone buttons.

## Status row
y0d: phone choices screen, provider, strings and capability done and tested; open: top bar visible and 480 dp column cap (question 3), owner answers to Q1/Q3.

## Delete
- none
