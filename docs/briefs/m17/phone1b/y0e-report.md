# y0e report: the TV lobby names players whose phone has an old app

## Summary

- The start card now shows at most one line under the player names: one old phone gets its own sentence, two or more get a count line. The line is ellipsised, so it cannot overflow the frame.
- An old phone is a connected phone whose ControllerInfo does not list `Capability.choices`. The host's own player (`isLocal`) is never listed, and a player with no phone session is not listed.
- The parked patch at `E:/AI/game-controller-m17side/.dart_tool/run-jobs/docs_briefs_m17_phone1b/parked-y0e.patch` was outside the worktree and the read was refused, so I rebuilt the change from the brief's `do:` list and the decision it records (one line, not one per phone).
- `tools/mine.sh` passes: format, analyze of party_host, and the touched tests ("OK 21 tests packages/party_host"; the script does not list which files those 21 came from, so I cannot say the new file's 9 were among them).
- Not run here: `night_start_frame_test.dart`. It is not a touched file, so `tools/mine.sh` did not run it, and the brief's `flutter test` on it was not run, since the task said to use mine.sh only. See Hand-over.

## Decisions

- `NightText.oldApp(name)` for one phone, `NightText.oldAppCount(count)` for two or more. The brief named only `oldApp`; the count line needs its own string.
- The name in the single-phone sentence is `NightText.playerName(nickname, number)`, as the names row draws it.
- `NightStartNames` takes `oldAppIds` (default `const {}`), so every existing caller is unchanged.
- `_StartColumn` takes a fourth parameter, `oldAppIds`, which is computed in `_NightStartScreenState` from `hostStateProvider`'s controllers.
- `isLocal` controllers are excluded. The brief said the player with no phone is not listed; a local player appears in the controllers list without a phone, so I excluded it by `isLocal` as well.

## Tests

New file `packages/party_host/test/night_start_old_app_test.dart`, 9 tests:
- No line when all phones list the capability (4 phones, 640x360): `find.textContaining('old app')` finds nothing.
- One old phone (Maxi, player 2) at 640x360: the text `Maxi has an old app and will play with simple buttons.` is found once.
- Two old phones: `2 players have an old app and will play with simple buttons.` is found once; no per-phone sentence.
- Three old phones (of 4): `3 players have an old app and will play with simple buttons.` is found once.
- Six players, two old (Dani, Ola), at all five device sizes (640x360, 852x393, 1024x768, 1280x800, 1920x1080): no Scrollable in the body, no exception from the frame, the count line's bottom is within the body's bottom, and both footer buttons are on screen and hit-testable.

Values used for expectations: the six names are Bartholome, Maxi, Alexandria, Chris, Dani, Ola; the seed is 7. I did not measure the pixel heights; the six-player fit is shown only by the mine run passing.

Note on the existing frame test: `phoneInfo()` in `lib/src/testing/samples.dart` sets no capabilities, so the four phones in `night_start_frame_test.dart` are all old apps and now show the count line "4 players have an old app...". That is a real change to what those tests draw. I did not run them (see Hand-over).

## Self-check (review-rules part A)

1. Host setups: TV-size and phone-size hosts are covered by the five-device loop in the new test; a joined phone that is an old build is the case the test names; a phone on "Play on this phone" or "Show on this device" is not separately tested.
2. Kept state: none added. The line is derived from the host snapshot on every build, so it starts and ends with the phones; with no old phones it is not drawn.
3. Combination with the pause menu, host away, player away, Get ready, dropped link, results and leaving: not tested. The line is a static part of the start card only.
4. Stayed in the job's folder and in `allow:`: yes, plus the report. The new test file is the only new file.
5. Stops: none.
6. Looks: the new test uses the frame builder at all five sizes, which is the look the start card draws in. The line has no fixed pixel height.

## Hand-over

- Unverified: `packages/party_host/test/night_start_frame_test.dart` was not run. Its four default phones are now old apps, so its body-fit tests now include the count line. Please run `flutter test packages/party_host/test/night_start_frame_test.dart` (or the full suite) to confirm.
- Unverified: the device check of the card at 6 players with two old phones. The test checks it in the frame, not on a device.

## Commit message — a draft

party_host: the start card names phones that are old apps (y0e)

Players whose phone does not list the choices capability are old apps and
play the rounds with simple buttons. The TV's start card now says so, in one
line under the names: one old phone gets its own sentence, two or more get a
count. The line is ellipsised, so the card never grows a line per phone.
The host's own player is not counted. The new test file covers no line, one,
two and three old phones, and a six-player night at all five frame sizes.

## Status row

phone1b y0e: done in code and new test; the start card shows one old-app line under the names (one phone named, two or more counted). Open: the existing night_start_frame_test.dart was not run here, and a device check of the six-player fit is not done.

## Delete

- none

## Questions

1. Should `night_start_frame_test.dart` be run by the runner, given its default phones are now old apps and the mine check does not run it?
2. Should `phoneInfo()` in `lib/src/testing/samples.dart` take a `capabilities` argument? It is outside `allow:`, so I did not change it; the new test builds its own ControllerInfo.
3. Is the count line's wording ("2 players have an old app...") the final owner wording for two or more?
