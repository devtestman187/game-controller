# k1 report: a Kids night caps the cat at "A little"

## Summary

- Owner (Nov 26): Kids nights are capped at "A little"; the last round stays cat-free; nights follow the host's saved cat setting.
- Change: `NightChaos.settingsForRound` takes `kids` (default false). With `kids` and the host's chaos at Party, the round gets Chaos.little. Off and little are unchanged, and the cap never raises a setting. The last round still sets Off.
- `_roundSettings` in puzzle_screen.dart reads `nightSettingsProvider.isKids` and passes it through.
- Tests first: the new unit tests in party_night_test.dart and the widget test in night_round_test.dart were written before the lib change. The brief marks this job tests-first: exempt, since they fail on base only because nothing caps the cat yet. I did not run them against the base to prove that.
- Test counts from mine.sh: `OK 40 tests packages/party_host`, `OK 9 tests packages/test_game`. mine.sh ran format and analyze on the packages; after the fix it reported no findings.

Computed expectations (NightChaos.settingsForRound):

| host chaos | lastRound | kids | result |
|---|---|---|---|
| party | false | true | little |
| little | false | true | little |
| off | false | true | off |
| party | false | false | party |
| party | true | true | off |

Widget test: a night round with host chaos Party and Kids plays at `Chaos.little` (PuzzlePlayView.settings().chaos).

Self-check (review-rules part A):
1. Host setups: a TV or PC host with a Kids night is covered by the widget test in night_round_test.dart; a phone host is not separately tested (the change is in shared lib code).
2. Kept state: none added. The cap is computed per round from the saved NightSettings; nothing new is stored.
3. Combinations: pause menu, host away, Get ready, dropped link, results, leaving: not changed by this job, and no test covers them.
4. Stayed inside allow: yes.
5. Stop rather than overstep: nothing stopped.
6. Looks: no UI look changed; no layout checks needed.

Line count: puzzle_screen.dart is 380 lines (was 379): +1 import, +2 in `_roundSettings` body, -2 in its dartdoc (4 lines to 2). party_night.dart is 152 lines.

## Files changed

- packages/party_host/lib/src/night/party_night.dart: `settingsForRound` gets `kids`; dartdoc updated for the Kids cap.
- packages/party_host/lib/src/ui/puzzle_screen.dart: import `night_settings.dart`; `_roundSettings` passes `kids`; dartdoc shortened to fit the 380-line limit.
- packages/party_host/test/party_night_test.dart: three new tests in the NightChaos group (Kids cap, non-Kids keeps Party, Kids last round stays Off).
- packages/party_host/test/night_round_test.dart: `openNightRound` gets `kids`; new widget test "a Kids night with the host's Chaos on Party plays at A little"; import `night_settings.dart` from src.
- packages/party_host/test/night_scoring_test.dart: not changed (no test needed there).

## Checks

- tools/mine.sh: first run failed analyze on one info (redundant `kids: false` in party_night_test.dart); fixed by removing the argument; second run: `RESULT: ok`, 8 files formatted, 2 packages analyzed and tested.
- The host suite run was part of mine.sh's touched tests (40 pass); the full host suite is run by the runner's check.

## Questions and suggestions

1. The brief says `night_scoring_test.dart` is in scope; I left it unchanged because it needs no new test for this change. Say if you want a scoring-side assertion added there.
2. Not tested: the cap on a phone host and in the pause menu or results flow. The change is in shared lib code, so it should hold there too.

## Commit message — a draft

Cap the cat at A little in Kids nights

Owner (Nov 26): Kids nights are capped at "A little", and nights follow
the host's saved cat setting. NightChaos.settingsForRound takes kids; with
it, a Party host chaos plays as little, while Off and little stay as they
are, so the cap never raises. The last round still keeps the cat away.
_roundSettings passes the night's isKids through. Tests first: unit tests
for the cap, the last round, and non-Kids nights; a widget test for a Kids
round at Party.

## Status row

Done: Kids nights cap the cat at A little (NightChaos.settingsForRound + _roundSettings), with unit and widget tests; open: no device check of the Kids night on a TV or phone.

## Delete

- none
