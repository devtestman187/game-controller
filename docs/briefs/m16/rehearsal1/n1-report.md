# M16 rehearsal1 n1 — report

## Summary

A phone whose player left the nickname blank sends its own name in the hello ("Phone AB12"). The host kept that
string, so its rows and the game's `GamePlayer.nickname` showed it, and the phone's lobby list and result card
showed it too. Now a phone-style name counts as blank everywhere:

- `isPhoneStyleName` (new, `packages/connection/lib/src/game_types.dart`) matches `^Phone [0-9A-Fa-f]{4}$` after trimming.
- `nicknameOf` returns null for it, as for a blank name. So the host's `players` rows send `''`, and
  `GamePlayer.nickname` is null. The hello still carries the phone name (the m14 test pins it), and the join
  screen is unchanged.
- `PhoneText.playerName` (`packages/party_host/lib/src/text/phone_text.dart`) shows "Player N" for it, so a result
  row from an older host reads right too.

Tests (written first, in new files; the lib change is what makes them pass):

- `packages/connection/test/phone_name_test.dart`: 2 `isPhoneStyleName` tests (true/false cases) plus, on both
  transports, the real hello path: a phone-style name gives a `players` row with `name` `''`; a phone with nickname
  'Mia' keeps 'Mia'; `game.players` nickname is null for the phone-style name.
- `controller_app/test/phone_name_display_test.dart`: in the menu look and the TV look: the lobby list shows
  "Player 2" for a `Phone AB12` row and "Mia" for a real nickname; the result card shows "Player 2" for an older
  host's `Phone AB12` standing and "Mia" as typed. Each checks `takeException()` is null. Also checks
  `phoneName(controllerId: 'ab12cd34')` == 'Phone AB12'.

Values computed for expectations: `phoneName(controllerId: 'ab12cd34')` = 'Phone AB12' (first four characters,
upper-cased). `isPhoneStyleName`: 'Phone AB12' true, ' Phone 1a2b ' true, 'Phone' false, 'Phone AB1' false,
'Phone ABCDE' false, 'Mia' false.

Fail-first: I did not measure this by reverting the lib change. On the code as it was, the connection file fails to
compile (no `isPhoneStyleName`), and the controller file would show 'Phone AB12' where it expects "Player 2".

## Screens — what each says for a phone-style name

| Screen | Before | Now |
|---|---|---|
| Phone lobby list (menu look and TV look) | "Phone AB12" | "Player N" |
| Phone result card, older host's standing | "Phone AB12" | "Player N" |
| Phone result card, newer host's standing | "" → "Player N" (unchanged) | "Player N" |
| Host rows / `GamePlayer.nickname` (TV, PC host) | "Phone AB12" | null → "P1" and the number, as for any blank name |

I checked the phone lobby and the phone result card, in both looks, with the controller test. The TV host fallback
is checked at the data level (`game.players` nickname is null); no TV widget test was run.

## Checks run

- `tools/mine.sh`: format, analyze, touched tests. Result OK: 346 connection tests, 1 party_host test, 5 controller
  tests.
- `tools/check.sh format analyze connection host phone`: PASS format, PASS analyze, PASS connection (346 tests),
  PASS host, PASS phone. (The brief names `party_host`; the suite is called `host`.)
- Not run: `tv` and `tools` suites, and the full workspace test run (the runner does it once per wave).

## Self-check (docs/review-rules.md part A)

1. Host setups: a TV or PC host sends `players` rows with the name `''` for a phone-style name (connection test
   on both transports). A phone on "Play on this phone" and "Show on this device" was not separately run; the
   change is in shared code, not in those paths. A joined phone: lobby test. A peer one build older: result-card
   test with `Phone AB12` standings.
2. Kept state: none added. No new state starts or ends.
3. Combinations with the pause menu, host away, player away, "Get ready", dropped link, results, leaving: not
   touched; the helper is a pure function.
4. Stayed inside the folder and allow list. Yes (see Files).
5. Stop: nothing to stop for. See Questions 1 and 2.
6. Every look: lobby and result card tested in the menu look and the TV look. No fixed pixel heights added.

## Files

- `packages/connection/lib/src/game_types.dart`: added `isPhoneStyleName` and a private regex; `nicknameOf` returns
  null for a phone-style name.
- `packages/connection/lib/connection.dart`: exported `isPhoneStyleName` in the `show` list (the list is now one
  name per line, because dart format wrapped it).
- `packages/connection/test/phone_name_test.dart`: new; 2 unit tests and 6 transport tests (3 per transport).
- `packages/party_host/lib/src/text/phone_text.dart`: `playerName` treats a phone-style name as blank; import adds
  `isPhoneStyleName`.
- `controller_app/test/phone_name_display_test.dart`: new; 1 unit test and 4 widget tests (2 per look).
- `docs/briefs/m16/rehearsal1/n1-report.md`: this report.

## Questions

1. **Churn revert removed uncommitted work.** `tools/mine.sh` printed "churn: reverted 3 generated file(s)". At the
   start of this job, `git status` showed three modified files: `tv_test_app/windows/flutter/generated_plugin_registrant.cc`,
   `generated_plugin_registrant.h` and `generated_plugins.cmake`. They are no longer modified, so the revert
   probably restored them to HEAD. I did not run any git command to check or undo this, and I did not touch those
   files. Please check whether those changes matter and restore them if they do.
2. **Check name.** The brief's check line says `party_host`, but the suite is `host` (`tools/check.sh --list`). I ran
   `host`. The brief or the runner's name may need fixing.
3. **Duplicate `allow:` line.** The brief lists `docs/briefs/m16/rehearsal1/n1-report.md` twice. Harmless, but
   the template may want one line.

## Suggestions

- `night_state.dart` (`packages/party_host/lib/src/night/night_state.dart:282-300`) has its own `_nicknameOf`
  that reads `GamePlayer.nickname`. It now gets null for a phone-style name, so it falls back as for any blank
  name. Not changed, since it is outside the allow list; a reviewer may want to confirm it.
- `ResultCard` and the lobby list both call `PhoneText.playerName`, so the rule lives in one place. Keep it that
  way when the rule changes.

## Commit message — a draft: a subject line under 72 characters, a blank line, then at most 8 lines on what changed and why.

```
connection, party_host: show "Player N" for a phone's own name

A phone whose player left the nickname blank sends "Phone AB12" in its
hello. The host kept that name, so the rows, the game's nickname and the
phone's lobby and result card all showed it. isPhoneStyleName now marks
it, nicknameOf treats it as blank, and PhoneText.playerName shows
"Player N" for it, which also reads right from a host one build older.
The hello keeps sending the phone name. Tests in new files, both looks.

Co-Authored-By: Claude Haiku 5.5 <noreply@anthropic.com>
```

## Status row — one line for the milestone's STATUS.md: what is now done, and what is open.

M16 rehearsal1 n1: done — phone-style names ("Phone AB12") show as "Player N" in the phone lobby and result card, and the host sends a blank name for them; open — the churn revert of three tv_test_app generated files (see Question 1), and no TV widget test for the host fallback.

## Delete

- none
