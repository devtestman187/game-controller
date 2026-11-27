# night2c v2 report: the night director is the default picker

tests-first: exempt, a default changes; the tests that pinned the old default went red and were then fixed.

## Files changed
- `lib/src/night/night_settings.dart`: `NightSettings.picker` default is `NightPicker.director` (so `kids` is director too); enum docs. Loading is untouched.
- `lib/src/text/night_setup_text.dart`: director help "The usual way: the night director picks each game and says why."; host help "You choose each game yourself, every time."
- `test/support/host_harness.dart`: `HostPicksNightSettings`, `hostPicksOverride`; `pumpHost` applies it before the caller's overrides, new `hostPicks` parameter (default true).
- `test/support/night_harness.dart`: `nightContainer` applies `hostPicksOverride`.
- `night_settings_test.dart`: default and Kids picker are director; new test: a saved `host` loads as host, a JSON with no picker key loads the director default.
- `night_setup_screen_test.dart`: host start card test pins host; director tests drop the now redundant argument; new test "the app default, with nothing saved, is the director start card".
- `night_pick_test.dart`, `night_pick_open_test.dart`, `night_how_to_reason_test.dart`: pin host where the test is about host picking; drop redundant `picker: director`.
- `night_round_test.dart`: the Kids helper now goes through the director's start button with `Random(1)` (see computed values).

## Computed values
- `_kidsShapeRaceSeed = 1`: found by running; with the Kids preset and `Random(1)` the director's first pick is a Shape Race round (the Kids pool is `shapeRace:easy` or `bumperRound:pinball`).

## Checks
- `tools/mine.sh`: OK, 124 tests in the touched files, format and analyze clean. The full `flutter test` in packages/party_host was not run to the end by me; mine.sh ran the touched test files only.
- Most of the ~21 listed files needed no edit: the harness override covers them.

## Questions / suggestions
1. The brief says the harness override sits before the caller's, so a test can still override. Riverpod asserts "overrode a provider twice", so that fails. I added `pumpHost(hostPicks: false)` instead; `pumpHostLook` (all_looks.dart, not in my allow) does not forward it, so the new default test runs on the menu look only, not every look.
2. `NightSettings.isKids` is `this == kids`, and `kids` now has the director picker. A Kids night saved by an older build (picker `host`) is no longer `isKids`, so `puzzle_screen.dart:258` stops capping its Chaos at "A little" and the setup screen's Kids button shows unselected. That conflicts with "saved settings keep their value". Needs an owner decision (for example `isKids` ignoring the picker); not done, outside the job.
3. A JSON missing the picker key is treated as broken by `tryFromJson` (whole save dropped, defaults used, which are now director). The result is the same as the brief asks for, but other saved fields are lost.

## Commit message
night2c v2: the night director is the default picker

NightSettings.picker now defaults to the director; a saved picker (host
included) still loads as saved. Setup help text says the director is the
usual way. The host and night harnesses pin the host picker so the
host-picks tests keep their start card; the tests that asserted the old
default are updated, with new tests for a saved host and the app default.

## Status row
night2c v2: director is the default picker, tests and help text updated; open: isKids for older saved Kids nights (picker host), default test not run on every look.

## Delete
- none
