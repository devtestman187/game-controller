## Summary

Added `NightFlowController`, `NightPacing`, `NightSchedule`, `NightRoundHooks` and the three providers. The controller auto-advances a night and emits NightEvents.
`tools/mine.sh`: OK, 22 tests in packages/party_host (format, analyze and tests clean). Which tests are new is not measured.

Files:
- lib/src/night/night_flow_controller.dart (new, about 215 lines): controller, pacing, hooks, schedule.
- lib/src/night/night_flow_provider.dart (new): pacing, schedule and controller providers.
- test/night_flow_controller_test.dart (new): 16 tests on a fake clock.
- test/night_flow_provider_test.dart (new): 5 tests.
- test/support/night_harness.dart: `nightContainer` takes an optional `overrides` list.

Computed values: default gap scoreboard to next round started = 8 s + 6 s = 14 s (under 15 s); how-to 6 s (5 to 10 s); events of a 3-round night = 1 + 3*4 + doubled 1 + ceremony + ended = 16 (5 rounds = 24).

## Decisions
- `NightPacing` has a const constructor, and a `Duration` cannot be compared in a const expression (the analyzer rejects it). So the 5 to 10 s and under-15 s rules are the getter `isPlayable`, and both controller constructors assert it.
- `pacing` and `onEvent` are public final fields, because the `prefer_initializing_formals` lint asked for it.
- `startNow` at the last round's scoreboard does nothing and leaves the ceremony timer waiting. NightFlow rejects a how-to card past the last round.
- `startNow` from setup after `begin` cancels the setup timer and goes straight to how-to then started.
- The provider test with a fake schedule checks that `begin` asks for the setup pause and that ending the night disposes the controller.

## Self-check
1. Host setups: not applicable, the controller is plain Dart. The provider tests show a new night and a resumed night.
2. State starts at `begin` and ends at NightEnded or `dispose`: the 3-round run and the dispose test.
3. Pause menu, host away and the rest belong to n1g. A dropped link has no hook here. Leaving: dispose test.
4. Only the allowed files changed.
5. No stop was needed.
6. No UI: not applicable.

## Hand-over
Job n1g adds pause, skip, reroll, join and leave to this file. The file now has about 215 lines.

## Commit message
night1c n1f: night flow controller auto-advances rounds

NightFlowController steps a night through setup, how-to, round,
results, scoreboard and ceremony on injected timers, emitting
NightEvents. A resumed night replays played rounds silently.
Providers build it from partyNightProvider.

## Status row
n1f done: auto-advance controller and providers with tests; open: pause, skip, reroll, join and leave (n1g).

## Delete
- none
